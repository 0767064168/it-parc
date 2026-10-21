// ============================================
// scratch_add_imei.js
// ============================================
require('dotenv').config();
const { query } = require('./src/config/db');

async function main() {
  try {
    console.log('Ajout de la colonne imei dans la table specs...');
    // Vérifier si la colonne existe déjà
    const columns = await query("SHOW COLUMNS FROM specs LIKE 'imei'");
    if (columns.length > 0) {
      console.log('La colonne imei existe déjà.');
    } else {
      await query("ALTER TABLE specs ADD COLUMN imei VARCHAR(50) DEFAULT NULL AFTER mac_address");
      console.log('Colonne imei ajoutée avec succès !');
    }
  } catch (err) {
    console.error('Erreur lors de l\'ajout de la colonne imei :', err);
  } finally {
    process.exit();
  }
}

main();
