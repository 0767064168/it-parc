// ============================================
// src/controllers/public_ticket.controller.js
// Création publique de tickets (sans authentification)
// ============================================
'use strict';

const { query, transaction } = require('../config/db');
const { success, error } = require('../utils/response');
const logger = require('../utils/logger');

/**
 * Génère le numéro séquentiel du ticket (Ex: TKT-2026-0001)
 */
async function generateTicketNumber() {
  const currentYear = new Date().getFullYear();
  const pattern = `TKT-${currentYear}-%`;
  const [row] = await query(
    'SELECT MAX(numero) as maxNum FROM tickets WHERE numero LIKE ?',
    [pattern]
  );
  let nextSeq = 1;
  if (row && row.maxNum) {
    const parts = row.maxNum.split('-');
    const lastSeq = parseInt(parts[2]);
    if (!isNaN(lastSeq)) nextSeq = lastSeq + 1;
  }
  return `TKT-${currentYear}-${String(nextSeq).padStart(4, '0')}`;
}

/**
 * Ajoute une notification in-app pour un utilisateur
 */
async function createNotification(userId, titre, contenu) {
  try {
    const result = await query(
      'INSERT INTO in_app_notifications (user_id, titre, contenu) VALUES (?, ?, ?)',
      [userId, titre, contenu]
    );
    if (global.io) {
      global.io.to(`user_${userId}`).emit('notification', {
        id: result.insertId,
        user_id: userId,
        titre,
        contenu,
        lu: 0,
        created_at: new Date().toISOString()
      });
    }
  } catch (err) {
    logger.error('Erreur notification publique:', err);
  }
}

/**
 * POST /api/public/tickets
 * Crée un ticket soumis depuis le formulaire public (sans authentification)
 */
async function createPublicTicket(req, res) {
  try {
    const { nom, email, type, priorite, titre, description } = req.body;

    // ── Validation basique ─────────────────────────
    if (!nom || !email || !type || !priorite || !titre || !description) {
      return error(res, 'Tous les champs sont obligatoires.', 400);
    }

    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      return error(res, 'Adresse email invalide.', 400);
    }

    const typesValides = ['panne', 'assistance', 'materiel', 'reseau'];
    const prioritesValides = ['faible', 'moyenne', 'haute', 'critique'];
    if (!typesValides.includes(type)) return error(res, 'Type de demande invalide.', 400);
    if (!prioritesValides.includes(priorite)) return error(res, 'Niveau d\'urgence invalide.', 400);

    // ── Trouver un compte auth_user lié à cet email ─
    // On recherche un auth_user actif avec cet email pour l'associer comme créateur
    let createurId = null;
    const authUsers = await query(
      'SELECT id FROM auth_users WHERE email = ? AND actif = 1 LIMIT 1',
      [email]
    );
    if (authUsers.length > 0) {
      createurId = authUsers[0].id;
    } else {
      // Si pas de compte : on utilise un compte système "externe" (premier admin disponible)
      const [adminFallback] = await query(
        'SELECT id FROM auth_users WHERE role = "admin" AND actif = 1 ORDER BY id ASC LIMIT 1'
      );
      if (!adminFallback) {
        return error(res, 'Aucun administrateur disponible pour traiter la demande.', 500);
      }
      createurId = adminFallback.id;
    }

    // ── Calcul deadline SLA ────────────────────────
    const slaConfigs = await query(
      'SELECT delai_resolution_min FROM sla_config WHERE priorite = ? AND actif = 1 LIMIT 1',
      [priorite]
    );
    let minutesSla = 4320; // 3 jours par défaut
    if (slaConfigs.length > 0) minutesSla = slaConfigs[0].delai_resolution_min;
    const slaDeadline = new Date(Date.now() + minutesSla * 60 * 1000);

    // ── Génération du numéro ───────────────────────
    const numero = await generateTicketNumber();

    // ── Description enrichie avec infos de l'expéditeur ─
    const descriptionComplete =
      `[Ticket soumis via formulaire public]\n` +
      `Demandeur : ${nom} <${email}>\n\n` +
      `${description}`;

    // ── Insertion en transaction ───────────────────
    const ticketId = await transaction(async (conn) => {
      const [resInsert] = await conn.execute(
        `INSERT INTO tickets (numero, titre, description, type, priorite, statut, createur_id, sla_deadline)
         VALUES (?, ?, ?, ?, ?, 'ouvert', ?, ?)`,
        [numero, titre, descriptionComplete, type, priorite, createurId, slaDeadline]
      );
      const newId = resInsert.insertId;

      // Log historique initial
      await conn.execute(
        'INSERT INTO ticket_historique (ticket_id, user_id, champ_modifie, ancienne_valeur, nouvelle_valeur) VALUES (?, ?, ?, ?, ?)',
        [newId, createurId, 'création', null, `Ticket créé via formulaire public par ${nom} (${email})`]
      );

      return newId;
    });

    const [createdTicket] = await query('SELECT * FROM tickets WHERE id = ?', [ticketId]);

    // ── Notifications aux admins & techniciens IT ──
    const itUsers = await query(
      'SELECT id, email FROM auth_users WHERE role IN ("admin", "technicien") AND actif = 1'
    );
    for (const itUser of itUsers) {
      await createNotification(
        itUser.id,
        `🌐 Nouveau ticket public ${numero}`,
        `"${titre}" soumis par ${nom} (${email}) — Urgence : ${priorite.toUpperCase()}`
      );
    }

    // ── Émission Socket.IO globale ─────────────────
    if (global.io) {
      global.io.emit('new_ticket', {
        message: `Nouveau ticket public ${numero} soumis par ${nom}`,
        ticket: createdTicket
      });
    }

    logger.info(`Ticket public créé : ${numero} par ${nom} (${email})`);

    return success(res, { id: ticketId, numero }, 'Votre demande a bien été enregistrée.', 201);
  } catch (err) {
    logger.error('Erreur création ticket public:', err);
    return error(res, 'Erreur serveur lors de l\'enregistrement de votre demande.', 500);
  }
}

module.exports = { createPublicTicket };
