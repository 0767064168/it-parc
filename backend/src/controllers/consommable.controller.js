'use strict';
const ConsommableModel = require('../models/consommable.model');
const { success, error } = require('../utils/response');
const logger = require('../utils/logger');

async function list(req, res) {
  try {
    const { search } = req.query;
    const consommables = await ConsommableModel.findAll({ search });
    return success(res, consommables);
  } catch (err) {
    logger.error('Erreur list consommables:', err);
    return error(res, 'Erreur serveur', 500);
  }
}

async function getOne(req, res) {
  try {
    const id = parseInt(req.params.id);
    const consommable = await ConsommableModel.findById(id);
    if (!consommable) return error(res, 'Consommable introuvable', 404);
    return success(res, consommable);
  } catch (err) {
    logger.error('Erreur getOne consommable:', err);
    return error(res, 'Erreur serveur', 500);
  }
}

async function create(req, res) {
  try {
    const insertId = await ConsommableModel.create(req.body);
    const created = await ConsommableModel.findById(insertId);
    return success(res, created, 'Consommable créé avec succès', 201);
  } catch (err) {
    logger.error('Erreur create consommable:', err);
    return error(res, 'Erreur serveur', 500);
  }
}

async function update(req, res) {
  try {
    const id = parseInt(req.params.id);
    const consommable = await ConsommableModel.findById(id);
    if (!consommable) return error(res, 'Consommable introuvable', 404);

    await ConsommableModel.update(id, req.body);
    const updated = await ConsommableModel.findById(id);
    return success(res, updated, 'Consommable mis à jour avec succès');
  } catch (err) {
    logger.error('Erreur update consommable:', err);
    return error(res, 'Erreur serveur', 500);
  }
}

async function remove(req, res) {
  try {
    const id = parseInt(req.params.id);
    const consommable = await ConsommableModel.findById(id);
    if (!consommable) return error(res, 'Consommable introuvable', 404);

    await ConsommableModel.remove(id);
    return success(res, null, 'Consommable supprimé avec succès');
  } catch (err) {
    logger.error('Erreur remove consommable:', err);
    return error(res, 'Erreur serveur', 500);
  }
}

async function adjustStock(req, res) {
  try {
    const id = parseInt(req.params.id);
    const { diff } = req.body; // e.g. -1 or +5

    const consommable = await ConsommableModel.findById(id);
    if (!consommable) return error(res, 'Consommable introuvable', 404);

    await ConsommableModel.adjustStock(id, parseInt(diff));
    const updated = await ConsommableModel.findById(id);

    // Si stock bas, envoyer une notification websocket
    if (updated.quantite <= updated.seuil_alerte) {
      const io = req.app.get('io');
      if (io) {
        io.emit('low_stock_warning', { 
          message: `Stock critique pour ${updated.nom} : il reste seulement ${updated.quantite} unité(s).`,
          consommable: updated 
        });
      }
    }

    return success(res, updated, 'Stock mis à jour avec succès');
  } catch (err) {
    logger.error('Erreur adjustStock:', err);
    return error(res, 'Erreur serveur', 500);
  }
}

module.exports = { list, getOne, create, update, remove, adjustStock };
