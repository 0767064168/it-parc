-- =============================================================================
-- Supabase / PostgreSQL Seed Data — Gestionnaire de Parc IT
-- Direction IT Bouaké
-- =============================================================================

-- ── 1. Comptes d'authentification ────────────────────────────────────────────
INSERT INTO auth_users (id, username, password_hash, role, nom, prenom, email, actif) VALUES
(1, 'admin',      '$2b$10$l1DTvXEMQTEBJEKRjM482eGa0hhm.I7FYWfJI3OwAt.4uzjI0cDQ.', 'admin',      'KONAN',   'Directeur IT', 'k.konan@entreprise.ci', 1),
(2, 'technicien', '$2b$10$U3/3AkhBUOcKqwJ3mmhwFOpr0Ws.nj9F4c99/7ORyXZvqN7ZktXFy', 'technicien', 'KOUASSI', 'Technicien',   'a.kouassi@entreprise.ci', 1),
(3, 'lecteur',    '$2b$10$4sywMabX9fCARjXKXix0LeV25dMJIlKlehAzfhbcJ.O9MONxfLNNK', 'lecteur',    'BROU',    'Responsable',  'a.brou@entreprise.ci', 1)
ON CONFLICT (id) DO NOTHING;

-- ── 2. Référentiel Utilisateurs ──────────────────────────────────────────────
INSERT INTO utilisateurs (id, nom, prenom, departement, site, email, telephone, actif) VALUES
(1,  'KONAN',         'Kouadio',  'Direction IT', 'Bouaké',  'k.konan@entreprise.ci',      '+225 07 00 00 01', 1),
(2,  'KOUASSI',       'Amani',    'Direction IT', 'Bouaké',  'a.kouassi@entreprise.ci',    '+225 07 00 00 02', 1),
(3,  'BROU',          'Ahou',     'Comptabilité', 'Bouaké',  'a.brou@entreprise.ci',       '+225 07 00 00 03', 1),
(4,  'KOFFI',         'Kanga',    'Commercial',   'Bouaké',  'k.koffi@entreprise.ci',      '+225 07 00 00 04', 1),
(5,  'YEBOUA',        'Léa',      'RH',           'Bouaké',  'l.yeboua@entreprise.ci',     '+225 07 00 00 05', 1),
(6,  'DJOMAN',        'Félix',    'Logistique',   'Bouaké',  'f.djoman@entreprise.ci',     '+225 07 00 00 06', 1),
(7,  'TAPE',          'Gisèle',   'Direction',    'Bouaké',  'g.tape@entreprise.ci',       '+225 07 00 00 07', 1),
(8,  'OUATTARA',      'Ibrahim',  'Commercial',   'Abidjan', 'i.ouattara@entreprise.ci',   '+225 07 00 00 08', 1),
(9,  'N''GUESSAN',    'Aya',      'Comptabilité', 'Abidjan', 'a.nguessan@entreprise.ci',   '+225 07 00 00 09', 1),
(10, 'DIARRASSOUBA',  'Mamadou',  'Logistique',   'Azaguié', 'm.diarrassouba@entreprise.ci','+225 07 00 00 10', 1),
(11, 'COULIBALY',     'Fatou',    'Commercial',   'Katiola', 'f.coulibaly@entreprise.ci',  '+225 07 00 00 11', 1),
(12, 'TRAORE',        'Moussa',   'Logistique',   'Djeboa',  'm.traore@entreprise.ci',     '+225 07 00 00 12', 1),
(13, 'AKRE',          'Cécile',   'RH',           'Bouaké',  'c.akre@entreprise.ci',       '+225 07 00 00 13', 1),
(14, 'SORO',          'Dramane',  'Direction IT', 'Bouaké',  'd.soro@entreprise.ci',       '+225 07 00 00 14', 1),
(15, 'BAMBA',         'Aminata',  'Comptabilité', 'Bouaké',  'a.bamba@entreprise.ci',      '+225 07 00 00 15', 1)
ON CONFLICT (id) DO NOTHING;

