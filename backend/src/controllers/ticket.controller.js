// ============================================
// src/controllers/ticket.controller.js
// Contrôleur de gestion des tickets IT
// ============================================
'use strict';

const { query, transaction } = require('../config/db');
const { success, error, paginated } = require('../utils/response');
const logger = require('../utils/logger');
const EmailService = require('../services/email.service');
const XLSX = require('@e965/xlsx');
const fs = require('fs');
const path = require('path');
let PDFDocument;
try {
  PDFDocument = require('pdfkit');
} catch (e) {
  logger.warn('pdfkit non installé, l\'export PDF utilisera un fallback basique');
}

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
    if (!isNaN(lastSeq)) {
      nextSeq = lastSeq + 1;
    }
  }
  
  return `TKT-${currentYear}-${String(nextSeq).padStart(4, '0')}`;
}

/**
 * Ajoute une notification in-app pour un utilisateur
 */
async function createNotification(userId, title, content) {
  try {
    const result = await query(
      'INSERT INTO in_app_notifications (user_id, titre, contenu) VALUES (?, ?, ?)',
      [userId, title, content]
    );
    
    if (global.io) {
      global.io.to(`user_${userId}`).emit('notification', {
        id: result.insertId,
        user_id: userId,
        titre: title,
        contenu: content,
        lu: 0,
        created_at: new Date().toISOString()
      });
    }
  } catch (err) {
    logger.error('Erreur lors de la création de la notification:', err);
  }
}

/**
 * Ajoute un enregistrement d'audit dans l'historique
 */
async function logHistory(conn, ticketId, userId, field, oldVal, newVal) {
  const sql = 'INSERT INTO ticket_historique (ticket_id, user_id, champ_modifie, ancienne_valeur, nouvelle_valeur) VALUES (?, ?, ?, ?, ?)';
  const params = [ticketId, userId, field, String(oldVal), String(newVal)];
  if (conn) {
    await conn.execute(sql, params);
  } else {
    await query(sql, params);
  }
}

/**
 * POST /api/tickets
 * Crée un nouveau ticket
 */
async function create(req, res) {
  try {
    const { titre, description, type, priorite, asset_id } = req.body;
    const createur_id = req.user.id;

    // 1. Détection automatique du site et département
    let site = 'Bouaké';
    let departement = 'IT';

    // Jointure auth_users -> utilisateurs par nom+prenom pour récupérer site/département
    const users = await query(
      `SELECT u.site, u.departement 
       FROM auth_users au
       LEFT JOIN utilisateurs u ON LOWER(u.nom) = LOWER(au.nom)
                                AND LOWER(u.prenom) = LOWER(au.prenom)
       WHERE au.id = ? LIMIT 1`,
      [req.user.id]
    );
    if (users.length > 0) {
      site = users[0].site || site;
      departement = users[0].departement || departement;
    }

    // 2. Calcul du SLA Deadline
    const slaConfigs = await query('SELECT delai_resolution_min FROM sla_config WHERE priorite = ? AND actif = 1 LIMIT 1', [priorite]);
    let minutesSla = 4320; // 3 jours par défaut
    if (slaConfigs.length > 0) {
      minutesSla = slaConfigs[0].delai_resolution_min;
    }
    const slaDeadline = new Date(Date.now() + minutesSla * 60 * 1000);

    // 3. Génération du numéro
    const numero = await generateTicketNumber();

    // 4. Insertion en transaction
    const ticketId = await transaction(async (conn) => {
      const [resInsert] = await conn.execute(
        `INSERT INTO tickets (numero, titre, description, type, priorite, statut, asset_id, createur_id, site, sla_deadline) 
         VALUES (?, ?, ?, ?, ?, 'ouvert', ?, ?, ?, ?)`,
        [numero, titre, description, type, priorite, asset_id || null, createur_id, site, slaDeadline]
      );
      
      const newId = resInsert.insertId;

      // Log historique initial
      await logHistory(conn, newId, createur_id, 'création', null, 'Ticket créé avec statut ouvert');

      // Si incident et asset_id fourni, marquer l'asset en incident
      if (type === 'incident' && asset_id) {
        // Optionnel : on peut changer le statut de l'asset si besoin
        await conn.execute(
          'UPDATE assets SET notes = CONCAT(IFNULL(notes, ""), "\n[Incident ouvert: ", ?, "]") WHERE id = ?',
          [numero, asset_id]
        );
      }

      return newId;
    });

    // 5. Envoyer notifications à l'équipe IT (Admins & Techniciens)
    const itUsers = await query('SELECT id, email FROM auth_users WHERE role IN ("admin", "technicien") AND actif = 1');
    for (const itUser of itUsers) {
      await createNotification(
        itUser.id,
        `Nouveau ticket ${numero}`,
        `Le ticket "${titre}" (${priorite.toUpperCase()}) a été créé par ${req.user.nom} pour le site ${site}.`
      );
    }

    const [createdTicket] = await query('SELECT * FROM tickets WHERE id = ?', [ticketId]);

    // Envoi de la notification email réelle à l'équipe IT
    const itEmails = itUsers.map(u => u.email).filter(email => email !== null && email !== undefined && email !== '');
    if (itEmails.length > 0) {
      EmailService.sendNewTicketAlert({
        ticket: createdTicket,
        creator: req.user,
        itEmails
      }).catch(err => logger.error('Erreur lors de l\'envoi de l\'email d\'alerte IT:', err));
    }

    const io = req.app.get('io');
    if (io) {
      io.emit('new_ticket', {
        message: `Nouveau ticket ${numero} créé par ${req.user.prenom} ${req.user.nom}`,
        ticket: createdTicket
      });
    }

    return success(res, createdTicket, 'Ticket créé avec succès', 201);
  } catch (err) {
    logger.error('Erreur création ticket:', err);
    return error(res, 'Erreur serveur lors de la création du ticket', 500);
  }
}

