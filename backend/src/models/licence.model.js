'use strict';
const { query } = require('../config/db');

async function findAll({ search } = {}) {
  const params = [];
  let where = '';
  if (search) {
    where = 'WHERE nom LIKE ? OR editeur LIKE ?';
    const s = `%${search}%`;
    params.push(s, s);
  }

  return await query(`
    SELECT l.*, 
           COUNT(la.id) as nb_utilisations
    FROM licences l
    LEFT JOIN licence_allocations la ON la.licence_id = l.id
    ${where}
    GROUP BY l.id
    ORDER BY l.nom
  `, params);
}

async function findById(id) {
  const [licence] = await query('SELECT * FROM licences WHERE id = ?', [id]);
  if (!licence) return null;

  const allocations = await query(`
    SELECT la.id as allocation_id, la.date_allocation,
           u.id as user_id, u.nom, u.prenom, u.departement, u.site
    FROM licence_allocations la
    JOIN utilisateurs u ON la.user_id = u.id
    WHERE la.licence_id = ?
  `, [id]);

  return { ...licence, allocations };
}

async function create(data) {
  const { nom, editeur, cle_activation, date_expiration, quota_max, cout, notes } = data;
  const result = await query(
    `INSERT INTO licences (nom, editeur, cle_activation, date_expiration, quota_max, cout, notes) 
     VALUES (?, ?, ?, ?, ?, ?, ?)`,
    [nom, editeur, cle_activation, date_expiration || null, quota_max || null, cout || 0.00, notes]
  );
  return result.insertId;
}

async function update(id, data) {
  const fields = Object.keys(data).map(k => `${k} = ?`).join(', ');
  await query(`UPDATE licences SET ${fields} WHERE id = ?`, [...Object.values(data), id]);
}

async function remove(id) {
  await query('DELETE FROM licences WHERE id = ?', [id]);
}

async function allocate(licenceId, userId) {
  const [existing] = await query(
    'SELECT id FROM licence_allocations WHERE licence_id = ? AND user_id = ?',
    [licenceId, userId]
  );
  if (existing) return;

  await query(
    'INSERT INTO licence_allocations (licence_id, user_id, date_allocation) VALUES (?, ?, CURDATE())',
    [licenceId, userId]
  );
}

async function deallocate(allocationId) {
  await query('DELETE FROM licence_allocations WHERE id = ?', [allocationId]);
}

module.exports = { findAll, findById, create, update, remove, allocate, deallocate };