-- ── 3. Équipements (Assets) ──────────────────────────────────────────────────
INSERT INTO assets (id, "Nom Machine", serial_number, marque, modele, type, statut, site, departement, notes) VALUES
-- Laptops (1-15)
(1,  'BKE-LT-001', 'SN-HP-001-2023',  'HP',     'EliteBook 840 G9',   'laptop', 'en_service',  'Bouaké',  'Direction IT', NULL),
(2,  'BKE-LT-002', 'SN-DEL-002-2023', 'Dell',   'Latitude 5540',      'laptop', 'en_service',  'Bouaké',  'Comptabilité', NULL),
(3,  'BKE-LT-003', 'SN-LEN-003-2022', 'Lenovo', 'ThinkPad L14 Gen3',  'laptop', 'en_service',  'Bouaké',  'Commercial',   NULL),
(4,  'BKE-LT-004', 'SN-HP-004-2023',  'HP',     'ProBook 450 G10',    'laptop', 'en_service',  'Bouaké',  'RH',           NULL),
(5,  'BKE-LT-005', 'SN-DEL-005-2022', 'Dell',   'Latitude 3540',      'laptop', 'en_service',  'Bouaké',  'Logistique',   NULL),
(6,  'BKE-LT-006', 'SN-HP-006-2023',  'HP',     'EliteBook 840 G9',   'laptop', 'en_service',  'Bouaké',  'Direction',    NULL),
(7,  'BKE-LT-007', 'SN-LEN-007-2021', 'Lenovo', 'ThinkPad E15 Gen2',  'laptop', 'hors_service','Bouaké',  'Direction IT', 'Écran défaillant'),
(8,  'BKE-LT-008', 'SN-HP-008-2023',  'HP',     'ProBook 440 G10',    'laptop', 'en_service',  'Bouaké',  'Comptabilité', NULL),
(9,  'BKE-LT-009', 'SN-DEL-009-2023', 'Dell',   'Latitude 5540',      'laptop', 'en_service',  'Bouaké',  'Commercial',   NULL),
(10, 'BKE-LT-010', 'SN-HP-010-2020',  'HP',     'EliteBook 840 G6',   'laptop', 'reforme',     'Bouaké',  'Direction IT', 'Trop ancien, remplacé'),
(11, 'ABJ-LT-001', 'SN-DEL-011-2023', 'Dell',   'Latitude 5540',      'laptop', 'en_service',  'Abidjan', 'Commercial',   NULL),
(12, 'ABJ-LT-002', 'SN-HP-012-2022',  'HP',     'EliteBook 840 G8',   'laptop', 'en_service',  'Abidjan', 'Comptabilité', NULL),
(13, 'AZG-LT-001', 'SN-LEN-013-2023', 'Lenovo', 'ThinkPad L14 Gen4',  'laptop', 'en_service',  'Azaguié', 'Logistique',   NULL),
(14, 'KAT-LT-001', 'SN-HP-014-2022',  'HP',     'ProBook 450 G9',     'laptop', 'en_service',  'Katiola', 'Commercial',   NULL),
(15, 'DJE-LT-001', 'SN-DEL-015-2023', 'Dell',   'Latitude 3540',      'laptop', 'en_service',  'Djeboa',  'Logistique',   NULL),
-- Desktops (16-27)
(16, 'BKE-DT-001', 'SN-HP-D01-2022',  'HP',     'EliteDesk 800 G6',   'desktop', 'en_service',     'Bouaké', 'Direction IT', NULL),
(17, 'BKE-DT-002', 'SN-DEL-D02-2022', 'Dell',   'OptiPlex 3090',      'desktop', 'en_service',     'Bouaké', 'Comptabilité', NULL),
(18, 'BKE-DT-003', 'SN-HP-D03-2021',  'HP',     'ProDesk 400 G7',     'desktop', 'en_service',     'Bouaké', 'RH',           NULL),
(19, 'BKE-DT-004', 'SN-DEL-D04-2023', 'Dell',   'OptiPlex 5000',      'desktop', 'en_service',     'Bouaké', 'Comptabilité', NULL),
(20, 'BKE-DT-005', 'SN-HP-D05-2019',  'HP',     'EliteDesk 800 G4',   'desktop', 'hors_service',   'Bouaké', 'Logistique',   'Panne alimentation'),
(21, 'BKE-DT-006', 'SN-DEL-D06-2022', 'Dell',   'OptiPlex 3090',      'desktop', 'en_service',     'Bouaké', 'Direction',    NULL),
(22, 'BKE-DT-007', 'SN-HP-D07-2020',  'HP',     'ProDesk 400 G6',     'desktop', 'reforme',        'Bouaké', 'Direction IT', 'Remplacé 2024'),
(23, 'BKE-DT-008', 'SN-DEL-D08-2023', 'Dell',   'OptiPlex 5000',      'desktop', 'en_service',     'Bouaké', 'Commercial',   NULL),
(24, 'BKE-DT-009', 'SN-HP-D09-2022',  'HP',     'EliteDesk 800 G6',   'desktop', 'en_service',     'Bouaké', 'Comptabilité', NULL),
(25, 'BKE-DT-010', 'SN-DEL-D10-2021', 'Dell',   'OptiPlex 3090',      'desktop', 'en_maintenance', 'Bouaké', 'Direction IT', 'En réparation'),
(26, 'BKE-DT-011', 'SN-HP-D11-2023',  'HP',     'ProDesk 400 G9',     'desktop', 'en_service',     'Bouaké', 'RH',           NULL),
(27, 'BKE-DT-012', 'SN-DEL-D12-2022', 'Dell',   'OptiPlex 5000',      'desktop', 'en_service',     'Bouaké', 'Commercial',   NULL),
-- Écrans (28-39)
(28, 'BKE-EC-001', 'SN-SAM-E01-2022', 'Samsung','S24F350FHU 24"',     'ecran', 'en_service',  'Bouaké', 'Direction IT', NULL),
(29, 'BKE-EC-002', 'SN-DEL-E02-2022', 'Dell',   'P2422H 24"',         'ecran', 'en_service',  'Bouaké', 'Comptabilité', NULL),
(30, 'BKE-EC-003', 'SN-SAM-E03-2023', 'Samsung','S27A400UJU 27"',     'ecran', 'en_service',  'Bouaké', 'Direction',    NULL),
(31, 'BKE-EC-004', 'SN-HP-E04-2021',  'HP',     'V24i G5 24"',        'ecran', 'en_service',  'Bouaké', 'RH',           NULL),
(32, 'BKE-EC-005', 'SN-DEL-E05-2022', 'Dell',   'P2222H 22"',         'ecran', 'en_service',  'Bouaké', 'Commercial',   NULL),
(33, 'BKE-EC-006', 'SN-SAM-E06-2020', 'Samsung','S22F350FH 22"',      'ecran', 'hors_service','Bouaké', 'Direction IT', NULL),
(34, 'BKE-EC-007', 'SN-LG-E07-2023',  'LG',     '24MK430H-B 24"',     'ecran', 'en_service',  'Bouaké', 'Comptabilité', NULL),
(35, 'BKE-EC-008', 'SN-HP-E08-2022',  'HP',     'V22v G5 22"',        'ecran', 'en_service',  'Bouaké', 'Commercial',   NULL),
(36, 'BKE-EC-009', 'SN-DEL-E09-2021', 'Dell',   'P2422H 24"',         'ecran', 'en_service',  'Bouaké', 'Logistique',   NULL),
(37, 'BKE-EC-010', 'SN-SAM-E10-2019', 'Samsung','S22D300HY 22"',      'ecran', 'reforme',     'Bouaké', 'Direction IT', NULL),
(38, 'BKE-EC-011', 'SN-LG-E11-2023',  'LG',     '27UK650-W 27"',      'ecran', 'en_service',  'Bouaké', 'Direction',    NULL),
(39, 'BKE-EC-012', 'SN-HP-E12-2022',  'HP',     'V24i G5 24"',        'ecran', 'en_service',  'Bouaké', 'RH',           NULL),
-- Imprimantes (40-45)
(40, 'BKE-IMP-001','SN-HP-I01-2021',  'HP',     'LaserJet Pro M404dn',  'imprimante', 'en_service',  'Bouaké', 'Direction IT', NULL),
(41, 'BKE-IMP-002','SN-RIC-I02-2022', 'Ricoh',  'MP 2014D',            'imprimante', 'en_service',  'Bouaké', 'Comptabilité', NULL),
(42, 'BKE-IMP-003','SN-CAN-I03-2021', 'Canon',  'imageRUNNER 2204N',   'imprimante', 'en_service',  'Bouaké', 'Direction',    NULL),
(43, 'BKE-IMP-004','SN-HP-I04-2023',  'HP',     'LaserJet Pro M428fdw','imprimante', 'en_service',  'Bouaké', 'RH',           NULL),
(44, 'BKE-IMP-005','SN-RIC-I05-2020', 'Ricoh',  'Aficio SP 3510DN',    'imprimante', 'hors_service','Bouaké', 'Logistique',   NULL),
(45, 'BKE-IMP-006','SN-HP-I06-2022',  'HP',     'LaserJet Pro M402dn', 'imprimante', 'en_service',  'Bouaké', 'Commercial',   NULL),
-- Scanners (46-49)
(46, 'BKE-SC-001', 'SN-CAN-S01-2021', 'Canon',  'imageFormula DR-C225W II', 'scanner', 'en_service',  'Bouaké', 'Comptabilité', NULL),
(47, 'BKE-SC-002', 'SN-EPS-S02-2022', 'Epson',  'WorkForce ES-400II',       'scanner', 'en_service',  'Bouaké', 'Direction IT', NULL),
(48, 'BKE-SC-003', 'SN-HP-S03-2021',  'HP',     'ScanJet Pro 2000 s2',      'scanner', 'en_service',  'Bouaké', 'RH',           NULL),
(49, 'BKE-SC-004', 'SN-CAN-S04-2020', 'Canon',  'CanoScan LIDE 400',        'scanner', 'hors_service','Bouaké', 'Direction IT', NULL),
-- Téléphones / Tablettes (50-60)
(50, 'BKE-TEL-001','SN-SAM-T01-2023', 'Samsung','Galaxy A54 5G',       'telephone', 'en_service',  'Bouaké',  'Direction IT', NULL),
(51, 'BKE-TEL-002','SN-SAM-T02-2022', 'Samsung','Galaxy A33 5G',       'telephone', 'en_service',  'Bouaké',  'Commercial',   NULL),
(52, 'BKE-TEL-003','SN-SAM-T03-2023', 'Samsung','Galaxy A54 5G',       'telephone', 'en_service',  'Bouaké',  'Direction',    NULL),
(53, 'BKE-TEL-004','SN-SAM-T04-2022', 'Samsung','Galaxy A23',          'telephone', 'en_service',  'Bouaké',  'Logistique',   NULL),
(54, 'BKE-TEL-005','SN-SAM-T05-2021', 'Samsung','Galaxy A12',          'telephone', 'hors_service','Bouaké',  'RH',           NULL),
(55, 'BKE-TEL-006','SN-SAM-T06-2023', 'Samsung','Galaxy A54 5G',       'telephone', 'en_service',  'Abidjan', 'Commercial',   NULL),
(56, 'BKE-TEL-007','SN-SAM-T07-2022', 'Samsung','Galaxy A33 5G',       'telephone', 'en_service',  'Azaguié', 'Logistique',   NULL),
(57, 'BKE-TEL-008','SN-SAM-T08-2023', 'Samsung','Galaxy Tab A8',       'tablette',  'en_service',  'Bouaké',  'Direction IT', NULL),
(58, 'BKE-TEL-009','SN-SAM-T09-2022', 'Samsung','Galaxy Tab A7 Lite',  'tablette',  'en_service',  'Bouaké',  'Commercial',   NULL),
(59, 'BKE-TEL-010','SN-SAM-T10-2023', 'Samsung','Galaxy A54 5G',       'telephone', 'en_service',  'Katiola', 'Commercial',   NULL),
(60, 'BKE-TEL-011','SN-SAM-T11-2022', 'Samsung','Galaxy A23',          'telephone', 'en_service',  'Djeboa',  'Logistique',   NULL),
-- Terminaux PAX A920 (61-72)
(61, 'PAX-001', 'PAX920-BKE-001', 'PAX', 'A920 Pro', 'pax_terminal', 'en_service',  'Bouaké',  'Commercial', 'Terminal cajou site Bouaké 1'),
(62, 'PAX-002', 'PAX920-BKE-002', 'PAX', 'A920 Pro', 'pax_terminal', 'en_service',  'Bouaké',  'Commercial', 'Terminal cajou site Bouaké 2'),
(63, 'PAX-003', 'PAX920-BKE-003', 'PAX', 'A920 Pro', 'pax_terminal', 'en_service',  'Bouaké',  'Commercial', 'Terminal cajou site Bouaké 3'),
(64, 'PAX-004', 'PAX920-ABJ-001', 'PAX', 'A920 Pro', 'pax_terminal', 'en_service',  'Abidjan', 'Commercial', 'Terminal cajou Abidjan 1'),
(65, 'PAX-005', 'PAX920-ABJ-002', 'PAX', 'A920 Pro', 'pax_terminal', 'en_service',  'Abidjan', 'Commercial', 'Terminal cajou Abidjan 2'),
(66, 'PAX-006', 'PAX920-AZG-001', 'PAX', 'A920 Pro', 'pax_terminal', 'en_service',  'Azaguié', 'Logistique', 'Terminal cajou Azaguié'),
(67, 'PAX-007', 'PAX920-AZG-002', 'PAX', 'A920 Pro', 'pax_terminal', 'en_service',  'Azaguié', 'Logistique', 'Terminal cajou Azaguié 2'),
(68, 'PAX-008', 'PAX920-KAT-001', 'PAX', 'A920 Pro', 'pax_terminal', 'en_service',  'Katiola', 'Commercial', 'Terminal cajou Katiola'),
(69, 'PAX-009', 'PAX920-KAT-002', 'PAX', 'A920 Pro', 'pax_terminal', 'en_service',  'Katiola', 'Commercial', 'Terminal cajou Katiola 2'),
(70, 'PAX-010', 'PAX920-DJE-001', 'PAX', 'A920 Pro', 'pax_terminal', 'en_service',  'Djeboa',  'Logistique', 'Terminal cajou Djeboa'),
(71, 'PAX-011', 'PAX920-DJE-002', 'PAX', 'A920 Pro', 'pax_terminal', 'en_service',  'Djeboa',  'Logistique', 'Terminal cajou Djeboa 2'),
(72, 'PAX-012', 'PAX920-BKE-004', 'PAX', 'A920 Pro', 'pax_terminal', 'hors_service','Bouaké',  'Commercial', 'En panne - retour fournisseur')
ON CONFLICT (id) DO NOTHING;

