// ============================================
// src/middlewares/roles.js — Contrôle des rôles
// ============================================
'use strict';

const { error } = require('../utils/response');

// Hiérarchie des rôles
const ROLES = {
  ADMIN: 'admin',
  TECHNICIEN: 'technicien',
  Lecteur: 'lecteur',
};

// Permissions par fonctionnalité
const PERMISSIONS = {
  'assets:read':       ['admin', 'technicien', 'lecteur'],
  'assets:create':     ['admin', 'technicien'],
  'assets:update':     ['admin', 'technicien'],
  'assets:delete':     ['admin', 'technicien'],
  'assets:archive':    ['admin', 'technicien'],
  'affectations:read': ['admin', 'technicien', 'lecteur'],
  'affectations:manage': ['admin', 'technicien'],
  'dashboard:read':    ['admin', 'technicien', 'lecteur'],
  'users:read':        ['admin', 'technicien'],
  'users:manage':      ['admin'],
  'import:excel':      ['admin'],
  'export:pdf':        ['admin', 'technicien'],
  'export:excel':      ['admin', 'technicien'],
  'settings:manage':   ['admin'],
  'licences:read':     ['admin', 'technicien'],
  'licences:manage':   ['admin'],
  'consommables:read': ['admin', 'technicien', 'lecteur'],
  'consommables:manage': ['admin', 'technicien'],
  'maintenances:read': ['admin', 'technicien', 'lecteur'],
  'maintenances:manage': ['admin', 'technicien'],
  'wiki:read':         ['admin', 'technicien', 'lecteur'],
  'wiki:manage':       ['admin', 'technicien'],
};

/**
 * Middleware de vérification de permission
 * @param {string} permission - La permission requise (ex: 'assets:create')
 */
const requirePermission = (permission) => (req, res, next) => {
  if (!req.user) {
    return error(res, 'Non authentifié', 401);
  }

  const allowed = PERMISSIONS[permission] || [];
  if (!allowed.includes(req.user.role)) {
    return error(
      res,
      `Accès refusé. Permission requise: ${permission}`,
      403
    );
  }

  next();
};

/**
 * Middleware vérifiant que l'utilisateur a l'un des rôles spécifiés
 * @param {...string} roles - Rôles autorisés
 */
const requireRole = (...roles) => (req, res, next) => {
  if (!req.user) {
    return error(res, 'Non authentifié', 401);
  }

  if (!roles.includes(req.user.role)) {
    return error(
      res,
      `Accès refusé. Rôle(s) requis: ${roles.join(', ')}`,
      403
    );
  }

  next();
};

module.exports = { requirePermission, requireRole, ROLES, PERMISSIONS };
