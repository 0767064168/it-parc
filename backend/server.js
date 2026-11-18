// ============================================
// server.js — Point d'entrée de l'application
// Gestionnaire de Parc IT — Backend Express
// ============================================
'use strict';

const path = require('path');
const fs = require('fs');
require('dotenv').config({ path: path.join(__dirname, '.env') });
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const compression = require('compression');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');

const logger = require('./src/utils/logger');
const { testConnection } = require('./src/config/db');
const { getJwtSecret } = require('./src/config/auth');

// --- Routes ---
const authRoutes = require('./src/routes/auth.routes');
const assetRoutes = require('./src/routes/asset.routes');
const dashboardRoutes = require('./src/routes/dashboard.routes');
const affectationRoutes = require('./src/routes/affectation.routes');
const userRoutes = require('./src/routes/user.routes');
const importExportRoutes = require('./src/routes/importexport.routes');
const ticketRoutes = require('./src/routes/ticket.routes');
const licenceRoutes = require('./src/routes/licence.routes');
const consommableRoutes = require('./src/routes/consommable.routes');
const maintenanceRoutes = require('./src/routes/maintenance.routes');
const wikiRoutes = require('./src/routes/wiki.routes');
const searchRoutes = require('./src/routes/search.routes');
const publicTicketRoutes = require('./src/routes/public_ticket.routes');

const http = require('http');
const { Server } = require('socket.io');

const app = express();
const PORT = process.env.PORT || 3000;

// Create HTTP server for WebSocket
const server = http.createServer(app);
const io = new Server(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST']
  }
});
app.set('io', io);
global.io = io;

io.on('connection', (socket) => {
  logger.info(`🔌 Client Socket.io connecté: ${socket.id}`);
  
  socket.on('join', (data) => {
    // Le client Flutter envoie { userId: '...' }
    const userId = typeof data === 'object' ? data.userId : data;
    if (userId) {
      socket.join(`user_${userId}`);
      logger.info(`🔌 Client ${socket.id} a rejoint le salon user_${userId}`);
    }
  });

  socket.on('disconnect', () => {
    logger.info(`🔌 Client Socket.io déconnecté: ${socket.id}`);
  });
});

// ── Créer les dossiers nécessaires (skip sur Vercel — filesystem en lecture seule)
const isVercel = !!process.env.VERCEL;
const uploadDir = isVercel ? '/tmp/uploads' : (process.env.UPLOAD_DIR || './uploads');
const logDir = isVercel ? '/tmp/logs' : (process.env.LOG_DIR || './logs');
try {
  [uploadDir, logDir].forEach(dir => {
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
  });
} catch (_) {
  // Vercel : filesystem en lecture seule, on ignore l'erreur
}

// ── Sécurité ─────────────────────────────────────────────────────────────────
// Désactiver la CSP uniquement pour le formulaire public /ticket
// (page HTML autonome avec scripts inline)
app.use((req, res, next) => {
  if (req.path === '/ticket' || req.path === '/qr-ticket' || req.path.startsWith('/public/')) {
    // Pas de CSP stricte sur les pages publiques
    return helmet({
      contentSecurityPolicy: false,
      crossOriginResourcePolicy: { policy: 'cross-origin' },
    })(req, res, next);
  }
  return helmet({ crossOriginResourcePolicy: { policy: 'cross-origin' } })(req, res, next);
});

// ── CORS ─────────────────────────────────────────────────────────────────────
const defaultAllowed = [
  'http://localhost:3000',
  'http://localhost:8080',
  'https://parc-it.vercel.app',
];
const envOrigins = process.env.ALLOWED_ORIGINS
  ? process.env.ALLOWED_ORIGINS.split(',').map(o => o.trim())
  : [];
const allowedOrigins = Array.from(new Set([...defaultAllowed, ...envOrigins]));

app.use(cors({
  origin: (origin, callback) => {
    // Autoriser les requêtes sans origine (apps mobiles/desktop Flutter)
    if (!origin) return callback(null, true);

    // Si ALLOWED_ORIGINS n'est pas défini explicitement, on autorise tout
    if (!process.env.ALLOWED_ORIGINS) return callback(null, true);

    return callback(null, allowedOrigins.includes(origin));
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));


// ── Rate Limiting ─────────────────────────────────────────────────────────────
const isDev = process.env.NODE_ENV === 'development';
const limiter = rateLimit({
  windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS) || 15 * 60 * 1000,
  max: isDev ? 100000 : (parseInt(process.env.RATE_LIMIT_MAX) || 200),
  skip: () => isDev,
  standardHeaders: true,
  legacyHeaders: false,
  message: { success: false, message: 'Trop de requêtes. Réessayez dans quelques minutes.' },
});
app.use('/api/', limiter);

// Rate limit pour l'auth
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 min
  max: isDev ? 100000 : 100,
  skip: () => isDev,
  standardHeaders: true,
  legacyHeaders: false,
  message: { success: false, message: 'Trop de tentatives de connexion. Réessayez dans 15 minutes.' },
});
app.use('/api/auth/login', authLimiter);

