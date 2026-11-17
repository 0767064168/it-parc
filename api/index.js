// ============================================
// api/index.js — Vercel Serverless Function
// Exporte l'application Express pour Vercel
// ============================================
'use strict';

const app = require('../backend/server');

module.exports = app;
