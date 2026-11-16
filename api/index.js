// ============================================
// api/index.js — Vercel Serverless Function
// Exporte l'application Express pour Vercel
// ============================================
'use strict';

// Charger les variables d'environnement (sur Vercel, elles viennent du dashboard)
require('dotenv').config({ path: require('path').join(__dirname, '..', 'backend', '.env') });

// Importer l'application Express (sans la démarrer)
const app = require('../backend/server');

module.exports = app;
