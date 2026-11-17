// ============================================
// api/[...all].js — Vercel Catch-All Route
// Redirige toutes les requêtes /api/* vers Express
// ============================================
'use strict';

const app = require('../backend/server');

module.exports = app;
