'use strict';

require('dotenv').config();
const fs = require('fs');
const path = require('path');
const { Client } = require('pg');

const seedPath = path.join(__dirname, '../../supabase/seed.sql');
const connectionString = process.env.SUPABASE_DB_URL || process.env.DATABASE_URL;

async function seed() {
  if (!connectionString) {
    throw new Error('SUPABASE_DB_URL (ou DATABASE_URL) est requis pour initialiser les données.');
  }

  const client = new Client({
    connectionString,
    ssl: process.env.DB_SSL === 'false' ? false : { rejectUnauthorized: true },
    connectionTimeoutMillis: 10000,
  });

  try {
    console.log('Connexion à Supabase (PostgreSQL)...');
    await client.connect();
    console.log('Application des données initiales (seed.sql)...');
    await client.query(fs.readFileSync(seedPath, 'utf8'));
    console.log('✅ Données de démonstration Supabase appliquées avec succès.');
  } catch (err) {
    console.error('❌ Erreur lors du seeding Supabase:', err.message);
    process.exitCode = 1;
  } finally {
    await client.end();
  }
}

seed();
