'use strict';

require('dotenv').config();
const fs = require('fs');
const path = require('path');
const { Client } = require('pg');

const migrationsDir = path.join(__dirname, '../../supabase/migrations');
const fallbackSchemaPath = path.join(__dirname, '../../supabase/schema.sql');
const connectionString = process.env.SUPABASE_DB_URL || process.env.DATABASE_URL;

async function migrate() {
  if (!connectionString) {
    throw new Error('SUPABASE_DB_URL (ou DATABASE_URL) est requis pour exécuter les migrations.');
  }

  const client = new Client({
    connectionString,
    ssl: process.env.DB_SSL === 'false' ? false : { rejectUnauthorized: false },
    connectionTimeoutMillis: 10000,
  });

  try {
    console.log('Connexion à Supabase (PostgreSQL)...');
    await client.connect();

    let migrationFiles = [];
    if (fs.existsSync(migrationsDir)) {
      migrationFiles = fs.readdirSync(migrationsDir)
        .filter((file) => file.endsWith('.sql'))
        .sort();
    }

    if (migrationFiles.length > 0) {
      console.log(`Exécution de ${migrationFiles.length} migration(s) Supabase...`);
      for (const file of migrationFiles) {
        console.log(`  -> Application de ${file}...`);
        const sql = fs.readFileSync(path.join(migrationsDir, file), 'utf8');
        await client.query(sql);
      }
    } else {
      console.log('Application du schéma Supabase principal...');
      await client.query(fs.readFileSync(fallbackSchemaPath, 'utf8'));
    }

    console.log('✅ Migrations Supabase appliquées avec succès.');
  } catch (err) {
    console.error('❌ Erreur de migration Supabase:', err.message);
    process.exitCode = 1;
  } finally {
    await client.end();
  }
}

migrate();
