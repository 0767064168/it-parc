// ============================================
// src/models/asset.model.js — Requêtes Assets
// ============================================
'use strict';

const { query, transaction } = require('../config/db');

/**
 * Liste paginée des assets avec filtres
 */
async function findAll({ page = 1, limit = 20, type, statut, site, departement, search, archived = false }) {
  const offset = (page - 1) * limit;
  const conditions = [archived ? 'a.deleted_at IS NOT NULL' : 'a.deleted_at IS NULL'];
  const params = [];

  if (type)        { conditions.push('a.type = ?');         params.push(type); }
  if (statut)      { conditions.push('a.statut = ?');       params.push(statut); }
  if (site)        { conditions.push('a.site = ?');         params.push(site); }
  if (departement) { conditions.push('a.departement = ?'); params.push(departement); }
  if (search) {
    conditions.push('(a.`Nom Machine` LIKE ? OR a.serial_number LIKE ? OR a.marque LIKE ? OR a.modele LIKE ? OR CONCAT(u.nom, " ", u.prenom) LIKE ?)');
    const s = `%${search}%`;
    params.push(s, s, s, s, s);
  }

  const where = conditions.join(' AND ');

  const countSql = `
    SELECT COUNT(DISTINCT a.id) as total
    FROM assets a
    LEFT JOIN affectations af ON af.asset_id = a.id AND af.actif = 1
    LEFT JOIN utilisateurs u ON u.id = af.user_id
    WHERE ${where}
  `;
  const [{ total }] = await query(countSql, params);

  const sql = `
    SELECT
      a.id, a.\`Nom Machine\` as asset_tag, a.serial_number, a.marque, a.modele,
      a.type, a.statut, a.site, a.departement, a.created_at, a.updated_at, a.deleted_at, a.notes,
      CONCAT(u.prenom, ' ', u.nom) as utilisateur_actuel,
      u.email as utilisateur_email,
      s.os, s.version_os,
      c.fin_garantie,
      CASE
        WHEN c.fin_garantie IS NOT NULL AND c.fin_garantie < CURDATE() THEN 'expiree'
        WHEN c.fin_garantie IS NOT NULL AND c.fin_garantie <= DATE_ADD(CURDATE(), INTERVAL 90 DAY) THEN 'proche'
        ELSE 'ok'
      END as statut_garantie
    FROM assets a
    LEFT JOIN affectations af ON af.asset_id = a.id AND af.actif = 1
    LEFT JOIN utilisateurs u ON u.id = af.user_id
    LEFT JOIN specs s ON s.asset_id = a.id
    LEFT JOIN couts c ON c.asset_id = a.id
    WHERE ${where}
    ORDER BY a.updated_at DESC, a.id DESC
    LIMIT ? OFFSET ?
  `;

  const assets = await query(sql, [...params, parseInt(limit), offset]);
  return { assets, total };
}

/**
 * Fiche complète d'un asset (toutes les sections)
 */
async function findById(id, includeArchived = false) {
  const [asset] = await query(`
    SELECT a.*, a.\`Nom Machine\` as asset_tag,
      CONCAT(u.prenom, ' ', u.nom) as utilisateur_actuel,
      u.departement as utilisateur_departement,
      u.email as utilisateur_email,
      u.telephone as utilisateur_telephone,
      u.site as utilisateur_site
    FROM assets a
    LEFT JOIN affectations af ON af.asset_id = a.id AND af.actif = 1
    LEFT JOIN utilisateurs u ON u.id = af.user_id
    WHERE a.id = ? ${includeArchived ? '' : 'AND a.deleted_at IS NULL'}
  `, [id]);

  if (!asset) return null;

  const [specs] = await query('SELECT * FROM specs WHERE asset_id = ?', [id]);
  const [securite] = await query('SELECT * FROM securite WHERE asset_id = ?', [id]);
  const [couts] = await query('SELECT * FROM couts WHERE asset_id = ?', [id]);
  const affectations = await query(`
    SELECT af.*,
      CONCAT(u.prenom, ' ', u.nom) as utilisateur_nom,
      u.departement, u.site, u.email
    FROM affectations af
    JOIN utilisateurs u ON u.id = af.user_id
    WHERE af.asset_id = ?
    ORDER BY af.date_attribution DESC
  `, [id]);

  const tickets = await query(`
    SELECT t.id, t.numero, t.titre, t.type, t.priorite, t.statut, t.created_at,
           CONCAT(u.prenom, ' ', u.nom) as technicien_nom
    FROM tickets t
    LEFT JOIN auth_users u ON u.id = t.technicien_id
    WHERE t.asset_id = ?
    ORDER BY t.created_at DESC
  `, [id]);

  const maintenances = await query(`
    SELECT m.id, m.type, m.date_prevue, m.date_realisee, m.description, m.cout, m.statut,
           CONCAT(u.prenom, ' ', u.nom) as tech_nom
    FROM maintenances m
    LEFT JOIN auth_users u ON u.id = m.technicien_id
    WHERE m.asset_id = ?
    ORDER BY m.date_prevue DESC
  `, [id]);

  return { 
    ...asset, 
    specs: specs || {}, 
    securite: securite || {}, 
    couts: couts || {}, 
    affectations,
    tickets,
    maintenances
  };
}

