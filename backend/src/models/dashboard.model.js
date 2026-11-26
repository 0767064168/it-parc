// ============================================
// src/models/dashboard.model.js — Statistiques
// ============================================
'use strict';

const { query } = require('../config/db');

/**
 * Statistiques globales du tableau de bord
 * Note: la colonne "asset_tag" est nommée "Nom Machine" dans la table assets
 */
async function getStats() {
  // Compteurs principaux
  const [totaux] = await query(`
    SELECT
      COUNT(*) as total,
      SUM(CASE WHEN statut = 'en_service'     THEN 1 ELSE 0 END) as en_service,
      SUM(CASE WHEN statut = 'hors_service'   THEN 1 ELSE 0 END) as hors_service,
      SUM(CASE WHEN statut = 'reforme'        THEN 1 ELSE 0 END) as reforme,
      SUM(CASE WHEN statut = 'en_maintenance' THEN 1 ELSE 0 END) as en_maintenance,
      SUM(CASE WHEN statut = 'en_stock'       THEN 1 ELSE 0 END) as en_stock
    FROM assets WHERE deleted_at IS NULL
  `);

  // Répartition par type
  const par_type = await query(`
    SELECT type, COUNT(*) as count
    FROM assets WHERE deleted_at IS NULL
    GROUP BY type ORDER BY count DESC
  `);

  // Répartition par site
  const par_site = await query(`
    SELECT site, COUNT(*) as count
    FROM assets WHERE deleted_at IS NULL AND site IS NOT NULL
    GROUP BY site ORDER BY count DESC
  `);

  // Répartition par département
  const par_departement = await query(`
    SELECT departement, COUNT(*) as count
    FROM assets WHERE deleted_at IS NULL AND departement IS NOT NULL
    GROUP BY departement ORDER BY count DESC
    LIMIT 10
  `);

  // Score de conformité sécurité
  const [securite] = await query(`
    SELECT
      COUNT(*) as total_avec_securite,
      SUM(defender)  as defender_ok,
      SUM(edr)       as edr_ok,
      SUM(intune)    as intune_ok,
      SUM(entra_id)  as entra_id_ok,
      SUM(bitlocker) as bitlocker_ok,
      SUM(onedrive)  as onedrive_ok,
      ROUND((
        SUM(defender) + SUM(edr) + SUM(intune) +
        SUM(entra_id) + SUM(bitlocker) + SUM(onedrive)
      ) * 100.0 / NULLIF(COUNT(*) * 6, 0), 1) as score_conformite
    FROM securite
    JOIN assets a ON a.id = securite.asset_id AND a.deleted_at IS NULL
  `);

  // Machines Windows 10 à migrer
  const [win10] = await query(`
    SELECT COUNT(*) as count
    FROM specs s JOIN assets a ON a.id = s.asset_id
    WHERE a.deleted_at IS NULL
      AND s.os LIKE '%Windows 10%'
      AND a.statut = 'en_service'
  `);

  // Alertes garanties (via table couts)
  const alertes_garanties = await query(`
    SELECT a.id, a.\`Nom Machine\` as asset_tag, a.marque, a.modele, a.type, a.site,
           c.fin_garantie,
           (c.fin_garantie::date - CURRENT_DATE) as jours_restants
    FROM couts c
    JOIN assets a ON a.id = c.asset_id AND a.deleted_at IS NULL
    WHERE c.fin_garantie IS NOT NULL
      AND c.fin_garantie <= (CURRENT_DATE + INTERVAL '90 days')
    ORDER BY c.fin_garantie ASC
    LIMIT 10
  `);

  // Derniers ajouts/modifications
  const recents = await query(`
    SELECT a.id, a.\`Nom Machine\` as asset_tag, a.marque, a.modele, a.type, a.statut,
           a.site, a.departement, a.created_at, a.updated_at
    FROM assets a
    WHERE a.deleted_at IS NULL
    ORDER BY a.updated_at DESC
    LIMIT 8
  `);

  // Machines non-conformes (au moins un contrôle sécurité KO)
  const [non_conformes] = await query(`
    SELECT COUNT(*) as count
    FROM securite s
    JOIN assets a ON a.id = s.asset_id AND a.deleted_at IS NULL
    WHERE (s.defender = 0 OR s.edr = 0 OR s.bitlocker = 0)
  `);

  // Licences expirant dans les 90 jours
  const [licences_expirant_90j] = await query(`
    SELECT COUNT(*) as count FROM licences
    WHERE date_expiration IS NOT NULL
      AND date_expiration >= CURRENT_DATE
      AND date_expiration <= (CURRENT_DATE + INTERVAL '90 days')
  `);

  // Consommables en stock bas (quantité <= seuil_alerte)
  const [consommables_stock_bas] = await query(`
    SELECT COUNT(*) as count FROM consommables
    WHERE quantite <= seuil_alerte
  `);

  // Maintenances planifiées à venir
  const [maintenances_a_venir] = await query(`
    SELECT COUNT(*) as count FROM maintenances
    WHERE statut = 'planifie'
      AND date_prevue >= CURRENT_DATE
  `);

  // Tickets ouverts ou urgents
  let tickets_urgents_count = 0;
  try {
    const [tickets_urgents] = await query(`
      SELECT COUNT(*) as count FROM tickets
      WHERE statut IN ('nouveau', 'en_cours', 'ouvert') AND (priorite IN ('haute', 'urgente') OR type = 'panne_materielle')
    `);
    tickets_urgents_count = tickets_urgents?.count || 0;
  } catch (_) {}

  return {
    totaux,
    par_type,
    par_site,
    par_departement,
    securite,
    machines_win10: win10.count,
    alertes_garanties,
    recents,
    non_conformes: non_conformes.count,
    licences_expirant_bientot: licences_expirant_90j.count,
    stock_critique: consommables_stock_bas.count,
    maintenances_planifiees: maintenances_a_venir.count,
    tickets_urgents: tickets_urgents_count,
  };
}

