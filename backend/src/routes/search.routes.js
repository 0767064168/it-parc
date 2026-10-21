// ============================================
// src/routes/search.routes.js — Routes Recherche
// ============================================
'use strict';

const express = require('express');
const router = express.Router();
const { globalSearch } = require('../controllers/search.controller');
const { authenticate } = require('../middlewares/auth');

router.get('/', authenticate, globalSearch);

module.exports = router;
