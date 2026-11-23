// ============================================
// src/controllers/affectation.controller.js
// ============================================
'use strict';

let PDFDocument;
try {
  PDFDocument = require('pdfkit');
} catch (e) {
  // pdfkit loaded lazily or fallback
}

const { query, transaction } = require('../config/db');
const { success, error, paginated } = require('../utils/response');
const logger = require('../utils/logger');

async function list(req, res) {
  try {
    const { page = 1, limit = 20, asset_id, user_id, actif } = req.query;
    const offset = (page - 1) * limit;
    const conditions = [];
    const params = [];

    if (asset_id) { conditions.push('af.asset_id = ?'); params.push(parseInt(asset_id)); }
    if (user_id)  { conditions.push('af.user_id = ?');  params.push(parseInt(user_id)); }
    if (actif !== undefined) { conditions.push('af.actif = ?'); params.push(actif === 'true' ? 1 : 0); }

    const where = conditions.length ? 'WHERE ' + conditions.join(' AND ') : '';

    const [{ total }] = await query(`SELECT COUNT(*) as total FROM affectations af ${where}`, params);
    const affectations = await query(`
      SELECT af.*,
        a.\`Nom Machine\` as asset_tag, a.marque, a.modele, a.type, a.statut,
        CONCAT(u.prenom, ' ', u.nom) as utilisateur_nom,
        u.nom as user_nom, u.prenom as user_prenom,
        u.departement, u.site, u.email, u.telephone
      FROM affectations af
      JOIN assets a ON a.id = af.asset_id
      JOIN utilisateurs u ON u.id = af.user_id
      ${where}
      ORDER BY af.date_attribution DESC
      LIMIT ? OFFSET ?
    `, [...params, parseInt(limit), offset]);

    const enriched = affectations.map(af => ({
      ...af,
      asset: {
        asset_tag: af.asset_tag,
        marque: af.marque,
        modele: af.modele,
        type: af.type,
        statut: af.statut
      },
      user: {
        nom: af.user_nom || af.utilisateur_nom,
        prenom: af.user_prenom || '',
        departement: af.departement,
        site: af.site,
        email: af.email,
        telephone: af.telephone
      }
    }));

    return paginated(res, enriched, total, page, limit);
  } catch (err) {
    logger.error('Erreur list affectations:', err);
    return error(res, 'Erreur serveur', 500);
  }
}

async function create(req, res) {
  try {
    const { asset_id, user_id, date_attribution, motif, nom, prenom, departement, site, ancien_utilisateur } = req.body;

    let finalUserId = user_id;
    const finalDate = date_attribution || new Date().toISOString().split('T')[0];
    const finalMotif = ancien_utilisateur
      ? (motif ? `${motif} | Ancien utilisateur: ${ancien_utilisateur}` : `Ancien utilisateur: ${ancien_utilisateur}`)
      : motif;

    await transaction(async (conn) => {
      if (!finalUserId && nom && prenom) {
        // Créer l'utilisateur à la volée avec département et site
        const [userResult] = await conn.execute(
          'INSERT INTO utilisateurs (nom, prenom, departement, site) VALUES (?, ?, ?, ?)',
          [nom.trim(), prenom.trim(), departement ? departement.trim() : null, site ? site.trim() : null]
        );
        finalUserId = userResult.insertId;
      } else if (finalUserId && (departement || site)) {
        // Mettre à jour site ou département de l'utilisateur si renseigné
        await conn.execute(
          'UPDATE utilisateurs SET departement = COALESCE(?, departement), site = COALESCE(?, site) WHERE id = ?',
          [departement ? departement.trim() : null, site ? site.trim() : null, finalUserId]
        );
      }

      if (!finalUserId) {
        throw new Error('Veuillez sélectionner un utilisateur ou saisir les informations d\'un nouvel utilisateur.');
      }

      // Clôturer l'affectation active précédente pour cet asset
      await conn.execute(
        'UPDATE affectations SET actif = 0, date_retrait = ? WHERE asset_id = ? AND actif = 1',
        [finalDate, asset_id]
      );

      // Créer la nouvelle affectation
      await conn.execute(
        'INSERT INTO affectations (asset_id, user_id, date_attribution, motif, actif) VALUES (?, ?, ?, ?, 1)',
        [asset_id, finalUserId, finalDate, finalMotif]
      );

      // Mettre à jour le statut, site et département de l'asset
      await conn.execute(
        'UPDATE assets SET statut = "en_service", departement = COALESCE(?, departement), site = COALESCE(?, site), updated_at = NOW() WHERE id = ?',
        [departement ? departement.trim() : null, site ? site.trim() : null, asset_id]
      );
    });

    await query(
      'INSERT INTO activity_logs (user_id, action, entity_type, entity_id, details) VALUES (?, ?, ?, ?, ?)',
      [req.user.id, 'AFFECTATION_CREATE', 'asset', asset_id, JSON.stringify({ user_id: finalUserId, motif: finalMotif })]
    );

    return success(res, null, 'Affectation enregistrée avec succès', 201);
  } catch (err) {
    logger.error('Erreur create affectation:', err);
    return error(res, err.message || 'Erreur lors de l\'affectation', 500);
  }
}

