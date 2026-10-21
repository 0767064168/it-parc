// ============================================
// src/middlewares/auth.js — Vérification JWT
// ============================================
'use strict';

const jwt = require('jsonwebtoken');
const { error } = require('../utils/response');
const logger = require('../utils/logger');

/**
 * Middleware d'authentification JWT
 * Vérifie le Bearer token dans le header Authorization
 */
const authenticate = (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return error(res, 'Token d\'authentification manquant', 401);
    }

    const token = authHeader.split(' ')[1];
    if (!token) {
      return error(res, 'Token invalide', 401);
    }

    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = {
      id: decoded.id,
      username: decoded.username,
      role: decoded.role,
      nom: decoded.nom,
    };

    next();
  } catch (err) {
    if (err.name === 'TokenExpiredError') {
      return error(res, 'Session expirée. Veuillez vous reconnecter.', 401);
    }
    if (err.name === 'JsonWebTokenError') {
      return error(res, 'Token invalide', 401);
    }
    logger.error('Erreur auth middleware:', err);
    return error(res, 'Erreur d\'authentification', 500);
  }
};

/**
 * Middleware optionnel — n'échoue pas si pas de token
 * Utilisé pour les routes accessibles en lecture sans auth
 */
const optionalAuth = (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    if (authHeader && authHeader.startsWith('Bearer ')) {
      const token = authHeader.split(' ')[1];
      if (token) {
        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        req.user = { id: decoded.id, username: decoded.username, role: decoded.role };
      }
    }
  } catch (_) {
    // Ignorer les erreurs de token en mode optionnel
  }
  next();
};

module.exports = { authenticate, optionalAuth };
