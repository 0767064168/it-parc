// ============================================
// src/routes/public_ticket.routes.js
// Routes publiques de soumission de tickets
// (aucune authentification requise)
// ============================================
'use strict';

const express = require('express');
const router = express.Router();
const { createPublicTicket } = require('../controllers/public_ticket.controller');

// POST /api/public/tickets  →  Soumettre un ticket via le formulaire public
router.post('/tickets', createPublicTicket);

module.exports = router;
