'use strict';
const express = require('express');
const { body, param } = require('express-validator');
const ctrl = require('../controllers/licence.controller');
const { authenticate } = require('../middlewares/auth');
const { requirePermission } = require('../middlewares/roles');
const { validate } = require('../middlewares/validate');
const router = express.Router();

router.use(authenticate);

router.get('/', requirePermission('licences:read'), ctrl.list);
router.get('/:id', requirePermission('licences:read'), [param('id').isInt()], validate, ctrl.getOne);

router.post('/',
  requirePermission('licences:manage'),
  [
    body('nom').notEmpty().withMessage('Nom du logiciel requis'),
    body('cout').optional().isFloat().withMessage('Le coût doit être un décimal'),
  ],
  validate,
  ctrl.create
);

router.put('/:id',
  requirePermission('licences:manage'),
  [param('id').isInt()],
  validate,
  ctrl.update
);

router.delete('/:id',
  requirePermission('licences:manage'),
  [param('id').isInt()],
  validate,
  ctrl.remove
);

router.post('/:id/allocate',
  requirePermission('licences:manage'),
  [
    param('id').isInt(),
    body('user_id').isInt().withMessage('ID utilisateur requis'),
  ],
  validate,
  ctrl.allocate
);

router.delete('/deallocate/:allocId',
  requirePermission('licences:manage'),
  [param('allocId').isInt()],
  validate,
  ctrl.deallocate
);

module.exports = router;
