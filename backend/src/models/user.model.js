'use strict';
const { query } = require('../config/db');

async function findAll({ page = 1, limit = 20, site, departement, search } = {}) {
  const offset = (page - 1) * limit;
  const conditions = [];
  const params = [];
  if (site)        { conditions.push('site = ?');        params.push(site); }
  if (departement) { conditions.push('departement = ?'); params.push(departement); }
  if (search) {
    conditions.push('(nom LIKE ? OR prenom LIKE ? OR email LIKE ?)');
    const s = `%${search}%`;
    params.push(s, s, s);
  }
  const where = conditions.length ? 'WHERE ' + conditions.join(' AND ') : '';
  const [{ total }] = await query(`SELECT COUNT(*) as total FROM utilisateurs ${where}`, params);
  const users = await query(`
    SELECT u.*,
      COUNT(af.id) as nb_assets
    FROM utilisateurs u
    LEFT JOIN affectations af ON af.user_id = u.id AND af.actif = 1
    ${where}
    GROUP BY u.id
    ORDER BY u.nom, u.prenom
    LIMIT ? OFFSET ?
  `, [...params, parseInt(limit), offset]);
  return { users, total };
}

async function findById(id) {
  const [user] = await query('SELECT * FROM utilisateurs WHERE id = ?', [id]);
  if (!user) return null;
  const assets = await query(`
    SELECT a.id, a.\`Nom Machine\` as asset_tag, a.marque, a.modele, a.type, a.statut,
           af.date_attribution, af.motif
    FROM affectations af
    JOIN assets a ON a.id = af.asset_id AND a.deleted_at IS NULL
    WHERE af.user_id = ? AND af.actif = 1
  `, [id]);
  return { ...user, assets };
}

async function create(data) {
  const nom        = data.nom        ?? null;
  const prenom     = data.prenom     ?? null;
  const departement= data.departement?? null;
  const site       = data.site       ?? null;
  const email      = data.email      ?? null;
  const telephone  = data.telephone  ?? null;
  const result = await query(
    'INSERT INTO utilisateurs (nom, prenom, departement, site, email, telephone) VALUES (?, ?, ?, ?, ?, ?)',
    [nom, prenom, departement, site, email, telephone]
  );
  return result.insertId;
}

async function update(id, data) {
  // Remplacer les undefined par null pour éviter les paramètres invalides.
  const safeData = Object.fromEntries(
    Object.entries(data).map(([k, v]) => [k, v === undefined ? null : v])
  );
  const fields = Object.keys(safeData).map(k => `${k} = ?`).join(', ');
  await query(`UPDATE utilisateurs SET ${fields} WHERE id = ?`, [...Object.values(safeData), id]);
}

async function remove(id) {
  await query('DELETE FROM utilisateurs WHERE id = ?', [id]);
}

module.exports = { findAll, findById, create, update, remove };
