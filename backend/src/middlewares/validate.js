// ============================================
// src/middlewares/validate.js — Validation
// ============================================
'use strict';

const { validationResult } = require('express-validator');
const { error } = require('../utils/response');

/**
 * Middleware exécutant les règles de validation express-validator
 * et retournant les erreurs en JSON formaté
 */
const validate = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    const details = errors.array().map(e => ({
      field: e.path,
      message: e.msg,
      value: e.value,
    }));
    return error(res, 'Données invalides', 422, details);
  }
  next();
};

module.exports = { validate };
