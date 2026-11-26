// ============================================
// src/controllers/importexport.controller.js
// Import Excel & Export PDF/Excel
// ============================================
'use strict';

const XLSX = require('@e965/xlsx');
const { query, transaction } = require('../config/db');
const { success, error } = require('../utils/response');
const logger = require('../utils/logger');
const fs = require('fs');
const path = require('path');

// ── Mapping colonnes Excel → champs DB ───────────────────────────────────────
const COLUMN_MAP = {
  // Identification
  'nom machine':              'asset_tag',
  'nom_machine':              'asset_tag',
  'asset tag':                'asset_tag',
  'tag':                      'asset_tag',
  'n° serie':                 'serial_number',
  'serial':                   'serial_number',
  'numero de serie':          'serial_number',
  'numero serie':             'serial_number',
  'marque':                   'marque',
  'modele':                   'modele',
  'type':                     'type',
  'statut cycle de vie':      'statut',
  'statut':                   'statut',
  'site / localisation':      'site',
  'site':                     'site',
  'departement':              'departement',
  'notes':                    'notes',
  // Specs
  'ram':                      'ram',
  'stockage':                 'stockage',
  'cpu':                      'cpu',
  'processeur':               'cpu',
  'os':                       'os',
  'systeme':                  'os',
  'version os':               'version_os',
  'mac wifi / mac ethernet':  'mac_address',
  'mac':                      'mac_address',
  'adresse mac':              'mac_address',
  'imei telephone':           'imei',
  'imei':                     'imei',
  'numero imei':              'imei',
  'ip':                       'ip_address',
  'adresse ip':               'ip_address',
  'hostname':                 'hostname',
  // Sécurité
  'defender actif (oui/non)': 'defender',
  'defender':                 'defender',
  'edr':                      'edr',
  'intune':                   'intune',
  'entra id join (oui/non)':  'entra_id',
  'entra id':                 'entra_id',
  'entra_id':                 'entra_id',
  'bitlocker':                'bitlocker',
  'onedrive actif (oui/non)': 'onedrive',
  'onedrive':                 'onedrive',
  // Coûts & Traçabilité
  'prix':                     'prix',
  'fournisseur':              'fournisseur',
  'bon de commande':          'bon_commande',
  'bon commande':             'bon_commande',
  'bon_commande':             'bon_commande',
  'date d’acquisition':       'date_acquisition',
  'date d\'acquisition':      'date_acquisition',
  'date acquisition':         'date_acquisition',
  'date achat':               'date_acquisition',
  'fin garantie':             'fin_garantie',
  'garantie':                 'fin_garantie',
  'date retrait / reforme':   'date_retrait',
  'retrait':                  'date_retrait',
  'immobilisation':           'notes',
  // Utilisateur & Affectation
  'utilisateur actuel':       'utilisateur',
  'utilisateur':              'utilisateur',
  'nom utilisateur':          'utilisateur',
  'date d’attribution':       'date_attribution',
  'date d\'attribution':      'date_attribution',
  'date attribution':         'date_attribution',
  'ancien utilisateur':       'notes',
};

const TYPE_MAP = {
  'laptop': 'laptop', 'portable': 'laptop', 'notebook': 'laptop',
  'desktop': 'desktop', 'tour': 'desktop', 'pc': 'desktop',
  'écran': 'ecran', 'ecran': 'ecran', 'moniteur': 'ecran',
  'imprimante': 'imprimante', 'printer': 'imprimante',
  'scanner': 'scanner',
  'téléphone': 'telephone', 'telephone': 'telephone', 'phone': 'telephone',
  'tablette': 'tablette', 'tablet': 'tablette',
  'pax': 'pax_terminal', 'terminal': 'pax_terminal', 'pax a920': 'pax_terminal',
  'serveur': 'serveur', 'server': 'serveur',
  'switch': 'switch', 'commutateur': 'switch',
  'routeur': 'routeur', 'router': 'routeur',
};

const NOMENCLATURE_REGEX = /^[A-Z0-9]{2,12}-[A-Z0-9]{2,10}-[A-Z0-9]{2,12}-[A-Z0-9_]{2,20}$/i;

