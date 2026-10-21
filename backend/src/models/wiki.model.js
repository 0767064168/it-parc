'use strict';
// =====================================================
// backend/src/models/wiki.model.js
// =====================================================
const { query } = require('../config/db');

// ─── Articles ─────────────────────────────────────────
async function findAll({ search, role } = {}) {
  const params = [];
  const conditions = [];

  if (role === 'lecteur') {
    conditions.push('w.est_public = 1');
  }

  if (search) {
    conditions.push('(w.titre LIKE ? OR w.contenu LIKE ? OR w.categorie LIKE ?)');
    const s = `%${search}%`;
    params.push(s, s, s);
  }

  const where = conditions.length ? 'WHERE ' + conditions.join(' AND ') : '';

  return await query(`
    SELECT w.*, 
           u.nom as auteur_nom, u.prenom as auteur_prenom
    FROM wiki_articles w
    JOIN auth_users u ON w.auteur_id = u.id
    ${where}
    ORDER BY w.updated_at DESC
  `, params);
}

async function findById(id) {
  const [article] = await query(`
    SELECT w.*, 
           u.nom as auteur_nom, u.prenom as auteur_prenom
    FROM wiki_articles w
    JOIN auth_users u ON w.auteur_id = u.id
    WHERE w.id = ?
  `, [id]);
  return article || null;
}

async function create(data, auteurId) {
  const { titre, contenu, categorie, est_public } = data;
  const result = await query(
    `INSERT INTO wiki_articles (titre, contenu, auteur_id, categorie, est_public) 
     VALUES (?, ?, ?, ?, ?)`,
    [titre, contenu, auteurId, categorie || 'Général', est_public !== undefined ? est_public : 0]
  );
  return result.insertId;
}

async function update(id, data) {
  const fields = Object.keys(data).map(k => `${k} = ?`).join(', ');
  await query(`UPDATE wiki_articles SET ${fields} WHERE id = ?`, [...Object.values(data), id]);
}

async function remove(id) {
  await query('DELETE FROM wiki_articles WHERE id = ?', [id]);
}

// ─── Pièces Jointes ───────────────────────────────────
async function findAttachments(articleId) {
  return await query(`
    SELECT wa.*, 
           u.nom as uploader_nom, u.prenom as uploader_prenom
    FROM wiki_attachments wa
    JOIN auth_users u ON wa.uploaded_by = u.id
    WHERE wa.article_id = ?
    ORDER BY wa.created_at DESC
  `, [articleId]);
}

async function findAttachmentById(id) {
  const [row] = await query(`
    SELECT wa.*, 
           u.nom as uploader_nom, u.prenom as uploader_prenom
    FROM wiki_attachments wa
    JOIN auth_users u ON wa.uploaded_by = u.id
    WHERE wa.id = ?
  `, [id]);
  return row || null;
}

async function createAttachment({ article_id, nom_fichier, nom_original, chemin, taille, type_mime, uploaded_by }) {
  const result = await query(
    `INSERT INTO wiki_attachments (article_id, nom_fichier, nom_original, chemin, taille, type_mime, uploaded_by)
     VALUES (?, ?, ?, ?, ?, ?, ?)`,
    [article_id, nom_fichier, nom_original, chemin, taille, type_mime, uploaded_by]
  );
  return result.insertId;
}

async function deleteAttachment(id) {
  await query('DELETE FROM wiki_attachments WHERE id = ?', [id]);
}

module.exports = {
  findAll, findById, create, update, remove,
  findAttachments, findAttachmentById, createAttachment, deleteAttachment,
};
