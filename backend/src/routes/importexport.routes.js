'use strict';
const express = require('express');
const fs = require('fs');
const multer = require('multer');
const path = require('path');
const { importExcel, previewExcel, exportExcel } = require('../controllers/importexport.controller');
const { authenticate } = require('../middlewares/auth');
const { requirePermission } = require('../middlewares/roles');
const router = express.Router();

const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    const defaultDir = process.env.VERCEL ? '/tmp/uploads/imports' : './uploads/imports';
    const dir = process.env.UPLOAD_DIR || defaultDir;
    if (!fs.existsSync(dir)) {
      try { fs.mkdirSync(dir, { recursive: true }); } catch (_) {}
    }
    cb(null, dir);
  },
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname);
    cb(null, `import_${Date.now()}${ext}`);
  },
});

const upload = multer({
  storage,
  limits: { fileSize: (parseInt(process.env.MAX_FILE_SIZE_MB) || 10) * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    const allowed = ['.xlsx', '.xls', '.csv'];
    if (allowed.includes(path.extname(file.originalname).toLowerCase())) {
      cb(null, true);
    } else {
      cb(new Error('Seuls les fichiers .xlsx, .xls et .csv sont acceptés'));
    }
  },
});

router.post('/import/excel',
  authenticate,
  requirePermission('import:excel'),
  upload.single('file'),
  importExcel
);

router.post('/import/preview',
  authenticate,
  requirePermission('import:excel'),
  upload.single('file'),
  previewExcel
);

router.get('/export/excel',
  authenticate,
  requirePermission('export:excel'),
  exportExcel
);

module.exports = router;
