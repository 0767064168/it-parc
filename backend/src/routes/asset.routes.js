'use strict';
const express = require('express');
const multer = require('multer');
const path = require('path');
const { body, param, query } = require('express-validator');
const ctrl = require('../controllers/asset.controller');
const { authenticate } = require('../middlewares/auth');
const { requirePermission } = require('../middlewares/roles');
const { validate } = require('../middlewares/validate');
const router = express.Router();

// Configuration Multer pour les pièces jointes des assets
const assetStorage = multer.diskStorage({
  destination: (req, file, cb) => {
    const defaultDir = process.env.VERCEL ? '/tmp/uploads/assets' : './uploads/assets';
    const dir = process.env.ASSET_UPLOAD_DIR || defaultDir;
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
    cb(null, `asset_${Date.now()}_${safeName}${ext}`);
  },
});

const assetUpload = multer({
  storage: assetStorage,
  limits: { fileSize: (parseInt(process.env.MAX_FILE_SIZE_MB) || 20) * 1024 * 1024 }, // Max 20 Mo par défaut
  fileFilter: (req, file, cb) => {
    const allowed = [
      '.pdf', '.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx',
      '.txt', '.md', '.csv',
      '.png', '.jpg', '.jpeg', '.gif', '.svg', '.webp',
      '.zip', '.7z', '.rar'
    ];
    if (allowed.includes(path.extname(file.originalname).toLowerCase())) {
      cb(null, true);
    } else {
      cb(new Error('Format de fichier non autorisé.'));
    }
  },
});

router.use(authenticate);

// ── CRUD Équipements ────────────────────────────────────────────────────────
router.get('/search', requirePermission('assets:read'), ctrl.searchAssets);
router.get('/filter-options', requirePermission('assets:read'), ctrl.filterOptions);
router.get('/', requirePermission('assets:read'), ctrl.list);
router.get('/:id', requirePermission('assets:read'), [
  param('id').isInt().withMessage('ID invalide')
], validate, ctrl.getOne);

router.post('/',
  requirePermission('assets:create'),
  [
    body('asset.asset_tag').notEmpty().withMessage('Asset Tag requis'),
    body('asset.marque').notEmpty().withMessage('Marque requise'),
    body('asset.type').notEmpty().withMessage('Type requis'),
    body('asset.statut').optional().isIn(['en_service','hors_service','reforme','en_maintenance','en_stock']),
  ],
  validate,
  ctrl.create
);

router.put('/:id',
  requirePermission('assets:update'),
  [param('id').isInt()],
  validate,
  ctrl.update
);

router.delete('/:id',
  requirePermission('assets:delete'),
  [param('id').isInt()],
  validate,
  ctrl.archive
);

// ── Pièces Jointes Équipements ──────────────────────────────────────────────
router.get('/:id/attachments',
  requirePermission('assets:read'),
  [param('id').isInt()],
  validate,
  ctrl.listAttachments
);

router.post('/:id/attachments',
  requirePermission('assets:update'),
  [param('id').isInt()],
  validate,
  assetUpload.single('file'),
  ctrl.uploadAttachment
);

router.get('/attachments/:attachmentId/download',
  requirePermission('assets:read'),
  [param('attachmentId').isInt()],
  validate,
  ctrl.downloadAttachment
);

router.delete('/attachments/:attachmentId',
  requirePermission('assets:update'),
  [param('attachmentId').isInt()],
  validate,
  ctrl.deleteAttachment
);

module.exports = router;
