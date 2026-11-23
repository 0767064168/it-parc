// ============================================
// src/routes/ticket.routes.js
// Routes pour le module de gestion des tickets IT
// ============================================
'use strict';

const express = require('express');
const { body, param, query } = require('express-validator');
const multer = require('multer');
const path = require('path');

const ctrl = require('../controllers/ticket.controller');
const { authenticate } = require('../middlewares/auth');
const { requireRole } = require('../middlewares/roles');
const { validate } = require('../middlewares/validate');

const router = express.Router();

// Configuration Upload Multer pour Pièces Jointes (Photos/Captures)
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    const defaultDir = process.env.VERCEL ? '/tmp/uploads/tickets' : './uploads/tickets';
    const dir = process.env.UPLOAD_DIR || defaultDir;
    if (!fs.existsSync(dir)) {
      try { fs.mkdirSync(dir, { recursive: true }); } catch (_) {}
    }
    cb(null, dir);
  },
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname);
    cb(null, `tkt_${Date.now()}_${Math.round(Math.random() * 1e9)}${ext}`);
  },
});

const upload = multer({
  storage,
  limits: { fileSize: (parseInt(process.env.MAX_FILE_SIZE_MB) || 10) * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    const allowed = ['.png', '.jpg', '.jpeg', '.gif', '.pdf', '.docx', '.xlsx', '.xls'];
    if (allowed.includes(path.extname(file.originalname).toLowerCase())) {
      cb(null, true);
    } else {
      cb(new Error('Fichiers autorisés: Images (PNG, JPG, GIF), PDF, Word, Excel.'));
    }
  },
});

// Toutes les routes nécessitent d''être connecté
router.use(authenticate);

// ── Statistiques et Exports (Routes spécifiques d''abord) ────────────────────
router.get('/stats/dashboard', requireRole('admin', 'technicien'), ctrl.getDashboardStats);
router.get('/stats/rapports', requireRole('admin'), ctrl.getReports);
router.get('/export/excel', requireRole('admin', 'technicien'), ctrl.exportExcel);
router.get('/export/pdf', requireRole('admin', 'technicien'), ctrl.exportPdf);
router.get('/notifications', ctrl.getNotifications);
router.patch('/notifications/:id/lu', [
  param('id').isInt().withMessage('ID de notification invalide')
], validate, ctrl.markNotificationAsRead);

// ── CRUD de base ─────────────────────────────────────────────────────────────
router.get('/', ctrl.list);

router.get('/:id', [
  param('id').isInt().withMessage('ID de ticket invalide')
], validate, ctrl.getOne);

router.post('/', [
  body('titre').notEmpty().trim().withMessage('Le titre est obligatoire (max 200 caract.)').isLength({ max: 200 }),
  body('description').notEmpty().trim().withMessage('La description est obligatoire'),
  body('type').isIn(['incident', 'demande_materiel', 'maintenance', 'acces_logiciel']).withMessage('Type invalide'),
  body('priorite').isIn(['critique', 'haute', 'moyenne', 'basse']).withMessage('Priorité suggérée invalide'),
  body('asset_id').optional({ nullable: true }).isInt().withMessage("ID d'asset invalide"),
], validate, ctrl.create);

router.put('/:id', [
  requireRole('admin'),
  param('id').isInt().withMessage('ID de ticket invalide'),
  body('titre').optional().notEmpty().trim().isLength({ max: 200 }),
  body('description').optional().notEmpty().trim(),
  body('type').optional().isIn(['incident', 'demande_materiel', 'maintenance', 'acces_logiciel']),
  body('priorite').optional().isIn(['critique', 'haute', 'moyenne', 'basse']),
], validate, ctrl.update);

// ── Cycle de Vie & Actions ───────────────────────────────────────────────────
router.patch('/:id/statut', [
  param('id').isInt().withMessage('ID invalide'),
  body('statut').isIn(['ouvert', 'en_cours', 'en_attente', 'resolu', 'ferme', 'annule', 'rouvert']).withMessage('Statut cible invalide'),
  body('commentaire').notEmpty().trim().withMessage('Un commentaire explicatif est obligatoire pour changer le statut'),
], validate, ctrl.changeStatus);

router.patch('/:id/assigner', [
  requireRole('admin', 'technicien'),
  param('id').isInt().withMessage('ID invalide'),
  body('technicien_id').isInt().withMessage('ID du technicien invalide'),
], validate, ctrl.assign);

router.post('/:id/commentaires', [
  param('id').isInt().withMessage('ID invalide'),
  body('contenu').notEmpty().trim().withMessage('Le contenu du commentaire ne peut pas être vide'),
  body('type').optional().isIn(['public', 'interne']),
], validate, ctrl.addComment);

router.get('/:id/historique', [
  requireRole('admin', 'technicien'),
  param('id').isInt().withMessage('ID invalide')
], validate, ctrl.getHistory);

router.post('/:id/evaluer', [
  param('id').isInt().withMessage('ID invalide'),
  body('note').isInt({ min: 1, max: 5 }).withMessage('La note doit être comprise entre 1 et 5 étoiles'),
  body('commentaire').optional().trim(),
], validate, ctrl.evaluate);

router.post('/:id/pieces-jointes', 
  upload.single('file'), 
  ctrl.uploadAttachment
);

module.exports = router;
