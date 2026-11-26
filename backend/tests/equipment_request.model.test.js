'use strict';

jest.mock('../src/config/db', () => ({
  query: jest.fn(),
  transaction: jest.fn(),
}));

const { query, transaction } = require('../src/config/db');
const EquipmentRequestModel = require('../src/models/equipment_request.model');

describe('equipment request model', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  test('limits requester results to their own requests', async () => {
    query.mockResolvedValue([]);

    await EquipmentRequestModel.findAll({ requesterId: 7, includeAll: false });

    expect(query).toHaveBeenCalledWith(
      expect.stringContaining('WHERE r.requester_id = ?'),
      [7]
    );
  });

  test('creates an audited request for the active account', async () => {
    query
      .mockResolvedValueOnce([{
        id: 7,
        username: 'j.dupont',
        nom: 'Dupont',
        prenom: 'Jean',
      }])
      .mockResolvedValueOnce([{ id: 17, status: 'soumise' }]);
    const execute = jest.fn()
      .mockResolvedValueOnce([{ insertId: 17 }])
      .mockResolvedValueOnce([{ insertId: 18 }]);
    transaction.mockImplementation((callback) => callback({ execute }));

    const created = await EquipmentRequestModel.create({
      requesterId: 7,
      category: 'ecran',
      description: '24 pouces',
      justification: 'Écran nécessaire au poste',
      priority: 'moyenne',
    });

    expect(created).toEqual({ id: 17, status: 'soumise' });
    expect(execute).toHaveBeenNthCalledWith(
      1,
      expect.stringContaining('INSERT INTO equipment_requests'),
      [7, 'Jean Dupont', 'j.dupont', 'ecran', '24 pouces', 'Écran nécessaire au poste', 'moyenne']
    );
    expect(execute).toHaveBeenNthCalledWith(
      2,
      expect.stringContaining('CAST(? AS JSONB)'),
      [7, 'REQUEST_CREATE', 'equipment_request', 17, JSON.stringify({ category: 'ecran', priority: 'moyenne' })]
    );
  });

  test('rejects invalid status transitions without updating the request', async () => {
    const execute = jest.fn().mockResolvedValueOnce([[
      { id: 8, status: 'refusee', asset_id: null, affectation_id: null, requester_id: 7 },
    ]]);
    transaction.mockImplementation((callback) => callback({ execute }));

    const result = await EquipmentRequestModel.changeStatus({
      id: 8,
      status: 'approuvee',
      reviewerId: 2,
      comment: null,
      assetId: null,
    });

    expect(result).toEqual({ error: 'invalid_transition' });
    expect(execute).toHaveBeenCalledTimes(1);
  });

  test('links an available asset and creates an assignment on delivery', async () => {
    const execute = jest.fn()
      .mockResolvedValueOnce([[
        { id: 8, status: 'approuvee', asset_id: null, affectation_id: null, requester_id: 7 },
      ]])
      .mockResolvedValueOnce([[{ id: 21 }]])
      .mockResolvedValueOnce([[]])
      .mockResolvedValueOnce([[
        { id: 7, username: 'j.dupont', nom: 'Dupont', prenom: 'Jean', email: 'jean@example.test' },
      ]])
      .mockResolvedValueOnce([[]])
      .mockResolvedValueOnce([[]])
      .mockResolvedValueOnce([{ insertId: 33 }])
      .mockResolvedValueOnce([{ insertId: 44 }])
      .mockResolvedValueOnce([[]])
      .mockResolvedValueOnce([[]])
      .mockResolvedValueOnce([{ insertId: 99 }]);
    transaction.mockImplementation((callback) => callback({ execute }));

    const result = await EquipmentRequestModel.changeStatus({
      id: 8,
      status: 'livree',
      reviewerId: 2,
      comment: 'Matériel remis',
      assetId: 21,
    });

    expect(result).toEqual({ status: 'livree', asset_id: 21, affectation_id: 44 });
    expect(execute).toHaveBeenCalledWith(
      expect.stringContaining('INSERT INTO affectations'),
      [21, 33, 'Demande matériel #8']
    );
    expect(execute).toHaveBeenCalledWith(
      expect.stringContaining('SET status = ?, reviewer_id = ?'),
      ['livree', 2, 'Matériel remis', 21, 44, 8]
    );
  });
});
