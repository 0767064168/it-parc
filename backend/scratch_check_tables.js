'use strict';
const { query } = require('./src/config/db');

async function main() {
  try {
    // Describe activity_logs
    const cols = await query('DESCRIBE activity_logs');
    console.log('activity_logs columns:');
    cols.forEach(c => console.log(' ', c.Field, c.Type, c.Null, c.Default));
    
    // Also get some sample assets for testing
    const assets = await query('SELECT id, `Nom Machine`, statut FROM assets LIMIT 5');
    console.log('\nSample assets:', JSON.stringify(assets));
    
    // Sample users
    const users = await query('SELECT id, nom, prenom FROM utilisateurs LIMIT 5');
    console.log('Sample users:', JSON.stringify(users));
    
    process.exit(0);
  } catch (e) {
    console.error(e.message);
    process.exit(1);
  }
}
main();
