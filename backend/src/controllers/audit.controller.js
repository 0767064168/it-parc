// ============================================
// src/controllers/audit.controller.js
// Campagnes d'inventaire physique & audits terrain
// ============================================
'use strict';

const { query } = require('../config/db');
const { success, error } = require('../utils/response');
const logger = require('../utils/logger');

let initialized = false;
async function ensureTables() {
  if (initialized) return;
  try {
    await query(`
      CREATE TABLE IF NOT EXISTS campagnes_inventaire (
        id SERIAL PRIMARY KEY,
        titre VARCHAR(150) NOT NULL,
        site VARCHAR(100),
        statut VARCHAR(30) DEFAULT 'en_cours',
        notes TEXT,
        created_by VARCHAR(100),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        closed_at TIMESTAMP
      )
    `);
    await query(`
      CREATE TABLE IF NOT EXISTS campagne_scans (
        id SERIAL PRIMARY KEY,
        campagne_id INT NOT NULL,
        asset_id INT,
        asset_tag VARCHAR(100) NOT NULL,
        site_theorique VARCHAR(100),
        site_scanne VARCHAR(100),
        conforme INT DEFAULT 1,
        scanne_par VARCHAR(100),
        scanned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);
    initialized = true;
  } catch (err) {
    logger.warn('Initialisation tables audit:', err.message);
  }
}

async function listCampagnes(req, res) {
  try {
    await ensureTables();
    const campagnes = await query(`
      SELECT c.*,
        COUNT(cs.id) as total_scannes
      FROM campagnes_inventaire c
      LEFT JOIN campagne_scans cs ON cs.campagne_id = c.id
      GROUP BY c.id
      ORDER BY c.created_at DESC
    `);

    // Pour chaque campagne, calculer le nombre théorique d'équipements attendus
    const enriched = await Promise.all(campagnes.map(async (c) => {
      let countTheorique = 0;
      if (c.site && c.site !== 'Tous') {
        const [resCount] = await query('SELECT COUNT(*) as count FROM assets WHERE deleted_at IS NULL AND site ILIKE ?', [`%${c.site}%`]);
        countTheorique = parseInt(resCount?.count || 0);
      } else {
        const [resCount] = await query('SELECT COUNT(*) as count FROM assets WHERE deleted_at IS NULL');
        countTheorique = parseInt(resCount?.count || 0);
      }
      const progression = countTheorique > 0 ? Math.min(100, Math.round((parseInt(c.total_scannes || 0) / countTheorique) * 100)) : 0;
      return {
        ...c,
        total_attendus: countTheorique,
        progression_pct: progression
      };
    }));

    return success(res, enriched, 'Campagnes d\'inventaire');
  } catch (err) {
    logger.error('Erreur listCampagnes:', err);
    return error(res, 'Erreur lors de la récupération des campagnes', 500);
  }
}

async function createCampagne(req, res) {
  try {
    await ensureTables();
    const { titre, site, notes } = req.body;
    if (!titre || !titre.trim()) {
      return error(res, 'Le titre de la campagne est obligatoire', 400);
    }
    const createdBy = req.user ? `${req.user.prenom || ''} ${req.user.nom || ''}`.trim() || req.user.username : 'Technicien IT';

    const insertResult = await query(
      'INSERT INTO campagnes_inventaire (titre, site, notes, created_by, statut) VALUES (?, ?, ?, ?, ?) RETURNING id',
      [titre.trim(), site?.trim() || 'Tous', notes?.trim() || null, createdBy, 'en_cours']
    );

    const newId = insertResult?.[0]?.id || insertResult?.insertId;
    return success(res, { id: newId, titre, site: site || 'Tous' }, 'Campagne d\'inventaire créée');
  } catch (err) {
    logger.error('Erreur createCampagne:', err);
    return error(res, 'Erreur lors de la création de la campagne', 500);
  }
}

async function getCampagneDetails(req, res) {
  try {
    await ensureTables();
    const id = parseInt(req.params.id);
    const [campagne] = await query('SELECT * FROM campagnes_inventaire WHERE id = ?', [id]);
    if (!campagne) return error(res, 'Campagne introuvable', 404);

    // Récupérer tous les scans effectués dans cette campagne
    const scans = await query(`
      SELECT cs.*, a.marque, a.modele, a.type, a.statut as asset_statut, a.departement as asset_dept
      FROM campagne_scans cs
      LEFT JOIN assets a ON a.id = cs.asset_id
      WHERE cs.campagne_id = ?
      ORDER BY cs.scanned_at DESC
    `, [id]);

    // Récupérer les assets attendus
    const assetConditions = ['a.deleted_at IS NULL'];
    const assetParams = [];
    if (campagne.site && campagne.site !== 'Tous') {
      assetConditions.push('a.site ILIKE ?');
      assetParams.push(`%${campagne.site}%`);
    }

    const attendus = await query(`
      SELECT a.id, a.\`Nom Machine\` as asset_tag, a.marque, a.modele, a.type, a.statut, a.site, a.departement
      FROM assets a
      WHERE ${assetConditions.join(' AND ')}
      ORDER BY a.\`Nom Machine\` ASC
    `, assetParams);

    const scannedAssetIds = new Set(scans.filter(s => s.asset_id).map(s => s.asset_id));
    const scannedTags = new Set(scans.map(s => String(s.asset_tag).toUpperCase().trim()));

    const manquants = attendus.filter(a => !scannedAssetIds.has(a.id) && !scannedTags.has(String(a.asset_tag).toUpperCase().trim()));
    const conformes = scans.filter(s => s.conforme === 1);
    const anomalies = scans.filter(s => s.conforme === 0);

    return success(res, {
      campagne,
      stats: {
        total_attendus: attendus.length,
        total_scannes: scans.length,
        conformes: conformes.length,
        anomalies: anomalies.length,
        manquants: manquants.length,
        progression_pct: attendus.length > 0 ? Math.min(100, Math.round((scans.length / attendus.length) * 100)) : 100
      },
      scans,
      manquants
    }, 'Détails de la campagne d\'audit');
  } catch (err) {
    logger.error('Erreur getCampagneDetails:', err);
    return error(res, 'Erreur lors du chargement des détails de la campagne', 500);
  }
}

