'use strict';

process.env.SUPABASE_DB_URL = 'postgresql://postgres:password@localhost:5432/test';

const { prepareSql, sanitizeParams } = require('../src/config/db');

describe('PostgreSQL query preparation', () => {
  test('converts placeholders and quoted identifiers without changing values', () => {
    expect(prepareSql(
      'SELECT a.`Nom Machine` FROM assets a WHERE a.id = ? AND a.statut = "en_service"'
    )).toBe(
      `SELECT a."Nom Machine" FROM assets a WHERE a.id = $1 AND a.statut = 'en_service'`
    );
  });

  test('preserves escaped newlines in double-quoted string values', () => {
    expect(prepareSql('SELECT "first\\nsecond"')).toBe("SELECT 'first\nsecond'");
  });

  test('converts LIKE to case-insensitive ILIKE', () => {
    expect(prepareSql('SELECT * FROM assets WHERE marque LIKE ?')).toBe(
      'SELECT * FROM assets WHERE marque ILIKE $1'
    );
  });

  test('converts boolean parameters to the smallint values used by the schema', () => {
    expect(sanitizeParams([true, false, undefined])).toEqual([1, 0, null]);
  });
});
