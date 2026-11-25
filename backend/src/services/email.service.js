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

/**
 * Notification lors de l'attribution d'un équipement à un collaborateur
 */
async function sendAffectationNotification({ userEmail, userName, assetTag, marque, modele, serialNumber, dateAttribution }) {
  if (!userEmail) return false;
  const subject = `[Attribution Matériel IT] Équipement ${assetTag} affecté à votre compte`;
  const dateStr = dateAttribution ? new Date(dateAttribution).toLocaleDateString('fr-FR') : new Date().toLocaleDateString('fr-FR');

  const html = `
    <div style="font-family: 'Segoe UI', Arial, sans-serif; background-color: #F8FAFC; padding: 40px 10px; color: #1E293B;">
      <div style="max-width: 600px; margin: 0 auto; background: #FFFFFF; border-radius: 16px; overflow: hidden; border: 1px solid #E2E8F0;">
        <div style="background-color: #0F172A; padding: 28px; text-align: center;">
          <h2 style="color: #FFFFFF; margin: 0; font-size: 20px;">Direction IT Bouaké</h2>
          <p style="color: #38BDF8; margin: 4px 0 0 0; font-size: 13px;">Attribution de Matériel Informatique</p>
        </div>
        <div style="padding: 28px 36px;">
          <p style="font-size: 15px;">Bonjour <strong>${userName}</strong>,</p>
          <p style="font-size: 14px; color: #334155; line-height: 1.5;">
            La Direction IT vous confirme l'attribution d'un équipement informatique en date du <strong>${dateStr}</strong> :
          </p>
          <table style="width: 100%; border-collapse: collapse; margin: 18px 0; background: #F8FAFC; border-radius: 8px;">
            <tr>
              <td style="padding: 10px 14px; color: #64748B; font-size: 13px;">Nom Machine / Tag</td>
              <td style="padding: 10px 14px; color: #0F172A; font-weight: 700; font-size: 13px;">${assetTag}</td>
            </tr>
            <tr>
              <td style="padding: 10px 14px; color: #64748B; font-size: 13px;">Modèle</td>
              <td style="padding: 10px 14px; color: #0F172A; font-size: 13px;">${marque || ''} ${modele || ''}</td>
            </tr>
            <tr>
              <td style="padding: 10px 14px; color: #64748B; font-size: 13px;">N° de Série</td>
              <td style="padding: 10px 14px; color: #0F172A; font-family: monospace; font-size: 13px;">${serialNumber || 'N/A'}</td>
            </tr>
          </table>
          <p style="font-size: 12.5px; color: #64748B;">
            Conformément à la charte informatique, vous êtes responsable de la bonne garde de ce matériel.
          </p>
        </div>
        <div style="background-color: #F8FAFC; padding: 16px; text-align: center; border-top: 1px solid #E2E8F0; font-size: 12px; color: #94A3B8;">
          Direction IT Bouaké • Notification automatique
        </div>
      </div>
    </div>
  `;

  const text = `Bonjour ${userName},\nL'équipement ${assetTag} (${marque || ''} ${modele || ''}, S/N: ${serialNumber || 'N/A'}) vous a été attribué le ${dateStr}.`;
  return sendMail({ to: userEmail, subject, html, text });
}

/**
 * Alerte de stock critique sur un consommable
 */
