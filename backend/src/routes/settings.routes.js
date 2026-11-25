'use strict';

const express = require('express');
const ctrl = require('../controllers/settings.controller');
const { authenticate } = require('../middlewares/auth');
const { requireRole } = require('../middlewares/roles');

const router = express.Router();

router.use(authenticate);

router.get('/', requireRole('admin', 'technicien'), ctrl.getSettings);
router.put('/', requireRole('admin'), ctrl.updateSettings);
router.post('/test-email', requireRole('admin'), ctrl.sendTestEmail);

module.exports = router;