const STATUT_MAP = {
  'en service': 'en_service', 'actif': 'en_service', 'active': 'en_service',
  'hors service': 'hors_service', 'hs': 'hors_service', 'inactif': 'hors_service',
  'réformé': 'reforme', 'reforme': 'reforme', 'retraité': 'reforme',
  'maintenance': 'en_maintenance', 'en maintenance': 'en_maintenance',
  'stock': 'en_stock', 'en stock': 'en_stock',
};

function normalizeKey(key) {
  return (key || '').toString().toLowerCase().trim()
    .replace(/\s+/g, ' ')
    .replace(/[éèêë]/g, 'e')
    .replace(/[àâä]/g, 'a')
    .replace(/[ùûü]/g, 'u')
    .replace(/[îï]/g, 'i')
    .replace(/[ôö]/g, 'o')
    .replace(/[ç]/g, 'c');
}

function parseBool(val) {
  if (val === null || val === undefined || val === '') return 0;
  const s = val.toString().toLowerCase().trim();
  return ['oui', 'yes', '1', 'true', 'ok', 'actif', 'active', 'x'].includes(s) ? 1 : 0;
}

function parseDate(val) {
  if (!val) return null;
  if (val instanceof Date) return val.toISOString().split('T')[0];
  // Excel serial date
  if (typeof val === 'number') {
    const d = new Date(Math.round((val - 25569) * 86400 * 1000));
    return d.toISOString().split('T')[0];
  }
  const s = val.toString().trim();
  // DD/MM/YYYY
  const m = s.match(/^(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{2,4})$/);
  if (m) {
    const y = m[3].length === 2 ? '20' + m[3] : m[3];
    return `${y}-${m[2].padStart(2,'0')}-${m[1].padStart(2,'0')}`;
  }
  return s || null;
}

/**
 * POST /api/import/excel
 */
