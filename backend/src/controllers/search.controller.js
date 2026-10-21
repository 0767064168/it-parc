// ============================================
// src/controllers/search.controller.js — Recherche Globale
// ============================================
'use strict';

const { query } = require('../config/db');
const { success, error } = require('../utils/response');
const logger = require('../utils/logger');

async function globalSearch(req, res) {
  try {
    const { q } = req.query;
    if (!q || q.trim().length < 2) {
      return error(res, 'Recherche trop courte (min 2 caractères)', 400);
    }
    const search = `%${q.trim()}%`;
    const limit = 10;

    // 1. Assets
    const assets = await query(`
      SELECT id, \`Nom Machine\` AS asset_tag, marque, modele, type, statut, site, departement
      FROM assets
      WHERE deleted_at IS NULL
        AND (\`Nom Machine\` LIKE ? OR serial_number LIKE ? OR marque LIKE ? OR modele LIKE ?)
      ORDER BY updated_at DESC
      LIMIT ?
    `, [search, search, search, search, limit]);

    // 2. Tickets
    const tickets = await query(`
      SELECT id, numero, titre, type, priorite, statut, site
      FROM tickets
      WHERE numero LIKE ? OR titre LIKE ? OR description LIKE ?
      ORDER BY created_at DESC
      LIMIT ?
    `, [search, search, search, limit]);

    // 3. Maintenances
    const maintenances = await query(`
      SELECT id, type, date_prevue, description, statut
      FROM maintenances
      WHERE description LIKE ? OR notes LIKE ?
      ORDER BY date_prevue DESC
      LIMIT ?
    `, [search, search, limit]);

    // 4. Licences
    const licences = await query(`
      SELECT id, nom, editeur, date_expiration, cle_activation
      FROM licences
      WHERE nom LIKE ? OR editeur LIKE ?
      ORDER BY nom ASC
      LIMIT ?
    `, [search, search, limit]);

    // 5. Wiki Articles
    const wiki = await query(`
      SELECT id, titre, categorie, est_public
      FROM wiki_articles
      WHERE titre LIKE ? OR contenu LIKE ? OR categorie LIKE ?
      ORDER BY created_at DESC
      LIMIT ?
    `, [search, search, search, limit]);

    return success(res, {
      assets,
      tickets,
      maintenances,
      licences,
      wiki
    }, 'Résultats de recherche globale');
  } catch (err) {
    logger.error('Erreur globalSearch:', err);
    return error(res, 'Erreur lors de la recherche', 500);
  }
}

module.exports = { globalSearch };
