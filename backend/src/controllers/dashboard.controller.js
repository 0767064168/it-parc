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
        AND date_expiration >= CURRENT_DATE
        AND date_expiration <= (CURRENT_DATE + INTERVAL '${licencesJours} days')
    `);
    const garantiesExpirant = await query(`
      SELECT a.id, a.\`Nom Machine\` as asset_tag, a.marque, a.modele, c.fin_garantie
      FROM couts c
      JOIN assets a ON a.id = c.asset_id AND a.deleted_at IS NULL
      WHERE c.fin_garantie IS NOT NULL
        AND c.fin_garantie >= CURRENT_DATE
        AND c.fin_garantie <= (CURRENT_DATE + INTERVAL '${garantiesJours} days')
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

async function exportAmortissementPdf(req, res) {
  try {
    const PDFDocument = require('pdfkit');
    const data = await DashboardModel.getAmortissementStats({ includeAll: true });
    const devise = data.devise || 'XOF';
    const year = new Date().getFullYear();

    const doc = new PDFDocument({
      size: 'A4',
      margin: 36,
      info: {
        Title: `Rapport d'Amortissement VNC - ${year}`,
        Author: 'Direction IT Bouaké',
        Subject: 'Grand Livre Amortissement & Budget Prévisionnel N+1',
      },
    });

    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `attachment; filename="Rapport_Amortissement_VNC_${year}.pdf"`);
    doc.pipe(res);

    const drawHeader = () => {
      doc.rect(36, 36, 523, 56).fill('#0f172a');
      doc.fillColor('#38bdf8').fontSize(8.5).font('Helvetica-Bold')
        .text('DIRECTION DES SYSTÈMES D\'INFORMATION • PARC IT BOUAKÉ', 48, 46);
      doc.fillColor('#ffffff').fontSize(13).font('Helvetica-Bold')
        .text('RAPPORT D\'AMORTISSEMENT VNC & BUDGET N+1', 48, 60);
      doc.fillColor('#cbd5e1').fontSize(8).font('Helvetica')
        .text(`Édition : ${new Date().toLocaleDateString('fr-FR')} • Durée linéaire : ${data.duree_amortissement_mois} mois`, 48, 76);
    };

    drawHeader();

    // Synthèse KPI
    let y = 104;
    doc.rect(36, y, 523, 54).fill('#f8fafc').strokeColor('#cbd5e1').stroke();
    const kpis = [
      { label: 'Acquisition Totale', val: `${Number(data.total_acquisition || 0).toLocaleString('fr-FR')} ${devise}` },
      { label: 'Valeur Nette Comptable', val: `${Number(data.total_vnc || 0).toLocaleString('fr-FR')} ${devise}` },
      { label: 'Taux Amorti / Âge Moyen', val: `${data.taux_global_amorti_pct}% (${data.age_moyen_annees} ans)` },
      { label: 'Budget Renouvellement N+1', val: `${Number(data.budget_previsionnel_n1 || 0).toLocaleString('fr-FR')} ${devise}` },
    ];
    kpis.forEach((kpi, idx) => {
      const x = 44 + idx * 129;
      doc.fillColor('#64748b').fontSize(7).font('Helvetica').text(kpi.label, x, y + 10, { width: 124 });
      doc.fillColor('#0f172a').fontSize(9).font('Helvetica-Bold').text(kpi.val, x, y + 24, { width: 124 });
    });

    y += 68;

    const drawTableHeader = (topY) => {
      doc.rect(36, topY, 523, 18).fill('#1e293b');
      doc.fillColor('#ffffff').fontSize(7.5).font('Helvetica-Bold');
      doc.text('Nom Machine', 40, topY + 5, { width: 92 });
      doc.text('Type / Site', 134, topY + 5, { width: 82 });
      doc.text('Acquis.', 218, topY + 5, { width: 58 });
      doc.text('Âge', 278, topY + 5, { width: 34 });
      doc.text(`Prix (${devise})`, 314, topY + 5, { width: 72, align: 'right' });
      doc.text(`VNC (${devise})`, 390, topY + 5, { width: 72, align: 'right' });
      doc.text('État', 468, topY + 5, { width: 86, align: 'right' });
      return topY + 20;
    };

    y = drawTableHeader(y);

    for (let i = 0; i < (data.items || []).length; i += 1) {
      const item = data.items[i];
      if (y > 760) {
        doc.addPage();
        drawHeader();
        y = drawTableHeader(104);
      }
      if (i % 2 === 1) {
        doc.rect(36, y - 2, 523, 15).fill('#f8fafc');
      }
      doc.fillColor('#0f172a').fontSize(7).font('Helvetica-Bold')
        .text(String(item.asset_tag || '—'), 40, y + 2, { width: 92, ellipsis: true });
      doc.fillColor('#475569').font('Helvetica')
        .text(`${item.type || '—'} • ${item.site || '—'}`, 134, y + 2, { width: 82, ellipsis: true })
        .text(String(item.date_acquisition || '—'), 218, y + 2, { width: 58 })
        .text(`${item.age_mois}m`, 278, y + 2, { width: 34 })
        .text(Number(item.prix_achat || 0).toLocaleString('fr-FR'), 314, y + 2, { width: 72, align: 'right' })
        .text(Number(item.vnc || 0).toLocaleString('fr-FR'), 390, y + 2, { width: 72, align: 'right' });
      doc.fillColor(item.est_amorti ? '#dc2626' : '#059669').font('Helvetica-Bold')
        .text(item.est_amorti ? '100% AMORTI' : `${item.taux_amorti_pct}%`, 468, y + 2, { width: 86, align: 'right' });
      y += 15;
    }

    doc.end();
  } catch (err) {
    logger.error('Erreur exportAmortissementPdf:', err);
    return error(res, 'Erreur lors de la génération du rapport PDF d\'amortissement', 500);
  }
}

