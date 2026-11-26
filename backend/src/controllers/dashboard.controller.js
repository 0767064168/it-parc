// ============================================
// src/controllers/dashboard.controller.js
// ============================================
'use strict';

const DashboardModel = require('../models/dashboard.model');
const { query } = require('../config/db');
const { sendExpiringAlertsDigest, sendNewTicketAlert } = require('../services/email.service');
const { success, error } = require('../utils/response');
const logger = require('../utils/logger');

async function getStats(req, res) {
  try {
    const stats = await DashboardModel.getStats();
    return success(res, stats, 'Statistiques tableau de bord');
  } catch (err) {
    logger.error('Erreur dashboard stats:', err);
    return error(res, 'Erreur lors du calcul des statistiques', 500);
  }
}

async function getAdvancedReports(req, res) {
  try {
    const reports = await DashboardModel.getAdvancedReports();
    return success(res, reports, 'Rapports statistiques avancés');
  } catch (err) {
    logger.error('Erreur advanced reports:', err);
    return error(res, 'Erreur lors de la récupération des rapports', 500);
  }
}

async function getAmortissement(req, res) {
  try {
    const data = await DashboardModel.getAmortissementStats();
    return success(res, data, 'Statistiques amortissement et budget');
  } catch (err) {
    logger.error('Erreur amortissement stats:', err);
    return error(res, 'Erreur lors du calcul de l\'amortissement', 500);
  }
}

async function triggerExpiringAlertsEmail(req, res) {
  try {
    let licencesJours = 30;
    let garantiesJours = 60;
    try {
      const settingsRows = await query('SELECT cle, valeur FROM system_settings WHERE cle IN (?, ?)', ['alerte_licences_jours', 'alerte_garanties_jours']);
      for (const s of settingsRows || []) {
        const parsed = parseInt(s.valeur, 10);
        if (!Number.isNaN(parsed) && parsed >= 1 && parsed <= 365) {
          if (s.cle === 'alerte_licences_jours') licencesJours = parsed;
          if (s.cle === 'alerte_garanties_jours') garantiesJours = parsed;
        }
      }
    } catch (_) {}

    const licencesExpirant = await query(`
      SELECT id, nom, editeur, date_expiration FROM licences
      WHERE date_expiration IS NOT NULL
        AND date_expiration >= CURDATE()
        AND date_expiration <= DATE_ADD(CURDATE(), INTERVAL ${licencesJours} DAY)
    `);
    const garantiesExpirant = await query(`
      SELECT a.id, a.\`Nom Machine\` as asset_tag, a.marque, a.modele, c.fin_garantie
      FROM couts c
      JOIN assets a ON a.id = c.asset_id AND a.deleted_at IS NULL
      WHERE c.fin_garantie IS NOT NULL
        AND c.fin_garantie >= CURDATE()
        AND c.fin_garantie <= DATE_ADD(CURDATE(), INTERVAL ${garantiesJours} DAY)
    `);
    const admins = await query("SELECT email FROM auth_users WHERE role IN ('admin', 'technicien') AND actif = 1 AND email IS NOT NULL");
    const adminEmails = admins.map(a => a.email).filter(Boolean);

    if (licencesExpirant.length === 0 && garantiesExpirant.length === 0) {
      return success(res, { sent: false, count: 0 }, 'Aucune licence ou garantie n\'arrive à échéance dans les 30 prochains jours.');
    }

    if (adminEmails.length > 0) {
      await sendExpiringAlertsDigest({ adminEmails, licencesExpirant, garantiesExpirant });
    }
    return success(res, {
      sent: true,
      licences: licencesExpirant.length,
      garanties: garantiesExpirant.length,
      recipients: adminEmails.length
    }, `Rapport d'échéance envoyé à ${adminEmails.length} administrateur(s).`);
  } catch (err) {
    logger.error('Erreur triggerExpiringAlertsEmail:', err);
    return error(res, 'Erreur lors de l\'envoi du rapport d\'échéances', 500);
  }
}

