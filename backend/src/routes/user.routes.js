'use strict';
const express = require('express');
const { body, param } = require('express-validator');
const ctrl = require('../controllers/user.controller');
const { authenticate } = require('../middlewares/auth');
const { requirePermission, requireRole } = require('../middlewares/roles');
const { validate } = require('../middlewares/validate');
const router = express.Router();

router.use(authenticate);

router.get('/', requirePermission('users:read'), ctrl.list);
router.get('/auth-accounts', requireRole('admin'), ctrl.listAuthUsers);
router.get('/:id', requirePermission('users:read'), [param('id').isInt()], validate, ctrl.getOne);

router.post('/',
  requirePermission('users:manage'),
  [
    body('nom').notEmpty().withMessage('Nom requis'),
    body('prenom').notEmpty().withMessage('Prénom requis'),
    body('email').optional().isEmail().withMessage('Email invalide'),
  ],
  validate,
  ctrl.create
);

router.put('/:id', requirePermission('users:manage'), [param('id').isInt()], validate, ctrl.update);
router.delete('/:id', requirePermission('users:manage'), [param('id').isInt()], validate, ctrl.remove);
router.patch('/auth-accounts/:id/toggle', requireRole('admin'), [param('id').isInt()], validate, ctrl.toggleAuthUser);

module.exports = router;
