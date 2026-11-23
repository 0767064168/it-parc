// ============================================
// src/routes/public_ticket.routes.js
// Routes publiques de soumission de tickets
// (aucune authentification requise)
// ============================================
'use strict';

const express = require('express');
const router = express.Router();
const rateLimit = require('express-rate-limit');
const { createPublicTicket } = require('../controllers/public_ticket.controller');

// Limiteur anti-spam spécifique pour le formulaire public (max 10 tickets par heure par IP)
const publicTicketLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  max: 10,
  message: {
    success: false,
    message: 'Trop de tickets soumis depuis cette connexion. Veuillez patienter avant de réessayer.',
  },
  standardHeaders: true,
  legacyHeaders: false,
});

// POST /api/public/tickets  →  Soumettre un ticket via le formulaire public
router.post('/tickets', publicTicketLimiter, createPublicTicket);

module.exports = router;
