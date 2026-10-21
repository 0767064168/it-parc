// ============================================
// src/services/email.service.js
// Service d'envoi d'e-mails pour les tickets
// ============================================
'use strict';

const nodemailer = require('nodemailer');
const logger = require('../utils/logger');

// Récupération des configurations
const isEnabled = process.env.EMAIL_NOTIFICATIONS_ENABLED === 'true';
const smtpHost = process.env.SMTP_HOST || 'smtp.mailtrap.io';
const smtpPort = parseInt(process.env.SMTP_PORT || '2525');
const smtpUser = process.env.SMTP_USER;
const smtpPass = process.env.SMTP_PASS;
const smtpFrom = process.env.SMTP_FROM || 'Gestionnaire Parc IT <noreply@entreprise.ci>';

let transporter = null;

// Initialisation du transporteur
if (isEnabled && smtpUser && smtpPass) {
  try {
    transporter = nodemailer.createTransport({
      host: smtpHost,
      port: smtpPort,
      secure: smtpPort === 465, // true pour le port 465, false pour les autres ports
      auth: {
        user: smtpUser,
        pass: smtpPass,
      },
    });
    logger.info(`📧 Service E-mail initialisé (SMTP: ${smtpHost}:${smtpPort})`);
  } catch (err) {
    logger.error('❌ Erreur d\'initialisation SMTP, mode simulation activé:', err);
  }
} else {
  logger.info('💡 Notifications E-mail en mode SIMULATION (logs de la console)');
}

/**
 * Envoie un email générique
 */
async function sendMail({ to, subject, html, text }) {
  if (!isEnabled || !transporter) {
    logger.info(`[SIMULATION E-MAIL] Vers: ${to} | Sujet: ${subject}\nTexte: ${text}`);
    return true;
  }

  try {
    const info = await transporter.sendMail({
      from: smtpFrom,
      to,
      subject,
      text,
      html,
    });
    logger.info(`✉️ E-mail envoyé avec succès à ${to}. MessageId: ${info.messageId}`);
    return true;
  } catch (err) {
    logger.error(`❌ Échec d'envoi d'e-mail à ${to}:`, err);
    // On ne plante pas l'application si l'envoi d'email échoue
    return false;
  }
}

/**
 * Notification lors de la création d'un nouveau ticket
 */