/**
 * GET /api/tickets
 * Liste filtrée et paginée des tickets
 */
async function list(req, res) {
  try {
    const { page = 1, limit = 20, statut, priorite, type, site, technicien_id, search } = req.query;
    const offset = (page - 1) * limit;

    const conditions = [];
    const params = [];

    // Restriction Lecteur : ne voit que ses propres tickets
    if (req.user.role === 'lecteur') {
      conditions.push('t.createur_id = ?');
      params.push(req.user.id);
    }

    // Filtres
    if (statut) {
      conditions.push('t.statut = ?');
      params.push(statut);
    }
    if (priorite) {
      conditions.push('t.priorite = ?');
      params.push(priorite);
    }
    if (type) {
      conditions.push('t.type = ?');
      params.push(type);
    }
    if (site) {
      conditions.push('t.site = ?');
      params.push(site);
    }
    if (technicien_id) {
      if (technicien_id === 'null') {
        conditions.push('t.technicien_id IS NULL');
      } else {
        conditions.push('t.technicien_id = ?');
        params.push(parseInt(technicien_id));
      }
    }

    // Recherche globale
    if (search) {
      conditions.push('(t.numero LIKE ? OR t.titre LIKE ? OR t.description LIKE ? OR a.`Nom Machine` LIKE ?)');
      const s = `%${search}%`;
      params.push(s, s, s, s);
    }

    const whereClause = conditions.length ? 'WHERE ' + conditions.join(' AND ') : '';

    // Total Count
    const [{ total }] = await query(`
      SELECT COUNT(*) as total 
      FROM tickets t 
      LEFT JOIN assets a ON t.asset_id = a.id
      ${whereClause}
    `, params);

    // List avec jointures
    const tickets = await query(`
      SELECT t.*,
             a.\`Nom Machine\` as asset_tag, a.marque as asset_marque, a.modele as asset_modele,
             uc.username as createur_username, uc.nom as createur_nom, uc.prenom as createur_prenom,
             ut.username as technicien_username, ut.nom as technicien_nom, ut.prenom as technicien_prenom
      FROM tickets t
      LEFT JOIN assets a ON t.asset_id = a.id
      LEFT JOIN auth_users uc ON t.createur_id = uc.id
      LEFT JOIN auth_users ut ON t.technicien_id = ut.id
      ${whereClause}
      ORDER BY 
        CASE t.statut
          WHEN 'ouvert' THEN 1
          WHEN 'rouvert' THEN 2
          WHEN 'en_cours' THEN 3
          WHEN 'en_attente' THEN 4
          WHEN 'resolu' THEN 5
          WHEN 'ferme' THEN 6
          WHEN 'annule' THEN 7
        END ASC,
        t.sla_deadline ASC,
        t.created_at DESC
      LIMIT ? OFFSET ?
    `, [...params, parseInt(limit), offset]);

    return paginated(res, tickets, total, page, limit);
  } catch (err) {
    logger.error('Erreur liste tickets:', err);
    return error(res, 'Erreur lors de la récupération des tickets', 500);
  }
}

/**
 * GET /api/tickets/:id
 * Détails complets d'un ticket
 */