async function getMonEspace(req, res) {
  try {
    const userEmail = req.user?.email || '';
    const userNom = req.user?.nom || '';
    const userPrenom = req.user?.prenom || '';

    // Équipements affectés activement à ce collaborateur (correspondance par email ou nom+prénom)
    const equipements = await query(`
      SELECT af.id as affectation_id, af.date_attribution, af.motif,
        a.id as asset_id, a.\`Nom Machine\` as asset_tag, a.marque, a.modele, a.type,
        a.serial_number, a.statut, a.site, a.departement,
        s.os, s.ram, s.stockage, s.cpu
      FROM affectations af
      JOIN assets a ON a.id = af.asset_id AND a.deleted_at IS NULL
      JOIN utilisateurs u ON u.id = af.user_id
      LEFT JOIN specs s ON s.asset_id = a.id
      WHERE af.actif = 1
        AND (
          (? <> '' AND LOWER(u.email) = LOWER(?))
          OR (? <> '' AND ? <> '' AND LOWER(u.nom) = LOWER(?) AND LOWER(u.prenom) = LOWER(?))
        )
      ORDER BY af.date_attribution DESC
    `, [userEmail, userEmail, userNom, userPrenom, userNom, userPrenom]);

    // Tickets récents créés par cet utilisateur
    const tickets = await query(`
      SELECT t.id, t.numero, t.titre, t.type, t.priorite, t.statut, t.created_at, t.updated_at,
        a.\`Nom Machine\` as asset_tag, a.marque, a.modele
      FROM tickets t
      LEFT JOIN assets a ON a.id = t.asset_id
      WHERE t.createur_id = ?
      ORDER BY t.created_at DESC
      LIMIT 15
    `, [req.user.id]);

    return success(res, { equipements, tickets }, 'Espace collaborateur');
  } catch (err) {
    logger.error('Erreur getMonEspace:', err);
    return error(res, 'Erreur lors du chargement de votre espace', 500);
  }
}

async function reportMonIncident(req, res) {
  try {
    const { asset_id, titre, description, priorite = 'moyenne' } = req.body;
    if (!titre || !titre.trim() || !description || !description.trim()) {
      return error(res, 'Le titre et la description de l\'incident sont obligatoires', 400);
    }

    const validPriorite = ['critique', 'haute', 'moyenne', 'basse'].includes(priorite) ? priorite : 'moyenne';
    const year = new Date().getFullYear();
    const rand = String(Math.floor(1000 + Math.random() * 9000));
    const numero = `TKT-${year}-${rand}`;

    let site = null;
    if (asset_id) {
      const [assetRow] = await query('SELECT site FROM assets WHERE id = ?', [parseInt(asset_id, 10)]);
      site = assetRow?.site || null;
    }

    const insertRes = await query(`
      INSERT INTO tickets (numero, titre, description, type, priorite, statut, asset_id, createur_id, site)
      VALUES (?, ?, ?, 'incident', ?, 'ouvert', ?, ?, ?) RETURNING id
    `, [numero, titre.trim(), description.trim(), validPriorite, asset_id ? parseInt(asset_id, 10) : null, req.user.id, site]);

    const newTicketId = insertRes?.[0]?.id || insertRes?.insertId;

    try {
      await query(
        'INSERT INTO activity_logs (user_id, action, entity_type, entity_id, details) VALUES (?, ?, ?, ?, ?)',
        [req.user.id, 'PORTAL_INCIDENT_REPORT', 'ticket', newTicketId || null, JSON.stringify({ numero, asset_id, titre: titre.trim(), priorite: validPriorite })]
      );
    } catch (_) {}

    // Notification e-mail aux admins/techniciens (non bloquant)
    try {
      const admins = await query("SELECT email FROM auth_users WHERE role IN ('admin', 'technicien') AND actif = 1 AND email IS NOT NULL");
      const itEmails = admins.map(a => a.email).filter(Boolean);
      if (itEmails.length > 0) {
        sendNewTicketAlert({
          ticket: { id: newTicketId, numero, titre: titre.trim(), description: description.trim(), priorite: validPriorite, type: 'incident', created_at: new Date() },
          creator: { nom: req.user.nom || '', prenom: req.user.prenom || '', username: req.user.username },
          itEmails
        }).catch(() => {});
      }
    } catch (_) {}

    return success(res, { id: newTicketId, numero, statut: 'ouvert' }, 'Incident signalé à l\'équipe IT avec succès', 201);
  } catch (err) {
    logger.error('Erreur reportMonIncident:', err);
    return error(res, 'Erreur lors du signalement de l\'incident', 500);
  }
}

async function cronExpiringAlerts(req, res) {
  const secret = process.env.CRON_SECRET;
  if (secret && req.headers.authorization !== `Bearer ${secret}`) {
    return error(res, 'Non autorisé', 401);
  }
  return triggerExpiringAlertsEmail(req, res);
}

module.exports = { getStats, getAdvancedReports, getAmortissement, triggerExpiringAlertsEmail, cronExpiringAlerts, getMonEspace, reportMonIncident };
