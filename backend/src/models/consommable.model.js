'use strict';
const { query } = require('../config/db');

async function findAll({ search } = {}) {
  const params = [];
  let where = '';
  if (search) {
    where = 'WHERE nom LIKE ? OR categorie LIKE ?';
    const s = `%${search}%`;
    params.push(s, s);
  }

  return await query(`
    SELECT * FROM consommables
    ${where}
    ORDER BY nom
  `, params);
}

async function findById(id) {
  const [consommable] = await query('SELECT * FROM consommables WHERE id = ?', [id]);
  return consommable || null;
}

async function create(data) {
  const { nom, categorie, quantite, seuil_alerte, emplacement } = data;
  const result = await query(
    `INSERT INTO consommables (nom, categorie, quantite, seuil_alerte, emplacement) 
     VALUES (?, ?, ?, ?, ?)`,
    [nom, categorie, quantite || 0, seuil_alerte || 5, emplacement]
  );
  return result.insertId;
}

async function update(id, data) {
  const fields = Object.keys(data).map(k => `${k} = ?`).join(', ');
  await query(`UPDATE consommables SET ${fields} WHERE id = ?`, [...Object.values(data), id]);
}

async function remove(id) {
  await query('DELETE FROM consommables WHERE id = ?', [id]);
}

async function adjustStock(id, diff) {
  await query('UPDATE consommables SET quantite = quantite + ? WHERE id = ?', [diff, id]);
}

module.exports = { findAll, findById, create, update, remove, adjustStock };
