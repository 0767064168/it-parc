'use strict';

require('dotenv').config();
const mysql = require('mysql2/promise');
const { Client } = require('pg');

const BATCH_SIZE = 250;
const TABLES = [
  'utilisateurs',
  'assets',
  'auth_users',
  'specs',
  'affectations',
  'securite',
  'couts',
  'activity_logs',
  'sla_config',
  'tickets',
  'ticket_commentaires',
  'ticket_historique',
  'ticket_pieces_jointes',
  'ticket_evaluations',
  'in_app_notifications',
  'licences',
  'licence_allocations',
  'consommables',
  'maintenances',
  'wiki_articles',
  'wiki_attachments',
  'asset_attachments',
];

async function migrateData() {
  const mysqlUrl = process.env.MYSQL_SOURCE_URL;
  const postgresUrl = process.env.SUPABASE_DB_URL || process.env.DATABASE_URL;
  if (!mysqlUrl || !postgresUrl) {
    throw new Error('MYSQL_SOURCE_URL and SUPABASE_DB_URL are required to migrate data.');
  }

  const source = await mysql.createConnection(mysqlUrl);
  const target = new Client({
    connectionString: postgresUrl,
    ssl: process.env.DB_SSL === 'false' ? false : { rejectUnauthorized: true },
    connectionTimeoutMillis: 10000,
  });

  try {
    await target.connect();

    const availableTables = [];
    for (const table of TABLES) {
      const [sourceTables] = await source.query(
        'SELECT COUNT(*) AS table_count FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = ?',
        [table]
      );
      if (sourceTables[0].table_count === 0) {
        console.log(`Table absente de MySQL, ignorée: ${table}`);
        continue;
      }

      const [sourceColumns] = await source.query(
        'SELECT column_name FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = ?',
        [table]
      );
      const targetColumns = await target.query(
        'SELECT column_name FROM information_schema.columns WHERE table_schema = current_schema() AND table_name = $1',
        [table]
      );
      if (targetColumns.rowCount === 0) {
        throw new Error(`La table Supabase "${table}" est absente. Exécutez d'abord npm run migrate.`);
      }

      const targetColumnNames = new Set(targetColumns.rows.map((row) => row.column_name));
      const unsupportedColumns = sourceColumns
        .map((row) => row.COLUMN_NAME || row.column_name)
        .filter((column) => !targetColumnNames.has(column));
      if (unsupportedColumns.length > 0) {
        throw new Error(`Colonnes MySQL absentes de Supabase pour "${table}": ${unsupportedColumns.join(', ')}`);
      }

      availableTables.push(table);
    }

    for (const table of availableTables) {
      let lastId = 0;
      let copied = 0;

      while (true) {
        const [rows] = await source.query(
          `SELECT * FROM \`${table}\` WHERE id > ? ORDER BY id ASC LIMIT ?`,
          [lastId, BATCH_SIZE]
        );
        if (rows.length === 0) break;

        const columns = Object.keys(rows[0]);
        const values = [];
        const tuples = rows.map((row, rowIndex) => {
          const placeholders = columns.map((column, columnIndex) => {
            values.push(row[column]);
            return `$${rowIndex * columns.length + columnIndex + 1}`;
          });
          return `(${placeholders.join(', ')})`;
        });
        const quotedColumns = columns.map((column) => `"${column.replace(/"/g, '""')}"`);

        await target.query(
          `INSERT INTO "${table}" (${quotedColumns.join(', ')}) VALUES ${tuples.join(', ')} ON CONFLICT ("id") DO NOTHING`,
          values
        );

        lastId = rows[rows.length - 1].id;
        copied += rows.length;
      }

      await target.query(
        `SELECT setval(pg_get_serial_sequence($1, 'id'), COALESCE(MAX(id), 1), MAX(id) IS NOT NULL) FROM "${table}"`,
        [table]
      );
      console.log(`${table}: ${copied} ligne(s) source traitée(s)`);
    }

    console.log('Transfert terminé. Les lignes existantes dans Supabase n’ont pas été remplacées.');
  } finally {
    await Promise.all([source.end(), target.end()]);
  }
}

migrateData().catch((err) => {
  console.error('Erreur de transfert MySQL vers Supabase:', err.message);
  process.exitCode = 1;
});
