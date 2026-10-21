'use strict';
const { query } = require('../config/db');

async function findAll({ asset_id, search } = {}) {
  const params = [];
  let conditions = [];

  if (asset_id) {
    conditions.push('m.asset_id = ?');
    params.push(asset_id);
  }
  if (search) {
    conditions.push('(m.description LIKE ? OR m.notes LIKE ? OR a.`Nom Machine` LIKE ?)');
    const s = `%${search}%`;
    params.push(s, s, s);
  }

  const where = conditions.length ? 'WHERE ' + conditions.join(' AND ') : '';

  return await query(`
    SELECT m.*, 
           a.\`Nom Machine\` as asset_tag, a.marque as asset_marque, a.modele as asset_modele,
           u.nom as tech_nom, u.prenom as tech_prenom
    FROM maintenances m
    JOIN assets a ON m.asset_id = a.id
    LEFT JOIN auth_users u ON m.technicien_id = u.id
    ${where}
    ORDER BY m.date_prevue DESC
  `, params);
}

async function findById(id) {
  const [maint] = await query(`
    SELECT m.*, 
           a.\`Nom Machine\` as asset_tag, a.marque as asset_marque, a.modele as asset_modele,
           u.nom as tech_nom, u.prenom as tech_prenom
    FROM maintenances m
    JOIN assets a ON m.asset_id = a.id
    LEFT JOIN auth_users u ON m.technicien_id = u.id
    WHERE m.id = ?
  `, [id]);
  return maint || null;
}

async function create(data) {
  const { asset_id, technicien_id, type, date_prevue, date_realisee, description, cout, notes, statut } = data;
  const result = await query(
    `INSERT INTO maintenances (asset_id, technicien_id, type, date_prevue, date_realisee, description, cout, notes, statut) 
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      asset_id,
      technicien_id || null,
      type || 'preventive',
      date_prevue,
      date_realisee || null,
      description,
      cout || 0.00,
      notes,
      statut || 'planifie'
    ]
  );
  return result.insertId;
}

async function update(id, data) {
  const fields = Object.keys(data).map(k => `${k} = ?`).join(', ');
  await query(`UPDATE maintenances SET ${fields} WHERE id = ?`, [...Object.values(data), id]);
}

async function remove(id) {
  await query('DELETE FROM maintenances WHERE id = ?', [id]);
}

module.exports = { findAll, findById, create, update, remove };
