// ============================================
// src/utils/response.js — Helpers réponses API
// ============================================
'use strict';

/**
 * Réponse de succès standardisée
 */
const success = (res, data = null, message = 'Succès', statusCode = 200) => {
  const payload = { success: true, message };
  if (data !== null) payload.data = data;
  return res.status(statusCode).json(payload);
};

/**
 * Réponse d'erreur standardisée
 */
const error = (res, message = 'Erreur', statusCode = 500, details = null) => {
  const payload = { success: false, message };
  if (details && process.env.NODE_ENV !== 'production') payload.details = details;
  return res.status(statusCode).json(payload);
};

/**
 * Réponse paginée
 */
const paginated = (res, data, total, page, limit, message = 'Succès') => {
  return res.status(200).json({
    success: true,
    message,
    data: {
      rows: data,
      total: parseInt(total),
    },
    pagination: {
      total: parseInt(total),
      page: parseInt(page),
      limit: parseInt(limit),
      totalPages: Math.ceil(total / limit),
      hasNext: page * limit < total,
      hasPrev: page > 1,
    },
  });
};

module.exports = { success, error, paginated };
