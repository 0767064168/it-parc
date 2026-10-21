'use strict';
const LicenceModel = require('../models/licence.model');
const { success, error } = require('../utils/response');
const logger = require('../utils/logger');

async function list(req, res) {
  try {
    const { search } = req.query;
    const licences = await LicenceModel.findAll({ search });
    return success(res, licences);
  } catch (err) {
    logger.error('Erreur list licences:', err);
    return error(res, 'Erreur serveur', 500);
  }
}

async function getOne(req, res) {
  try {
    const id = parseInt(req.params.id);
    const licence = await LicenceModel.findById(id);
    if (!licence) return error(res, 'Licence introuvable', 404);
    return success(res, licence);
  } catch (err) {
    logger.error('Erreur getOne licence:', err);
    return error(res, 'Erreur serveur', 500);
  }
}

async function create(req, res) {
  try {
    const insertId = await LicenceModel.create(req.body);
    const created = await LicenceModel.findById(insertId);
    return success(res, created, 'Licence créée avec succès', 201);
  } catch (err) {
    logger.error('Erreur create licence:', err);
    return error(res, 'Erreur serveur', 500);
  }
}

async function update(req, res) {
  try {
    const id = parseInt(req.params.id);
    const licence = await LicenceModel.findById(id);
    if (!licence) return error(res, 'Licence introuvable', 404);

    await LicenceModel.update(id, req.body);
    const updated = await LicenceModel.findById(id);
    return success(res, updated, 'Licence mise à jour avec succès');
  } catch (err) {
    logger.error('Erreur update licence:', err);
    return error(res, 'Erreur serveur', 500);
  }
}

async function remove(req, res) {
  try {
    const id = parseInt(req.params.id);
    const licence = await LicenceModel.findById(id);
    if (!licence) return error(res, 'Licence introuvable', 404);

    await LicenceModel.remove(id);
    return success(res, null, 'Licence supprimée avec succès');
  } catch (err) {
    logger.error('Erreur remove licence:', err);
    return error(res, 'Erreur serveur', 500);
  }
}

async function allocate(req, res) {
  try {
    const licenceId = parseInt(req.params.id);
    const { user_id } = req.body;

    const licence = await LicenceModel.findById(licenceId);
    if (!licence) return error(res, 'Licence introuvable', 404);

    // Vérification quota
    if (licence.quota_max && licence.allocations.length >= licence.quota_max) {
      return error(res, 'Quota de licence atteint pour ce logiciel.', 400);
    }

    await LicenceModel.allocate(licenceId, parseInt(user_id));
    const updated = await LicenceModel.findById(licenceId);
    return success(res, updated, 'Licence affectée avec succès');
  } catch (err) {
    logger.error('Erreur allocate licence:', err);
    return error(res, 'Erreur serveur', 500);
  }
}

async function deallocate(req, res) {
  try {
    const allocationId = parseInt(req.params.allocId);
    await LicenceModel.deallocate(allocationId);
    return success(res, null, 'Affectation de licence supprimée');
  } catch (err) {
    logger.error('Erreur deallocate licence:', err);
    return error(res, 'Erreur serveur', 500);
  }
}

module.exports = { list, getOne, create, update, remove, allocate, deallocate };