async function retrait(req, res) {
  try {
    const { asset_id, motif, nouveau_statut = 'hors_service' } = req.body;

    await transaction(async (conn) => {
      await conn.execute(
        'UPDATE affectations SET actif = 0, date_retrait = NOW(), motif = ? WHERE asset_id = ? AND actif = 1',
        [motif, asset_id]
      );
      await conn.execute(
        'UPDATE assets SET statut = ?, updated_at = NOW() WHERE id = ?',
        [nouveau_statut, asset_id]
      );
    });

    return success(res, null, 'Retrait enregistré');
  } catch (err) {
    logger.error('Erreur retrait:', err);
    return error(res, 'Erreur lors du retrait', 500);
  }
}

async function update(req, res) {
  try {
    const id = parseInt(req.params.id);
    const { user_id, date_attribution, date_retrait, motif, actif, nom, prenom, departement, site } = req.body;

    const existing = await query('SELECT * FROM affectations WHERE id = ?', [id]);
    if (!existing || !existing.length) return error(res, 'Affectation introuvable', 404);
    
    const affectation = existing[0];
    const asset_id = affectation.asset_id;

    await transaction(async (conn) => {
      let finalUserId = user_id;
      if (!finalUserId && nom && prenom) {
        const [userResult] = await conn.execute(
          'INSERT INTO utilisateurs (nom, prenom, departement, site) VALUES (?, ?, ?, ?)',
          [nom.trim(), prenom.trim(), departement ? departement.trim() : null, site ? site.trim() : null]
        );
        finalUserId = userResult.insertId;
      }

      if (finalUserId && (nom !== undefined || prenom !== undefined || departement !== undefined || site !== undefined)) {
        await conn.execute(
          `UPDATE utilisateurs
           SET nom = COALESCE(?, nom), prenom = COALESCE(?, prenom),
               departement = COALESCE(?, departement), site = COALESCE(?, site)
           WHERE id = ?`,
          [
            nom?.trim() || null,
            prenom?.trim() || null,
            departement?.trim() || null,
            site?.trim() || null,
            finalUserId,
          ]
        );
      }

      let updateFields = [];
      let params = [];

      if (finalUserId !== undefined) { updateFields.push('user_id = ?'); params.push(finalUserId); }
      if (date_attribution !== undefined) { updateFields.push('date_attribution = ?'); params.push(date_attribution); }
      if (date_retrait !== undefined) { updateFields.push('date_retrait = ?'); params.push(date_retrait); }
      if (motif !== undefined) { updateFields.push('motif = ?'); params.push(motif); }
      if (actif !== undefined) { updateFields.push('actif = ?'); params.push(actif ? 1 : 0); }

      if (updateFields.length > 0) {
        params.push(id);
        await conn.execute(
          `UPDATE affectations SET ${updateFields.join(', ')} WHERE id = ?`,
          params
        );
      }

      // Mettre à jour le statut de l'asset si le statut actif a changé
      if (actif !== undefined && actif !== (affectation.actif === 1)) {
        const nouveauStatutAsset = actif ? 'en_service' : 'en_stock';
        await conn.execute(
          'UPDATE assets SET statut = ?, updated_at = NOW() WHERE id = ?',
          [nouveauStatutAsset, asset_id]
        );
      }
    });

    return success(res, null, 'Affectation mise à jour');
  } catch (err) {
    logger.error('Erreur update affectation:', err);
    return error(res, err.message || 'Erreur lors de la mise à jour', 500);
  }
}

