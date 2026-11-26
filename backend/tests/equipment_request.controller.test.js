'use strict';

jest.mock('../src/models/equipment_request.model', () => ({
  findAll: jest.fn(),
  findAvailableAssets: jest.fn(),
  create: jest.fn(),
  changeStatus: jest.fn(),
}));

jest.mock('../src/utils/logger', () => ({
  error: jest.fn(),
}));

const EquipmentRequestModel = require('../src/models/equipment_request.model');
const EquipmentRequestController = require('../src/controllers/equipment_request.controller');

function mockRes() {
  return {
    status: jest.fn().mockReturnThis(),
    json: jest.fn().mockReturnThis(),
  };
}

describe('equipment request controller', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  test('shows all requests to IT staff and only own requests to other users', async () => {
    EquipmentRequestModel.findAll.mockResolvedValue([]);

    await EquipmentRequestController.list({ user: { id: 5, role: 'lecteur' } }, mockRes());
    await EquipmentRequestController.list({ user: { id: 2, role: 'technicien' } }, mockRes());

    expect(EquipmentRequestModel.findAll).toHaveBeenNthCalledWith(1, {
      requesterId: 5,
      includeAll: false,
    });
    expect(EquipmentRequestModel.findAll).toHaveBeenNthCalledWith(2, {
      requesterId: 2,
      includeAll: true,
    });
  });

  test('creates a request for the authenticated requester', async () => {
    EquipmentRequestModel.create.mockResolvedValue({ id: 11 });
    const res = mockRes();

    await EquipmentRequestController.create({
      user: { id: 5 },
      body: { category: 'ecran', description: '24 pouces', justification: 'Besoin de travailler', priority: 'moyenne' },
    }, res);

    expect(EquipmentRequestModel.create).toHaveBeenCalledWith({
      requesterId: 5,
      category: 'ecran',
      description: '24 pouces',
      justification: 'Besoin de travailler',
      priority: 'moyenne',
    });
    expect(res.status).toHaveBeenCalledWith(201);
  });

  test('returns a conflict when the selected asset is no longer available', async () => {
    EquipmentRequestModel.changeStatus.mockResolvedValue({ error: 'asset_unavailable' });
    const res = mockRes();

    await EquipmentRequestController.changeStatus({
      params: { id: '11' },
      body: { status: 'livree', asset_id: '24' },
      user: { id: 2 },
    }, res);

    expect(EquipmentRequestModel.changeStatus).toHaveBeenCalledWith({
      id: 11,
      status: 'livree',
      reviewerId: 2,
      comment: undefined,
      assetId: 24,
    });
    expect(res.status).toHaveBeenCalledWith(409);
  });
});