async function getOne(req, res) {
  try {
    const id = parseInt(req.params.id);

    const tickets = await query(`
      SELECT t.*,
             a.\`Nom Machine\` as asset_tag, a.marque as asset_marque, a.modele as asset_modele, a.type as asset_type, a.statut as asset_statut,
             uc.username as createur_username, uc.nom as createur_nom, uc.prenom as createur_prenom,
             ut.username as technicien_username, ut.nom as technicien_nom, ut.prenom as technicien_prenom
      FROM tickets t
      LEFT JOIN assets a ON t.asset_id = a.id
      LEFT JOIN auth_users uc ON t.createur_id = uc.id
      LEFT JOIN auth_users ut ON t.technicien_id = ut.id
      WHERE t.id = ? LIMIT 1
    `, [id]);

    if (!tickets.length) {
      return error(res, 'Ticket introuvable', 404);
    }

    const ticket = tickets[0];

    // Vérifier les droits du lecteur (uniquement ses tickets)
    if (req.user.role === 'lecteur' && ticket.createur_id !== req.user.id) {
      return error(res, 'Accès interdit à ce ticket', 403);
    }

    // Commentaires (filtre les internes pour le lecteur)
    let commentsSql = `
      SELECT c.*, u.nom as auteur_nom, u.prenom as auteur_prenom, u.role as auteur_role
      FROM ticket_commentaires c
      LEFT JOIN auth_users u ON c.auteur_id = u.id
      WHERE c.ticket_id = ?
    `;
    const commentsParams = [id];
    if (req.user.role === 'lecteur') {
      commentsSql += ' AND c.type = "public"';
    }
    commentsSql += ' ORDER BY c.created_at ASC';
    const commentaires = await query(commentsSql, commentsParams);

    // Historique (accessible Admin / Technicien seulement)
    let historique = [];
    if (req.user.role !== 'lecteur') {
      historique = await query(`
        SELECT h.*, u.nom as user_nom, u.prenom as user_prenom
        FROM ticket_historique h
        LEFT JOIN auth_users u ON h.user_id = u.id
        WHERE h.ticket_id = ?
        ORDER BY h.created_at DESC
      `, [id]);
    }

    // Pièces jointes
    const piecesJointes = await query('SELECT * FROM ticket_pieces_jointes WHERE ticket_id = ?', [id]);

    // Évaluation de satisfaction
    const [evaluation] = await query('SELECT * FROM ticket_evaluations WHERE ticket_id = ? LIMIT 1', [id]);

    return success(res, {
      ...ticket,
      commentaires,
      historique,
      piecesJointes,
      evaluation: evaluation || null,
    });
  } catch (err) {
    logger.error('Erreur getOne ticket:', err);
    return error(res, 'Erreur lors de la récupération du ticket', 500);
  }
}

/**
 * PUT /api/tickets/:id
 * Modifie les infos de base (Admin seulement)
 */
async function update(req, res) {
  try {
    const id = parseInt(req.params.id);
    const { titre, description, priorite, type } = req.body;

    const tickets = await query('SELECT * FROM tickets WHERE id = ?', [id]);
    if (!tickets.length) return error(res, 'Ticket introuvable', 404);
    const ticket = tickets[0];

    await transaction(async (conn) => {
      // Calculer nouveau SLA si priorité change
      let newSlaDeadline = ticket.sla_deadline;
      if (priorite && priorite !== ticket.priorite) {
        const slaConfigs = await query('SELECT delai_resolution_min FROM sla_config WHERE priorite = ? LIMIT 1', [priorite]);
        if (slaConfigs.length) {
          const minSla = slaConfigs[0].delai_resolution_min;
          newSlaDeadline = new Date(new Date(ticket.created_at).getTime() + minSla * 60 * 1000);
        }
        await logHistory(conn, id, req.user.id, 'priorite', ticket.priorite, priorite);
      }

      if (titre && titre !== ticket.titre) {
        await logHistory(conn, id, req.user.id, 'titre', ticket.titre, titre);
      }
      if (description && description !== ticket.description) {
        await logHistory(conn, id, req.user.id, 'description', 'Modifié', 'Modifié');
      }
      if (type && type !== ticket.type) {
        await logHistory(conn, id, req.user.id, 'type', ticket.type, type);
      }

      await conn.execute(
        'UPDATE tickets SET titre = ?, description = ?, priorite = ?, type = ?, sla_deadline = ? WHERE id = ?',
        [titre || ticket.titre, description || ticket.description, priorite || ticket.priorite, type || ticket.type, newSlaDeadline, id]
      );
    });

    const [updated] = await query('SELECT * FROM tickets WHERE id = ?', [id]);
    return success(res, updated, 'Ticket mis à jour');
  } catch (err) {
    logger.error('Erreur update ticket:', err);
    return error(res, 'Erreur serveur', 500);
  }
}