-- ── 4. Spécifications techniques ─────────────────────────────────────────────
INSERT INTO specs (asset_id, ram, stockage, cpu, os, version_os, mac_address, hostname) VALUES
(1,  '16 Go', 'SSD 512 Go', 'Intel Core i5-1235U',  'Windows 11 Pro', '23H2', '00:1A:2B:3C:4D:01', 'BKE-LT-001'),
(2,  '8 Go',  'SSD 256 Go', 'Intel Core i5-1345U',  'Windows 11 Pro', '23H2', '00:1A:2B:3C:4D:02', 'BKE-LT-002'),
(3,  '16 Go', 'SSD 512 Go', 'Intel Core i5-1235U',  'Windows 11 Pro', '23H2', '00:1A:2B:3C:4D:03', 'BKE-LT-003'),
(4,  '8 Go',  'SSD 256 Go', 'Intel Core i5-1235U',  'Windows 10 Pro', '22H2', '00:1A:2B:3C:4D:04', 'BKE-LT-004'),
(5,  '8 Go',  'HDD 500 Go', 'Intel Core i3-1215U',  'Windows 10 Pro', '22H2', '00:1A:2B:3C:4D:05', 'BKE-LT-005'),
(6,  '32 Go', 'SSD 1 To',   'Intel Core i7-1255U',  'Windows 11 Pro', '23H2', '00:1A:2B:3C:4D:06', 'BKE-LT-006'),
(7,  '8 Go',  'SSD 256 Go', 'Intel Core i5-1135G7', 'Windows 10 Pro', '21H2', '00:1A:2B:3C:4D:07', 'BKE-LT-007'),
(8,  '8 Go',  'SSD 256 Go', 'Intel Core i5-1335U',  'Windows 11 Pro', '23H2', '00:1A:2B:3C:4D:08', 'BKE-LT-008'),
(9,  '16 Go', 'SSD 512 Go', 'Intel Core i5-1345U',  'Windows 11 Pro', '23H2', '00:1A:2B:3C:4D:09', 'BKE-LT-009'),
(10, '4 Go',  'HDD 320 Go', 'Intel Core i5-8265U',  'Windows 10 Pro', '21H1', '00:1A:2B:3C:4D:0A', 'BKE-LT-010'),
(11, '8 Go',  'SSD 256 Go', 'Intel Core i5-1345U',  'Windows 11 Pro', '23H2', '00:1A:2B:3C:4D:0B', 'ABJ-LT-001'),
(12, '8 Go',  'SSD 256 Go', 'Intel Core i5-1135G7', 'Windows 11 Pro', '22H2', '00:1A:2B:3C:4D:0C', 'ABJ-LT-002'),
(13, '16 Go', 'SSD 512 Go', 'Intel Core i5-1335U',  'Windows 11 Pro', '23H2', '00:1A:2B:3C:4D:0D', 'AZG-LT-001'),
(14, '8 Go',  'SSD 256 Go', 'Intel Core i5-1235U',  'Windows 10 Pro', '22H2', '00:1A:2B:3C:4D:0E', 'KAT-LT-001'),
(15, '8 Go',  'SSD 256 Go', 'Intel Core i3-1215U',  'Windows 11 Pro', '23H2', '00:1A:2B:3C:4D:0F', 'DJE-LT-001'),
(16, '16 Go', 'SSD 512 Go', 'Intel Core i5-10500',  'Windows 11 Pro', '23H2', NULL,                 'BKE-DT-001'),
(17, '8 Go',  'SSD 256 Go', 'Intel Core i5-10400',  'Windows 10 Pro', '22H2', NULL,                 'BKE-DT-002'),
(18, '8 Go',  'HDD 1 To',   'Intel Core i5-10400',  'Windows 10 Pro', '21H2', NULL,                 'BKE-DT-003'),
(19, '16 Go', 'SSD 512 Go', 'Intel Core i5-12500',  'Windows 11 Pro', '23H2', NULL,                 'BKE-DT-004'),
(20, '4 Go',  'HDD 500 Go', 'Intel Core i7-8700',   'Windows 10 Pro', '21H1', NULL,                 'BKE-DT-005'),
(21, '8 Go',  'SSD 256 Go', 'Intel Core i5-10400',  'Windows 11 Pro', '22H2', NULL,                 'BKE-DT-006'),
(22, '4 Go',  'HDD 500 Go', 'Intel Core i5-9400',   'Windows 10 Pro', '20H2', NULL,                 'BKE-DT-007'),
(23, '16 Go', 'SSD 512 Go', 'Intel Core i5-12500',  'Windows 11 Pro', '23H2', NULL,                 'BKE-DT-008'),
(24, '8 Go',  'SSD 256 Go', 'Intel Core i5-10500',  'Windows 11 Pro', '22H2', NULL,                 'BKE-DT-009'),
(25, '8 Go',  'SSD 256 Go', 'Intel Core i5-10400',  'Windows 11 Pro', '22H2', NULL,                 'BKE-DT-010'),
(26, '16 Go', 'SSD 512 Go', 'Intel Core i5-13500',  'Windows 11 Pro', '23H2', NULL,                 'BKE-DT-011'),
(27, '8 Go',  'SSD 256 Go', 'Intel Core i5-12500',  'Windows 11 Pro', '23H2', NULL,                 'BKE-DT-012')
ON CONFLICT (asset_id) DO NOTHING;

