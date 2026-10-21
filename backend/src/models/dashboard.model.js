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
           DATEDIFF(c.fin_garantie, CURDATE()) as jours_restants
    FROM couts c
    JOIN assets a ON a.id = c.asset_id AND a.deleted_at IS NULL
    WHERE c.fin_garantie IS NOT NULL
      AND c.fin_garantie <= DATE_ADD(CURDATE(), INTERVAL 90 DAY)
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
      AND date_expiration >= CURDATE()
      AND date_expiration <= DATE_ADD(CURDATE(), INTERVAL 90 DAY)
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
      AND date_prevue >= CURDATE()
  `);

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
    SELECT DATE_FORMAT(date_prevue, '%Y-%m') as mois, SUM(cout) as total_cout, COUNT(*) as count
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

  return {
    assets_by_type,
    assets_by_statut,
    maintenances_costs,
    licences_utilisation,
    consommables_stock
  };
}

module.exports = { getStats, getAdvancedReports };