async function exportAmortissementExcel(req, res) {
  try {
    const XLSX = require('@e965/xlsx');
    const data = await DashboardModel.getAmortissementStats({ includeAll: true });
    const devise = data.devise || 'XOF';
    const year = new Date().getFullYear();

    const wb = XLSX.utils.book_new();

    const summaryRows = [
      { Indicateur: 'Valeur d\'Acquisition Totale', Valeur: data.total_acquisition, Devise: devise },
      { Indicateur: 'Valeur Nette Comptable (VNC)', Valeur: data.total_vnc, Devise: devise },
      { Indicateur: 'Taux Global d\'Amortissement (%)', Valeur: data.taux_global_amorti_pct, Devise: '%' },
      { Indicateur: 'Équipements Totaux', Valeur: data.nb_machines_total, Devise: 'unités' },
      { Indicateur: 'Équipements 100% Amortis', Valeur: data.nb_machines_amorties, Devise: 'unités' },
      { Indicateur: 'Âge Moyen du Parc (ans)', Valeur: data.age_moyen_annees, Devise: 'ans' },
      { Indicateur: 'Budget Prévisionnel Renouvellement N+1', Valeur: data.budget_previsionnel_n1, Devise: devise },
      { Indicateur: 'Durée d\'Amortissement Linéaire (mois)', Valeur: data.duree_amortissement_mois, Devise: 'mois' },
    ];
    const wsSummary = XLSX.utils.json_to_sheet(summaryRows);
    XLSX.utils.book_append_sheet(wb, wsSummary, 'Synthèse Financière');

    const ledgerRows = (data.items || []).map((item) => ({
      'Nom Machine': item.asset_tag,
      'Type': item.type,
      'Marque': item.marque || '',
      'Modèle': item.modele || '',
      'Site': item.site || '',
      'Statut': item.statut || '',
      'Date Acquisition': item.date_acquisition,
      'Âge (mois)': item.age_mois,
      [`Prix Achat (${devise})`]: item.prix_achat,
      [`VNC Actuelle (${devise})`]: item.vnc,
      'Taux Amorti (%)': item.taux_amorti_pct,
      'État Amortissement': item.est_amorti ? '100% AMORTI (À RENOUVELER)' : 'EN COURS D\'AMORTISSEMENT',
    }));
    const wsLedger = XLSX.utils.json_to_sheet(ledgerRows);
    XLSX.utils.book_append_sheet(wb, wsLedger, 'Grand Livre VNC');

    const buffer = XLSX.write(wb, { type: 'buffer', bookType: 'xlsx' });
    res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    res.setHeader('Content-Disposition', `attachment; filename="Grand_Livre_Amortissement_${year}.xlsx"`);
    return res.send(buffer);
  } catch (err) {
    logger.error('Erreur exportAmortissementExcel:', err);
    return error(res, 'Erreur lors de l\'export Excel d\'amortissement', 500);
  }
}

module.exports = {
  getStats,
  getAdvancedReports,
  getAmortissement,
  exportAmortissementPdf,
  exportAmortissementExcel,
  triggerExpiringAlertsEmail,
  cronExpiringAlerts,
  getMonEspace,
  reportMonIncident,
};