/**
 * PATCH /api/tickets/:id/statut
 * Modifie le statut (Technicien / Admin / Créateur)
 */
async function changeStatus(req, res) {
  try {
    const id = parseInt(req.params.id);
    const { statut, commentaire } = req.body;

    const tickets = await query('SELECT * FROM tickets WHERE id = ?', [id]);
    if (!tickets.length) return error(res, 'Ticket introuvable', 404);
    const ticket = tickets[0];

    // Droits de transition
    if (req.user.role === 'lecteur') {
      // Le créateur ne peut que "Fermer" (ferme) ou "Réouvrir" (rouvert)
      if (ticket.createur_id !== req.user.id) {
        return error(res, 'Action interdite sur ce ticket', 403);
      }
      if (!['ferme', 'rouvert'].includes(statut)) {
        return error(res, 'Les utilisateurs ne peuvent que Fermer ou Réouvrir un ticket', 400);
      }
    }

    await transaction(async (conn) => {
      let closedAt = ticket.closed_at;
      let tempsResolution = ticket.temps_resolution_min;

      // Transition vers Résolu
      if (statut === 'resolu') {
        const diffMs = Date.now() - new Date(ticket.created_at).getTime();
        tempsResolution = Math.round(diffMs / (60 * 1000));
        closedAt = new Date();
      } else if (statut === 'ferme' || statut === 'annule') {
        closedAt = new Date();
      } else if (statut === 'rouvert') {
        closedAt = null;
      }

      // 1. Mettre à jour le ticket
      await conn.execute(
        'UPDATE tickets SET statut = ?, closed_at = ?, temps_resolution_min = ? WHERE id = ?',
        [statut, closedAt, tempsResolution, id]
      );

      // 2. Insérer le commentaire obligatoire
      await conn.execute(
        'INSERT INTO ticket_commentaires (ticket_id, auteur_id, contenu, type) VALUES (?, ?, ?, "public")',
        [id, req.user.id, commentaire]
      );

      // 3. Log historique
      await logHistory(conn, id, req.user.id, 'statut', ticket.statut, statut);

      // 4. Notifications
      if (statut === 'resolu') {
        await createNotification(
          ticket.createur_id,
          `Ticket résolu: ${ticket.numero}`,
          `Votre ticket "${ticket.titre}" a été résolu. Merci de valider et évaluer.`
        );
      } else if (statut === 'rouvert') {
        if (ticket.technicien_id) {
          await createNotification(
            ticket.technicien_id,
            `Ticket réouvert: ${ticket.numero}`,
            `L'utilisateur a réouvert le ticket "${ticket.titre}". Motif: ${commentaire}`
          );
        }
      }
    });

    // Récupérer le créateur du ticket pour lui envoyer l'email de notification
    const [creator] = await query('SELECT nom, prenom, email FROM auth_users WHERE id = ? LIMIT 1', [ticket.createur_id]);
    if (creator && creator.email) {
      EmailService.sendTicketStatusUpdate({
        ticket,
        creator,
        userEmail: creator.email,
        oldStatus: ticket.statut,
        newStatus: statut,
        comment: commentaire
      }).catch(err => logger.error('Erreur lors de l\'envoi de l\'email de changement de statut ticket:', err));
    }

    const [updated] = await query('SELECT * FROM tickets WHERE id = ?', [id]);
    return success(res, updated, `Statut mis à jour vers : ${statut}`);
  } catch (err) {
    logger.error('Erreur changement statut:', err);
    return error(res, 'Erreur lors du changement de statut', 500);
  }
}

/**
 * PATCH /api/tickets/:id/assigner
 * Assigne un technicien (IT Admin / Technicien)
 */