async function sendNewTicketAlert({ ticket, creator, itEmails }) {
  const subject = `[Nouveau Ticket] ${ticket.numero} : ${ticket.titre}`;
  
  const formattedDate = new Date(ticket.created_at || Date.now()).toLocaleDateString('fr-FR', {
    day: 'numeric',
    month: 'long',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit'
  });

  const priorityColor = {
    critique: '#EF4444',
    haute: '#F97316',
    moyenne: '#3B82F6',
    basse: '#10B981'
  }[ticket.priorite] || '#6B7280';

  const html = `
    <div style="font-family: 'Segoe UI', Arial, sans-serif; background-color: #F8FAFC; padding: 40px 10px; color: #1E293B;">
      <div style="max-width: 600px; margin: 0 auto; background: #FFFFFF; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 6px -1px rgba(0,0,0,0.05), 0 2px 4px -1px rgba(0,0,0,0.03); border: 1px solid #E2E8F0;">
        <!-- Header -->
        <div style="background-color: #0F172A; padding: 30px; text-align: center;">
          <h2 style="color: #FFFFFF; margin: 0; font-size: 22px; font-weight: 700; letter-spacing: 0.5px;">Direction IT Bouaké</h2>
          <p style="color: #94A3B8; margin: 5px 0 0 0; font-size: 14px;">Gestionnaire de Parc & Centre de Services</p>
        </div>
        
        <!-- Content -->
        <div style="padding: 30px 40px;">
          <h3 style="color: #0F172A; margin-top: 0; font-size: 18px; border-bottom: 2px solid #F1F5F9; padding-bottom: 12px;">🚨 Nouveau Ticket Créé</h3>
          
          <table style="width: 100%; border-collapse: collapse; margin: 20px 0;">
            <tr>
              <td style="padding: 8px 0; color: #64748B; font-size: 14px; width: 140px;">Numéro</td>
              <td style="padding: 8px 0; color: #0F172A; font-size: 14px; font-weight: 600;">${ticket.numero}</td>
            </tr>
            <tr>
              <td style="padding: 8px 0; color: #64748B; font-size: 14px;">Créé par</td>
              <td style="padding: 8px 0; color: #0F172A; font-size: 14px;">${creator.prenom} ${creator.nom}</td>
            </tr>
            <tr>
              <td style="padding: 8px 0; color: #64748B; font-size: 14px;">Priorité</td>
              <td style="padding: 8px 0; font-size: 14px;">
                <span style="background-color: ${priorityColor}15; color: ${priorityColor}; padding: 3px 8px; border-radius: 6px; font-weight: 600; font-size: 12px; text-transform: uppercase;">
                  ${ticket.priorite}
                </span>
              </td>
            </tr>
            <tr>
              <td style="padding: 8px 0; color: #64748B; font-size: 14px;">Catégorie / Type</td>
              <td style="padding: 8px 0; color: #0F172A; font-size: 14px; text-transform: capitalize;">${ticket.type.replace('_', ' ')}</td>
            </tr>
            <tr>
              <td style="padding: 8px 0; color: #64748B; font-size: 14px;">Date de création</td>
              <td style="padding: 8px 0; color: #0F172A; font-size: 14px;">${formattedDate}</td>
            </tr>
          </table>
          
          <div style="background-color: #F8FAFC; border-left: 4px solid #6366F1; padding: 15px; border-radius: 0 8px 8px 0; margin: 24px 0;">
            <p style="margin: 0 0 8px 0; font-weight: 600; color: #0F172A; font-size: 14px;">Titre: ${ticket.titre}</p>
            <p style="margin: 0; color: #475569; font-size: 13.5px; line-height: 1.5; white-space: pre-line;">${ticket.description}</p>
          </div>
          
          <div style="text-align: center; margin-top: 30px;">
            <a href="http://localhost:8080/tickets/${ticket.id}" style="background-color: #4F46E5; color: #FFFFFF; padding: 12px 24px; border-radius: 8px; text-decoration: none; font-weight: 600; font-size: 14px; display: inline-block; box-shadow: 0 4px 6px -1px rgba(79, 70, 229, 0.2);">
              Traiter le Ticket
            </a>
          </div>
        </div>
        
        <!-- Footer -->
        <div style="background-color: #F8FAFC; padding: 20px; text-align: center; border-top: 1px solid #E2E8F0; font-size: 12px; color: #94A3B8;">
          Ce message a été généré automatiquement par le portail DSI.<br/>
          Merci de ne pas y répondre directement.
        </div>
      </div>
    </div>
  `;

  const text = `Nouveau ticket ${ticket.numero} créé par ${creator.prenom} ${creator.nom}.\nPriorité: ${ticket.priorite.toUpperCase()}\nTitre: ${ticket.titre}\nDescription:\n${ticket.description}`;

  // Envoi à la liste des adresses email de l'équipe IT (séparées par des virgules)
  if (itEmails && itEmails.length > 0) {
    await sendMail({
      to: itEmails.join(', '),
      subject,
      html,
      text
    });
  }
}

/**
 * Notification lors de la résolution ou de la clôture d'un ticket
 */
