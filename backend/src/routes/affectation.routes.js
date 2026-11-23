'use strict';
const express = require('express');
const { body, param } = require('express-validator');
const ctrl = require('../controllers/affectation.controller');
const { authenticate } = require('../middlewares/auth');
const { requirePermission } = require('../middlewares/roles');
const { validate } = require('../middlewares/validate');
const router = express.Router();

router.use(authenticate);

router.get('/', requirePermission('affectations:read'), ctrl.list);
router.get('/:id/pdf', requirePermission('affectations:read'), ctrl.generatePdf);

router.post('/',
  requirePermission('affectations:manage'),
  [
    body('asset_id').isInt().withMessage('asset_id requis'),
    body('user_id').optional({ nullable: true }).isInt().withMessage('user_id doit être un entier'),
    body('date_attribution').optional({ nullable: true }).isDate().withMessage('Date invalide'),
    body('nom').optional({ nullable: true }).isString(),
    body('prenom').optional({ nullable: true }).isString(),
    body('departement').optional({ nullable: true }).isString(),
    body('site').optional({ nullable: true }).isString(),
    body('ancien_utilisateur').optional({ nullable: true }).isString(),
    body('motif').optional({ nullable: true }).isString(),
  ],
  validate,
  ctrl.create
);

router.post('/retrait',
  requirePermission('affectations:manage'),
  [
    body('asset_id').isInt().withMessage('asset_id requis'),
  ],
  validate,
  ctrl.retrait
);

router.put('/:id',
  requirePermission('affectations:manage'),
  [
    param('id').isInt().withMessage('ID invalide'),
    body('user_id').optional().isInt().withMessage('ID utilisateur requis'),
    body('date_attribution').optional().isDate().withMessage('Date d\'attribution invalide'),
    body('date_retrait').optional({ nullable: true }).isDate().withMessage('Date de retrait invalide'),
    body('actif').optional().isBoolean().withMessage('Statut actif doit être un booléen'),
    body('nom').optional({ nullable: true }).isString(),
    body('prenom').optional({ nullable: true }).isString(),
    body('departement').optional({ nullable: true }).isString(),
    body('site').optional({ nullable: true }).isString(),
  ],
  validate,
  ctrl.update
);

router.delete('/:id',
  requirePermission('affectations:manage'),
  [param('id').isInt().withMessage('ID invalide')],
  validate,
  ctrl.remove
);

module.exports = router;
