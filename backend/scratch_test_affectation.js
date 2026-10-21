'use strict';
const { query, transaction } = require('./src/config/db');
const bcrypt = require('bcrypt');

async function main() {
  try {
    // 1) Login simulation — get a valid user to simulate req.user
    const users = await query('SELECT * FROM auth_users WHERE username = "admin" LIMIT 1');
    if (!users.length) { console.error('Admin not found'); process.exit(1); }
    const admin = users[0];

    // 2) Get a valid asset
    const assets = await query('SELECT id, `Nom Machine`, statut FROM assets LIMIT 1');
    const asset = assets[0];
    console.log('Asset:', asset.id, asset['Nom Machine']);

    // 3) Get a valid user
    const utilisateurs = await query('SELECT id, nom, prenom FROM utilisateurs LIMIT 1');
    const user = utilisateurs[0];
    console.log('User:', user.id, user.prenom, user.nom);

    // 4) Test affectation with existing user (user_id provided)
    const asset_id = asset.id;
    const user_id = user.id;
    const date_attribution = '2026-07-12';
    const motif = 'Test via script';

    await transaction(async (conn) => {
      await conn.execute(
        'UPDATE affectations SET actif = 0, date_retrait = ? WHERE asset_id = ? AND actif = 1',
        [date_attribution, asset_id]
      );
      await conn.execute(
        'INSERT INTO affectations (asset_id, user_id, date_attribution, motif, actif) VALUES (?, ?, ?, ?, 1)',
        [asset_id, user_id, date_attribution, motif]
      );
      await conn.execute(
        'UPDATE assets SET statut = "en_service", updated_at = NOW() WHERE id = ?',
        [asset_id]
      );
    });

    await query(
      'INSERT INTO activity_logs (user_id, action, entity_type, entity_id, details) VALUES (?, ?, ?, ?, ?)',
      [admin.id, 'AFFECTATION_CREATE', 'asset', asset_id, JSON.stringify({ user_id, motif })]
    );

    console.log('✅ Test 1 (utilisateur existant): OK');

    // 5) Test affectation with new user (no user_id)
    let newUserId;
    await transaction(async (conn) => {
      const [res] = await conn.execute(
        'INSERT INTO utilisateurs (nom, prenom, departement) VALUES (?, ?, ?)',
        ['TestNom', 'TestPrenom', 'IT']
      );
      newUserId = res.insertId;
      console.log('Created new user ID:', newUserId);

      await conn.execute(
        'UPDATE affectations SET actif = 0, date_retrait = ? WHERE asset_id = ? AND actif = 1',
        [date_attribution, asset_id]
      );
      await conn.execute(
        'INSERT INTO affectations (asset_id, user_id, date_attribution, motif, actif) VALUES (?, ?, ?, ?, 1)',
        [asset_id, newUserId, date_attribution, 'Nouveau collaborateur']
      );
      await conn.execute(
        'UPDATE assets SET statut = "en_service", updated_at = NOW() WHERE id = ?',
        [asset_id]
      );
    });

    console.log('✅ Test 2 (nouveau collaborateur): OK');
    process.exit(0);
  } catch (e) {
    console.error('❌ Error:', e.message);
    process.exit(1);
  }
}
main();
