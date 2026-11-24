'use strict';
const express = require('express');
const { getStats, getAdvancedReports, getAmortissement } = require('../controllers/dashboard.controller');
const { authenticate } = require('../middlewares/auth');
const { requirePermission } = require('../middlewares/roles');
const router = express.Router();

router.get('/stats', authenticate, requirePermission('dashboard:read'), getStats);
router.get('/reports', authenticate, requirePermission('dashboard:read'), getAdvancedReports);
router.get('/amortissement', authenticate, requirePermission('dashboard:read'), getAmortissement);

module.exports = router;
