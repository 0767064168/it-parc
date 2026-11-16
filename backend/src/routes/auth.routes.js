'use strict';
const express = require('express');
const { body } = require('express-validator');
const { login, logout, me, changePassword } = require('../controllers/auth.controller');
const { authenticate } = require('../middlewares/auth');
const { validate } = require('../middlewares/validate');
const router = express.Router();

router.post('/login',
  [
    body('username').trim().notEmpty().withMessage('Nom d\'utilisateur requis'),
    body('password').notEmpty().withMessage('Mot de passe requis'),
  ],
  validate,
  login
);

router.post('/logout', authenticate, logout);
router.get('/me', authenticate, me);

router.post('/change-password',
  authenticate,
  [
    body('currentPassword').notEmpty(),
    body('newPassword').isLength({ min: 8 }).withMessage('Minimum 8 caractères')
      .matches(/[A-Z]/).withMessage('Au moins une majuscule')
      .matches(/[0-9]/).withMessage('Au moins un chiffre'),
  ],
  validate,
  changePassword
);

// ── Upload Avatar ───────────────────────────────────────────────────────────
const multer = require('multer');
const path = require('path');
const fs = require('fs');

const avatarStorage = multer.diskStorage({
  destination: (req, file, cb) => {
    const dir = process.env.VERCEL ? '/tmp/uploads/avatars' : './uploads/avatars';
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
    cb(null, dir);
  },
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname);
    cb(null, `avatar_${req.user.id}_${Date.now()}${ext}`);
  },
});

const avatarUpload = multer({
  storage: avatarStorage,
  limits: { fileSize: 5 * 1024 * 1024 }, // Max 5 MB
  fileFilter: (req, file, cb) => {
    const allowed = ['.png', '.jpg', '.jpeg', '.gif', '.webp'];
    if (allowed.includes(path.extname(file.originalname).toLowerCase())) {
      cb(null, true);
    } else {
      cb(new Error('Format d\'image non autorisé. Seuls PNG, JPG, JPEG, GIF et WEBP sont acceptés.'));
    }
  },
});

const { updateAvatar } = require('../controllers/auth.controller');
router.post('/avatar', authenticate, avatarUpload.single('avatar'), updateAvatar);

module.exports = router;