async function getAdvancedReports() {
  const assets_by_type = await query(`
    SELECT type, COUNT(*) as count 
    FROM assets WHERE deleted_at IS NULL 
    GROUP BY type ORDER BY count DESC
  `);

  const assets_by_statut = await query(`
    SELECT statut, COUNT(*) as count 
    FROM assets WHERE deleted_at IS NULL 
    GROUP BY statut ORDER BY count DESC
  `);

  const maintenances_costs = await query(`
    SELECT to_char(date_prevue, 'YYYY-MM') as mois, SUM(cout) as total_cout, COUNT(*) as count
    FROM maintenances
    WHERE date_prevue IS NOT NULL
    GROUP BY mois
    ORDER BY mois ASC
    LIMIT 12
  `);

  const licences_utilisation = await query(`
    SELECT l.id, l.nom, l.editeur, l.quota_max, COUNT(la.id) as allocated
    FROM licences l
    LEFT JOIN licence_allocations la ON l.id = la.licence_id
    GROUP BY l.id
  `);

  const consommables_stock = await query(`
    SELECT id, nom, quantite, seuil_alerte FROM consommables
  `);

  let sla_stats = { total_tickets: 0, resolus: 0, dans_sla: 0, hors_sla: 0, taux_respect_sla: 100, temps_moyen_resolution_min: 0 };
  let tickets_by_technicien = [];
  try {
    const [slaRow] = await query(`
      SELECT
        COUNT(*) as total_tickets,
        SUM(CASE WHEN statut IN ('resolu', 'ferme') THEN 1 ELSE 0 END) as resolus,
        SUM(CASE WHEN statut IN ('resolu', 'ferme') AND (sla_deadline IS NULL OR closed_at IS NULL OR closed_at <= sla_deadline) THEN 1 ELSE 0 END) as dans_sla,
        SUM(CASE WHEN (sla_deadline IS NOT NULL AND ((closed_at IS NOT NULL AND closed_at > sla_deadline) OR (statut NOT IN ('resolu', 'ferme', 'annule') AND NOW() > sla_deadline))) THEN 1 ELSE 0 END) as hors_sla,
        ROUND(AVG(CASE WHEN temps_resolution_min > 0 THEN temps_resolution_min ELSE NULL END), 0) as temps_moyen_resolution_min
      FROM tickets
    `);
    if (slaRow) {
      const resolus = parseInt(slaRow.resolus || 0, 10);
      const dansSla = parseInt(slaRow.dans_sla || 0, 10);
      sla_stats = {
        total_tickets: parseInt(slaRow.total_tickets || 0, 10),
        resolus,
        dans_sla: dansSla,
        hors_sla: parseInt(slaRow.hors_sla || 0, 10),
        taux_respect_sla: resolus > 0 ? Math.round((dansSla / resolus) * 100) : 100,
        temps_moyen_resolution_min: parseInt(slaRow.temps_moyen_resolution_min || 0, 10),
      };
    }
    tickets_by_technicien = await query(`
      SELECT COALESCE(CONCAT(u.prenom, ' ', u.nom), 'Non assigné') as technicien,
        COUNT(t.id) as total,
        SUM(CASE WHEN t.statut IN ('resolu', 'ferme') THEN 1 ELSE 0 END) as resolus
      FROM tickets t
      LEFT JOIN auth_users u ON u.id = t.technicien_id
      GROUP BY u.id, u.prenom, u.nom
      ORDER BY total DESC
      LIMIT 8
    `);
  } catch (_) {}

  return {
    assets_by_type,
    assets_by_statut,
    maintenances_costs,
    licences_utilisation,
    consommables_stock,
    sla_stats,
    tickets_by_technicien
  };
}