-- ── 5. Conformité sécurité ───────────────────────────────────────────────────
INSERT INTO securite (asset_id, defender, edr, intune, entra_id, bitlocker, onedrive) VALUES
(1,  1,1,1,1,1,1), (2,  1,1,1,1,1,1), (3,  1,1,1,1,0,1),
(4,  1,1,0,0,0,1), (5,  1,0,0,0,0,0), (6,  1,1,1,1,1,1),
(7,  1,0,0,0,0,0), (8,  1,1,1,1,1,1), (9,  1,1,1,1,1,1),
(10, 0,0,0,0,0,0), (11, 1,1,1,1,1,1), (12, 1,1,1,0,1,1),
(13, 1,1,1,1,0,1), (14, 1,0,0,0,0,0), (15, 1,1,0,0,0,1),
(16, 1,1,1,1,1,1), (17, 1,1,0,0,0,1), (18, 1,0,0,0,0,0),
(19, 1,1,1,1,1,1), (20, 0,0,0,0,0,0), (21, 1,1,1,0,1,1),
(22, 0,0,0,0,0,0), (23, 1,1,1,1,1,1), (24, 1,1,1,1,1,1),
(25, 1,0,0,0,0,0), (26, 1,1,1,1,1,1), (27, 1,1,1,1,1,1)
ON CONFLICT (asset_id) DO NOTHING;