async function sendTicketStatusUpdate({ ticket, creator, userEmail, oldStatus, newStatus, comment }) {
  const statusLabels = {
    resolu: 'Résolu ✅',
    ferme: 'Clôturé 🔒',
    annule: 'Annulé ❌',
    en_cours: 'Pris en charge 🛠️',
    en_attente: 'Mis en attente ⏳',
    rouvert: 'Réouvert 🔄'
  };

  const subject = `[Mise à jour Ticket] ${ticket.numero} : ${statusLabels[newStatus] || newStatus}`;
  
  const priorityColor = {
    critique: '#EF4444',
    haute: '#F97316',
    moyenne: '#3B82F6',
    basse: '#10B981'
  }[ticket.priorite] || '#6B7280';

  const html = `
    <div style="font-family: 'Segoe UI', Arial, sans-serif; background-color: #F8FAFC; padding: 40px 10px; color: #1E293B;">
      <div style="max-width: 600px; margin: 0 auto; background: #FFFFFF; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 6px -1px rgba(0,0,0,0.05), 0 2px 4px -1px rgba(0,0,0,0.03); border: 1px solid #E2E8F0;">
        <!-- Header -->
        <div style="background-color: #0F172A; padding: 30px; text-align: center;">
          <h2 style="color: #FFFFFF; margin: 0; font-size: 22px; font-weight: 700; letter-spacing: 0.5px;">Direction IT Bouaké</h2>
          <p style="color: #94A3B8; margin: 5px 0 0 0; font-size: 14px;">Gestionnaire de Parc & Centre de Services</p>
        </div>
        
        <!-- Content -->
        <div style="padding: 30px 40px;">
          <h3 style="color: #0F172A; margin-top: 0; font-size: 18px; border-bottom: 2px solid #F1F5F9; padding-bottom: 12px;">📣 Statut Mis à Jour</h3>
          
          <p style="font-size: 15px; line-height: 1.5; color: #334155;">
            Bonjour <strong>${creator.prenom} ${creator.nom}</strong>,
          </p>
          <p style="font-size: 15px; line-height: 1.5; color: #334155;">
            Le statut de votre ticket de support a été modifié de <strong>${oldStatus}</strong> à <strong>${statusLabels[newStatus] || newStatus}</strong>.
          </p>

          <table style="width: 100%; border-collapse: collapse; margin: 20px 0; background: #F8FAFC; border-radius: 8px; padding: 15px; display: table;">
            <tr style="display: table-row;">
              <td style="padding: 8px 15px; color: #64748B; font-size: 14px; width: 140px; display: table-cell;">Numéro</td>
              <td style="padding: 8px 15px; color: #0F172A; font-size: 14px; font-weight: 600; display: table-cell;">${ticket.numero}</td>
            </tr>
            <tr style="display: table-row;">
              <td style="padding: 8px 15px; color: #64748B; font-size: 14px; display: table-cell;">Titre du ticket</td>
              <td style="padding: 8px 15px; color: #0F172A; font-size: 14px; display: table-cell;">${ticket.titre}</td>
            </tr>
            <tr style="display: table-row;">
              <td style="padding: 8px 15px; color: #64748B; font-size: 14px; display: table-cell;">Nouveau Statut</td>
              <td style="padding: 8px 15px; font-size: 14px; display: table-cell;">
                <span style="background-color: #10B98115; color: #10B981; padding: 3px 8px; border-radius: 6px; font-weight: 600; font-size: 12px;">
                  ${statusLabels[newStatus] || newStatus}
                </span>
              </td>
            </tr>
          </table>

          ${comment ? `
          <div style="background-color: #FFFBEB; border-left: 4px solid #F59E0B; padding: 15px; border-radius: 0 8px 8px 0; margin: 24px 0;">
            <p style="margin: 0 0 6px 0; font-weight: 600; color: #B45309; font-size: 13px; text-transform: uppercase;">Commentaire de l'intervenant</p>
            <p style="margin: 0; color: #78350F; font-size: 13.5px; line-height: 1.5; white-space: pre-line;">${comment}</p>
          </div>
          ` : ''}
          
          <div style="text-align: center; margin-top: 30px;">
            <a href="http://localhost:8080/tickets/${ticket.id}" style="background-color: #4F46E5; color: #FFFFFF; padding: 12px 24px; border-radius: 8px; text-decoration: none; font-weight: 600; font-size: 14px; display: inline-block; box-shadow: 0 4px 6px -1px rgba(79, 70, 229, 0.2);">
              Consulter le Ticket
            </a>
          </div>
        </div>
        
        <!-- Footer -->
        <div style="background-color: #F8FAFC; padding: 20px; text-align: center; border-top: 1px solid #E2E8F0; font-size: 12px; color: #94A3B8;">
          Ce message a été généré automatiquement par le portail DSI.<br/>
          Merci de ne pas y répondre directement.
        </div>
      </div>
    </div>
  `;

  const text = `Le statut de votre ticket ${ticket.numero} "${ticket.titre}" a été modifié vers ${newStatus.toUpperCase()}.\nCommentaire:\n${comment || 'Aucun commentaire fourni'}`;

  if (userEmail) {
    await sendMail({
      to: userEmail,
      subject,
      html,
      text
    });
  }
}

module.exports = {
  sendMail,
  sendNewTicketAlert,
  sendTicketStatusUpdate
};