async function assign(req, res) {
  try {
    const id = parseInt(req.params.id);
    const { technicien_id } = req.body;

    const tickets = await query('SELECT * FROM tickets WHERE id = ?', [id]);
    if (!tickets.length) return error(res, 'Ticket introuvable', 404);
    const ticket = tickets[0];

    const techs = await query('SELECT nom, prenom FROM auth_users WHERE id = ? AND role IN ("admin", "technicien") LIMIT 1', [technicien_id]);
    if (!techs.length) return error(res, 'Technicien introuvable ou rôle invalide', 404);
    const tech = techs[0];

    await transaction(async (conn) => {
      // Changement de statut automatique vers en_cours si c''était ouvert
      const newStatus = ticket.statut === 'ouvert' ? 'en_cours' : ticket.statut;
      
      await conn.execute(
        'UPDATE tickets SET technicien_id = ?, statut = ? WHERE id = ?',
        [technicien_id, newStatus, id]
      );

      await logHistory(conn, id, req.user.id, 'technicien_id', ticket.technicien_id || 'Aucun', `${tech.prenom} ${tech.nom}`);
      if (newStatus !== ticket.statut) {
        await logHistory(conn, id, req.user.id, 'statut', ticket.statut, newStatus);
      }
    });

    // Notifications
    await createNotification(
      technicien_id,
      `Ticket assigné: ${ticket.numero}`,
      `Vous avez été assigné au ticket "${ticket.titre}".`
    );

    await createNotification(
      ticket.createur_id,
      `Technicien assigné à votre ticket`,
      `Le technicien ${tech.prenom} ${tech.nom} prend en charge votre ticket ${ticket.numero}.`
    );

    logger.info(`[NOTIFICATION EMAIL] Ticket ${ticket.numero} assigné à ${tech.prenom} ${tech.nom}`);

    const [updated] = await query('SELECT * FROM tickets WHERE id = ?', [id]);
    return success(res, updated, 'Technicien assigné avec succès');
  } catch (err) {
    logger.error('Erreur assignation ticket:', err);
    return error(res, 'Erreur lors de l\'assignation du ticket', 500);
  }
}

/**
 * POST /api/tickets/:id/commentaires
 * Ajoute un commentaire
 */
async function addComment(req, res) {
  try {
    const id = parseInt(req.params.id);
    const { contenu, type = 'public' } = req.body;

    const tickets = await query('SELECT * FROM tickets WHERE id = ?', [id]);
    if (!tickets.length) return error(res, 'Ticket introuvable', 404);
    const ticket = tickets[0];

    if (req.user.role === 'lecteur') {
      if (ticket.createur_id !== req.user.id) {
        return error(res, 'Accès interdit', 403);
      }
      if (type === 'interne') {
        return error(res, 'Action interdite: les notes internes sont réservées à l\'équipe IT', 403);
      }
    }

    const resInsert = await query(
      'INSERT INTO ticket_commentaires (ticket_id, auteur_id, contenu, type) VALUES (?, ?, ?, ?)',
      [id, req.user.id, contenu, type]
    );

    // Notifications in-app
    if (type === 'public') {
      if (req.user.id === ticket.createur_id) {
        // L''utilisateur commente -> notifier le technicien
        if (ticket.technicien_id) {
          await createNotification(
            ticket.technicien_id,
            `Nouveau commentaire sur ${ticket.numero}`,
            `${req.user.nom} a écrit: "${contenu.substring(0, 30)}..."`
          );
        }
      } else {
        // Le technicien/admin commente -> notifier le créateur
        await createNotification(
          ticket.createur_id,
          `Nouveau commentaire sur votre ticket ${ticket.numero}`,
          `L'équipe IT a écrit: "${contenu.substring(0, 30)}..."`
        );
      }
    }

    const [comment] = await query(`
      SELECT c.*, u.nom as auteur_nom, u.prenom as auteur_prenom, u.role as auteur_role
      FROM ticket_commentaires c
      LEFT JOIN auth_users u ON c.auteur_id = u.id
      WHERE c.id = ?
    `, [resInsert.insertId]);

    logger.info(`[NOTIFICATION EMAIL] Commentaire ajouté sur ticket ${ticket.numero}`);

    return success(res, comment, 'Commentaire ajouté avec succès', 201);
  } catch (err) {
    logger.error('Erreur addComment:', err);
    return error(res, 'Erreur lors de l\'ajout du commentaire', 500);
  }
}

/**
 * POST /api/tickets/:id/evaluer
 * Évalue la satisfaction
 */
async function evaluate(req, res) {
  try {
    const id = parseInt(req.params.id);
    const { note, commentaire } = req.body;

    const tickets = await query('SELECT * FROM tickets WHERE id = ?', [id]);
    if (!tickets.length) return error(res, 'Ticket introuvable', 404);
    const ticket = tickets[0];

    if (ticket.createur_id !== req.user.id) {
      return error(res, 'Seul le créateur du ticket peut évaluer la satisfaction', 403);
    }

    await transaction(async (conn) => {
      await conn.execute(
        'INSERT INTO ticket_evaluations (ticket_id, user_id, note, commentaire) VALUES (?, ?, ?, ?)',
        [id, req.user.id, note, commentaire || null]
      );
      await conn.execute(
        'UPDATE tickets SET note_satisfaction = ?, statut = "ferme" WHERE id = ?',
        [note, id]
      );
      await logHistory(conn, id, req.user.id, 'satisfaction', 'Aucune', `${note} étoiles`);
    });

    const [updated] = await query('SELECT * FROM tickets WHERE id = ?', [id]);
    return success(res, updated, 'Merci pour votre évaluation !');
  } catch (err) {
    logger.error('Erreur evaluation:', err);
    return error(res, 'Erreur lors de la validation de l\'évaluation', 500);
  }
}