async function importExcel(req, res) {
  if (!req.file) return error(res, 'Fichier Excel requis', 400);

  try {
    const wb = XLSX.readFile(req.file.path);
    const sheetName = wb.SheetNames[0];
    const ws = wb.Sheets[sheetName];
    
    // Lire le fichier sous forme de tableau 2D (lignes/colonnes)
    const rowsRaw = XLSX.utils.sheet_to_json(ws, { header: 1, defval: '' });

    if (!rowsRaw.length) return error(res, 'Le fichier est vide ou le format est incorrect', 400);

    // Détecter automatiquement la ligne d'en-tête
    let headerRowIndex = -1;
    let colMap = {};

    console.log('--- EXCEL IMPORT DEBUG ---');
    console.log('Total rows found in sheet:', rowsRaw.length);

    // Parcourir les 10 premières lignes pour trouver les en-têtes
    for (let r = 0; r < Math.min(rowsRaw.length, 10); r++) {
      const row = rowsRaw[r];
      if (!row || !row.length) continue;

      const tempMap = {};
      let matchCount = 0;

      row.forEach((cell, colIndex) => {
        if (cell === undefined || cell === null) return;
        const norm = normalizeKey(cell.toString());
        if (COLUMN_MAP[norm]) {
          tempMap[colIndex] = COLUMN_MAP[norm];
          matchCount++;
        }
      });

      // Si on trouve au moins "asset_tag" + une autre colonne, ou au moins 2 colonnes valides
      if (matchCount >= 2 || (matchCount >= 1 && Object.values(tempMap).includes('asset_tag'))) {
        headerRowIndex = r;
        colMap = tempMap;
        console.log(`Header row found at index ${r} (Excel line ${r + 1})`);
        console.log('Detected columns:', colMap);
        break;
      }
    }

    if (headerRowIndex === -1) {
      fs.unlink(req.file.path, () => {});
      return error(res, 'Impossible de trouver les en-têtes de colonnes requis (ex: asset tag, marque, type) dans le fichier.', 400);
    }

    let imported = 0, skipped = 0, errors = [], warnings = [], created = 0, updated = 0;
    const totalDataRows = rowsRaw.length - (headerRowIndex + 1);

    for (let i = headerRowIndex + 1; i < rowsRaw.length; i++) {
      const row = rowsRaw[i];
      if (!row || !row.length) {
        skipped++;
        continue;
      }

      try {
        const mapped = {};
        Object.entries(colMap).forEach(([colIndexStr, field]) => {
          const colIndex = parseInt(colIndexStr);
          mapped[field] = row[colIndex] !== undefined && row[colIndex] !== null ? row[colIndex] : '';
        });

        if (!mapped.asset_tag) { skipped++; continue; }

        const asset_tag = mapped.asset_tag.toString().trim().toUpperCase();
        if (!asset_tag) { skipped++; continue; }

        if (!NOMENCLATURE_REGEX.test(asset_tag)) {
          warnings.push({
            ligne: i + 1,
            asset_tag,
            message: 'Nomenclature non conforme (attendu : ÉQUIPEMENT-SOCIÉTÉ-DÉPARTEMENT-NOM, ex: PC-CC-IT-YVES)'
          });
        }

        // Normaliser type et statut
        const rawType = normalizeKey(mapped.type || '');
        const type = TYPE_MAP[rawType] || 'autre';
        const rawStatut = normalizeKey(mapped.statut || '');
        const statut = STATUT_MAP[rawStatut] || 'en_service';

        await transaction(async (conn) => {
          // Vérifier si l'asset existe déjà
          const [exists] = await conn.execute(
            'SELECT id FROM assets WHERE `Nom Machine` = ? LIMIT 1',
            [asset_tag]
          );

          let assetId;
          if (exists.length) {
            assetId = exists[0].id;
            await conn.execute(`
              UPDATE assets SET serial_number=?, marque=?, modele=?, type=?, statut=?,
                site=?, departement=?, notes=?, updated_at=NOW()
              WHERE id=?
            `, [mapped.serial_number||null, mapped.marque||null, mapped.modele||null,
                type, statut, mapped.site||null, mapped.departement||null,
                mapped.notes||null, assetId]);
            updated++;
          } else {
            const [r] = await conn.execute(`
              INSERT INTO assets (\`Nom Machine\`, serial_number, marque, modele, type, statut, site, departement, notes)
              VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            `, [asset_tag, mapped.serial_number||null, mapped.marque||null,
                mapped.modele||null, type, statut, mapped.site||null,
                mapped.departement||null, mapped.notes||null]);
            assetId = r.insertId;
            created++;
          }

          // Specs
          if (mapped.ram || mapped.cpu || mapped.os || mapped.stockage || mapped.imei) {
            await conn.execute(`
              INSERT INTO specs (asset_id, ram, stockage, cpu, os, version_os, mac_address, imei, ip_address, hostname)
              VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
              ON DUPLICATE KEY UPDATE
                ram=VALUES(ram), stockage=VALUES(stockage), cpu=VALUES(cpu),
                os=VALUES(os), version_os=VALUES(version_os),
                mac_address=VALUES(mac_address), imei=VALUES(imei), ip_address=VALUES(ip_address),
                hostname=VALUES(hostname)
            `, [assetId, mapped.ram||null, mapped.stockage||null, mapped.cpu||null,
                mapped.os||null, mapped.version_os||null, mapped.mac_address||null,
                mapped.imei||null, mapped.ip_address||null, mapped.hostname||null]);
          }

          // Sécurité
          if (mapped.defender !== undefined || mapped.intune !== undefined) {
            await conn.execute(`
              INSERT INTO securite (asset_id, defender, edr, intune, entra_id, bitlocker, onedrive)
              VALUES (?, ?, ?, ?, ?, ?, ?)
              ON DUPLICATE KEY UPDATE
                defender=VALUES(defender), edr=VALUES(edr), intune=VALUES(intune),
                entra_id=VALUES(entra_id), bitlocker=VALUES(bitlocker), onedrive=VALUES(onedrive)
            `, [assetId, parseBool(mapped.defender), parseBool(mapped.edr),
                parseBool(mapped.intune), parseBool(mapped.entra_id),
                parseBool(mapped.bitlocker), parseBool(mapped.onedrive)]);
          }

          // Coûts
          if (mapped.prix || mapped.fournisseur || mapped.fin_garantie) {
            const prix = mapped.prix ? parseFloat(mapped.prix.toString().replace(/[^0-9.,]/g,'').replace(',','.')) : null;
            await conn.execute(`
              INSERT INTO couts (asset_id, prix, fournisseur, bon_commande, date_acquisition, fin_garantie)
              VALUES (?, ?, ?, ?, ?, ?)
              ON DUPLICATE KEY UPDATE
                prix=VALUES(prix), fournisseur=VALUES(fournisseur),
                bon_commande=VALUES(bon_commande), date_acquisition=VALUES(date_acquisition),
                fin_garantie=VALUES(fin_garantie)
            `, [assetId, prix, mapped.fournisseur||null, mapped.bon_commande||null,
                parseDate(mapped.date_acquisition), parseDate(mapped.fin_garantie)]);
          }

          // Liaison utilisateur / affectation active
          if (mapped.utilisateur) {
            const userVal = mapped.utilisateur.toString().trim();
            if (userVal) {
              let userId = null;
              if (userVal.includes('@')) {
                const [users] = await conn.execute(
                  'SELECT id FROM utilisateurs WHERE LOWER(email) = ? LIMIT 1',
                  [userVal.toLowerCase()]
                );
                if (users.length) userId = users[0].id;
              } else {
                const searchVal = `%${userVal.toLowerCase()}%`;
                const [users] = await conn.execute(
                  `SELECT id FROM utilisateurs 
                   WHERE LOWER(CONCAT(prenom, ' ', nom)) = ? 
                      OR LOWER(CONCAT(nom, ' ', prenom)) = ? 
                      OR LOWER(nom) = ? 
                      OR LOWER(CONCAT(prenom, ' ', nom)) LIKE ?
                      OR LOWER(CONCAT(nom, ' ', prenom)) LIKE ? 
                   LIMIT 1`,
                  [userVal.toLowerCase(), userVal.toLowerCase(), userVal.toLowerCase(), searchVal, searchVal]
                );
                if (users.length) userId = users[0].id;
              }

              if (userId) {
                const [activeAff] = await conn.execute(
                  'SELECT id, user_id FROM affectations WHERE asset_id = ? AND actif = 1 LIMIT 1',
                  [assetId]
                );

                if (activeAff.length) {
                  if (activeAff[0].user_id !== userId) {
                    // Désactiver l'ancienne affectation
                    await conn.execute(
                      'UPDATE affectations SET actif = 0, date_retrait = NOW() WHERE id = ?',
                      [activeAff[0].id]
                    );
                    // Créer la nouvelle affectation
                    await conn.execute(
                      'INSERT INTO affectations (asset_id, user_id, date_attribution, motif, actif) VALUES (?, ?, NOW(), ?, 1)',
                      [assetId, userId, 'Import Excel (Mise à jour)']
                    );
                  }
                } else {
                  // Aucune affectation active, en créer une
                  await conn.execute(
                    'INSERT INTO affectations (asset_id, user_id, date_attribution, motif, actif) VALUES (?, ?, NOW(), ?, 1)',
                    [assetId, userId, 'Import Excel (Création)']
                  );
                }
              }
            }
          }
        });

        imported++;
      } catch (rowErr) {
        errors.push({ ligne: i + 1, erreur: rowErr.message });
        skipped++;
      }
    }

    // Supprimer le fichier uploadé
    fs.unlink(req.file.path, () => {});

    await query(
      'INSERT INTO activity_logs (user_id, action, entity_type, details) VALUES (?, ?, ?, ?)',
      [req.user.id, 'IMPORT_EXCEL', 'asset', JSON.stringify({ imported, created, updated, skipped, total: totalDataRows })]
    );

    return success(res, { created, updated, skipped, errors, warnings, total: totalDataRows },
      `Import terminé: ${imported} machines traitées (${created} créées, ${updated} mises à jour)`);
  } catch (err) {
    logger.error('Erreur import Excel:', err);
    if (req.file) fs.unlink(req.file.path, () => {});
    return error(res, 'Erreur lors de l\'import: ' + err.message, 500);
  }
}

