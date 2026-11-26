'use strict';

jest.mock('../src/config/db', () => ({
  query: jest.fn(),
  transaction: jest.fn(),
}));

jest.mock('../src/utils/logger', () => ({
  info: jest.fn(),
  warn: jest.fn(),
  error: jest.fn(),
  http: jest.fn(),
}));

jest.mock('../src/services/email.service', () => ({
  sendMail: jest.fn().mockResolvedValue(true),
  sendNewTicketAlert: jest.fn().mockResolvedValue(true),
  sendExpiringAlertsDigest: jest.fn().mockResolvedValue(true),
}));

const { query } = require('../src/config/db');
const auditCtrl = require('../src/controllers/audit.controller');
const logsCtrl = require('../src/controllers/logs.controller');
const dashboardCtrl = require('../src/controllers/dashboard.controller');
const settingsCtrl = require('../src/controllers/settings.controller');
const assetCtrl = require('../src/controllers/asset.controller');
const { PERMISSIONS } = require('../src/middlewares/roles');

function mockRes() {
  return {
    status: jest.fn().mockReturnThis(),
    json: jest.fn().mockReturnThis(),
  };
}

describe('Nouveaux modules DSI (Audits, Logs, Mon Espace, Paramètres, Amortissement)', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  test('audit.createCampagne rejette un titre vide (400)', async () => {
    query.mockResolvedValue([]);
    const req = { body: { titre: '   ' }, user: { username: 'admin' } };
    const res = mockRes();

    await auditCtrl.createCampagne(req, res);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({ success: false }));
  });

  test('audit.recordScan détecte une anomalie de site', async () => {
    query
      .mockResolvedValueOnce([{ id: 1, titre: 'Audit Bouaké', site: 'Bouaké' }]) // campagne
      .mockResolvedValueOnce([{ id: 10, asset_tag: 'PC-010', site: 'Abidjan' }]) // asset found on Abidjan
      .mockResolvedValueOnce([]); // insert scan

    const req = {
      params: { id: '1' },
      body: { code: 'PC-010', site_constate: 'Bouaké' },
      user: { username: 'tech' },
    };
    const res = mockRes();

    await auditCtrl.recordScan(req, res);
    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      data: expect.objectContaining({
        asset_tag: 'PC-010',
        conforme: false,
        site_theorique: 'Abidjan',
        site_scanne: 'Bouaké',
      }),
    }));
  });

  test('logs.getLogStats retourne les statistiques agrégées', async () => {
    query
      .mockResolvedValueOnce([{ total: 42 }])
      .mockResolvedValueOnce([{ count: 7 }])
      .mockResolvedValueOnce([{ action: 'AFFECTATION_CREATE', count: 15 }])
      .mockResolvedValueOnce([{ entity_type: 'asset', count: 20 }]);

    const res = mockRes();
    await logsCtrl.getLogStats({}, res);

    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      data: expect.objectContaining({
        total: 42,
        last_24h: 7,
      }),
    }));
  });

  test('dashboard.getAmortissement calcule VNC et budget N+1', async () => {
    query.mockResolvedValueOnce([
      { id: 1, asset_tag: 'PC-NEW', type: 'laptop', statut: 'en_service', prix: 600000, date_acquisition: new Date().toISOString().split('T')[0] },
      { id: 2, asset_tag: 'PC-OLD', type: 'laptop', statut: 'en_service', prix: 500000, date_acquisition: '2020-01-01' },
    ]);

    const res = mockRes();
    await dashboardCtrl.getAmortissement({}, res);

    expect(res.status).toHaveBeenCalledWith(200);
    const payload = res.json.mock.calls[0][0];
    expect(payload.success).toBe(true);
    expect(payload.data.nb_machines_total).toBe(2);
    expect(payload.data.nb_machines_amorties).toBe(1);
    expect(payload.data.budget_previsionnel_n1).toBe(500000);
  });

  test('dashboard.reportMonIncident valide les champs obligatoires (400)', async () => {
    const req = { body: { titre: '', description: '' }, user: { id: 1 } };
    const res = mockRes();

    await dashboardCtrl.reportMonIncident(req, res);
    expect(res.status).toHaveBeenCalledWith(400);
  });

  test('settings.getSettings retourne les valeurs par défaut + surcharges DB', async () => {
    query.mockResolvedValue([]);
    query.mockResolvedValueOnce([]); // CREATE TABLE
    query.mockResolvedValueOnce([{ cle: 'amortissement_mois', valeur: '48' }]);

    const res = mockRes();
    await settingsCtrl.getSettings({}, res);

    expect(res.status).toHaveBeenCalledWith(200);
    const payload = res.json.mock.calls[0][0];
    expect(payload.data.settings.amortissement_mois).toBe('48');
    expect(payload.data.settings.devise).toBe('XOF');
  });

  test('settings.sendTestEmail exécute le test en mode simulation', async () => {
    const req = { body: { email: 'test@bouake.ci' }, user: { username: 'admin' } };
    const res = mockRes();

    await settingsCtrl.sendTestEmail(req, res);
    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      data: expect.objectContaining({ sent: true, to: 'test@bouake.ci' }),
    }));
  });

  test('les techniciens peuvent archiver et supprimer des équipements', () => {
    expect(PERMISSIONS['assets:delete']).toContain('technicien');
    expect(PERMISSIONS['assets:archive']).toContain('technicien');
  });

  test('asset.archive fonctionne sans req.body (DELETE sans payload)', async () => {
    query.mockResolvedValue([]);
    query.mockResolvedValueOnce([{ id: 42, asset_tag: 'PC-CC-IT-TEST' }]);

    const req = { params: { id: '42' }, user: { id: 1 } }; // req.body undefined
    const res = mockRes();

    await assetCtrl.archive(req, res);
    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({ success: true }));
  });

  test('asset.archive transmet le motif quand fourni', async () => {
    query.mockResolvedValue([]);
    query.mockResolvedValueOnce([{ id: 42, asset_tag: 'PC-CC-IT-TEST' }]);

    const req = { params: { id: '42' }, body: { motif: 'Matériel réformé' }, user: { id: 1 } };
    const res = mockRes();

    await assetCtrl.archive(req, res);
    expect(res.status).toHaveBeenCalledWith(200);
    expect(query).toHaveBeenCalledWith(
      expect.stringContaining('CAST(? AS TEXT)'),
      ['reforme', 'Matériel réformé', 42]
    );
  });

  test('asset.restore restaure un équipement archivé en stock', async () => {
    query.mockResolvedValue([]);
    query.mockResolvedValueOnce([{ id: 42, asset_tag: 'PC-CC-IT-TEST', deleted_at: '2026-11-20' }]);

    const req = { params: { id: '42' }, user: { id: 1 } };
    const res = mockRes();

    await assetCtrl.restore(req, res);
    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({ success: true }));
    expect(query).toHaveBeenCalledWith(
      expect.stringContaining("UPDATE assets SET deleted_at = NULL, statut = 'en_stock'"),
      [42]
    );
  });

  test('asset.restore rejette un équipement non archivé (400)', async () => {
    query.mockResolvedValue([]);
    query.mockResolvedValueOnce([{ id: 42, asset_tag: 'PC-CC-IT-TEST', deleted_at: null }]);

    const req = { params: { id: '42' }, user: { id: 1 } };
    const res = mockRes();

    await assetCtrl.restore(req, res);
    expect(res.status).toHaveBeenCalledWith(400);
  });
});
