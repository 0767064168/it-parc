'use strict';

const fs = require('fs');
const path = require('path');
const logger = require('../utils/logger');

function getSupabaseConfig() {
  const url = (process.env.SUPABASE_URL || '').replace(/\/+$/, '');
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY || '';
  const bucket = process.env.SUPABASE_STORAGE_BUCKET || 'attachments';
  if (!url || !key) return null;
  return { url, key, bucket };
}

/**
 * Envoie un fichier vers Supabase Storage si configuré, sinon conserve le chemin local.
 * @returns {Promise<string>} Chemin stocké en base (supabase://... ou chemin local)
 */
async function uploadFile(localPath, objectKey, mimeType = 'application/octet-stream') {
  const cfg = getSupabaseConfig();
  if (!cfg) return localPath;

  try {
    const buffer = fs.readFileSync(localPath);
    const endpoint = `${cfg.url}/storage/v1/object/${cfg.bucket}/${objectKey}`;
    const response = await fetch(endpoint, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${cfg.key}`,
        apikey: cfg.key,
        'Content-Type': mimeType || 'application/octet-stream',
        'x-upsert': 'true',
      },
      body: buffer,
    });

    if (!response.ok) {
      const errText = await response.text().catch(() => '');
      logger.warn(`Supabase Storage upload échoué (${response.status}), repli local: ${errText}`);
      return localPath;
    }

    // Supprimer le fichier temporaire local une fois persisté sur Supabase
    fs.unlink(localPath, () => {});
    return `supabase://${cfg.bucket}/${objectKey}`;
  } catch (err) {
    logger.warn(`Supabase Storage indisponible, repli local: ${err.message}`);
    return localPath;
  }
}

/**
 * Télécharge un fichier depuis Supabase Storage ou le disque local vers la réponse Express.
 */
async function sendStoredFile(storedPath, res, originalName, mimeType) {
  if (storedPath && storedPath.startsWith('supabase://')) {
    const cfg = getSupabaseConfig();
    if (!cfg) {
      throw new Error('Configuration Supabase Storage manquante pour lire ce fichier');
    }
    const withoutScheme = storedPath.slice('supabase://'.length);
    const slashIdx = withoutScheme.indexOf('/');
    const bucket = slashIdx > 0 ? withoutScheme.slice(0, slashIdx) : cfg.bucket;
    const objectKey = slashIdx > 0 ? withoutScheme.slice(slashIdx + 1) : withoutScheme;

    const endpoint = `${cfg.url}/storage/v1/object/${bucket}/${objectKey}`;
    const response = await fetch(endpoint, {
      headers: {
        Authorization: `Bearer ${cfg.key}`,
        apikey: cfg.key,
      },
    });

    if (!response.ok) {
      return false;
    }

    const arrayBuf = await response.arrayBuffer();
    res.setHeader('Content-Disposition', `attachment; filename="${encodeURIComponent(originalName)}"`);
    res.setHeader('Content-Type', mimeType || 'application/octet-stream');
    res.send(Buffer.from(arrayBuf));
    return true;
  }

  const filePath = path.resolve(storedPath);
  if (!fs.existsSync(filePath)) return false;

  res.setHeader('Content-Disposition', `attachment; filename="${encodeURIComponent(originalName)}"`);
  res.setHeader('Content-Type', mimeType || 'application/octet-stream');
  res.sendFile(filePath);
  return true;
}

/**
 * Supprime un fichier depuis Supabase Storage ou le disque local.
 */
async function deleteStoredFile(storedPath) {
  if (!storedPath) return;
  if (storedPath.startsWith('supabase://')) {
    const cfg = getSupabaseConfig();
    if (!cfg) return;
    const withoutScheme = storedPath.slice('supabase://'.length);
    const slashIdx = withoutScheme.indexOf('/');
    const bucket = slashIdx > 0 ? withoutScheme.slice(0, slashIdx) : cfg.bucket;
    const objectKey = slashIdx > 0 ? withoutScheme.slice(slashIdx + 1) : withoutScheme;

    await fetch(`${cfg.url}/storage/v1/object/${bucket}/${objectKey}`, {
      method: 'DELETE',
      headers: {
        Authorization: `Bearer ${cfg.key}`,
        apikey: cfg.key,
      },
    }).catch((err) => logger.warn(`Erreur suppression Supabase Storage: ${err.message}`));
    return;
  }

  const filePath = path.resolve(storedPath);
  if (fs.existsSync(filePath)) {
    fs.unlinkSync(filePath);
  }
}

module.exports = {
  uploadFile,
  sendStoredFile,
  deleteStoredFile,
  isSupabaseStorageEnabled: () => Boolean(getSupabaseConfig()),
};
