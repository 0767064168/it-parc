// ============================================
// src/controllers/settings.controller.js
// Paramètres système de la Direction IT
// ============================================
'use strict';

const { query } = require('../config/db');
const { success, error } = require('../utils/response');
const { sendMail } = require('../services/email.service');
const logger = require('../utils/logger');

const DEFAULT_SETTINGS = {
  organisation_nom: 'Direction IT Bouaké',
  devise: 'XOF',
  amortissement_mois: '36',
  alerte_licences_jours: '30',
  alerte_garanties_jours: '60',
  email_notifications_auto: 'true',
};

let initialized = false;
async function ensureTable() {
  if (initialized) return;
  try {
    await query(`
      CREATE TABLE IF NOT EXISTS system_settings (
        cle VARCHAR(100) PRIMARY KEY,
        valeur TEXT,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);
    initialized = true;
  } catch (err) {
    logger.warn('Init table system_settings:', err.message);
  }
}

async function getSettings(req, res) {
  try {
    await ensureTable();
    const rows = await query('SELECT cle, valeur FROM system_settings');
    const settings = { ...DEFAULT_SETTINGS };
    for (const r of rows) {
      if (r.cle && r.valeur !== undefined) {
        settings[r.cle] = r.valeur;
      }
    }
    return success(res, {
      settings,
      smtp_enabled: process.env.EMAIL_NOTIFICATIONS_ENABLED === 'true',
      smtp_host: process.env.SMTP_HOST || 'Non configuré (Mode Simulation)',
    }, 'Paramètres système');
  } catch (err) {
    logger.error('Erreur getSettings:', err);
    return error(res, 'Erreur lors du chargement des paramètres', 500);
  }
}

async function updateSettings(req, res) {
  try {
    await ensureTable();
    const allowedKeys = Object.keys(DEFAULT_SETTINGS);
    const updates = req.body?.settings || req.body || {};
    const applied = {};

    for (const key of allowedKeys) {
      if (updates[key] !== undefined && updates[key] !== null) {
        const val = String(updates[key]).trim();
        const existing = await query('SELECT cle FROM system_settings WHERE cle = ?', [key]);
        if (existing && existing.length > 0) {
          await query('UPDATE system_settings SET valeur = ?, updated_at = NOW() WHERE cle = ?', [val, key]);
        } else {
          await query('INSERT INTO system_settings (cle, valeur) VALUES (?, ?)', [key, val]);
        }
        applied[key] = val;
      }
    }

    try {
      await query(
        'INSERT INTO activity_logs (user_id, action, entity_type, entity_id, details) VALUES (?, ?, ?, ?, ?)',
        [req.user?.id || null, 'SETTINGS_UPDATE', 'settings', null, JSON.stringify(applied)]
      );
    } catch (_) {}

    return success(res, applied, 'Paramètres enregistrés avec succès');
  } catch (err) {
    logger.error('Erreur updateSettings:', err);
    return error(res, 'Erreur lors de la sauvegarde des paramètres', 500);
  }
}

async function sendTestEmail(req, res) {
  try {
    const targetEmail = req.body?.email || req.user?.email;
    if (!targetEmail) {
      return error(res, 'Aucune adresse e-mail destinataire fournie', 400);
    }

    const ok = await sendMail({
      to: targetEmail,
      subject: '[Test Configuration] Gestionnaire de Parc IT — Direction IT Bouaké',
      html: `
        <div style="font-family: Arial, sans-serif; padding: 24px; background: #f8fafc; color: #0f172a;">
          <div style="max-width: 520px; margin: 0 auto; background: #fff; padding: 24px; border-radius: 12px; border: 1px solid #e2e8f0;">
            <h2 style="margin-top: 0; color: #0284c7;">✅ Test de messagerie réussi</h2>
            <p>Cet e-mail confirme que le service de notification du <strong>Gestionnaire de Parc IT</strong> est opérationnel.</p>
            <p style="font-size: 12px; color: #64748b;">Déclenché par : ${req.user?.username || 'Administrateur'} le ${new Date().toLocaleString('fr-FR')}</p>
          </div>
        </div>
      `,
      text: `Test de messagerie réussi - Gestionnaire de Parc IT (${new Date().toLocaleString('fr-FR')}).`,
    });

    const isSmtpActive = process.env.EMAIL_NOTIFICATIONS_ENABLED === 'true';
    return success(res, {
      sent: ok,
      mode: isSmtpActive ? 'SMTP' : 'SIMULATION',
      to: targetEmail,
    }, isSmtpActive
      ? `E-mail de test envoyé à ${targetEmail}.`
      : `Test exécuté en mode SIMULATION (logs console) pour ${targetEmail}.`);
  } catch (err) {
    logger.error('Erreur sendTestEmail:', err);
    return error(res, 'Erreur lors du test d\'envoi e-mail', 500);
  }
}

module.exports = { getSettings, updateSettings, sendTestEmail };
