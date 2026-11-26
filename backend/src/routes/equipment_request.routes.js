'use strict';

const express = require('express');
const { body, param } = require('express-validator');
const ctrl = require('../controllers/equipment_request.controller');
const { authenticate } = require('../middlewares/auth');
const { requireRole } = require('../middlewares/roles');
const { validate } = require('../middlewares/validate');

const router = express.Router();
router.use(authenticate);

router.get('/', ctrl.list);
router.get('/available-assets', requireRole('admin', 'technicien'), ctrl.listAvailableAssets);

router.post('/', [
  body('category').isIn(['ordinateur_portable', 'ordinateur_fixe', 'ecran', 'telephone', 'accessoire', 'autre']),
  body('description').optional({ nullable: true }).isString().isLength({ max: 1000 }),
  body('justification').isString().trim().isLength({ min: 10, max: 2000 }),
  body('priority').optional().isIn(['basse', 'moyenne', 'haute']),
], validate, ctrl.create);

router.patch('/:id/status', [
  requireRole('admin', 'technicien'),
  param('id').isInt({ min: 1 }),
  body('status').isIn(['en_examen', 'approuvee', 'refusee', 'livree']),
  body('comment').optional({ nullable: true }).isString().isLength({ max: 1000 }),
  body('asset_id').optional({ nullable: true }).isInt({ min: 1 }),
], validate, ctrl.changeStatus);

module.exports = router;