async function recordScan(req, res) {
  try {
    await ensureTables();
    const id = parseInt(req.params.id);
    const { code, site_constate } = req.body;
    if (!code || !code.trim()) return error(res, 'Code ou Tag machine requis', 400);

    const cleanCode = code.trim();
    const [campagne] = await query('SELECT * FROM campagnes_inventaire WHERE id = ?', [id]);
    if (!campagne) return error(res, 'Campagne introuvable', 404);

    // Chercher l'asset par tag ou serial_number
    const matchingAssets = await query(`
      SELECT id, \`Nom Machine\` as asset_tag, serial_number, site, departement, marque, modele
      FROM assets
      WHERE deleted_at IS NULL AND (
        \`Nom Machine\` ILIKE ? OR
        serial_number ILIKE ? OR
        id = ?
      )
      LIMIT 1
    `, [cleanCode, cleanCode, isNaN(parseInt(cleanCode)) ? -1 : parseInt(cleanCode)]);

    const scannePar = req.user ? `${req.user.prenom || ''} ${req.user.nom || ''}`.trim() || req.user.username : 'Technicien';
    const siteActuel = site_constate || campagne.site || 'Bouaké';

    let assetId = null;
    let assetTag = cleanCode;
    let siteTheorique = null;
    let conforme = 1;

    if (matchingAssets && matchingAssets.length > 0) {
      const match = matchingAssets[0];
      assetId = match.id;
      assetTag = match.asset_tag || cleanCode;
      siteTheorique = match.site;
      
      // Conforme si le site constaté correspond au site théorique
      if (siteTheorique && siteActuel !== 'Tous' && !siteTheorique.toLowerCase().includes(siteActuel.toLowerCase())) {
        conforme = 0; // Anomalie de site
      }
    } else {
      conforme = 0; // Matériel non répertorié
    }

    await query(`
      INSERT INTO campagne_scans (campagne_id, asset_id, asset_tag, site_theorique, site_scanne, conforme, scanne_par)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    `, [id, assetId, assetTag, siteTheorique, siteActuel, conforme, scannePar]);

    return success(res, {
      asset_id: assetId,
      asset_tag: assetTag,
      conforme: conforme === 1,
      site_theorique: siteTheorique,
      site_scanne: siteActuel,
      trouve: !!assetId
    }, conforme === 1 ? 'Équipement scanné et conforme' : 'Anomalie détectée pour cet équipement');
  } catch (err) {
    logger.error('Erreur recordScan:', err);
    return error(res, 'Erreur lors de l\'enregistrement du scan: ' + err.message, 500);
  }
}

async function closeCampagne(req, res) {
  try {
    await ensureTables();
    const id = parseInt(req.params.id);
    await query('UPDATE campagnes_inventaire SET statut = "cloture", closed_at = NOW() WHERE id = ?', [id]);
    return success(res, null, 'Campagne clôturée avec succès');
  } catch (err) {
    logger.error('Erreur closeCampagne:', err);
    return error(res, 'Erreur lors de la clôture', 500);
  }
}

module.exports = {
  listCampagnes,
  createCampagne,
  getCampagneDetails,
  recordScan,
  closeCampagne
};
