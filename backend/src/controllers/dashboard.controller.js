// ============================================
// src/controllers/dashboard.controller.js
// ============================================
'use strict';

const DashboardModel = require('../models/dashboard.model');
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

module.exports = { getStats, getAdvancedReports, getAmortissement };