/**
 * GET /api/export/excel
 */
async function exportExcel(req, res) {
  try {
    const { type, statut, site, departement } = req.query;
    const conditions = ['a.deleted_at IS NULL'];
    const params = [];
    if (type)        { conditions.push('a.type = ?');        params.push(type); }
    if (statut)      { conditions.push('a.statut = ?');      params.push(statut); }
    if (site)        { conditions.push('a.site = ?');        params.push(site); }
    if (departement) { conditions.push('a.departement = ?'); params.push(departement); }

    const assets = await query(`
      SELECT
        a.\`Nom Machine\` AS "Asset Tag",
        a.serial_number AS "N° Série",
        a.marque AS "Marque",
        a.modele AS "Modèle",
        a.type AS "Type",
        a.statut AS "Statut",
        a.site AS "Site",
        a.departement AS "Département",
        CONCAT(u.prenom, ' ', u.nom) AS "Utilisateur Actuel",
        u.email AS "Email Utilisateur",
        s.ram AS "RAM",
        s.stockage AS "Stockage",
        s.cpu AS "CPU",
        s.os AS "Système d'exploitation",
        s.version_os AS "Version OS",
        s.mac_address AS "Adresse MAC",
        s.imei AS "Numéro IMEI",
        s.ip_address AS "Adresse IP",
        s.hostname AS "Hostname",
        CASE WHEN sec.defender=1 THEN 'Oui' ELSE 'Non' END AS "Defender",
        CASE WHEN sec.edr=1 THEN 'Oui' ELSE 'Non' END AS "EDR",
        CASE WHEN sec.intune=1 THEN 'Oui' ELSE 'Non' END AS "Intune",
        CASE WHEN sec.entra_id=1 THEN 'Oui' ELSE 'Non' END AS "Entra ID",
        CASE WHEN sec.bitlocker=1 THEN 'Oui' ELSE 'Non' END AS "BitLocker",
        CASE WHEN sec.onedrive=1 THEN 'Oui' ELSE 'Non' END AS "OneDrive",
        c.prix AS "Prix (XOF)",
        c.fournisseur AS "Fournisseur",
        c.bon_commande AS "Bon de commande",
        c.date_acquisition AS "Date acquisition",
        c.fin_garantie AS "Fin garantie",
        a.notes AS "Notes",
        a.created_at AS "Date création",
        a.updated_at AS "Dernière modification"
      FROM assets a
      LEFT JOIN affectations af ON af.asset_id = a.id AND af.actif = 1
      LEFT JOIN utilisateurs u ON u.id = af.user_id
      LEFT JOIN specs s ON s.asset_id = a.id
      LEFT JOIN securite sec ON sec.asset_id = a.id
      LEFT JOIN couts c ON c.asset_id = a.id
      WHERE ${conditions.join(' AND ')}
      ORDER BY a.type, a.site, a.\`Nom Machine\`
    `, params);

    const wb = XLSX.utils.book_new();
    const ws = XLSX.utils.json_to_sheet(assets);

    // Style largeurs colonnes
    ws['!cols'] = [
      {wch:15},{wch:20},{wch:12},{wch:25},{wch:12},{wch:14},
      {wch:12},{wch:15},{wch:25},{wch:28},{wch:10},{wch:18},
      {wch:25},{wch:20},{wch:10},{wch:18},{wch:18},{wch:15},{wch:20}, // inserted wch:18 for IMEI
      {wch:8},{wch:8},{wch:8},{wch:10},{wch:10},{wch:10},
      {wch:14},{wch:18},{wch:18},{wch:16},{wch:14},
      {wch:25},{wch:18},{wch:20},
    ];

    XLSX.utils.book_append_sheet(wb, ws, 'Inventaire');

    const filename = `inventaire_parc_it_${new Date().toISOString().split('T')[0]}.xlsx`;
    const buffer = XLSX.write(wb, { type: 'buffer', bookType: 'xlsx' });

    res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
    res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    res.send(buffer);

    await query(
      'INSERT INTO activity_logs (user_id, action, entity_type, details) VALUES (?, ?, ?, ?)',
      [req.user.id, 'EXPORT_EXCEL', 'asset', JSON.stringify({ count: assets.length, filters: { type, statut, site, departement } })]
    );
  } catch (err) {
    logger.error('Erreur export Excel:', err);
    return error(res, 'Erreur lors de l\'export', 500);
  }
}