-- ── 6. Coûts & Garanties ─────────────────────────────────────────────────────
INSERT INTO couts (asset_id, prix, fournisseur, bon_commande, date_acquisition, fin_garantie, devise) VALUES
(1,  750000,  'CFAO Technologies', 'BC-2023-001', '2023-03-15', '2026-03-15', 'XOF'),
(2,  680000,  'ORCA CI',           'BC-2023-002', '2023-04-10', '2026-04-10', 'XOF'),
(3,  720000,  'CFAO Technologies', 'BC-2022-015', '2022-09-20', '2025-09-20', 'XOF'),
(4,  630000,  'ORCA CI',           'BC-2023-003', '2023-05-08', '2026-05-08', 'XOF'),
(5,  480000,  'CFAO Technologies', 'BC-2022-020', '2022-11-12', '2025-11-12', 'XOF'),
(6,  950000,  'ORCA CI',           'BC-2023-004', '2023-06-01', '2026-06-01', 'XOF'),
(7,  550000,  'CFAO Technologies', 'BC-2021-008', '2021-07-14', '2024-07-14', 'XOF'),
(8,  640000,  'ORCA CI',           'BC-2023-010', '2023-08-22', '2026-08-22', 'XOF'),
(9,  680000,  'CFAO Technologies', 'BC-2023-011', '2023-09-05', '2026-09-05', 'XOF'),
(10, 400000,  'ORCA CI',           'BC-2020-005', '2020-03-10', '2023-03-10', 'XOF'),
(11, 680000,  'CFAO Technologies', 'BC-2023-015', '2023-10-15', '2026-10-15', 'XOF'),
(12, 620000,  'ORCA CI',           'BC-2022-030', '2022-12-20', '2025-12-20', 'XOF'),
(13, 720000,  'CFAO Technologies', 'BC-2023-020', '2023-11-08', '2026-11-08', 'XOF'),
(14, 630000,  'ORCA CI',           'BC-2022-025', '2022-10-10', '2025-10-10', 'XOF'),
(15, 480000,  'CFAO Technologies', 'BC-2023-025', '2023-12-01', '2026-12-01', 'XOF'),
(16, 580000,  'ORCA CI',           'BC-2022-010', '2022-05-20', '2025-05-20', 'XOF'),
(17, 480000,  'CFAO Technologies', 'BC-2022-011', '2022-06-15', '2025-06-15', 'XOF'),
(18, 450000,  'ORCA CI',           'BC-2021-012', '2021-08-10', '2024-08-10', 'XOF'),
(19, 620000,  'CFAO Technologies', 'BC-2023-030', '2023-07-25', '2026-07-25', 'XOF'),
(20, 350000,  'ORCA CI',           'BC-2019-005', '2019-11-20', '2022-11-20', 'XOF'),
(21, 480000,  'CFAO Technologies', 'BC-2022-018', '2022-08-12', '2025-08-12', 'XOF'),
(22, 320000,  'ORCA CI',           'BC-2020-008', '2020-05-15', '2023-05-15', 'XOF'),
(23, 620000,  'CFAO Technologies', 'BC-2023-035', '2023-09-18', '2026-09-18', 'XOF'),
(24, 530000,  'ORCA CI',           'BC-2022-022', '2022-07-08', '2025-07-08', 'XOF')
ON CONFLICT (asset_id) DO NOTHING;