async function remove(req, res) {
  try {
    const id = parseInt(req.params.id);
    
    const existing = await query('SELECT * FROM affectations WHERE id = ?', [id]);
    if (!existing || !existing.length) return error(res, 'Affectation introuvable', 404);

    const affectation = existing[0];

    await transaction(async (conn) => {
      await conn.execute('DELETE FROM affectations WHERE id = ?', [id]);
      
      // Si on supprime une affectation active, on remet l'asset en stock
      if (affectation.actif === 1) {
        await conn.execute(
          'UPDATE assets SET statut = "en_stock", updated_at = NOW() WHERE id = ?',
          [affectation.asset_id]
        );
      }
    });

    return success(res, null, 'Affectation supprimée');
  } catch (err) {
    logger.error('Erreur remove affectation:', err);
    return error(res, 'Erreur lors de la suppression', 500);
  }
}

async function generatePdf(req, res) {
  try {
    const id = parseInt(req.params.id);
    if (isNaN(id)) return error(res, 'ID d\'affectation invalide', 400);

    if (!PDFDocument) {
      PDFDocument = require('pdfkit');
    }
    if (!PDFDocument) {
      return error(res, 'Générateur PDF non disponible', 500);
    }

    const rows = await query(`
      SELECT 
        af.id, af.date_attribution, af.date_retrait, af.motif, af.actif,
        a.id as asset_id, a.\`Nom Machine\` as asset_tag, a.serial_number, a.marque, a.modele, a.type, a.statut,
        a.site as asset_site, a.departement as asset_dept,
        u.id as user_id, u.nom as user_nom, u.prenom as user_prenom, u.departement as user_dept, u.site as user_site,
        u.email as user_email, u.telephone as user_tel,
        s.ram, s.stockage, s.cpu, s.os, s.version_os, s.mac_address, s.imei,
        sec.antivirus_nom, sec.antivirus_a_jour, sec.bitlocker_active, sec.intune_enrolled,
        c.date_achat, c.cout_achat
      FROM affectations af
      JOIN assets a ON a.id = af.asset_id
      JOIN utilisateurs u ON u.id = af.user_id
      LEFT JOIN specs s ON s.asset_id = a.id
      LEFT JOIN securite sec ON sec.asset_id = a.id
      LEFT JOIN couts c ON c.asset_id = a.id
      WHERE af.id = ?
    `, [id]);

    if (!rows || rows.length === 0) {
      return error(res, 'Affectation introuvable', 404);
    }

    const aff = rows[0];

    const doc = new PDFDocument({
      size: 'A4',
      margin: 40,
      info: {
        Title: `Fiche d'affectation - ${aff.asset_tag || aff.id}`,
        Author: 'Direction IT',
        Subject: 'Fiche de décharge et attribution de matériel informatique',
      }
    });

    const filename = `Fiche_Affectation_${aff.asset_tag || aff.id}.pdf`;
    res.setHeader('Content-Disposition', `inline; filename="${filename}"`);
    res.setHeader('Content-Type', 'application/pdf');
    doc.pipe(res);

    // En-tête bandeau bleu nuit
    doc.rect(40, 40, 515, 68).fill('#0f172a');
    
    doc.fillColor('#38bdf8').fontSize(9).font('Helvetica-Bold')
       .text('DIRECTION DES SYSTÈMES D\'INFORMATION & DU PARC IT', 55, 52);
    
    doc.fillColor('#ffffff').fontSize(13).font('Helvetica-Bold')
       .text('FICHE D\'ATTRIBUTION & DE DÉCHARGE MATÉRIEL', 55, 67);

    doc.fillColor('#94a3b8').fontSize(8).font('Helvetica')
       .text('Document officiel d\'affectation de poste de travail et d\'équipements informatiques', 55, 87);

    const dateFormatted = aff.date_attribution 
      ? new Date(aff.date_attribution).toLocaleDateString('fr-FR')
      : new Date().toLocaleDateString('fr-FR');
      
    doc.fillColor('#ffffff').fontSize(9).font('Helvetica-Bold')
       .text(`N° AFF-${String(aff.id).padStart(4, '0')}`, 430, 52, { align: 'right', width: 110 });
    doc.fillColor('#cbd5e1').fontSize(8).font('Helvetica')
       .text(`Date : ${dateFormatted}`, 430, 68, { align: 'right', width: 110 });
    doc.fillColor(aff.actif ? '#4ade80' : '#f87171').fontSize(8).font('Helvetica-Bold')
       .text(aff.actif ? '● ACTIF' : '○ RETIRÉ', 430, 84, { align: 'right', width: 110 });

    let currentY = 122;

    function drawSectionHeader(title, y) {
      doc.rect(40, y, 515, 20).fill('#f1f5f9');
      doc.rect(40, y, 4, 20).fill('#0284c7');
      doc.fillColor('#0f172a').fontSize(8.5).font('Helvetica-Bold').text(title.toUpperCase(), 50, y + 6);
      return y + 26;
    }

    function drawRow(label1, val1, label2, val2, y) {
      doc.fillColor('#64748b').fontSize(8).font('Helvetica-Bold').text(label1, 45, y);
      doc.fillColor('#0f172a').fontSize(8.5).font('Helvetica').text(String(val1 || '—'), 150, y, { width: 125, ellipsis: true });
      
      if (label2) {
        doc.fillColor('#64748b').fontSize(8).font('Helvetica-Bold').text(label2, 290, y);
        doc.fillColor('#0f172a').fontSize(8.5).font('Helvetica').text(String(val2 || '—'), 395, y, { width: 155, ellipsis: true });
      }
      return y + 17;
    }

    // 1. Bénéficiaire
    currentY = drawSectionHeader('1. Bénéficiaire du Matériel (Utilisateur Actuel)', currentY);
    currentY = drawRow('Nom & Prénom :', `${aff.user_nom || ''} ${aff.user_prenom || ''}`.trim() || '—', 'Département :', aff.user_dept || aff.asset_dept || '—', currentY);
    currentY = drawRow('Site / Localisation :', aff.user_site || aff.asset_site || '—', 'Email professionnel :', aff.user_email || '—', currentY);
    if (aff.user_tel) {
      currentY = drawRow('Téléphone :', aff.user_tel, '', '', currentY);
    }
    currentY += 6;

    // 2. Équipement
    currentY = drawSectionHeader('2. Matériel Informatique Attribué', currentY);
    currentY = drawRow('Nom Machine (Tag) :', aff.asset_tag || '—', 'Type d\'équipement :', (aff.type || '—').toUpperCase(), currentY);
    currentY = drawRow('Marque & Modèle :', `${aff.marque || ''} ${aff.modele || ''}`.trim() || '—', 'Numéro de Série (S/N) :', aff.serial_number || '—', currentY);
    if (aff.imei || aff.mac_address) {
      currentY = drawRow('IMEI Téléphone :', aff.imei || '—', 'Adresse MAC WiFi/Eth :', aff.mac_address || '—', currentY);
    }
    currentY += 6;

    // 3. Spécifications techniques
    currentY = drawSectionHeader('3. Spécifications Techniques & Système', currentY);
    currentY = drawRow('Processeur (CPU) :', aff.cpu || '—', 'Mémoire RAM :', aff.ram ? `${aff.ram} Go` : '—', currentY);
    currentY = drawRow('Stockage / Disque :', aff.stockage ? `${aff.stockage} Go` : '—', 'Système d\'Exploitation :', `${aff.os || ''} ${aff.version_os || ''}`.trim() || 'Windows', currentY);
    currentY += 6;

    // 4. Sécurité & Conformité
    currentY = drawSectionHeader('4. Sécurité, Logiciels & Références', currentY);
    const defOk = aff.antivirus_a_jour !== 0 ? 'Actif & à jour' : 'Non conforme';
    const entOk = aff.intune_enrolled ? 'Enrôlé / Conforme' : 'Oui';
    currentY = drawRow('Microsoft Defender :', defOk, 'OneDrive Entreprise :', 'Configuré / Actif', currentY);
    currentY = drawRow('Licence Windows :', 'Professionnelle Activée', 'Entra ID (Azure AD) :', entOk, currentY);
    if (aff.motif) {
      currentY = drawRow('Motif / Bon Commande :', aff.motif, '', '', currentY);
    }
    currentY += 8;

    // 5. Engagements
    currentY = drawSectionHeader('5. Engagements du Bénéficiaire & Charte Informatique', currentY);
    doc.fillColor('#334155').fontSize(7.5).font('Helvetica');
    const terms = [
      '• Le collaborateur atteste avoir reçu le matériel désigné ci-dessus en parfait état de fonctionnement.',
      '• Ce matériel informatique et ses accessoires sont strictement réservés à un usage professionnel.',
      '• Le collaborateur s\'engage à respecter les règles de sécurité informatique (verrouillage de session, confidentialité).',
      '• En cas d\'incident technique, perte, vol ou dommage, la Direction IT doit être alertée sans délai.',
      '• Le matériel devra être restitué intégralement à la Direction IT dès la fin de contrat ou changement de poste.'
    ];
    terms.forEach(term => {
      doc.text(term, 45, currentY, { width: 505 });
      currentY += 12;
    });
    currentY += 8;

    // 6. Cadre des Signatures
    doc.rect(40, currentY, 250, 95).strokeColor('#cbd5e1').stroke();
    doc.rect(40, currentY, 250, 18).fill('#f8fafc');
    doc.fillColor('#0f172a').fontSize(8).font('Helvetica-Bold')
       .text('LE BÉNÉFICIAIRE', 45, currentY + 5);
    doc.fillColor('#64748b').fontSize(7).font('Helvetica')
       .text('Mention manuscrite "Lu et approuvé, bon pour accord" :', 45, currentY + 23)
       .text(`Nom : ${aff.user_prenom || ''} ${aff.user_nom || ''}`, 45, currentY + 35)
       .text('Date : ___________________', 45, currentY + 78)
       .text('Signature :', 150, currentY + 78);

    doc.rect(305, currentY, 250, 95).strokeColor('#cbd5e1').stroke();
    doc.rect(305, currentY, 250, 18).fill('#f8fafc');
    doc.fillColor('#0f172a').fontSize(8).font('Helvetica-Bold')
       .text('POUR LA DIRECTION IT / ADMINISTRATEUR', 310, currentY + 5);
    doc.fillColor('#64748b').fontSize(7).font('Helvetica')
       .text('Mise en service et validation du poste :', 310, currentY + 23)
       .text('Responsable IT / Gestionnaire du Parc', 310, currentY + 35)
       .text('Date : ___________________', 310, currentY + 78)
       .text('Cachet & Signature :', 415, currentY + 78);

    // Bas de page
    doc.fillColor('#94a3b8').fontSize(7).font('Helvetica')
       .text('Gestionnaire de Parc IT • Direction IT Bouaké • Document officiel certifié', 40, 785, { align: 'center', width: 515 });

    doc.end();

  } catch (err) {
    logger.error('Erreur generatePdf affectation:', err);
    return error(res, 'Erreur lors de la génération de la fiche PDF', 500);
  }
}

module.exports = { list, create, retrait, update, remove, generatePdf };