/**
 * POST /api/tickets/:id/pieces-jointes
 * Upload une pièce jointe
 */
async function uploadAttachment(req, res) {
  try {
    const id = parseInt(req.params.id);

    const tickets = await query('SELECT * FROM tickets WHERE id = ?', [id]);
    if (!tickets.length) return error(res, 'Ticket introuvable', 404);

    if (!req.file) {
      return error(res, 'Aucun fichier fourni', 400);
    }

    const { originalname, filename, size } = req.file;
    const chemin = `/uploads/${filename}`;

    const resInsert = await query(
      'INSERT INTO ticket_pieces_jointes (ticket_id, nom_fichier, chemin, taille) VALUES (?, ?, ?, ?)',
      [id, originalname, chemin, size]
    );

    const [pj] = await query('SELECT * FROM ticket_pieces_jointes WHERE id = ?', [resInsert.insertId]);
    return success(res, pj, 'Fichier joint téléversé avec succès', 201);
  } catch (err) {
    logger.error('Erreur upload pj:', err);
    return error(res, 'Erreur serveur', 500);
  }
}

/**
 * GET /api/tickets/:id/historique
 * Récupère l'audit trail
 */
async function getHistory(req, res) {
  try {
    const id = parseInt(req.params.id);
    const historique = await query(`
      SELECT h.*, u.nom as user_nom, u.prenom as user_prenom
      FROM ticket_historique h
      LEFT JOIN auth_users u ON h.user_id = u.id
      WHERE h.ticket_id = ?
      ORDER BY h.created_at DESC
    `, [id]);
    return success(res, historique);
  } catch (err) {
    return error(res, 'Erreur serveur', 500);
  }
}

/**
 * GET /api/tickets/stats/dashboard
 * Indicateurs KPIs temps réel
 */
async function getDashboardStats(req, res) {
  try {
    // 1. Nombre total par statuts
    const statusCounts = await query(`
      SELECT statut, COUNT(*) as count 
      FROM tickets 
      GROUP BY statut
    `);

    // 2. Tickets en retard SLA (non résolus/fermés)
    const [{ enRetardSla }] = await query(`
      SELECT COUNT(*) as enRetardSla 
      FROM tickets 
      WHERE statut NOT IN ('resolu', 'ferme', 'annule') AND sla_deadline < NOW()
    `);

    // 3. Résolus aujourd'hui
    const [{ resolusAujourdhui }] = await query(`
      SELECT COUNT(*) as resolusAujourdhui 
      FROM tickets 
      WHERE statut IN ('resolu', 'ferme') AND DATE(closed_at) = CURDATE()
    `);

    // 4. Heatmap par sites
    const parSite = await query(`
      SELECT site, COUNT(*) as count 
      FROM tickets 
      WHERE type = 'incident'
      GROUP BY site
    `);

    // 5. Heatmap par départements
    const parDepartement = await query(`
      SELECT u.departement, COUNT(t.id) as count 
      FROM tickets t
      LEFT JOIN auth_users au ON t.createur_id = au.id
      LEFT JOIN utilisateurs u ON LOWER(u.nom) = LOWER(au.nom)
                               AND LOWER(u.prenom) = LOWER(au.prenom)
      WHERE t.type = 'incident' AND u.departement IS NOT NULL
      GROUP BY u.departement
    `);

    // 6. Charge par techniciens
    const chargeTechs = await query(`
      SELECT ut.id, ut.nom, ut.prenom, COUNT(t.id) as active_tickets
      FROM auth_users ut
      LEFT JOIN tickets t ON t.technicien_id = ut.id AND t.statut IN ('ouvert', 'en_cours', 'en_attente', 'rouvert')
      WHERE ut.role IN ('admin', 'technicien')
      GROUP BY ut.id
    `);

    return success(res, {
      statusCounts,
      enRetardSla,
      resolusAujourdhui,
      heatmap: { parSite, parDepartement },
      chargeTechs
    });
  } catch (err) {
    logger.error('Erreur stats dashboard:', err);
    return error(res, 'Erreur serveur', 500);
  }
}