-- ── 7. Affectations ──────────────────────────────────────────────────────────
INSERT INTO affectations (asset_id, user_id, date_attribution, motif, actif) VALUES
(1,  1,  '2023-03-15', 'Attribution initiale', 1),
(2,  3,  '2023-04-10', 'Attribution initiale', 1),
(3,  4,  '2022-09-20', 'Attribution initiale', 1),
(4,  5,  '2023-05-08', 'Attribution initiale', 1),
(5,  6,  '2022-11-12', 'Attribution initiale', 1),
(6,  7,  '2023-06-01', 'Attribution direction', 1),
(8,  3,  '2023-08-22', 'Remplacement LT-002 en réparation', 1),
(9,  4,  '2023-09-05', 'Attribution commercial', 1),
(11, 8,  '2023-10-15', 'Attribution Abidjan', 1),
(12, 9,  '2022-12-20', 'Attribution comptabilité Abidjan', 1),
(13, 10, '2023-11-08', 'Attribution Azaguié', 1),
(14, 11, '2022-10-10', 'Attribution Katiola', 1),
(15, 12, '2023-12-01', 'Attribution Djeboa', 1),
(16, 1,  '2022-05-20', 'Poste direction IT', 1),
(17, 3,  '2022-06-15', 'Poste comptabilité', 1),
(19, 15, '2023-07-25', 'Poste comptabilité', 1),
(21, 7,  '2022-08-12', 'Poste direction', 1),
(23, 4,  '2023-09-18', 'Poste commercial', 1),
(24, 3,  '2022-07-08', 'Poste comptabilité', 1);