function parseWorkbookRows(filePath) {
  const wb = XLSX.readFile(filePath);
  const sheetName = wb.SheetNames[0];
  const ws = wb.Sheets[sheetName];
  const rowsRaw = XLSX.utils.sheet_to_json(ws, { header: 1, defval: '' });
  if (!rowsRaw.length) return { errorMsg: 'Le fichier est vide ou le format est incorrect' };

  let headerRowIndex = -1;
  let colMap = {};
  for (let r = 0; r < Math.min(rowsRaw.length, 10); r++) {
    const row = rowsRaw[r];
    if (!row || !row.length) continue;
    const tempMap = {};
    let matchCount = 0;
    row.forEach((cell, colIndex) => {
      if (cell === undefined || cell === null) return;
      const norm = normalizeKey(cell.toString());
      if (COLUMN_MAP[norm]) {
        tempMap[colIndex] = COLUMN_MAP[norm];
        matchCount++;
      }
    });
    if (matchCount >= 2 || (matchCount >= 1 && Object.values(tempMap).includes('asset_tag'))) {
      headerRowIndex = r;
      colMap = tempMap;
      break;
    }
  }

  if (headerRowIndex === -1) {
    return { errorMsg: 'Impossible de trouver les en-têtes de colonnes requis (ex: Nom Machine, marque, type) dans le fichier.' };
  }
  return { rowsRaw, headerRowIndex, colMap };
}

