'use strict';
const express = require('express');
const { body, param } = require('express-validator');
const ctrl = require('../controllers/user.controller');
const { authenticate } = require('../middlewares/auth');
const { requirePermission, requireRole } = require('../middlewares/roles');
const { validate } = require('../middlewares/validate');
const router = express.Router();

router.use(authenticate);

router.get('/', requireRole('admin'), ctrl.listAuthUsers);
router.get('/collaborateurs', requirePermission('users:read'), ctrl.list);
router.get('/auth-accounts', requireRole('admin'), ctrl.listAuthUsers);
router.get('/:id', requireRole('admin'), [param('id').isInt()], validate, ctrl.getOne);

router.post('/',
  requireRole('admin'),
  [
    body('username').notEmpty().withMessage('Identifiant requis'),
    body('password').isLength({ min: 6 }).withMessage('Mot de passe requis (min. 6 caractères)'),
    body('role').isIn(['admin', 'technicien', 'lecteur']).withMessage('Rôle invalide'),
    body('nom').notEmpty().withMessage('Nom requis'),
    body('prenom').notEmpty().withMessage('Prénom requis'),
    body('email').optional().isEmail().withMessage('Email invalide'),
  ],
  validate,
  async (req, res) => {
    try {
      const bcrypt = require('bcryptjs');
      const { query } = require('../config/db');
      const { success, error } = require('../utils/response');
      const hash = await bcrypt.hash(req.body.password, 12);
      await query(
        'INSERT INTO auth_users (username, password_hash, role, nom, prenom, email, actif) VALUES (?, ?, ?, ?, ?, ?, 1)',
        [req.body.username.trim(), hash, req.body.role, req.body.nom.trim(), req.body.prenom.trim(), req.body.email ? req.body.email.trim() : null]
      );
      return success(res, null, 'Compte créé avec succès', 201);
    } catch (err) {
      if (err.message && err.message.includes('unique')) return res.status(409).json({ success: false, message: 'Cet identifiant est déjà utilisé' });
      return res.status(500).json({ success: false, message: err.message || 'Erreur création compte' });
    }
  }
);

router.put('/:id', requirePermission('users:manage'), [param('id').isInt()], validate, ctrl.update);
router.delete('/:id', requirePermission('users:manage'), [param('id').isInt()], validate, ctrl.remove);
router.patch('/auth-accounts/:id/toggle', requireRole('admin'), [param('id').isInt()], validate, ctrl.toggleAuthUser);

module.exports = router;