-- ── 8. Tickets Démo ──────────────────────────────────────────────────────────
INSERT INTO tickets (id, numero, titre, description, type, priorite, statut, asset_id, createur_id, technicien_id, site, sla_deadline, temps_resolution_min, note_satisfaction, created_at, closed_at) VALUES
(1, 'TKT-2026-0001', 'Le serveur de base de données ne répond plus', 'L''accès à la base ERP est coupé. Urgent !', 'incident', 'critique', 'ouvert', 1, 3, NULL, 'Bouaké', CURRENT_TIMESTAMP + INTERVAL '4 hours', 0, NULL, CURRENT_TIMESTAMP - INTERVAL '1 hour', NULL),
(2, 'TKT-2026-0002', 'Demande d''écran supplémentaire 24"', 'Besoin d''un double écran pour les rapports comptables.', 'demande_materiel', 'moyenne', 'en_cours', NULL, 3, 2, 'Bouaké', CURRENT_TIMESTAMP + INTERVAL '3 days', 0, NULL, CURRENT_TIMESTAMP - INTERVAL '1 day', NULL),
(3, 'TKT-2026-0003', 'Problème de connexion VPN', 'Impossible de se connecter au VPN entreprise.', 'acces_logiciel', 'haute', 'ferme', 2, 3, 2, 'Bouaké', CURRENT_TIMESTAMP - INTERVAL '4 hours', 180, 5, CURRENT_TIMESTAMP - INTERVAL '8 hours', CURRENT_TIMESTAMP - INTERVAL '5 hours')
ON CONFLICT (id) DO NOTHING;

-- Commentaires de tickets
INSERT INTO ticket_commentaires (ticket_id, auteur_id, contenu, type, created_at) VALUES
(2, 2, 'Bonjour, demande bien reçue. Vérification du stock en cours.', 'public', CURRENT_TIMESTAMP - INTERVAL '12 hours'),
(2, 2, 'Note interne : Écran 24" disponible en stock.', 'interne', CURRENT_TIMESTAMP - INTERVAL '11 hours'),
(3, 2, 'Certificat VPN renouvelé.', 'public', CURRENT_TIMESTAMP - INTERVAL '6 hours'),
(3, 3, 'Ça refonctionne, merci !', 'public', CURRENT_TIMESTAMP - INTERVAL '5 hours');

-- Évaluations de tickets
INSERT INTO ticket_evaluations (ticket_id, user_id, note, commentaire, created_at) VALUES
(3, 3, 5, 'Résolution ultra rapide, merci beaucoup !', CURRENT_TIMESTAMP - INTERVAL '5 hours');

-- Notifications
INSERT INTO in_app_notifications (user_id, titre, contenu, lu, created_at) VALUES
(3, 'Ticket résolu: TKT-2026-0003', 'Votre ticket VPN a été résolu. Merci de l''évaluer.', 0, CURRENT_TIMESTAMP - INTERVAL '5 hours');

