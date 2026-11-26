'use strict';
const express = require('express');
const { getStats, getAdvancedReports, getAmortissement, triggerExpiringAlertsEmail, cronExpiringAlerts, getMonEspace, reportMonIncident } = require('../controllers/dashboard.controller');
const { authenticate } = require('../middlewares/auth');
const { requirePermission } = require('../middlewares/roles');
const router = express.Router();

router.get('/stats', authenticate, requirePermission('dashboard:read'), getStats);
router.get('/reports', authenticate, requirePermission('dashboard:read'), getAdvancedReports);
router.get('/amortissement', authenticate, requirePermission('dashboard:read'), getAmortissement);
router.post('/send-expiring-alerts', authenticate, requirePermission('affectations:manage'), triggerExpiringAlertsEmail);
router.get('/cron/expiring-alerts', cronExpiringAlerts);
router.get('/mon-espace', authenticate, getMonEspace);
router.post('/mon-espace/incident', authenticate, reportMonIncident);

module.exports = router;
