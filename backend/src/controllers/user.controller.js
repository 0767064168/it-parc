'use strict';
const UserModel = require('../models/user.model');
const { query } = require('../config/db');
const { success, error, paginated } = require('../utils/response');
const logger = require('../utils/logger');
const bcrypt = require('bcryptjs');

async function list(req, res) {
  try {
    const { page = 1, limit = 20, site, departement, search } = req.query;
    const { users, total } = await UserModel.findAll({ page: parseInt(page), limit: parseInt(limit), site, departement, search });
    return paginated(res, users, total, page, limit);
  } catch (err) {
    logger.error('Erreur list users:', err);
    return error(res, 'Erreur serveur', 500);
  }
}

async function getOne(req, res) {
  try {
    const user = await UserModel.findById(parseInt(req.params.id));
    if (!user) return error(res, 'Utilisateur introuvable', 404);
    return success(res, user);
  } catch (err) {
    return error(res, 'Erreur serveur', 500);
  }
}

async function create(req, res) {
  try {
    const userId = await UserModel.create(req.body);
    // Créer compte auth si fourni
    if (req.body.username && req.body.password) {
      const hash = await bcrypt.hash(req.body.password, 12);
      await query(
        'INSERT INTO auth_users (username, password_hash, role, nom, prenom, email) VALUES (?, ?, ?, ?, ?, ?)',
        [req.body.username, hash, req.body.role || 'lecteur', req.body.nom, req.body.prenom, req.body.email || null]
      );
    }
    const created = await UserModel.findById(userId);
    return success(res, created, 'Utilisateur créé', 201);
  } catch (err) {
    logger.error('Erreur create user:', err);
    if (err.code === 'ER_DUP_ENTRY') return error(res, 'Email ou username déjà utilisé', 409);
    return error(res, 'Erreur serveur', 500);
  }
}

async function update(req, res) {
  try {
    const id = parseInt(req.params.id);
    const existing = await UserModel.findById(id);
    if (!existing) return error(res, 'Utilisateur introuvable', 404);
    await UserModel.update(id, req.body);
    const updated = await UserModel.findById(id);
    return success(res, updated, 'Utilisateur mis à jour');
  } catch (err) {
    return error(res, 'Erreur serveur', 500);
  }
}

// Liste des comptes auth (admin seulement)
async function listAuthUsers(req, res) {
  try {
    const users = await query('SELECT id, username, role, nom, prenom, actif, created_at FROM auth_users ORDER BY created_at DESC');
    return success(res, users);
  } catch (err) {
    return error(res, 'Erreur serveur', 500);
  }
}

async function toggleAuthUser(req, res) {
  try {
    const { id } = req.params;
    const users = await query('SELECT actif FROM auth_users WHERE id = ?', [id]);
    if (!users.length) return error(res, 'Compte introuvable', 404);
    const newActif = users[0].actif ? 0 : 1;
    await query('UPDATE auth_users SET actif = ? WHERE id = ?', [newActif, id]);
    return success(res, { actif: newActif }, newActif ? 'Compte activé' : 'Compte désactivé');
  } catch (err) {
    return error(res, 'Erreur serveur', 500);
  }
}

async function remove(req, res) {
  try {
    const id = parseInt(req.params.id);
    const existing = await UserModel.findById(id);
    if (!existing) return error(res, 'Utilisateur introuvable', 404);
    
    await UserModel.remove(id);
    return success(res, null, 'Utilisateur supprimé avec succès');
  } catch (err) {
    logger.error('Erreur remove user:', err);
    if (err.code === 'ER_ROW_IS_REFERENCED_2') {
      return error(res, 'Impossible de supprimer cet utilisateur car il a des affectations ou des éléments liés.', 409);
    }
    return error(res, 'Erreur lors de la suppression de l\'utilisateur', 500);
  }
}

module.exports = { list, getOne, create, update, remove, listAuthUsers, toggleAuthUser };
