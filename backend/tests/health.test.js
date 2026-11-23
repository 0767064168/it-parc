'use strict';

const originalVercel = process.env.VERCEL;
process.env.VERCEL = '1';

jest.mock('../src/config/db', () => ({
  query: jest.fn(),
  transaction: jest.fn(),
  testConnection: jest.fn(),
}));

jest.mock('../src/utils/logger', () => ({
  error: jest.fn(),
  http: jest.fn(),
  info: jest.fn(),
  warn: jest.fn(),
}));

jest.mock('express-rate-limit', () => jest.fn(() => (_req, _res, next) => next()));
jest.mock('socket.io', () => ({
  Server: class {
    on() {}
  },
}));

const request = require('supertest');
const { testConnection } = require('../src/config/db');
const logger = require('../src/utils/logger');
const app = require('../server');

describe('health endpoint', () => {
  afterAll(() => {
    if (originalVercel === undefined) {
      delete process.env.VERCEL;
    } else {
      process.env.VERCEL = originalVercel;
    }
  });

  beforeEach(() => {
    jest.clearAllMocks();
  });

  test('hides database errors from the response and logs the failure', async () => {
    const databaseError = new Error('timeout exceeded when trying to connect');
    testConnection.mockRejectedValueOnce(databaseError);

    const response = await request(app).get('/api/health');

    expect(response.status).toBe(503);
    expect(response.body).toEqual({
      success: false,
      status: 'DB_ERROR',
      error: 'Base de données indisponible',
    });
    expect(logger.error).toHaveBeenCalledWith('Erreur de santé DB:', databaseError);
  });
});
