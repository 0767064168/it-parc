// ============================================
// src/controllers/logs.controller.js
// Journal d'audit système & traçabilité sécurité
// ============================================
'use strict';

const { query } = require('../config/db');
const { success, error, paginated } = require('../utils/response');
const logger = require('../utils/logger');

async function listLogs(req, res) {
  try {
    const page = Math.max(1, parseInt(req.query.page, 10) || 1);
    const limit = Math.min(100, Math.max(1, parseInt(req.query.limit, 10) || 30));
    const offset = (page - 1) * limit;
    const { action, entity_type, search } = req.query;

    const conditions = [];
    const params = [];

    if (action) {
      conditions.push('al.action ILIKE ?');
      params.push(`%${action}%`);
    }
    if (entity_type) {
      conditions.push('al.entity_type = ?');
      params.push(entity_type);
    }
    if (search) {
      conditions.push('(al.action ILIKE ? OR al.entity_type ILIKE ? OR CAST(al.details AS TEXT) ILIKE ? OR au.username ILIKE ? OR au.nom ILIKE ? OR au.prenom ILIKE ?)');
      const s = `%${search}%`;
      params.push(s, s, s, s, s, s);
    }

    const where = conditions.length ? 'WHERE ' + conditions.join(' AND ') : '';

    const [{ total }] = await query(`
      SELECT COUNT(*) as total
      FROM activity_logs al
      LEFT JOIN auth_users au ON au.id = al.user_id
      ${where}
    `, params);

    const logs = await query(`
      SELECT al.*,
        au.username, au.nom, au.prenom, au.role
      FROM activity_logs al
      LEFT JOIN auth_users au ON au.id = al.user_id
      ${where}
      ORDER BY al.created_at DESC
      LIMIT ? OFFSET ?
    `, [...params, limit, offset]);

    return paginated(res, logs, total, page, limit);
  } catch (err) {
    logger.error('Erreur listLogs:', err);
    return error(res, 'Erreur lors de la récupération du journal d\'audit', 500);
  }
}

async function getLogStats(req, res) {
  try {
    const [totalRow] = await query('SELECT COUNT(*) as total FROM activity_logs');
    const [last24hRow] = await query(`
      SELECT COUNT(*) as count FROM activity_logs
      WHERE created_at >= NOW() - INTERVAL '24 hours'
    `);
    const byAction = await query(`
      SELECT action, COUNT(*) as count
      FROM activity_logs
      GROUP BY action
      ORDER BY count DESC
      LIMIT 8
    `);
    const byEntity = await query(`
      SELECT entity_type, COUNT(*) as count
      FROM activity_logs
      WHERE entity_type IS NOT NULL
      GROUP BY entity_type
      ORDER BY count DESC
    `);

    return success(res, {
      total: totalRow?.total || 0,
      last_24h: last24hRow?.count || 0,
      by_action: byAction,
      by_entity: byEntity,
    }, 'Statistiques du journal d\'audit');
  } catch (err) {
    logger.error('Erreur getLogStats:', err);
    return error(res, 'Erreur statistiques logs', 500);
  }
}

module.exports = { listLogs, getLogStats };
