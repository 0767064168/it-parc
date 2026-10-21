'use strict';
const bcrypt = require('bcrypt');
const { query } = require('./src/config/db');

(async () => {
  try {
    const hash = await bcrypt.hash('admin123', 10);
    await query('UPDATE auth_users SET password_hash = ? WHERE username = ?', [hash, 'admin']);
    console.log('✅ Mot de passe admin réinitialisé à "admin123" dans la base de données');
    process.exit(0);
  } catch (err) {
    console.error('❌ Erreur:', err);
    process.exit(1);
  }
})();
