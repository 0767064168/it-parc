'use strict';

const mockExecute = jest.fn();
const mockQuery = jest.fn();

jest.mock('../src/config/db', () => ({
  query: (...args) => mockQuery(...args),
  transaction: (callback) => callback({ execute: mockExecute }),
}));

jest.mock('../src/utils/logger', () => ({
  info: jest.fn(),
  warn: jest.fn(),
  error: jest.fn(),
}));

const { update } = require('../src/controllers/affectation.controller');

describe('update affectation', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  test('updates the assigned user profile and assignment fields', async () => {
    mockQuery.mockResolvedValueOnce([{ id: 12, asset_id: 8, user_id: 7, actif: 1 }]);
    const req = {
      params: { id: '12' },
      body: {
        user_id: 7,
        nom: 'DUPONT',
        prenom: 'Jean',
        departement: 'IT',
        site: 'Bouaké',
        date_attribution: '2026-11-23',
        motif: 'Réaffectation',
        actif: true,
      },
    };
    const res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn().mockReturnThis(),
    };

    await update(req, res);

    expect(mockExecute).toHaveBeenNthCalledWith(
      1,
      expect.stringContaining('UPDATE utilisateurs'),
      ['DUPONT', 'Jean', 'IT', 'Bouaké', 7],
    );
    expect(mockExecute).toHaveBeenNthCalledWith(
      2,
      expect.stringContaining('UPDATE affectations SET'),
      [7, '2026-11-23', 'Réaffectation', 1, 12],
    );
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      message: 'Affectation mise à jour',
    }));
  });
});