/**
 * Recherche full-text
 */
async function search(q, limit = 20) {
  const s = `%${q}%`;
  return query(`
    SELECT a.id, a.\`Nom Machine\` as asset_tag, a.serial_number, a.marque, a.modele,
           a.type, a.statut, a.site, a.departement,
           CONCAT(u.prenom, ' ', u.nom) as utilisateur_actuel
    FROM assets a
    LEFT JOIN affectations af ON af.asset_id = a.id AND af.actif = 1
    LEFT JOIN utilisateurs u ON u.id = af.user_id
    WHERE a.deleted_at IS NULL
      AND (a.\`Nom Machine\` LIKE ? OR a.serial_number LIKE ? OR a.marque LIKE ?
           OR a.modele LIKE ? OR CONCAT(u.nom, ' ', u.prenom) LIKE ?)
    ORDER BY a.updated_at DESC
    LIMIT ?
  `, [s, s, s, s, s, parseInt(limit)]);
}

/**
 * Créer un asset avec ses sous-tables
 */
async function create(data) {
  const { asset, specs, securite, couts } = data;

  return transaction(async (conn) => {
    const [result] = await conn.execute(`
      INSERT INTO assets (\`Nom Machine\`, serial_number, marque, modele, type, statut, site, departement, notes, photo_url)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `, [
      asset.asset_tag, asset.serial_number, asset.marque, asset.modele,
      asset.type, asset.statut || 'en_service', asset.site, asset.departement,
      asset.notes || null, asset.photo_url || null
    ]);

    const assetId = result.insertId;

    if (specs) {
      await conn.execute(`
        INSERT INTO specs (asset_id, ram, stockage, cpu, os, version_os, mac_address, imei, ip_address, hostname)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `, [assetId, specs.ram, specs.stockage, specs.cpu, specs.os,
          specs.version_os, specs.mac_address, specs.imei, specs.ip_address, specs.hostname]);
    }

    if (securite) {
      await conn.execute(`
        INSERT INTO securite (asset_id, defender, edr, intune, entra_id, bitlocker, onedrive)
        VALUES (?, ?, ?, ?, ?, ?, ?)
      `, [assetId,
          securite.defender ? 1 : 0, securite.edr ? 1 : 0,
          securite.intune ? 1 : 0, securite.entra_id ? 1 : 0,
          securite.bitlocker ? 1 : 0, securite.onedrive ? 1 : 0]);
    }

    if (couts) {
      await conn.execute(`
        INSERT INTO couts (asset_id, prix, fournisseur, bon_commande, date_acquisition, fin_garantie)
        VALUES (?, ?, ?, ?, ?, ?)
      `, [assetId, couts.prix, couts.fournisseur, couts.bon_commande,
          couts.date_acquisition, couts.fin_garantie]);
    }

    return assetId;
  });
}

/**
 * Mettre à jour un asset
 */
async function update(id, data) {
  const { asset, specs, securite, couts } = data;

  return transaction(async (conn) => {
    if (asset && Object.keys(asset).length > 0) {
      const dbAsset = {};
      for (const [key, val] of Object.entries(asset)) {
        if (key === 'asset_tag') {
          dbAsset['Nom Machine'] = val;
        } else {
          dbAsset[key] = val;
        }
      }
      const fields = Object.keys(dbAsset).map(k => `\`${k}\` = ?`).join(', ');
      await conn.execute(
        `UPDATE assets SET ${fields}, updated_at = NOW() WHERE id = ?`,
        [...Object.values(dbAsset), id]
      );
    }

    if (specs) {
      await conn.execute(`
        INSERT INTO specs (asset_id, ram, stockage, cpu, os, version_os, mac_address, imei, ip_address, hostname)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
          ram=VALUES(ram), stockage=VALUES(stockage), cpu=VALUES(cpu),
          os=VALUES(os), version_os=VALUES(version_os), mac_address=VALUES(mac_address),
          imei=VALUES(imei), ip_address=VALUES(ip_address), hostname=VALUES(hostname)
      `, [id, specs.ram, specs.stockage, specs.cpu, specs.os,
          specs.version_os, specs.mac_address, specs.imei, specs.ip_address, specs.hostname]);
    }

    if (securite) {
      await conn.execute(`
        INSERT INTO securite (asset_id, defender, edr, intune, entra_id, bitlocker, onedrive)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
          defender=VALUES(defender), edr=VALUES(edr), intune=VALUES(intune),
          entra_id=VALUES(entra_id), bitlocker=VALUES(bitlocker), onedrive=VALUES(onedrive)
      `, [id,
          securite.defender ? 1 : 0, securite.edr ? 1 : 0,
          securite.intune ? 1 : 0, securite.entra_id ? 1 : 0,
          securite.bitlocker ? 1 : 0, securite.onedrive ? 1 : 0]);
    }

    if (couts) {
      await conn.execute(`
        INSERT INTO couts (asset_id, prix, fournisseur, bon_commande, date_acquisition, fin_garantie)
        VALUES (?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
          prix=VALUES(prix), fournisseur=VALUES(fournisseur),
          bon_commande=VALUES(bon_commande), date_acquisition=VALUES(date_acquisition),
          fin_garantie=VALUES(fin_garantie)
      `, [id, couts.prix, couts.fournisseur, couts.bon_commande,
          couts.date_acquisition, couts.fin_garantie]);
    }

    return true;
  });
}

