'use strict';

require('dotenv').config();
const fs = require('fs');
const path = require('path');
const { Client } = require('pg');

const schemaPath = path.join(__dirname, '../../supabase/schema.sql');
const connectionString = process.env.SUPABASE_DB_URL || process.env.DATABASE_URL;

async function migrate() {
  if (!connectionString) {
    throw new Error('SUPABASE_DB_URL is required to run the Supabase schema.');
  }

  const client = new Client({
    connectionString,
    ssl: process.env.DB_SSL === 'false' ? false : { rejectUnauthorized: true },
    connectionTimeoutMillis: 10000,
  });

  try {
    console.log('Connexion à Supabase (PostgreSQL)...');
    await client.connect();
    await client.query(fs.readFileSync(schemaPath, 'utf8'));
    console.log('Schéma Supabase appliqué avec succès.');
  } catch (err) {
    console.error('Erreur de migration Supabase:', err.message);
    process.exitCode = 1;
  } finally {
    await client.end();
  }
}

migrate();
