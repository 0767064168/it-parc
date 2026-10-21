'use strict';
const express = require('express');
const { body, param } = require('express-validator');
const ctrl = require('../controllers/consommable.controller');
const { authenticate } = require('../middlewares/auth');
const { requirePermission } = require('../middlewares/roles');
const { validate } = require('../middlewares/validate');
const router = express.Router();

router.use(authenticate);

router.get('/', requirePermission('consommables:read'), ctrl.list);
router.get('/:id', requirePermission('consommables:read'), [param('id').isInt()], validate, ctrl.getOne);

router.post('/',
  requirePermission('consommables:manage'),
  [
    body('nom').notEmpty().withMessage('Nom requis'),
    body('quantite').optional().isInt({ min: 0 }).withMessage('La quantité doit être un entier positif'),
  ],
  validate,
  ctrl.create
);

router.put('/:id',
  requirePermission('consommables:manage'),
  [param('id').isInt()],
  validate,
  ctrl.update
);

router.delete('/:id',
  requirePermission('consommables:manage'),
  [param('id').isInt()],
  validate,
  ctrl.remove
);

router.patch('/:id/adjust',
  requirePermission('consommables:manage'),
  [
    param('id').isInt(),
    body('diff').isInt().withMessage('Différence requise (entier relatif)'),
  ],
  validate,
  ctrl.adjustStock
);

module.exports = router;
