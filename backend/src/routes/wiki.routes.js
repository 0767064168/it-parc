'use strict';
// =====================================================
// backend/src/routes/wiki.routes.js
// =====================================================
const express = require('express');
const multer = require('multer');
const path = require('path');
const { body, param } = require('express-validator');
const ctrl = require('../controllers/wiki.controller');
const { authenticate } = require('../middlewares/auth');
const { requirePermission } = require('../middlewares/roles');
const { validate } = require('../middlewares/validate');
const router = express.Router();

// ─── Multer — upload pièces jointes wiki ─────────────
const wikiStorage = multer.diskStorage({
  destination: (req, file, cb) => {
    const defaultDir = process.env.VERCEL ? '/tmp/uploads/wiki' : './uploads/wiki';
    const dir = process.env.WIKI_UPLOAD_DIR || defaultDir;
    if (!fs.existsSync(dir)) {
      try { fs.mkdirSync(dir, { recursive: true }); } catch (_) {}
    }
    cb(null, dir);
  },
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname);
    const safeName = path.basename(file.originalname, ext)
      .replace(/[^a-zA-Z0-9_\-]/g, '_')
      .substring(0, 60);
    cb(null, `wiki_${Date.now()}_${safeName}${ext}`);
  },
});

const wikiUpload = multer({
  storage: wikiStorage,
  limits: { fileSize: (parseInt(process.env.MAX_FILE_SIZE_MB) || 20) * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    const allowed = [
      '.pdf', '.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx',
      '.txt', '.md', '.csv',
      '.png', '.jpg', '.jpeg', '.gif', '.svg', '.webp',
      '.zip', '.7z', '.rar',
    ];
    if (allowed.includes(path.extname(file.originalname).toLowerCase())) {
      cb(null, true);
    } else {
      cb(new Error('Type de fichier non autorisé'));
    }
  },
});

router.use(authenticate);

// ── Articles (routes fixes en premier) ───────────────
router.get('/', requirePermission('wiki:read'), ctrl.list);

router.post('/',
  requirePermission('wiki:manage'),
  [
    body('titre').notEmpty().withMessage('Titre requis'),
    body('contenu').notEmpty().withMessage('Contenu requis'),
  ],
  validate,
  ctrl.create
);

// ── Pièces Jointes : routes statiques AVANT les routes /:id ──
// IMPORTANT: Ces routes DOIVENT être déclarées avant /:id sinon
// Express interprète "attachments" comme valeur de :id.

// Téléchargement d'une pièce jointe
router.get('/attachments/:attachmentId/download',
  requirePermission('wiki:read'),
  [param('attachmentId').isInt()],
  validate,
  ctrl.downloadAttachment
);

// Suppression d'une pièce jointe
router.delete('/attachments/:attachmentId',
  requirePermission('wiki:manage'),
  [param('attachmentId').isInt()],
  validate,
  ctrl.deleteAttachment
);

// ── Articles : routes dynamiques /:id ─────────────────
router.get('/:id', requirePermission('wiki:read'), [param('id').isInt()], validate, ctrl.getOne);

router.put('/:id',
  requirePermission('wiki:manage'),
  [param('id').isInt()],
  validate,
  ctrl.update
);

router.delete('/:id',
  requirePermission('wiki:manage'),
  [param('id').isInt()],
  validate,
  ctrl.remove
);

// Liste des pièces jointes d'un article
router.get('/:id/attachments',
  requirePermission('wiki:read'),
  [param('id').isInt()],
  validate,
  ctrl.listAttachments
);

// Upload d'une pièce jointe
router.post('/:id/attachments',
  requirePermission('wiki:manage'),
  [param('id').isInt()],
  validate,
  wikiUpload.single('file'),
  ctrl.uploadAttachment
);

module.exports = router;
