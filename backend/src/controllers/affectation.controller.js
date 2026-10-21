// ============================================
// src/controllers/affectation.controller.js
// ============================================
'use strict';

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
        u.departement, u.site, u.email
      FROM affectations af
      JOIN assets a ON a.id = af.asset_id
      JOIN utilisateurs u ON u.id = af.user_id
      ${where}
      ORDER BY af.date_attribution DESC
      LIMIT ? OFFSET ?
    `, [...params, parseInt(limit), offset]);

    return paginated(res, affectations, total, page, limit);
  } catch (err) {
    logger.error('Erreur list affectations:', err);
    return error(res, 'Erreur serveur', 500);
  }
}

async function create(req, res) {
  try {
    const { asset_id, user_id, date_attribution, motif, nom, prenom, departement } = req.body;

    let finalUserId = user_id;

    await transaction(async (conn) => {
      if (!finalUserId && nom && prenom) {
        // Créer l'utilisateur à la volée
        const [userResult] = await conn.execute(
          'INSERT INTO utilisateurs (nom, prenom, departement) VALUES (?, ?, ?)',
          [nom.trim(), prenom.trim(), departement ? departement.trim() : null]
        );
        finalUserId = userResult.insertId;
      }

      if (!finalUserId) {
        throw new Error('Veuillez sélectionner un utilisateur ou saisir les informations d\'un nouvel utilisateur.');
      }

      // Clôturer l'affectation active précédente
      await conn.execute(
        'UPDATE affectations SET actif = 0, date_retrait = ? WHERE asset_id = ? AND actif = 1',
        [date_attribution, asset_id]
      );
      // Créer la nouvelle affectation
      await conn.execute(
        'INSERT INTO affectations (asset_id, user_id, date_attribution, motif, actif) VALUES (?, ?, ?, ?, 1)',
        [asset_id, finalUserId, date_attribution, motif]
      );
      // Mettre à jour le statut asset
      await conn.execute(
        'UPDATE assets SET statut = "en_service", updated_at = NOW() WHERE id = ?',
        [asset_id]
      );
    });

    await query(
      'INSERT INTO activity_logs (user_id, action, entity_type, entity_id, details) VALUES (?, ?, ?, ?, ?)',
      [req.user.id, 'AFFECTATION_CREATE', 'asset', asset_id, JSON.stringify({ user_id: finalUserId, motif })]
    );

    return success(res, null, 'Affectation enregistrée', 201);
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
    const { user_id, date_attribution, date_retrait, motif, actif, nom, prenom, departement } = req.body;

    const existing = await query('SELECT * FROM affectations WHERE id = ?', [id]);
    if (!existing || !existing.length) return error(res, 'Affectation introuvable', 404);
    
    const affectation = existing[0];
    const asset_id = affectation.asset_id;

    await transaction(async (conn) => {
      let finalUserId = user_id;
      if (!finalUserId && nom && prenom) {
        const [userResult] = await conn.execute(
          'INSERT INTO utilisateurs (nom, prenom, departement) VALUES (?, ?, ?)',
          [nom.trim(), prenom.trim(), departement ? departement.trim() : null]
        );
        finalUserId = userResult.insertId;
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

module.exports = { list, create, retrait, update, remove };