/**
 * GET /api/tickets/stats/rapports
 * Données pour graphiques et rapports
 */
async function getReports(req, res) {
  try {
    const { start_date, end_date } = req.query;
    let dateFilter = '';
    const params = [];
    if (start_date && end_date) {
      dateFilter = 'AND created_at BETWEEN ? AND ?';
      params.push(start_date, end_date);
    }

    // 1. Volume de tickets par mois (sur les 6 derniers mois)
    const volumeParPeriode = await query(`
      SELECT DATE_FORMAT(created_at, '%Y-%m') as periode, COUNT(*) as count 
      FROM tickets 
      WHERE 1=1 ${dateFilter}
      GROUP BY periode 
      ORDER BY periode ASC
      LIMIT 6
    `, params);

    // 2. Tickets par type
    const parType = await query(`
      SELECT type, COUNT(*) as count 
      FROM tickets 
      WHERE 1=1 ${dateFilter}
      GROUP BY type
    `, params);

    // 3. Taux de résolution SLA dans les délais
    const [{ totalResolus }] = await query(`
      SELECT COUNT(*) as totalResolus FROM tickets WHERE statut IN ('resolu', 'ferme') ${dateFilter}
    `, params);

    const [{ resolusSlaOk }] = await query(`
      SELECT COUNT(*) as resolusSlaOk 
      FROM tickets 
      WHERE statut IN ('resolu', 'ferme') AND closed_at <= sla_deadline ${dateFilter}
    `, params);

    const tauxSla = totalResolus > 0 ? Math.round((resolusSlaOk / totalResolus) * 100) : 100;

    // 4. MTTR (Temps moyen de résolution en minutes) par priorité
    const mttr = await query(`
      SELECT priorite, ROUND(AVG(temps_resolution_min)) as mttr_min
      FROM tickets 
      WHERE statut IN ('resolu', 'ferme') ${dateFilter}
      GROUP BY priorite
    `, params);

    // 5. Satisfaction utilisateur (note moyenne)
    const [{ noteMoyenne }] = await query(`
      SELECT ROUND(AVG(note_satisfaction), 1) as noteMoyenne 
      FROM tickets 
      WHERE note_satisfaction IS NOT NULL ${dateFilter}
    `, params);

    // 6. Top 10 assets défaillants (incidents)
    const topAssetsDefaillants = await query(`
      SELECT a.id, a.\`Nom Machine\` as asset_tag, a.marque, a.modele, COUNT(t.id) as nb_incidents
      FROM tickets t
      JOIN assets a ON t.asset_id = a.id
      WHERE t.type = 'incident' ${dateFilter}
      GROUP BY a.id
      ORDER BY nb_incidents DESC
      LIMIT 10
    `, params);

    return success(res, {
      volumeParPeriode,
      parType,
      tauxSla,
      mttr,
      satisfaction: noteMoyenne || 0.0,
      topAssetsDefaillants
    });
  } catch (err) {
    logger.error('Erreur reports:', err);
    return error(res, 'Erreur serveur', 500);
  }
}

/**
 * GET /api/tickets/export/excel
 * Exporte les tickets au format Excel (.xlsx)
 */
async function exportExcel(req, res) {
  try {
    const rows = await query(`
      SELECT t.numero, t.titre, t.description, t.type, t.priorite, t.statut, t.site, 
             t.created_at, t.closed_at, t.temps_resolution_min, t.note_satisfaction,
             a.\`Nom Machine\` as asset_tag, uc.username as createur, ut.username as technicien
      FROM tickets t
      LEFT JOIN assets a ON t.asset_id = a.id
      LEFT JOIN auth_users uc ON t.createur_id = uc.id
      LEFT JOIN auth_users ut ON t.technicien_id = ut.id
      ORDER BY t.created_at DESC
    `);

    // Formater pour Excel
    const formatted = rows.map(r => ({
      'Numéro': r.numero,
      'Titre': r.titre,
      'Description': r.description,
      'Type': r.type,
      'Priorité': r.priorite.toUpperCase(),
      'Statut': r.statut.toUpperCase(),
      'Site': r.site,
      'Date Création': new Date(r.created_at).toLocaleString('fr-FR'),
      'Date Clôture': r.closed_at ? new Date(r.closed_at).toLocaleString('fr-FR') : 'Non clôturé',
      'Temps Résolution (min)': r.temps_resolution_min || 0,
      'Satisfaction (1-5)': r.note_satisfaction || 'N/A',
      'Asset': r.asset_tag || 'Aucun',
      'Créateur': r.createur,
      'Technicien': r.technicien || 'Non assigné',
    }));

    const wb = XLSX.utils.book_new();
    const ws = XLSX.utils.json_to_sheet(formatted);
    XLSX.utils.book_append_sheet(wb, ws, 'Tickets IT');

    const buf = XLSX.write(wb, { type: 'buffer', bookType: 'xlsx' });

    res.setHeader('Content-Disposition', 'attachment; filename="rapport_tickets_it.xlsx"');
    res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    return res.send(buf);
  } catch (err) {
    logger.error('Erreur export Excel:', err);
    return error(res, 'Erreur lors de la génération de l\'export Excel', 500);
  }
}