async function getAmortissementStats() {
  const items = await query(`
    SELECT 
      a.id, a.\`Nom Machine\` as asset_tag, a.marque, a.modele, a.type, a.statut, a.site,
      c.prix, c.date_acquisition, c.fin_garantie, c.fournisseur, c.devise
    FROM assets a
    LEFT JOIN couts c ON c.asset_id = a.id
    WHERE a.deleted_at IS NULL
    ORDER BY a.id ASC
  `);

  const now = new Date();
  let DURATION_MONTHS = 36; // 3 ans d'amortissement linéaire standard
  let configuredDevise = 'XOF';
  try {
    const settingsRows = await query('SELECT cle, valeur FROM system_settings WHERE cle IN (?, ?)', ['amortissement_mois', 'devise']);
    for (const s of settingsRows || []) {
      if (s.cle === 'amortissement_mois' && parseInt(s.valeur, 10) > 0) {
        DURATION_MONTHS = parseInt(s.valeur, 10);
      }
      if (s.cle === 'devise' && s.valeur) {
        configuredDevise = s.valeur;
      }
    }
  } catch (_) {}

  let totalAcquisition = 0;
  let totalVNC = 0;
  let amortis100Count = 0;
  let ageTotalMois = 0;
  let assetsWithDateCount = 0;

  const ageDistribution = {
    moins_1_an: 0,
    entre_1_2_ans: 0,
    entre_2_3_ans: 0,
    plus_3_ans: 0
  };

  const formattedItems = items.map(item => {
    let prixAchat = item.prix ? parseFloat(item.prix) : 0;
    if (!prixAchat) {
      if (item.type === 'laptop') prixAchat = 650000;
      else if (item.type === 'desktop') prixAchat = 500000;
      else if (item.type === 'ecran') prixAchat = 120000;
      else if (item.type === 'imprimante') prixAchat = 350000;
      else if (item.type === 'pax_terminal') prixAchat = 250000;
      else prixAchat = 400000;
    }

    const dateAcq = item.date_acquisition ? new Date(item.date_acquisition) : new Date(now.getFullYear() - 2, 0, 1);
    const diffMonths = Math.max(0, (now.getFullYear() - dateAcq.getFullYear()) * 12 + (now.getMonth() - dateAcq.getMonth()));
    
    ageTotalMois += diffMonths;
    assetsWithDateCount++;

    if (diffMonths < 12) ageDistribution.moins_1_an++;
    else if (diffMonths < 24) ageDistribution.entre_1_2_ans++;
    else if (diffMonths < 36) ageDistribution.entre_2_3_ans++;
    else ageDistribution.plus_3_ans++;

    const ratioAmorti = Math.min(1, diffMonths / DURATION_MONTHS);
    const vnc = Math.max(0, Math.round(prixAchat * (1 - ratioAmorti)));
    const estAmorti = ratioAmorti >= 1;

    if (estAmorti) amortis100Count++;
    totalAcquisition += prixAchat;
    totalVNC += vnc;

    return {
      id: item.id,
      asset_tag: item.asset_tag,
      marque: item.marque,
      modele: item.modele,
      type: item.type,
      statut: item.statut,
      site: item.site,
      fournisseur: item.fournisseur,
      date_acquisition: dateAcq.toISOString().split('T')[0],
      age_mois: diffMonths,
      age_annees: (diffMonths / 12).toFixed(1),
      prix_achat: Math.round(prixAchat),
      vnc: vnc,
      taux_amorti_pct: Math.round(ratioAmorti * 100),
      est_amorti: estAmorti,
      devise: item.devise || 'XOF'
    };
  });

  const ageMoyenAnnees = assetsWithDateCount > 0 ? (ageTotalMois / assetsWithDateCount / 12).toFixed(1) : 0;
  const tauxGlobalAmortiPct = totalAcquisition > 0 ? Math.round(((totalAcquisition - totalVNC) / totalAcquisition) * 100) : 0;
  const budgetPrevisionnelN1 = formattedItems
    .filter(i => i.est_amorti && i.statut !== 'reforme')
    .reduce((acc, curr) => acc + curr.prix_achat, 0);

  return {
    total_acquisition: totalAcquisition,
    total_vnc: totalVNC,
    taux_global_amorti_pct: tauxGlobalAmortiPct,
    nb_machines_total: items.length,
    nb_machines_amorties: amortis100Count,
    age_moyen_annees: parseFloat(ageMoyenAnnees),
    budget_previsionnel_n1: budgetPrevisionnelN1,
    duree_amortissement_mois: DURATION_MONTHS,
    devise: configuredDevise,
    distribution_age: ageDistribution,
    items: formattedItems.slice(0, 50)
  };
}

module.exports = { getStats, getAdvancedReports, getAmortissementStats };
