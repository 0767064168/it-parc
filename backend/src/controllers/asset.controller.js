// ============================================
// src/controllers/asset.controller.js
// ============================================
'use strict';

const fs = require('fs');
const path = require('path');
let QRCode;
try {
  QRCode = require('qrcode');
} catch (e) {
  // lazy loaded
}
const AssetModel = require('../models/asset.model');
const { query } = require('../config/db');
const { success, error, paginated } = require('../utils/response');
const logger = require('../utils/logger');

async function list(req, res) {
  try {
    const { page = 1, limit = 20, type, statut, site, departement, search } = req.query;
    const { assets, total } = await AssetModel.findAll({
      page: parseInt(page), limit: parseInt(limit),
      type, statut, site, departement, search
    });
    return paginated(res, assets, total, page, limit);
  } catch (err) {
    logger.error('Erreur list assets:', err);
    return error(res, 'Erreur lors de la récupération des assets', 500);
  }
}

async function getOne(req, res) {
  try {
    const asset = await AssetModel.findById(parseInt(req.params.id));
    if (!asset) return error(res, 'Asset introuvable', 404);
    return success(res, asset);
  } catch (err) {
    logger.error('Erreur getOne asset:', err);
    return error(res, 'Erreur serveur', 500);
  }
}

async function searchAssets(req, res) {
  try {
    const { q, limit = 20 } = req.query;
    if (!q || q.trim().length < 2) return error(res, 'Recherche trop courte (min 2 caractères)', 400);
    const assets = await AssetModel.search(q.trim(), parseInt(limit));
    return success(res, assets);
  } catch (err) {
    logger.error('Erreur search:', err);
    return error(res, 'Erreur lors de la recherche', 500);
  }
}

async function create(req, res) {
  try {
    const assetId = await AssetModel.create(req.body);
    await query(
      'INSERT INTO activity_logs (user_id, action, entity_type, entity_id, details) VALUES (?, ?, ?, ?, ?)',
      [req.user.id, 'CREATE', 'asset', assetId, JSON.stringify({ asset_tag: req.body.asset?.asset_tag })]
    );
    const created = await AssetModel.findById(assetId);
    return success(res, created, 'Asset créé avec succès', 201);
  } catch (err) {
    logger.error('Erreur create asset:', err);
    if (err.code === 'ER_DUP_ENTRY') return error(res, 'Asset Tag ou numéro de série déjà existant', 409);
    return error(res, 'Erreur lors de la création', 500);
  }
}

async function update(req, res) {
  try {
    const id = parseInt(req.params.id);
    const existing = await AssetModel.findById(id);
    if (!existing) return error(res, 'Asset introuvable', 404);

    const payload = req.body.asset ? req.body : { asset: req.body };
    await AssetModel.update(id, payload);
    await query(
      'INSERT INTO activity_logs (user_id, action, entity_type, entity_id, details) VALUES (?, ?, ?, ?, ?)',
      [req.user.id, 'UPDATE', 'asset', id, JSON.stringify(payload.asset || payload)]
    );
    const updated = await AssetModel.findById(id);
    return success(res, updated, 'Asset mis à jour');
  } catch (err) {
    logger.error('Erreur update asset:', err);
    return error(res, 'Erreur lors de la mise à jour', 500);
  }
}

async function archive(req, res) {
  try {
    const id = parseInt(req.params.id);
    const existing = await AssetModel.findById(id);
    if (!existing) return error(res, 'Asset introuvable', 404);

    await AssetModel.archive(id, req.body.motif);
    await query(
      'INSERT INTO activity_logs (user_id, action, entity_type, entity_id, details) VALUES (?, ?, ?, ?, ?)',
      [req.user.id, 'ARCHIVE', 'asset', id, JSON.stringify({ motif: req.body.motif })]
    );
    return success(res, null, 'Asset archivé avec succès');
  } catch (err) {
    logger.error('Erreur archive asset:', err);
    return error(res, 'Erreur lors de l\'archivage', 500);
  }
}

async function filterOptions(req, res) {
  try {
    const options = await AssetModel.getFilterOptions();
    return success(res, options);
  } catch (err) {
    logger.error('Erreur filterOptions:', err);
    return error(res, 'Erreur serveur', 500);
  }
}

// ─── Pièces Jointes ───────────────────────────────────
async function listAttachments(req, res) {
  try {
    const assetId = parseInt(req.params.id);
    const asset = await AssetModel.findById(assetId);
    if (!asset) return error(res, 'Équipement introuvable', 404);

    const attachments = await AssetModel.findAttachments(assetId);
    return success(res, attachments);
  } catch (err) {
    logger.error('Erreur listAttachments asset:', err);
    return error(res, 'Erreur serveur', 500);
  }
}