/**
 * GET /api/tickets/export/pdf
 * Exporte un rapport PDF premium
 */
async function exportPdf(req, res) {
  try {
    if (!PDFDocument) {
      return error(res, 'Bibliothèque de génération PDF non disponible', 500);
    }

    const tickets = await query(`
      SELECT numero, titre, type, priorite, statut, site, created_at
      FROM tickets 
      ORDER BY created_at DESC 
      LIMIT 30
    `);

    const doc = new PDFDocument({ margin: 50 });
    
    res.setHeader('Content-Disposition', 'attachment; filename="rapport_performance_it.pdf"');
    res.setHeader('Content-Type', 'application/pdf');
    doc.pipe(res);

    // Header
    doc.fillColor('#0969DA').fontSize(24).text('RAPPORT DE GESTION DES TICKETS IT', { align: 'center' });
    doc.fillColor('#57606A').fontSize(10).text(`Généré le : ${new Date().toLocaleString('fr-FR')} - Direction IT Bouaké`, { align: 'center' });
    doc.moveDown(2);

    // Section 1: KPI
    doc.fillColor('#24292F').fontSize(16).text('Derniers tickets enregistrés (Max 30) :', { underline: true });
    doc.moveDown(1);

    // Table Header
    doc.fontSize(10).fillColor('#24292F');
    const tableTop = doc.y;
    doc.text('Numéro', 50, tableTop, { bold: true });
    doc.text('Titre', 150, tableTop, { bold: true });
    doc.text('Type', 320, tableTop, { bold: true });
    doc.text('Priorité', 400, tableTop, { bold: true });
    doc.text('Statut', 470, tableTop, { bold: true });
    
    doc.moveTo(50, tableTop + 15).lineTo(550, tableTop + 15).strokeColor('#D0D7DE').stroke();
    
    // Table Body
    let y = tableTop + 25;
    tickets.forEach(t => {
      if (y > 700) {
        doc.addPage();
        y = 50;
      }
      doc.text(t.numero, 50, y);
      doc.text(t.titre.substring(0, 25) + (t.titre.length > 25 ? '...' : ''), 150, y);
      doc.text(t.type, 320, y);
      doc.text(t.priorite.toUpperCase(), 400, y);
      doc.text(t.statut.toUpperCase(), 470, y);
      y += 20;
    });

    doc.end();
  } catch (err) {
    logger.error('Erreur export PDF:', err);
    return error(res, 'Erreur lors de la génération de l\'export PDF', 500);
  }
}

/**
 * GET /api/tickets/notifications
 * Récupère les notifications de l'utilisateur connecté
 */
async function getNotifications(req, res) {
  try {
    const userId = req.user.id;
    const rows = await query(
      'SELECT * FROM in_app_notifications WHERE user_id = ? ORDER BY created_at DESC LIMIT 50',
      [userId]
    );
    return success(res, rows);
  } catch (err) {
    logger.error('Erreur getNotifications:', err);
    return error(res, 'Erreur serveur', 500);
  }
}

/**
 * PATCH /api/tickets/notifications/:id/lu
 * Marque une notification comme lue
 */
async function markNotificationAsRead(req, res) {
  try {
    const id = parseInt(req.params.id);
    const userId = req.user.id;
    await query(
      'UPDATE in_app_notifications SET lu = 1 WHERE id = ? AND user_id = ?',
      [id, userId]
    );
    return success(res, null, 'Notification marquée comme lue');
  } catch (err) {
    logger.error('Erreur markNotificationAsRead:', err);
    return error(res, 'Erreur serveur', 500);
  }
}

module.exports = {
  create,
  list,
  getOne,
  update,
  changeStatus,
  assign,
  addComment,
  evaluate,
  uploadAttachment,
  getHistory,
  getDashboardStats,
  getReports,
  exportExcel,
  exportPdf,
  getNotifications,
  markNotificationAsRead
};
