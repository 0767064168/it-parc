'use strict';

const { getJwtSecret } = require('../src/config/auth');

describe('authentication configuration', () => {
  const originalSecret = process.env.JWT_SECRET;

  afterEach(() => {
    if (originalSecret === undefined) {
      delete process.env.JWT_SECRET;
    } else {
      process.env.JWT_SECRET = originalSecret;
    }
  });

  test('rejects a missing JWT secret', () => {
    delete process.env.JWT_SECRET;
    expect(() => getJwtSecret()).toThrow('JWT_SECRET');
  });

  test('rejects a placeholder JWT secret', () => {
    process.env.JWT_SECRET = 'REMPLACER_PAR_UN_SECRET_ALEATOIRE_D_AU_MOINS_32_CARACTERES';
    expect(() => getJwtSecret()).toThrow('JWT_SECRET');
  });

  test('accepts a sufficiently long JWT secret', () => {
    process.env.JWT_SECRET = 'a'.repeat(64);
    expect(getJwtSecret()).toBe('a'.repeat(64));
  });
});
