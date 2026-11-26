'use strict';

const EquipmentRequestModel = require('../models/equipment_request.model');
const { success, error } = require('../utils/response');
const logger = require('../utils/logger');

async function list(req, res) {
  try {
    const includeAll = ['admin', 'technicien'].includes(req.user.role);
    const requests = await EquipmentRequestModel.findAll({
      requesterId: req.user.id,
      includeAll,
    });
    return success(res, requests);
  } catch (err) {
    logger.error('Erreur list equipment requests:', err);
    return error(res, 'Impossible de récupérer les demandes de matériel', 500);
  }
}

async function listAvailableAssets(req, res) {
  try {
    const assets = await EquipmentRequestModel.findAvailableAssets();
    return success(res, assets);
  } catch (err) {
    logger.error('Erreur list available request assets:', err);
    return error(res, 'Impossible de récupérer le matériel disponible', 500);
  }
}

async function create(req, res) {
  try {
    const created = await EquipmentRequestModel.create({
      requesterId: req.user.id,
      category: req.body.category,
      description: req.body.description,
      justification: req.body.justification,
      priority: req.body.priority || 'moyenne',
    });
    if (!created) return error(res, 'Compte utilisateur introuvable ou désactivé', 404);
    return success(res, created, 'Demande de matériel envoyée', 201);
  } catch (err) {
    logger.error('Erreur création demande de matériel:', err);
    return error(res, 'Impossible de créer la demande de matériel', 500);
  }
}

async function changeStatus(req, res) {
  try {
    const result = await EquipmentRequestModel.changeStatus({
      id: Number(req.params.id),
      status: req.body.status,
      reviewerId: req.user.id,
      comment: req.body.comment,
      assetId: req.body.asset_id === undefined ? null : Number(req.body.asset_id),
    });
    if (result.error === 'not_found') return error(res, 'Demande introuvable', 404);
    if (result.error === 'invalid_transition') {
      return error(res, 'Cette transition de statut n’est pas autorisée', 409);
    }
    if (result.error === 'asset_required') {
      return error(res, 'Sélectionnez un équipement disponible pour marquer la demande comme livrée', 400);
    }
    if (result.error === 'asset_unavailable') {
      return error(res, 'L’équipement sélectionné n’est plus disponible en stock', 409);
    }
    if (result.error === 'requester_unavailable') {
      return error(res, 'Le compte du demandeur est désactivé ou introuvable', 409);
    }
    if (result.error === 'requester_ambiguous') {
      return error(res, 'Plusieurs fiches collaborateurs correspondent au demandeur; corrigez-les avant la livraison', 409);
    }
    if (result.error === 'requester_personnel_inactive') {
      return error(res, 'La fiche du demandeur est désactivée; réactivez-la avant la livraison', 409);
    }
    return success(res, result, 'Statut de la demande mis à jour');
  } catch (err) {
    logger.error('Erreur mise à jour demande de matériel:', err);
    return error(res, 'Impossible de mettre à jour la demande de matériel', 500);
  }
}

module.exports = { list, listAvailableAssets, create, changeStatus };
