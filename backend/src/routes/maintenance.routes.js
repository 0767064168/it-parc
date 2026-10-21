'use strict';
const express = require('express');
const { body, param } = require('express-validator');
const ctrl = require('../controllers/maintenance.controller');
const { authenticate } = require('../middlewares/auth');
const { requirePermission } = require('../middlewares/roles');
const { validate } = require('../middlewares/validate');
const router = express.Router();

router.use(authenticate);

router.get('/', requirePermission('maintenances:read'), ctrl.list);
router.get('/:id', requirePermission('maintenances:read'), [param('id').isInt()], validate, ctrl.getOne);

router.post('/',
  requirePermission('maintenances:manage'),
  [
    body('asset_id').isInt().withMessage('ID équipement requis'),
    body('date_prevue').isDate().withMessage('Date prévue invalide'),
    body('description').notEmpty().withMessage('Description requise'),
  ],
  validate,
  ctrl.create
);

router.put('/:id',
  requirePermission('maintenances:manage'),
  [param('id').isInt()],
  validate,
  ctrl.update
);

router.delete('/:id',
  requirePermission('maintenances:manage'),
  [param('id').isInt()],
  validate,
  ctrl.remove
);

module.exports = router;