/**
 * Archivage logique (soft delete)
 */
async function archive(id, motif = null) {
  await query(
    "UPDATE assets SET statut = ?, deleted_at = NOW(), updated_at = NOW(), notes = CONCAT(COALESCE(notes, ''), ' | Archivé: ', ?) WHERE id = ?",
    ['reforme', motif || 'Archivé', id]
  );
  // Clôturer les affectations actives
  await query(
    "UPDATE affectations SET actif = 0, date_retrait = NOW(), motif = LEFT(CONCAT(COALESCE(motif, ''), ' | Asset archivé'), 255) WHERE asset_id = ? AND actif = 1",
    [id]
  );
  return true;
}

/**
 * Restauration d'un asset archivé (remise en stock)
 */
async function restore(id) {
  await query(
    "UPDATE assets SET deleted_at = NULL, statut = 'en_stock', updated_at = NOW(), notes = CONCAT(COALESCE(notes, ''), ' | Restauré le ', TO_CHAR(NOW(), 'DD/MM/YYYY')) WHERE id = ?",
    [id]
  );
  return true;
}

/**
 * Obtenir les valeurs distinctes pour les filtres
 */
async function getFilterOptions() {
  const types = await query('SELECT DISTINCT type FROM assets WHERE deleted_at IS NULL AND type IS NOT NULL ORDER BY type');
  const sites = await query('SELECT DISTINCT site FROM assets WHERE deleted_at IS NULL AND site IS NOT NULL ORDER BY site');
  const departements = await query('SELECT DISTINCT departement FROM assets WHERE deleted_at IS NULL AND departement IS NOT NULL ORDER BY departement');
  const statuts = ['en_service', 'hors_service', 'reforme', 'en_maintenance', 'en_stock'];

  return {
    types: types ? types.map(r => r.type) : [],
    sites: sites ? sites.map(r => r.site) : [],
    departements: departements ? departements.map(r => r.departement) : [],
    statuts,
  };
}

// ─── Pièces Jointes ───────────────────────────────────
async function findAttachments(assetId) {
  return await query(`
    SELECT aa.*, 
           u.nom as uploader_nom, u.prenom as uploader_prenom
    FROM asset_attachments aa
    JOIN auth_users u ON aa.uploaded_by = u.id
    WHERE aa.asset_id = ?
    ORDER BY aa.created_at DESC
  `, [assetId]);
}

async function findAttachmentById(id) {
  const [row] = await query(`
    SELECT aa.*, 
           u.nom as uploader_nom, u.prenom as uploader_prenom
    FROM asset_attachments aa
    JOIN auth_users u ON aa.uploaded_by = u.id
    WHERE aa.id = ?
  `, [id]);
  return row || null;
}

async function createAttachment({ asset_id, nom_fichier, nom_original, chemin, taille, type_mime, uploaded_by }) {
  const result = await query(
    `INSERT INTO asset_attachments (asset_id, nom_fichier, nom_original, chemin, taille, type_mime, uploaded_by)
     VALUES (?, ?, ?, ?, ?, ?, ?)`,
    [asset_id, nom_fichier, nom_original, chemin, taille, type_mime, uploaded_by]
  );
  return result.insertId;
}

async function deleteAttachment(id) {
  await query('DELETE FROM asset_attachments WHERE id = ?', [id]);
}

module.exports = { 
  findAll, findById, search, create, update, archive, restore, getFilterOptions,
  findAttachments, findAttachmentById, createAttachment, deleteAttachment 
};
