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
let PDFDocument;
try {
  PDFDocument = require('pdfkit');
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

    const motif = req.body?.motif || null;
    await AssetModel.archive(id, motif);
    await query(
      'INSERT INTO activity_logs (user_id, action, entity_type, entity_id, details) VALUES (?, ?, ?, ?, ?)',
      [req.user.id, 'ARCHIVE', 'asset', id, JSON.stringify({ motif })]
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

async function generatePdf(req, res) {
  try {
    const id = parseInt(req.params.id);
    if (!id || isNaN(id)) return error(res, 'ID d\'équipement invalide', 400);

    if (!PDFDocument) {
      PDFDocument = require('pdfkit');
    }
    if (!PDFDocument) {
      return error(res, 'Générateur PDF non disponible', 500);
    }

    const asset = await AssetModel.findById(id);
    if (!asset) return error(res, 'Équipement introuvable', 404);

    const assetTag = asset.asset_tag || asset['Nom Machine'] || `ASSET-${id}`;
    const doc = new PDFDocument({
      size: 'A4',
      margin: 40,
      info: {
        Title: `Fiche Technique - ${assetTag}`,
        Author: 'Direction IT Bouaké',
        Subject: 'Fiche d\'inventaire et d\'identification de matériel informatique'
      }
    });

    const filename = `Fiche_Technique_${assetTag}.pdf`;
    res.setHeader('Content-Disposition', `inline; filename="${filename}"`);
    res.setHeader('Content-Type', 'application/pdf');
    doc.pipe(res);

    // En-tête bandeau
    doc.rect(40, 40, 515, 68).fill('#0f172a');
    doc.fillColor('#38bdf8').fontSize(9).font('Helvetica-Bold')
       .text('DIRECTION DES SYSTÈMES D\'INFORMATION & DU PARC IT', 55, 52);
    doc.fillColor('#ffffff').fontSize(13).font('Helvetica-Bold')
       .text('FICHE TECHNIQUE & D\'INVENTAIRE MATÉRIEL', 55, 67);
    doc.fillColor('#94a3b8').fontSize(8).font('Helvetica')
       .text('Direction IT Bouaké • Dossier technique officiel du parc informatique', 55, 87);

    doc.fillColor('#38bdf8').fontSize(11).font('Helvetica-Bold')
       .text(assetTag, 420, 56, { align: 'right', width: 120 });
    doc.fillColor('#cbd5e1').fontSize(8).font('Helvetica')
       .text(`Édition : ${new Date().toLocaleDateString('fr-FR')}`, 420, 72, { align: 'right', width: 120 })
       .text(`Statut : ${(asset.statut || 'EN SERVICE').toUpperCase()}`, 420, 84, { align: 'right', width: 120 });

    let currentY = 120;

    const drawSectionHeader = (title, y) => {
      doc.rect(40, y, 515, 18).fill('#f1f5f9');
      doc.fillColor('#1e293b').fontSize(8.5).font('Helvetica-Bold')
         .text(title.toUpperCase(), 48, y + 5);
      return y + 24;
    };

    const drawRow = (label1, val1, label2, val2, y) => {
      doc.fillColor('#64748b').fontSize(7.5).font('Helvetica').text(label1, 48, y, { width: 120 });
      doc.fillColor('#0f172a').fontSize(8).font('Helvetica-Bold').text(String(val1 || '—'), 160, y, { width: 120 });
      if (label2) {
        doc.fillColor('#64748b').fontSize(7.5).font('Helvetica').text(label2, 295, y, { width: 120 });
        doc.fillColor('#0f172a').fontSize(8).font('Helvetica-Bold').text(String(val2 || '—'), 415, y, { width: 135 });
      }
      return y + 14;
    };

    // 1. Identification
    currentY = drawSectionHeader('1. Identification de l\'Équipement', currentY);
    currentY = drawRow('Nom Machine (Tag) :', assetTag, 'Type d\'équipement :', (asset.type || '—').toUpperCase(), currentY);
    currentY = drawRow('Marque & Modèle :', `${asset.marque || ''} ${asset.modele || ''}`.trim() || '—', 'Numéro de Série (S/N) :', asset.serial_number || '—', currentY);
    currentY = drawRow('Statut opérationnel :', (asset.statut || '—').replace(/_/g, ' ').toUpperCase(), 'Site d\'affectation :', asset.site || 'BOUAKE', currentY);
    currentY = drawRow('Département affecté :', asset.departement || '—', 'Date de création :', asset.created_at ? new Date(asset.created_at).toLocaleDateString('fr-FR') : '—', currentY);
    currentY += 6;

    // 2. Spécifications techniques
    const s = asset.specs || {};
    currentY = drawSectionHeader('2. Caractéristiques & Spécifications Techniques', currentY);
    currentY = drawRow('Processeur (CPU) :', s.cpu || '—', 'Mémoire Vive (RAM) :', s.ram || '—', currentY);
    currentY = drawRow('Stockage Principal :', s.stockage || '—', 'Système d\'exploitation :', `${s.os || 'Windows'} ${s.version_os || ''}`.trim(), currentY);
    currentY = drawRow('Adresse MAC :', s.mac_address || '—', 'Numéro IMEI :', s.imei || '—', currentY);
    currentY = drawRow('Adresse IP locale :', s.ip_address || '—', 'Nom d\'hôte (Hostname) :', s.hostname || assetTag, currentY);
    currentY += 6;

    // 3. Conformité & Sécurité
    const sec = asset.securite || {};
    currentY = drawSectionHeader('3. Conformité & Sécurité du Poste', currentY);
    currentY = drawRow('Antivirus Microsoft Defender :', sec.defender ? 'ACTIF (Conforme)' : 'NON DÉPLOYÉ', 'Chiffrement BitLocker :', sec.bitlocker ? 'ACTIVÉ (Conforme)' : 'DÉSACTIVÉ', currentY);
    currentY = drawRow('Enrôlement Microsoft Intune :', sec.intune ? 'ENRÔLÉ (MDM)' : 'NON ENRÔLÉ', 'Jonction Microsoft Entra ID :', sec.entra_id ? 'JOINT (Azure AD)' : 'NON JOINT', currentY);
    currentY = drawRow('Agent EDR / XDR :', sec.edr ? 'INSTALLÉ' : 'ABSENT', 'Sauvegarde OneDrive Pro :', sec.onedrive ? 'SYNCHRONISÉ' : 'NON CONFIGURÉ', currentY);
    currentY += 6;

    // 4. Utilisateur Actuel
    currentY = drawSectionHeader('4. Affectation Actuelle & Détenteur', currentY);
    currentY = drawRow('Collaborateur détenteur :', asset.utilisateur_actuel || 'En stock (Non attribué)', 'Direction / Service :', asset.utilisateur_departement || asset.departement || '—', currentY);
    currentY = drawRow('Email professionnel :', asset.utilisateur_email || '—', 'Contact téléphonique :', asset.utilisateur_telephone || '—', currentY);
    currentY += 6;

    // 5. Coûts & Garantie
    const c = asset.couts || {};
    currentY = drawSectionHeader('5. Données Financières & Garanties', currentY);
    currentY = drawRow('Fournisseur :', c.fournisseur || '—', 'Bon de commande :', c.bon_commande || '—', currentY);
    currentY = drawRow('Coût d\'acquisition :', c.prix ? `${Number(c.prix).toLocaleString('fr-FR')} XOF` : '—', 'Date d\'acquisition :', c.date_acquisition ? new Date(c.date_acquisition).toLocaleDateString('fr-FR') : '—', currentY);
    currentY = drawRow('Fin de garantie constructeur :', c.fin_garantie ? new Date(c.fin_garantie).toLocaleDateString('fr-FR') : '—', 'Observations / Notes :', asset.notes || 'R.A.S', currentY);
    currentY += 12;

    // Bloc de validation IT
    doc.rect(40, currentY, 515, 60).strokeColor('#cbd5e1').stroke();
    doc.fillColor('#0f172a').fontSize(8).font('Helvetica-Bold')
       .text('VISA ET VALIDATION DIRECTION IT', 50, currentY + 8);
    doc.fillColor('#64748b').fontSize(7.5).font('Helvetica')
       .text('Document technique faisant foi de l\'enregistrement de cet équipement au registre d\'inventaire officiel du parc informatique.', 50, currentY + 22)
       .text('Responsable Parc IT : ___________________________   Date de validation : ' + new Date().toLocaleDateString('fr-FR') + '   Cachet & Signature :', 50, currentY + 38);

    // Bas de page
    doc.fillColor('#94a3b8').fontSize(7).font('Helvetica')
       .text('Direction IT Bouaké • Fiche Technique Officielle d\'Équipement Informatique • Page 1/1', 40, 785, { align: 'center', width: 515 });

    doc.end();
  } catch (err) {
    logger.error('Erreur generatePdf asset:', err);
    return error(res, 'Erreur lors de la génération de la fiche technique: ' + err.message, 500);
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
  getQrCode,
  generatePdf
};