-- ── 9. Licences Démo ─────────────────────────────────────────────────────────
INSERT INTO licences (id, nom, editeur, cle_activation, date_expiration, quota_max, cout, notes) VALUES
(1, 'Microsoft 365 Business Standard', 'Microsoft', 'XXXXX-XXXXX-XXXXX-XXXXX', CURRENT_DATE + INTERVAL '180 days', 50, 450000.00, 'Pack bureautique pour l''équipe'),
(2, 'Adobe Acrobat Pro', 'Adobe', 'ADOBE-PRO-2026-KEY', CURRENT_DATE + INTERVAL '60 days', 10, 180000.00, 'Direction et Compta')
ON CONFLICT (id) DO NOTHING;

-- ── 10. Consommables Démo ───────────────────────────────────────────────────
INSERT INTO consommables (id, nom, categorie, quantite, seuil_alerte, emplacement) VALUES
(1, 'Toner HP 58A Noir (CF258A)', 'Cartouche d''encre', 12, 4, 'Armoire IT - Étagère 1'),
(2, 'Câble HDMI 2.0 (2m)', 'Câble', 25, 5, 'Armoire IT - Tiroir B'),
(3, 'Câble RJ45 Cat6 (3m)', 'Câble', 30, 8, 'Armoire IT - Tiroir B'),
(4, 'Souris optique filaire USB', 'Périphérique', 15, 5, 'Armoire IT - Étagère 2')
ON CONFLICT (id) DO NOTHING;

-- ── 11. Maintenances Démo ───────────────────────────────────────────────────
INSERT INTO maintenances (asset_id, technicien_id, type, date_prevue, description, cout, statut) VALUES
(16, 2, 'preventive', CURRENT_DATE + INTERVAL '7 days', 'Dépoussiérage et changement pâte thermique', 15000.00, 'planifie'),
(40, 2, 'preventive', CURRENT_DATE + INTERVAL '14 days', 'Nettoyage rouleaux et calibrage', 25000.00, 'planifie');

-- ── 12. Wiki IT ──────────────────────────────────────────────────────────────
INSERT INTO wiki_articles (titre, contenu, auteur_id, categorie, est_public) VALUES
('Procédure de configuration VPN entreprise', 'Pour configurer le VPN : Téléchargez le client OpenVPN puis importez la configuration profile.ovpn...', 2, 'Réseau', 1),
('Attribution de matériel - Règles et charte', 'Tout collaborateur recevant un équipement doit signer la fiche d''affectation et respecter la charte informatique...', 1, 'Procédures', 1);

-- ── 13. Synchronisation des séquences (Identity / Serial) ───────────────────
SELECT setval(pg_get_serial_sequence('utilisateurs', 'id'), COALESCE(MAX(id), 1), MAX(id) IS NOT NULL) FROM utilisateurs;
SELECT setval(pg_get_serial_sequence('assets', 'id'), COALESCE(MAX(id), 1), MAX(id) IS NOT NULL) FROM assets;
SELECT setval(pg_get_serial_sequence('auth_users', 'id'), COALESCE(MAX(id), 1), MAX(id) IS NOT NULL) FROM auth_users;
SELECT setval(pg_get_serial_sequence('specs', 'id'), COALESCE(MAX(id), 1), MAX(id) IS NOT NULL) FROM specs;
SELECT setval(pg_get_serial_sequence('securite', 'id'), COALESCE(MAX(id), 1), MAX(id) IS NOT NULL) FROM securite;
SELECT setval(pg_get_serial_sequence('couts', 'id'), COALESCE(MAX(id), 1), MAX(id) IS NOT NULL) FROM couts;
SELECT setval(pg_get_serial_sequence('affectations', 'id'), COALESCE(MAX(id), 1), MAX(id) IS NOT NULL) FROM affectations;
SELECT setval(pg_get_serial_sequence('tickets', 'id'), COALESCE(MAX(id), 1), MAX(id) IS NOT NULL) FROM tickets;
SELECT setval(pg_get_serial_sequence('ticket_commentaires', 'id'), COALESCE(MAX(id), 1), MAX(id) IS NOT NULL) FROM ticket_commentaires;
SELECT setval(pg_get_serial_sequence('ticket_evaluations', 'id'), COALESCE(MAX(id), 1), MAX(id) IS NOT NULL) FROM ticket_evaluations;
SELECT setval(pg_get_serial_sequence('in_app_notifications', 'id'), COALESCE(MAX(id), 1), MAX(id) IS NOT NULL) FROM in_app_notifications;
SELECT setval(pg_get_serial_sequence('licences', 'id'), COALESCE(MAX(id), 1), MAX(id) IS NOT NULL) FROM licences;
SELECT setval(pg_get_serial_sequence('consommables', 'id'), COALESCE(MAX(id), 1), MAX(id) IS NOT NULL) FROM consommables;
SELECT setval(pg_get_serial_sequence('maintenances', 'id'), COALESCE(MAX(id), 1), MAX(id) IS NOT NULL) FROM maintenances;
SELECT setval(pg_get_serial_sequence('wiki_articles', 'id'), COALESCE(MAX(id), 1), MAX(id) IS NOT NULL) FROM wiki_articles;