async function sendStockCritiqueAlert({ adminEmails, consommableNom, quantite, seuil }) {
  if (!adminEmails || !adminEmails.length) return false;
  const subject = `[ALERTE STOCK CRITIQUE] ${consommableNom} (${quantite} restant(s))`;

  const html = `
    <div style="font-family: 'Segoe UI', Arial, sans-serif; background-color: #F8FAFC; padding: 40px 10px; color: #1E293B;">
      <div style="max-width: 600px; margin: 0 auto; background: #FFFFFF; border-radius: 16px; overflow: hidden; border: 1px solid #FECACA;">
        <div style="background-color: #991B1B; padding: 24px; text-align: center;">
          <h2 style="color: #FFFFFF; margin: 0; font-size: 19px;">⚠️ Alerte Stock Critique</h2>
          <p style="color: #FECACA; margin: 4px 0 0 0; font-size: 13px;">Réapprovisionnement consommable requis</p>
        </div>
        <div style="padding: 28px 36px;">
          <p style="font-size: 14px; color: #334155;">
            Le consommable <strong>${consommableNom}</strong> a atteint son seuil critique de sécurité :
          </p>
          <div style="background: #FEF2F2; border-left: 4px solid #EF4444; padding: 14px; border-radius: 6px; margin: 16px 0;">
            <div style="font-size: 14px; color: #991B1B;"><strong>Quantité actuelle :</strong> ${quantite} unité(s)</div>
            <div style="font-size: 13px; color: #B91C1C; margin-top: 4px;"><strong>Seuil d'alerte configuré :</strong> ${seuil} unité(s)</div>
          </div>
          <p style="font-size: 13px; color: #64748B;">Merci de planifier une commande fournisseur dans les plus brefs délais.</p>
        </div>
      </div>
    </div>
  `;

  const text = `ALERTE STOCK CRITIQUE : ${consommableNom} est à ${quantite} unité(s) (seuil : ${seuil}).`;
  return sendMail({ to: adminEmails.join(','), subject, html, text });
}

/**
 * Rapport d'échéance (Licences & Garanties < 30 jours)
 */
async function sendExpiringAlertsDigest({ adminEmails, licencesExpirant, garantiesExpirant }) {
  if (!adminEmails || !adminEmails.length) return false;
  if ((!licencesExpirant || !licencesExpirant.length) && (!garantiesExpirant || !garantiesExpirant.length)) return false;

  const subject = `[Veille Parc IT] ${licencesExpirant.length} licence(s) et ${garantiesExpirant.length} garantie(s) arrivent à échéance`;
  const html = `
    <div style="font-family: 'Segoe UI', Arial, sans-serif; background-color: #F8FAFC; padding: 40px 10px; color: #1E293B;">
      <div style="max-width: 600px; margin: 0 auto; background: #FFFFFF; border-radius: 16px; overflow: hidden; border: 1px solid #E2E8F0;">
        <div style="background-color: #0F172A; padding: 24px; text-align: center;">
          <h2 style="color: #FFFFFF; margin: 0; font-size: 19px;">📅 Veille Échéances Parc IT</h2>
          <p style="color: #F59E0B; margin: 4px 0 0 0; font-size: 13px;">Renouvellements à prévoir sous 30 jours</p>
        </div>
        <div style="padding: 24px 32px;">
          ${licencesExpirant.length > 0 ? `
            <h3 style="font-size: 15px; color: #0F172A; border-bottom: 1px solid #E2E8F0; padding-bottom: 6px;">🔑 Licences Logicielles (${licencesExpirant.length})</h3>
            <ul style="font-size: 13px; color: #334155; padding-left: 18px;">
              ${licencesExpirant.map(l => `<li><strong>${l.nom}</strong> (${l.editeur || 'Éditeur'}) — Expire le ${new Date(l.date_expiration).toLocaleDateString('fr-FR')}</li>`).join('')}
            </ul>
          ` : ''}
          ${garantiesExpirant.length > 0 ? `
            <h3 style="font-size: 15px; color: #0F172A; border-bottom: 1px solid #E2E8F0; padding-bottom: 6px; margin-top: 20px;">🛡️ Garanties Matérielles (${garantiesExpirant.length})</h3>
            <ul style="font-size: 13px; color: #334155; padding-left: 18px;">
              ${garantiesExpirant.map(g => `<li><strong>${g.asset_tag}</strong> (${g.marque || ''} ${g.modele || ''}) — Fin le ${new Date(g.fin_garantie).toLocaleDateString('fr-FR')}</li>`).join('')}
            </ul>
          ` : ''}
        </div>
      </div>
    </div>
  `;

  const text = `Veille Parc IT : ${licencesExpirant.length} licence(s) et ${garantiesExpirant.length} garantie(s) arrivent à échéance sous 30 jours.`;
  return sendMail({ to: adminEmails.join(','), subject, html, text });
}

module.exports = {
  sendMail,
  sendNewTicketAlert,
  sendTicketStatusUpdate,
  sendAffectationNotification,
  sendStockCritiqueAlert,
  sendExpiringAlertsDigest
};