// ── Parsers ───────────────────────────────────────────────────────────────────
app.use(compression());
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// ── Logging HTTP ──────────────────────────────────────────────────────────────
app.use(morgan('combined', {
  stream: { write: (msg) => logger.http(msg.trim()) }
}));

// ── Redirection racine vers l'application Flutter Web ─────────────────────────
app.get('/', (req, res) => {
  res.redirect('http://localhost:8080');
});

// ── Normalisation d'URL (compatibilité Vercel Serverless) ─────────────────────
app.use((req, res, next) => {
  if (!req.url.startsWith('/api') && !req.url.startsWith('/uploads') && !req.url.startsWith('/public') && !req.url.startsWith('/ticket') && !req.url.startsWith('/qr')) {
    req.url = '/api' + (req.url.startsWith('/') ? req.url : '/' + req.url);
  }
  next();
});

// ── Routes API ────────────────────────────────────────────────────────────────
app.use('/api/auth', authRoutes);
app.use('/api/assets', assetRoutes);
app.use('/api/dashboard', dashboardRoutes);
app.use('/api/affectations', affectationRoutes);
app.use('/api/users', userRoutes);
app.use('/api/import-export', importExportRoutes);
app.use('/api/tickets', ticketRoutes);
app.use('/api/licences', licenceRoutes);
app.use('/api/consommables', consommableRoutes);
app.use('/api/maintenances', maintenanceRoutes);
app.use('/api/wiki', wikiRoutes);
app.use('/api/search', searchRoutes);
app.use('/api/public', publicTicketRoutes);
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));
app.use('/public', express.static(path.join(__dirname, 'public')));

// ── Formulaire public de soumission de tickets ────────────────────────────────
app.get('/ticket', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'public-ticket.html'));
});

// ── Affiche QR code imprimable ────────────────────────────────────────────────
app.get('/qr-ticket', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'qr-ticket.html'));
});

// ── Image QR code directe ─────────────────────────────────────────────────────
app.get('/qr_ticket.png', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'qr_ticket.png'));
});

// ── Santé du serveur ──────────────────────────────────────────────────────────
app.get('/api/health', async (req, res) => {
  try {
    await testConnection();
    res.json({
      success: true,
      status: 'OK',
      timestamp: new Date().toISOString(),
      version: '1.0.0',
      environment: process.env.NODE_ENV,
    });
  } catch (err) {
    res.status(503).json({ success: false, status: 'DB_ERROR', error: err.message });
  }
});

// ── 404 ───────────────────────────────────────────────────────────────────────
app.use((req, res) => {
  res.status(404).json({ success: false, message: `Route non trouvée: ${req.method} ${req.originalUrl}` });
});

// ── Gestionnaire d'erreurs global ─────────────────────────────────────────────
app.use((err, req, res, next) => {
  logger.error(`${err.message} — ${req.method} ${req.originalUrl}`, { stack: err.stack });
  const status = err.status || err.statusCode || 500;
  res.status(status).json({
    success: false,
    message: process.env.NODE_ENV === 'production' ? 'Erreur interne du serveur' : err.message,
  });
});

// ── Démarrage ─────────────────────────────────────────────────────────────────
async function start() {
  try {
    getJwtSecret();
    await testConnection();
    logger.info('✅ Connexion Supabase PostgreSQL établie');
    server.listen(PORT, '0.0.0.0', () => {
      logger.info(`🚀 Serveur démarré sur http://0.0.0.0:${PORT}`);
      logger.info(`📡 Environnement: ${process.env.NODE_ENV}`);
      logger.info(`🌐 CORS autorisé pour: ${allowedOrigins.join(', ')}`);
    });
  } catch (err) {
    logger.error(`❌ Impossible de démarrer le serveur: ${err.message}`);
    process.exit(1);
  }
}

// ── Démarrage (uniquement en local, pas sur Vercel) ───────────────────────────
if (require.main === module) {
  start();
}

module.exports = app;
