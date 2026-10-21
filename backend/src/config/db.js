'use strict';

const { Pool, types } = require('pg');
const logger = require('../utils/logger');

const connectionString = process.env.SUPABASE_DB_URL || process.env.DATABASE_URL;

if (!connectionString) {
  throw new Error('SUPABASE_DB_URL is required to connect to the Supabase database.');
}

types.setTypeParser(types.builtins.INT8, (value) => parseInt(value, 10));

const pool = new Pool({
  connectionString,
  ssl: process.env.DB_SSL === 'false' ? false : { rejectUnauthorized: true },
  max: parseInt(process.env.DB_POOL_SIZE, 10) || 10,
  connectionTimeoutMillis: 10000,
});

pool.on('error', (err) => {
  logger.error(`Erreur inattendue du pool PostgreSQL: ${err.message}`);
});

function convertMysqlSql(sql) {
  let converted = '';
  let state = 'normal';
  let parameterIndex = 0;

  for (let i = 0; i < sql.length; i += 1) {
    const char = sql[i];
    const next = sql[i + 1];

    if (state === 'single') {
      converted += char;
      if (char === "'" && next === "'") {
        converted += next;
        i += 1;
      } else if (char === "'") {
        state = 'normal';
      }
      continue;
    }

    if (state === 'double') {
      if (char === '"') {
        converted += "'";
        state = 'normal';
      } else if (char === '\\' && next) {
        const escapedCharacters = { n: '\n', r: '\r', t: '\t', '\\': '\\', '"': '"' };
        if (Object.prototype.hasOwnProperty.call(escapedCharacters, next)) {
          converted += escapedCharacters[next];
          i += 1;
        } else {
          converted += char;
        }
      } else if (char === "'") {
        converted += "''";
      } else {
        converted += char;
      }
      continue;
    }

    if (state === 'backtick') {
      if (char === '`') {
        converted += '"';
        state = 'normal';
      } else if (char === '"') {
        converted += '""';
      } else {
        converted += char;
      }
      continue;
    }

    if (char === "'") {
      state = 'single';
      converted += char;
    } else if (char === '"') {
      state = 'double';
      converted += "'";
    } else if (char === '`') {
      state = 'backtick';
      converted += '"';
    } else if (char === '?') {
      parameterIndex += 1;
      converted += `$${parameterIndex}`;
    } else {
      converted += char;
    }
  }

  converted = converted
    .replace(/\bCURDATE\s*\(\s*\)/gi, 'CURRENT_DATE')
    .replace(/\bIFNULL\s*\(/gi, 'COALESCE(')
    .replace(/\bLIKE\b/gi, 'ILIKE')
    .replace(/DATE_ADD\(\s*CURRENT_DATE\s*,\s*INTERVAL\s+(\d+)\s+DAY\s*\)/gi, "(CURRENT_DATE + INTERVAL '$1 days')")
    .replace(/DATE_FORMAT\(\s*([^,()]+)\s*,\s*'%Y-%m'\s*\)/gi, "to_char($1, 'YYYY-MM')")
    .replace(/DATEDIFF\(\s*([^,()]+)\s*,\s*([^()]+)\)/gi, '(($1)::date - ($2)::date)');

  const insert = converted.match(/\bINSERT\s+INTO\s+("?[\w]+"?)/i);
  const conflictColumns = {
    assets: '"Nom Machine"',
    specs: 'asset_id',
    securite: 'asset_id',
    couts: 'asset_id',
  };
  const table = insert && insert[1].replace(/"/g, '').toLowerCase();
  const conflictColumn = conflictColumns[table];

  converted = converted.replace(
    /\s+ON DUPLICATE KEY UPDATE\s+([\s\S]*)$/i,
    (_, assignments) => {
      if (!conflictColumn) {
        throw new Error(`PostgreSQL conflict target is not configured for ${table || 'this table'}.`);
      }
      const postgresAssignments = assignments.replace(
        /\bVALUES\s*\(\s*([a-zA-Z_][\w]*)\s*\)/gi,
        'EXCLUDED.$1'
      );
      return ` ON CONFLICT (${conflictColumn}) DO UPDATE SET ${postgresAssignments}`;
    }
  );

  return converted;
}

function sanitizeParams(params) {
  return params.map((value) => {
    if (value === undefined) return null;
    if (typeof value === 'boolean') return value ? 1 : 0;
    return value;
  });
}

function toMysqlResult(result) {
  return {
    insertId: result.rows[0] ? result.rows[0].id : undefined,
    affectedRows: result.rowCount,
    rows: result.rows,
  };
}

async function testConnection() {
  await pool.query('SELECT 1');
  return true;
}

async function query(sql, params = []) {
  try {
    let postgresSql = convertMysqlSql(sql);
    if (/^\s*INSERT\b/i.test(postgresSql) && !/\bRETURNING\b/i.test(postgresSql)) {
      postgresSql += ' RETURNING id';
    }

    const result = await pool.query(postgresSql, sanitizeParams(params));
    if (/^\s*(SELECT|WITH)\b/i.test(postgresSql)) return result.rows;
    return toMysqlResult(result);
  } catch (err) {
    logger.error(`DB Error: ${err.message}\nSQL: ${sql}\nParams: ${JSON.stringify(params)}`);
    throw err;
  }
}

async function transaction(callback) {
  const client = await pool.connect();
  const conn = {
    async execute(sql, params = []) {
      let postgresSql = convertMysqlSql(sql);
      const isInsert = /^\s*INSERT\b/i.test(postgresSql);
      if (isInsert && !/\bRETURNING\b/i.test(postgresSql)) {
        postgresSql += ' RETURNING id';
      }

      const result = await client.query(postgresSql, sanitizeParams(params));
      return isInsert ? [toMysqlResult(result)] : [result.rows];
    },
  };

  try {
    await client.query('BEGIN');
    const result = await callback(conn);
    await client.query('COMMIT');
    return result;
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

module.exports = { pool, query, transaction, testConnection, convertMysqlSql, sanitizeParams };
