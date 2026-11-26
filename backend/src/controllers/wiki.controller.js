'use strict';
// =====================================================
// backend/src/controllers/wiki.controller.js
// =====================================================
const path = require('path');
const fs = require('fs');
const WikiModel = require('../models/wiki.model');
const { success, error } = require('../utils/response');
const logger = require('../utils/logger');
const storageService = require('../services/storage.service');

// ─── Articles ─────────────────────────────────────────
async function list(req, res) {
  try {
    const { search } = req.query;
    const role = req.user.role;
    const articles = await WikiModel.findAll({ search, role });
    return success(res, articles);
  } catch (err) {
    logger.error('Erreur list wiki:', err);
    return error(res, 'Erreur serveur', 500);
  }
}

async function getOne(req, res) {
  try {
    const id = parseInt(req.params.id);
    const article = await WikiModel.findById(id);
    if (!article) return error(res, 'Article de wiki introuvable', 404);

    if (req.user.role === 'lecteur' && !article.est_public) {
      return error(res, 'Accès interdit à cet article', 403);
    }

    return success(res, article);
  } catch (err) {
    logger.error('Erreur getOne wiki:', err);
    return error(res, 'Erreur serveur', 500);
  }
}

async function create(req, res) {
  try {
    const insertId = await WikiModel.create(req.body, req.user.id);
    const created = await WikiModel.findById(insertId);
    return success(res, created, 'Article de wiki créé avec succès', 201);
  } catch (err) {
    logger.error('Erreur create wiki:', err);
    return error(res, 'Erreur serveur', 500);
  }
}

async function update(req, res) {
  try {
    const id = parseInt(req.params.id);
    const article = await WikiModel.findById(id);
    if (!article) return error(res, 'Article de wiki introuvable', 404);

    await WikiModel.update(id, req.body);
    const updated = await WikiModel.findById(id);
    return success(res, updated, 'Article de wiki mis à jour avec succès');
  } catch (err) {
    logger.error('Erreur update wiki:', err);
    return error(res, 'Erreur serveur', 500);
  }
}

async function remove(req, res) {
  try {
    const id = parseInt(req.params.id);
    const article = await WikiModel.findById(id);
    if (!article) return error(res, 'Article de wiki introuvable', 404);

    await WikiModel.remove(id);
    return success(res, null, 'Article de wiki supprimé avec succès');
  } catch (err) {
    logger.error('Erreur remove wiki:', err);
    return error(res, 'Erreur serveur', 500);
  }
}

// ─── Pièces Jointes ───────────────────────────────────
async function listAttachments(req, res) {
  try {
    const articleId = parseInt(req.params.id);
    const article = await WikiModel.findById(articleId);
    if (!article) return error(res, 'Article introuvable', 404);

    const attachments = await WikiModel.findAttachments(articleId);
    return success(res, attachments);
  } catch (err) {
    logger.error('Erreur listAttachments wiki:', err);
    return error(res, 'Erreur serveur', 500);
  }
}

async function uploadAttachment(req, res) {
  try {
    const articleId = parseInt(req.params.id);
    const article = await WikiModel.findById(articleId);
    if (!article) {
      // Nettoyer le fichier uploadé si l'article n'existe pas
      if (req.file) fs.unlinkSync(req.file.path);
      return error(res, 'Article introuvable', 404);
    }

    if (!req.file) return error(res, 'Aucun fichier reçu', 400);

    const storedPath = await storageService.uploadFile(
      req.file.path,
      `wiki/${articleId}/${req.file.filename}`,
      req.file.mimetype
    );

    const attachmentId = await WikiModel.createAttachment({
      article_id: articleId,
      nom_fichier: req.file.filename,
      nom_original: req.file.originalname,
      chemin: storedPath,
      taille: req.file.size,
      type_mime: req.file.mimetype,
      uploaded_by: req.user.id,
    });

    const attachment = await WikiModel.findAttachmentById(attachmentId);
    return success(res, attachment, 'Fichier uploadé avec succès', 201);
  } catch (err) {
    logger.error('Erreur uploadAttachment wiki:', err);
    if (req.file && fs.existsSync(req.file.path)) {
      fs.unlinkSync(req.file.path);
    }
    return error(res, 'Erreur serveur', 500);
  }
}

async function downloadAttachment(req, res) {
  try {
    const attachmentId = parseInt(req.params.attachmentId);
    const attachment = await WikiModel.findAttachmentById(attachmentId);
    if (!attachment) return error(res, 'Fichier introuvable', 404);

    let filePath = attachment.chemin;
    if (filePath && !filePath.startsWith('supabase://') && !path.isAbsolute(filePath)) {
      filePath = path.join(__dirname, '../../', filePath);
    }

    const sent = await storageService.sendStoredFile(
      filePath,
      res,
      attachment.nom_original,
      attachment.type_mime
    );
    if (!sent) {
      logger.error(`Fichier physique introuvable: ${filePath}`);
      return error(res, 'Fichier physique introuvable sur le serveur', 404);
    }
  } catch (err) {
    logger.error('Erreur downloadAttachment wiki:', err);
    return error(res, 'Erreur serveur', 500);
  }
}

async function deleteAttachment(req, res) {
  try {
    const attachmentId = parseInt(req.params.attachmentId);
    const attachment = await WikiModel.findAttachmentById(attachmentId);
    if (!attachment) return error(res, 'Fichier introuvable', 404);

    await storageService.deleteStoredFile(attachment.chemin);
    await WikiModel.deleteAttachment(attachmentId);
    return success(res, null, 'Fichier supprimé avec succès');
  } catch (err) {
    logger.error('Erreur deleteAttachment wiki:', err);
    return error(res, 'Erreur serveur', 500);
  }
}

module.exports = { list, getOne, create, update, remove, listAttachments, uploadAttachment, downloadAttachment, deleteAttachment };
