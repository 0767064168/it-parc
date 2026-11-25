'use strict';

const express = require('express');
const ctrl = require('../controllers/logs.controller');
const { authenticate } = require('../middlewares/auth');
const { requireRole } = require('../middlewares/roles');

const router = express.Router();

router.use(authenticate);
router.use(requireRole('admin', 'technicien'));

router.get('/', ctrl.listLogs);
router.get('/stats', ctrl.getLogStats);

module.exports = router;
