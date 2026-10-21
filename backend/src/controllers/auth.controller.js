// ============================================
// src/controllers/auth.controller.js
// ============================================
'use strict';

const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const fs = require('fs');
const path = require('path');
const { query } = require('../config/db');
const { success, error } = require('../utils/response');
const logger = require('../utils/logger');

/**
 * POST /api/auth/login
 */
async function login(req, res) {
  try {
    const { username, password } = req.body;

    // Chercher l'utilisateur
    const users = await query(
      'SELECT id, username, password_hash, role, nom, prenom, actif, avatar_url FROM auth_users WHERE username = ? LIMIT 1',
      [username.toLowerCase().trim()]
    );

    if (!users.length) {
      return error(res, 'Identifiants incorrects', 401);
    }

    const user = users[0];

    if (!user.actif) {
      return error(res, 'Compte désactivé. Contactez l\'administrateur.', 403);
    }

    const passwordMatch = await bcrypt.compare(password, user.password_hash);
    if (!passwordMatch) {
      // Log tentative échouée
      await query(
        'INSERT INTO activity_logs (user_id, action, entity_type, details) VALUES (?, ?, ?, ?)',
        [user.id, 'LOGIN_FAILED', 'auth', JSON.stringify({ username, ip: req.ip })]
      );
      return error(res, 'Identifiants incorrects', 401);
    }

    // Générer le token JWT
    const token = jwt.sign(
      { id: user.id, username: user.username, role: user.role, nom: `${user.prenom} ${user.nom}` },
      process.env.JWT_SECRET,
      { expiresIn: process.env.JWT_EXPIRES_IN || '8h' }
    );

    // Log de connexion réussie
    await query(
      'INSERT INTO activity_logs (user_id, action, entity_type, details) VALUES (?, ?, ?, ?)',
      [user.id, 'LOGIN_SUCCESS', 'auth', JSON.stringify({ ip: req.ip })]
    );

    logger.info(`Connexion réussie: ${user.username} (${user.role})`);

    return success(res, {
      token,
      user: {
        id: user.id,
        username: user.username,
        role: user.role,
        nom: user.nom,
        prenom: user.prenom,
        nomComplet: `${user.prenom} ${user.nom}`,
        avatarUrl: user.avatar_url,
      },
      expiresIn: process.env.JWT_EXPIRES_IN || '8h',
    }, 'Connexion réussie');
  } catch (err) {
    logger.error('Erreur login:', err);
    return error(res, 'Erreur lors de la connexion', 500);
  }
}

/**
 * POST /api/auth/logout (optionnel côté serveur)
 */
async function logout(req, res) {
  try {
    if (req.user) {
      await query(
        'INSERT INTO activity_logs (user_id, action, entity_type, details) VALUES (?, ?, ?, ?)',
        [req.user.id, 'LOGOUT', 'auth', JSON.stringify({ ip: req.ip })]
      );
    }
    return success(res, null, 'Déconnexion réussie');
  } catch (err) {
    return success(res, null, 'Déconnexion réussie');
  }
}

/**
 * GET /api/auth/me — Profil de l'utilisateur connecté
 */
async function me(req, res) {
  try {
    const users = await query(
      'SELECT id, username, role, nom, prenom, created_at, avatar_url FROM auth_users WHERE id = ? AND actif = 1',
      [req.user.id]
    );
    if (!users.length) return error(res, 'Utilisateur introuvable', 404);
    const user = users[0];
    return success(res, {
      ...user,
      nomComplet: `${user.prenom} ${user.nom}`,
      avatarUrl: user.avatar_url,
    });
  } catch (err) {
    logger.error('Erreur me:', err);
    return error(res, 'Erreur serveur', 500);
  }
}

/**
 * POST /api/auth/change-password
 */
async function changePassword(req, res) {
  try {
    const { currentPassword, newPassword } = req.body;
    const users = await query('SELECT id, password_hash FROM auth_users WHERE id = ?', [req.user.id]);
    if (!users.length) return error(res, 'Utilisateur introuvable', 404);

    const match = await bcrypt.compare(currentPassword, users[0].password_hash);
    if (!match) return error(res, 'Mot de passe actuel incorrect', 401);

    const hash = await bcrypt.hash(newPassword, 12);
    await query('UPDATE auth_users SET password_hash = ? WHERE id = ?', [hash, req.user.id]);

    await query(
      'INSERT INTO activity_logs (user_id, action, entity_type) VALUES (?, ?, ?)',
      [req.user.id, 'PASSWORD_CHANGED', 'auth']
    );

    return success(res, null, 'Mot de passe modifié avec succès');
  } catch (err) {
    logger.error('Erreur changePassword:', err);
    return error(res, 'Erreur serveur', 500);
  }
}

/**
 * POST /api/auth/avatar — Upload photo de profil
 */
async function updateAvatar(req, res) {
  try {
    if (!req.file) {
      return error(res, 'Aucun fichier fourni', 400);
    }

    const userId = req.user.id;
    const newAvatarUrl = `/uploads/avatars/${req.file.filename}`;

    // Récupérer l'avatar actuel pour le supprimer du disque
    const users = await query('SELECT avatar_url FROM auth_users WHERE id = ?', [userId]);
    if (users.length && users[0].avatar_url) {
      const oldPath = path.join(__dirname, '../..', users[0].avatar_url);
      if (fs.existsSync(oldPath)) {
        try {
          fs.unlinkSync(oldPath);
        } catch (_) {}
      }
    }

    // Mettre à jour en BDD
    await query('UPDATE auth_users SET avatar_url = ? WHERE id = ?', [newAvatarUrl, userId]);

    // Log action
    await query(
      'INSERT INTO activity_logs (user_id, action, entity_type) VALUES (?, ?, ?)',
      [userId, 'AVATAR_CHANGED', 'auth']
    );

    return success(res, { avatarUrl: newAvatarUrl }, 'Photo de profil mise à jour');
  } catch (err) {
    logger.error('Erreur updateAvatar:', err);
    return error(res, 'Erreur serveur lors de la mise à jour de la photo de profil', 500);
  }
}

module.exports = { login, logout, me, changePassword, updateAvatar };
