// ============================================
// src/controllers/dashboard.controller.js
// ============================================
'use strict';

const DashboardModel = require('../models/dashboard.model');
const { query } = require('../config/db');
const { sendExpiringAlertsDigest } = require('../services/email.service');
const { success, error } = require('../utils/response');
const logger = require('../utils/logger');

async function getStats(req, res) {
  try {
    const stats = await DashboardModel.getStats();
    return success(res, stats, 'Statistiques tableau de bord');
  } catch (err) {
    logger.error('Erreur dashboard stats:', err);
    return error(res, 'Erreur lors du calcul des statistiques', 500);
  }
}

async function getAdvancedReports(req, res) {
  try {
    const reports = await DashboardModel.getAdvancedReports();
    return success(res, reports, 'Rapports statistiques avancés');
  } catch (err) {
    logger.error('Erreur advanced reports:', err);
    return error(res, 'Erreur lors de la récupération des rapports', 500);
  }
}

async function getAmortissement(req, res) {
  try {
    const data = await DashboardModel.getAmortissementStats();
    return success(res, data, 'Statistiques amortissement et budget');
  } catch (err) {
    logger.error('Erreur amortissement stats:', err);
    return error(res, 'Erreur lors du calcul de l\'amortissement', 500);
  }
}

async function triggerExpiringAlertsEmail(req, res) {
  try {
    const licencesExpirant = await query(`
      SELECT id, nom, editeur, date_expiration FROM licences
      WHERE date_expiration IS NOT NULL
        AND date_expiration >= CURDATE()
        AND date_expiration <= DATE_ADD(CURDATE(), INTERVAL 30 DAY)
    `);
    const garantiesExpirant = await query(`
      SELECT a.id, a.\`Nom Machine\` as asset_tag, a.marque, a.modele, c.fin_garantie
      FROM couts c
      JOIN assets a ON a.id = c.asset_id AND a.deleted_at IS NULL
      WHERE c.fin_garantie IS NOT NULL
        AND c.fin_garantie >= CURDATE()
        AND c.fin_garantie <= DATE_ADD(CURDATE(), INTERVAL 30 DAY)
    `);
    const admins = await query("SELECT email FROM auth_users WHERE role IN ('admin', 'technicien') AND actif = 1 AND email IS NOT NULL");
    const adminEmails = admins.map(a => a.email).filter(Boolean);

    if (licencesExpirant.length === 0 && garantiesExpirant.length === 0) {
      return success(res, { sent: false, count: 0 }, 'Aucune licence ou garantie n\'arrive à échéance dans les 30 prochains jours.');
    }

    if (adminEmails.length > 0) {
      await sendExpiringAlertsDigest({ adminEmails, licencesExpirant, garantiesExpirant });
    }
    return success(res, {
      sent: true,
      licences: licencesExpirant.length,
      garanties: garantiesExpirant.length,
      recipients: adminEmails.length
    }, `Rapport d'échéance envoyé à ${adminEmails.length} administrateur(s).`);
  } catch (err) {
    logger.error('Erreur triggerExpiringAlertsEmail:', err);
    return error(res, 'Erreur lors de l\'envoi du rapport d\'échéances', 500);
  }
}

module.exports = { getStats, getAdvancedReports, getAmortissement, triggerExpiringAlertsEmail };
