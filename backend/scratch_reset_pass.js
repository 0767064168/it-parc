'use strict';
const bcrypt = require('bcrypt');
const { query } = require('./src/config/db');

(async () => {
  try {
    const password = process.env.ADMIN_PASSWORD;
    if (!password || password.length < 12) {
      throw new Error('ADMIN_PASSWORD doit contenir au moins 12 caractères');
    }
    const hash = await bcrypt.hash(password, 12);
    await query('UPDATE auth_users SET password_hash = ? WHERE username = ?', [hash, 'admin']);
    console.log('✅ Mot de passe administrateur réinitialisé');
    process.exit(0);
  } catch (err) {
    console.error('❌ Erreur:', err);
    process.exit(1);
  }
})();
