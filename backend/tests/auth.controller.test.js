'use strict';

jest.mock('../src/config/db', () => ({
  query: jest.fn(),
}));

jest.mock('../src/utils/logger', () => ({
  info: jest.fn(),
  warn: jest.fn(),
  error: jest.fn(),
}));

const { query } = require('../src/config/db');
const logger = require('../src/utils/logger');
const { login } = require('../src/controllers/auth.controller');

describe('login error handling', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  test('returns a generic error while logging the database failure', async () => {
    const databaseError = new Error('timeout exceeded when trying to connect');
    query.mockRejectedValueOnce(databaseError);
    const req = {
      body: { username: 'admin', password: 'password' },
      ip: '127.0.0.1',
    };
    const res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn().mockReturnThis(),
    };

    await login(req, res);

    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith({
      success: false,
      message: 'Erreur lors de la connexion',
    });
    expect(logger.error).toHaveBeenCalledWith('Erreur login:', databaseError);
  });
});
