'use strict';

const express = require('express');
const { body, param } = require('express-validator');
const ctrl = require('../controllers/audit.controller');
const { authenticate } = require('../middlewares/auth');
const { requirePermission } = require('../middlewares/roles');
const { validate } = require('../middlewares/validate');

const router = express.Router();

router.use(authenticate);

router.get('/', requirePermission('dashboard:read'), ctrl.listCampagnes);
router.post('/', requirePermission('affectations:manage'), [
  body('titre').isString().notEmpty().withMessage('Titre obligatoire'),
  body('site').optional().isString(),
  body('notes').optional().isString()
], validate, ctrl.createCampagne);

router.get('/:id', requirePermission('dashboard:read'), ctrl.getCampagneDetails);
router.post('/:id/scan', requirePermission('affectations:manage'), [
  body('code').isString().notEmpty().withMessage('Code requis')
], validate, ctrl.recordScan);

router.post('/:id/cloturer', requirePermission('affectations:manage'), ctrl.closeCampagne);

module.exports = router;
