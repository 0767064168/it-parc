'use strict';

require('dotenv').config();
const fs = require('fs');
const path = require('path');
const { Client } = require('pg');

const schemaPath = path.join(__dirname, '../../supabase/schema.sql');
const connectionString = process.env.DATABASE_URL || process.env.SUPABASE_DB_URL;

async function migrate() {
  if (!connectionString) {
    throw new Error('DATABASE_URL (local PostgreSQL) or SUPABASE_DB_URL is required to run the schema.');
  }

  const client = new Client({
    connectionString,
    ssl: process.env.DB_SSL === 'false' ? false : { rejectUnauthorized: true },
    connectionTimeoutMillis: 10000,
  });

  try {
    console.log('Connexion à PostgreSQL...');
    await client.connect();
    await client.query(fs.readFileSync(schemaPath, 'utf8'));
    console.log('Schéma PostgreSQL appliqué avec succès.');
  } catch (err) {
    console.error('Erreur de migration PostgreSQL:', err.message);
    process.exitCode = 1;
  } finally {
    await client.end();
  }
}

migrate();
