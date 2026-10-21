'use strict';
const MaintenanceModel = require('../models/maintenance.model');
const { success, error } = require('../utils/response');
const logger = require('../utils/logger');

async function list(req, res) {
  try {
    const { asset_id, search } = req.query;
    const list = await MaintenanceModel.findAll({ asset_id, search });
    return success(res, list);
  } catch (err) {
    logger.error('Erreur list maintenances:', err);
    return error(res, 'Erreur serveur', 500);
  }
}

async function getOne(req, res) {
  try {
    const id = parseInt(req.params.id);
    const maint = await MaintenanceModel.findById(id);
    if (!maint) return error(res, 'Maintenance introuvable', 404);
    return success(res, maint);
  } catch (err) {
    logger.error('Erreur getOne maintenance:', err);
    return error(res, 'Erreur serveur', 500);
  }
}

async function create(req, res) {
  try {
    const insertId = await MaintenanceModel.create(req.body);
    const created = await MaintenanceModel.findById(insertId);
    return success(res, created, 'Maintenance planifiée avec succès', 201);
  } catch (err) {
    logger.error('Erreur create maintenance:', err);
    return error(res, 'Erreur serveur', 500);
  }
}

async function update(req, res) {
  try {
    const id = parseInt(req.params.id);
    const maint = await MaintenanceModel.findById(id);
    if (!maint) return error(res, 'Maintenance introuvable', 404);

    await MaintenanceModel.update(id, req.body);
    const updated = await MaintenanceModel.findById(id);
    return success(res, updated, 'Maintenance mise à jour avec succès');
  } catch (err) {
    logger.error('Erreur update maintenance:', err);
    return error(res, 'Erreur serveur', 500);
  }
}

async function remove(req, res) {
  try {
    const id = parseInt(req.params.id);
    const maint = await MaintenanceModel.findById(id);
    if (!maint) return error(res, 'Maintenance introuvable', 404);

    await MaintenanceModel.remove(id);
    return success(res, null, 'Maintenance supprimée avec succès');
  } catch (err) {
    logger.error('Erreur remove maintenance:', err);
    return error(res, 'Erreur serveur', 500);
  }
}

module.exports = { list, getOne, create, update, remove };