/**
 * POST /api/importexport/import/preview
 * Pré-validation sans écriture en base (CSV / XLSX / XLS)
 */
async function previewExcel(req, res) {
  if (!req.file) return error(res, 'Fichier requis', 400);
  try {
    const parsed = parseWorkbookRows(req.file.path);
    fs.unlink(req.file.path, () => {});
    if (parsed.errorMsg) return error(res, parsed.errorMsg, 400);

    const { rowsRaw, headerRowIndex, colMap } = parsed;
    const seenTags = new Set();
    const preview = [];

    for (let i = headerRowIndex + 1; i < rowsRaw.length; i++) {
      const row = rowsRaw[i];
      if (!row || !row.length || row.every((c) => c === '' || c === null || c === undefined)) continue;

      const mapped = {};
      Object.entries(colMap).forEach(([colIndexStr, field]) => {
        const colIndex = parseInt(colIndexStr, 10);
        mapped[field] = row[colIndex] !== undefined && row[colIndex] !== null ? row[colIndex] : '';
      });

      const tag = (mapped.asset_tag || '').toString().trim().toUpperCase();
      const messages = [];
      let status = 'valid';

      if (!tag) {
        status = 'error';
        messages.push('Nom Machine manquant (ligne ignorée)');
      } else {
        if (!NOMENCLATURE_REGEX.test(tag)) {
          status = 'warning';
          messages.push('Nomenclature non conforme (attendu : ÉQUIPEMENT-SOCIÉTÉ-DÉPARTEMENT-NOM)');
        }
        if (seenTags.has(tag)) {
          if (status === 'valid') status = 'warning';
          messages.push('Doublon dans le fichier (sera mis à jour)');
        }
        seenTags.add(tag);
      }

      preview.push({
        line: i + 1,
        asset_tag: tag || '—',
        marque: (mapped.marque || '—').toString(),
        modele: (mapped.modele || '—').toString(),
        type: (mapped.type || 'autre').toString(),
        site: (mapped.site || '—').toString(),
        departement: (mapped.departement || '—').toString(),
        status,
        messages,
      });
    }

    return success(res, { rows: preview, total: preview.length }, 'Pré-validation terminée');
  } catch (err) {
    if (req.file) fs.unlink(req.file.path, () => {});
    logger.error('Erreur preview Excel:', err);
    return error(res, 'Erreur lors de la pré-validation: ' + err.message, 500);
  }
}

module.exports = { importExcel, previewExcel, exportExcel };
