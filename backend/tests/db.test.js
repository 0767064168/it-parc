'use strict';

process.env.SUPABASE_DB_URL = 'postgresql://postgres:password@localhost:5432/test';

const { convertMysqlSql, sanitizeParams } = require('../src/config/db');

describe('MySQL to PostgreSQL query conversion', () => {
  test('converts placeholders and quoted identifiers without changing values', () => {
    expect(convertMysqlSql(
      'SELECT a.`Nom Machine` FROM assets a WHERE a.id = ? AND a.statut = "en_service"'
    )).toBe(
      `SELECT a."Nom Machine" FROM assets a WHERE a.id = $1 AND a.statut = 'en_service'`
    );
  });

  test('preserves MySQL escaped newlines in quoted string values', () => {
    expect(convertMysqlSql('SELECT "first\\nsecond"')).toBe("SELECT 'first\nsecond'");
  });

  test('converts date helpers used by the dashboard queries', () => {
    expect(convertMysqlSql(
      "SELECT DATE_FORMAT(created_at, '%Y-%m'), DATEDIFF(fin_garantie, CURDATE()), DATE_ADD(CURDATE(), INTERVAL 90 DAY)"
    )).toBe(
      "SELECT to_char(created_at, 'YYYY-MM'), ((fin_garantie)::date - (CURRENT_DATE)::date), (CURRENT_DATE + INTERVAL '90 days')"
    );
  });

  test('converts MySQL upserts to the table unique key', () => {
    expect(convertMysqlSql(
      'INSERT INTO specs (asset_id, ram) VALUES (?, ?) ON DUPLICATE KEY UPDATE ram=VALUES(ram)'
    )).toBe(
      'INSERT INTO specs (asset_id, ram) VALUES ($1, $2) ON CONFLICT (asset_id) DO UPDATE SET ram=EXCLUDED.ram'
    );
  });

  test('converts boolean parameters to the smallint values used by the schema', () => {
    expect(sanitizeParams([true, false, undefined])).toEqual([1, 0, null]);
  });
});
