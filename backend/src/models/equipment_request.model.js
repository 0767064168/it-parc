'use strict';

const { query, transaction } = require('../config/db');

async function findAll({ requesterId, includeAll }) {
  const where = includeAll ? '' : 'WHERE r.requester_id = ?';
  const params = includeAll ? [] : [requesterId];
  return query(`
    SELECT r.*,
      COALESCE(NULLIF(CONCAT_WS(' ', requester.prenom, requester.nom), ''), r.requester_name) AS requester_display_name,
      requester.username AS requester_current_username,
      reviewer.username AS reviewer_username,
      a.\`Nom Machine\` AS asset_tag
    FROM equipment_requests r
    LEFT JOIN auth_users requester ON requester.id = r.requester_id
    LEFT JOIN auth_users reviewer ON reviewer.id = r.reviewer_id
    LEFT JOIN assets a ON a.id = r.asset_id
    ${where}
    ORDER BY r.created_at DESC, r.id DESC
  `, params);
}

async function findById(id) {
  const [request] = await query(`
    SELECT r.*,
      COALESCE(NULLIF(CONCAT_WS(' ', requester.prenom, requester.nom), ''), r.requester_name) AS requester_display_name,
      reviewer.username AS reviewer_username,
      a.\`Nom Machine\` AS asset_tag
    FROM equipment_requests r
    LEFT JOIN auth_users requester ON requester.id = r.requester_id
    LEFT JOIN auth_users reviewer ON reviewer.id = r.reviewer_id
    LEFT JOIN assets a ON a.id = r.asset_id
    WHERE r.id = ?
  `, [id]);
  return request || null;
}

async function findAvailableAssets() {
  return query(`
    SELECT id, \`Nom Machine\` AS asset_tag, marque, modele
    FROM assets
    WHERE deleted_at IS NULL AND statut = 'en_stock'
    ORDER BY \`Nom Machine\`
  `);
}

async function create({ requesterId, category, description, justification, priority }) {
  const [requester] = await query(
    'SELECT id, username, nom, prenom FROM auth_users WHERE id = ? AND actif = 1',
    [requesterId]
  );
  if (!requester) return null;

  const requesterName = [requester.prenom, requester.nom].filter(Boolean).join(' ') || requester.username;
  const id = await transaction(async (conn) => {
    const [inserted] = await conn.execute(
      `INSERT INTO equipment_requests
        (requester_id, requester_name, requester_username, category, description, justification, priority)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [requesterId, requesterName, requester.username, category, description || null, justification, priority]
    );
    const requestId = inserted.insertId;
    await conn.execute(
      `INSERT INTO activity_logs (user_id, action, entity_type, entity_id, details)
       VALUES (?, ?, ?, ?, CAST(? AS JSONB))`,
      [requesterId, 'REQUEST_CREATE', 'equipment_request', requestId, JSON.stringify({ category, priority })]
    );
    return requestId;
  });

  return findById(id);
}

async function changeStatus({ id, status, reviewerId, comment, assetId }) {
  return transaction(async (conn) => {
    const [requests] = await conn.execute(
      'SELECT id, status, asset_id, affectation_id, requester_id FROM equipment_requests WHERE id = ? FOR UPDATE',
      [id]
    );
    const existing = requests[0];
    if (!existing) return { error: 'not_found' };

    const allowedPreviousStatuses = {
      en_examen: ['soumise'],
      approuvee: ['soumise', 'en_examen'],
      refusee: ['soumise', 'en_examen'],
      livree: ['approuvee'],
    };
    if (!allowedPreviousStatuses[status]?.includes(existing.status)) {
      return { error: 'invalid_transition' };
    }

    let linkedAssetId = existing.asset_id;
    let affectationId = existing.affectation_id;
    if (status === 'livree') {
      if (!Number.isInteger(assetId) || assetId <= 0) return { error: 'asset_required' };
      const [assets] = await conn.execute(
        "SELECT id FROM assets WHERE id = ? AND deleted_at IS NULL AND statut = 'en_stock' FOR UPDATE",
        [assetId]
      );
      if (!assets.length) return { error: 'asset_unavailable' };
      const [activeAssignments] = await conn.execute(
        'SELECT id FROM affectations WHERE asset_id = ? AND actif = 1 LIMIT 1 FOR UPDATE',
        [assetId]
      );
      if (activeAssignments.length) return { error: 'asset_unavailable' };

      const [requesters] = await conn.execute(
        'SELECT id, username, nom, prenom, email FROM auth_users WHERE id = ? AND actif = 1',
        [existing.requester_id]
      );
      const requester = requesters[0];
      if (!requester) return { error: 'requester_unavailable' };

      let [people] = requester.email
        ? await conn.execute(
          'SELECT id, actif FROM utilisateurs WHERE email IS NOT NULL AND LOWER(email) = LOWER(?) ORDER BY id LIMIT 2',
          [requester.email]
        )
        : [[]];
      if (!people.length && requester.nom && requester.prenom) {
        [people] = await conn.execute(
          'SELECT id, actif FROM utilisateurs WHERE LOWER(nom) = LOWER(?) AND LOWER(prenom) = LOWER(?) ORDER BY id LIMIT 2',
          [requester.nom, requester.prenom]
        );
      }
      if (people.length > 1) return { error: 'requester_ambiguous' };
      if (people[0] && Number(people[0].actif) === 0) return { error: 'requester_personnel_inactive' };
      let personnelId = people[0]?.id;
      if (!personnelId) {
        const [createdPerson] = await conn.execute(
          'INSERT INTO utilisateurs (nom, prenom, email) VALUES (?, ?, ?)',
          [requester.nom || requester.username, requester.prenom || 'Collaborateur', requester.email || null]
        );
        personnelId = createdPerson.insertId;
      }

      const [assignment] = await conn.execute(
        `INSERT INTO affectations (asset_id, user_id, date_attribution, motif, actif)
         VALUES (?, ?, CURRENT_DATE, ?, 1)`,
        [assetId, personnelId, `Demande matériel #${id}`]
      );
      affectationId = assignment.insertId;
      await conn.execute(
        "UPDATE assets SET statut = 'en_service', updated_at = NOW() WHERE id = ?",
        [assetId]
      );
      linkedAssetId = assetId;
    }

    const reviewedAt = status === 'approuvee' || status === 'refusee';
    const deliveredAt = status === 'livree';
    await conn.execute(
      `UPDATE equipment_requests
       SET status = ?, reviewer_id = ?, decision_comment = COALESCE(CAST(? AS TEXT), decision_comment),
           asset_id = ?, affectation_id = ?, updated_at = NOW(),
           reviewed_at = ${reviewedAt ? 'NOW()' : 'reviewed_at'},
           delivered_at = ${deliveredAt ? 'NOW()' : 'delivered_at'}
       WHERE id = ?`,
      [status, reviewerId, comment || null, linkedAssetId, affectationId, id]
    );
    await conn.execute(
      `INSERT INTO activity_logs (user_id, action, entity_type, entity_id, details)
       VALUES (?, ?, ?, ?, CAST(? AS JSONB))`,
      [reviewerId, `REQUEST_${status.toUpperCase()}`, 'equipment_request', id, JSON.stringify({ status, asset_id: linkedAssetId, affectation_id: affectationId })]
    );
    return { status, asset_id: linkedAssetId, affectation_id: affectationId };
  });
}

module.exports = { findAll, findById, findAvailableAssets, create, changeStatus };