async function uploadAttachment(req, res) {
  try {
    const assetId = parseInt(req.params.id);
    const asset = await AssetModel.findById(assetId);
    if (!asset) {
      if (req.file) fs.unlinkSync(req.file.path);
      return error(res, 'Équipement introuvable', 404);
    }

    if (!req.file) return error(res, 'Aucun fichier reçu', 400);

    const attachmentId = await AssetModel.createAttachment({
      asset_id: assetId,
      nom_fichier: req.file.filename,
      nom_original: req.file.originalname,
      chemin: req.file.path,
      taille: req.file.size,
      type_mime: req.file.mimetype,
      uploaded_by: req.user.id,
    });

    const attachment = await AssetModel.findAttachmentById(attachmentId);
    return success(res, attachment, 'Fichier importé avec succès', 201);
  } catch (err) {
    logger.error('Erreur uploadAttachment asset:', err);
    if (req.file && fs.existsSync(req.file.path)) {
      fs.unlinkSync(req.file.path);
    }
    return error(res, 'Erreur serveur', 500);
  }
}

async function downloadAttachment(req, res) {
  try {
    const attachmentId = parseInt(req.params.attachmentId);
    const attachment = await AssetModel.findAttachmentById(attachmentId);
    if (!attachment) return error(res, 'Fichier introuvable', 404);

    const filePath = path.resolve(attachment.chemin);
    if (!fs.existsSync(filePath)) return error(res, 'Fichier physique introuvable', 404);

    res.setHeader('Content-Disposition', `attachment; filename="${encodeURIComponent(attachment.nom_original)}"`);
    res.setHeader('Content-Type', attachment.type_mime || 'application/octet-stream');
    res.sendFile(filePath);
  } catch (err) {
    logger.error('Erreur downloadAttachment asset:', err);
    return error(res, 'Erreur serveur', 500);
  }
}

async function deleteAttachment(req, res) {
  try {
    const attachmentId = parseInt(req.params.attachmentId);
    const attachment = await AssetModel.findAttachmentById(attachmentId);
    if (!attachment) return error(res, 'Fichier introuvable', 404);

    const filePath = path.resolve(attachment.chemin);
    if (fs.existsSync(filePath)) {
      fs.unlinkSync(filePath);
    }

    await AssetModel.deleteAttachment(attachmentId);
    return success(res, null, 'Fichier supprimé avec succès');
  } catch (err) {
    logger.error('Erreur deleteAttachment asset:', err);
    return error(res, 'Erreur serveur', 500);
  }
}

async function getQrCode(req, res) {
  try {
    const id = parseInt(req.params.id);
    const asset = await AssetModel.findById(id);
    if (!asset) return error(res, 'Équipement introuvable', 404);

    if (!QRCode) {
      try { QRCode = require('qrcode'); } catch (_) {}
    }
    if (!QRCode) {
      return error(res, 'Module QR Code non disponible', 500);
    }

    const assetTag = asset['Nom Machine'] || asset.asset_tag || `ASSET-${asset.id}`;
    const qrData = JSON.stringify({
      id: asset.id,
      tag: assetTag,
      sn: asset.serial_number || '',
      type: asset.type,
      site: asset.site || ''
    });

    if (req.query.format === 'image' || req.query.download === 'true') {
      const buffer = await QRCode.toBuffer(qrData, {
        errorCorrectionLevel: 'M',
        margin: 2,
        width: 320,
      });
      res.setHeader('Content-Type', 'image/png');
      res.setHeader('Content-Disposition', `attachment; filename="QR_${assetTag}.png"`);
      return res.send(buffer);
    }

    const dataUrl = await QRCode.toDataURL(qrData, {
      errorCorrectionLevel: 'M',
      margin: 2,
      width: 250,
      color: {
        dark: '#0f172a',
        light: '#ffffff'
      }
    });

    return success(res, {
      dataUrl,
      asset: {
        id: asset.id,
        asset_tag: assetTag,
        serial_number: asset.serial_number,
        marque: asset.marque,
        modele: asset.modele,
        type: asset.type,
        site: asset.site,
        departement: asset.departement,
        statut: asset.statut
      }
    });
  } catch (err) {
    logger.error('Erreur getQrCode asset:', err);
    return error(res, 'Erreur lors de la génération du QR Code', 500);
  }
}

module.exports = {
  list,
  getOne,
  searchAssets,
  create,
  update,
  archive,
  filterOptions,
  listAttachments,
  uploadAttachment,
  downloadAttachment,
  deleteAttachment,
  getQrCode
};
