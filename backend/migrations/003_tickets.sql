-- ============================================
-- 003_tickets.sql — Schéma & données de base
-- Module de gestion des tickets IT
-- ============================================

USE `gestionnaire_parc_it`;

SET foreign_key_checks = 0;

-- ── Table: sla_config ────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `sla_config` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `priorite` ENUM('critique', 'haute', 'moyenne', 'basse') NOT NULL,
  `delai_prise_en_charge_min` INT UNSIGNED NOT NULL,
  `delai_resolution_min` INT UNSIGNED NOT NULL,
  `actif` TINYINT(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_priorite` (`priorite`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Seed SLA Config
INSERT INTO `sla_config` (priorite, delai_prise_en_charge_min, delai_resolution_min, actif) VALUES
('critique', 15, 240, 1),
('haute', 60, 480, 1),
('moyenne', 240, 4320, 1),
('basse', 1440, 10080, 1)
ON DUPLICATE KEY UPDATE delai_prise_en_charge_min=VALUES(delai_prise_en_charge_min), delai_resolution_min=VALUES(delai_resolution_min);

-- ── Table: tickets ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `tickets` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `numero` VARCHAR(20) NOT NULL,
  `titre` VARCHAR(200) NOT NULL,
  `description` TEXT NOT NULL,
  `type` ENUM('incident', 'demande_materiel', 'maintenance', 'acces_logiciel') NOT NULL,
  `priorite` ENUM('critique', 'haute', 'moyenne', 'basse') NOT NULL,
  `statut` ENUM('ouvert', 'en_cours', 'en_attente', 'resolu', 'ferme', 'annule', 'rouvert') NOT NULL DEFAULT 'ouvert',
  `asset_id` INT UNSIGNED DEFAULT NULL,
  `createur_id` INT UNSIGNED NOT NULL,
  `technicien_id` INT UNSIGNED DEFAULT NULL,
  `site` VARCHAR(50) DEFAULT NULL,
  `sla_deadline` DATETIME DEFAULT NULL,
  `temps_resolution_min` INT UNSIGNED DEFAULT 0,
  `note_satisfaction` TINYINT UNSIGNED DEFAULT NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `closed_at` DATETIME DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_numero` (`numero`),
  KEY `idx_statut` (`statut`),
  KEY `idx_priorite` (`priorite`),
  KEY `idx_createur` (`createur_id`),
  CONSTRAINT `fk_tickets_asset` FOREIGN KEY (`asset_id`) REFERENCES `assets` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_tickets_createur` FOREIGN KEY (`createur_id`) REFERENCES `auth_users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_tickets_tech` FOREIGN KEY (`technicien_id`) REFERENCES `auth_users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ── Table: ticket_commentaires ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `ticket_commentaires` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `ticket_id` INT UNSIGNED NOT NULL,
  `auteur_id` INT UNSIGNED NOT NULL,
  `contenu` TEXT NOT NULL,
  `type` ENUM('public', 'interne') NOT NULL DEFAULT 'public',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_comments_ticket` FOREIGN KEY (`ticket_id`) REFERENCES `tickets` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_comments_auteur` FOREIGN KEY (`auteur_id`) REFERENCES `auth_users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ── Table: ticket_historique ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `ticket_historique` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `ticket_id` INT UNSIGNED NOT NULL,
  `user_id` INT UNSIGNED NOT NULL,
  `champ_modifie` VARCHAR(50) NOT NULL,
  `ancienne_valeur` TEXT DEFAULT NULL,
  `nouvelle_valeur` TEXT DEFAULT NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_history_ticket` FOREIGN KEY (`ticket_id`) REFERENCES `tickets` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_history_user` FOREIGN KEY (`user_id`) REFERENCES `auth_users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ── Table: ticket_pieces_jointes ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `ticket_pieces_jointes` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `ticket_id` INT UNSIGNED NOT NULL,
  `nom_fichier` VARCHAR(255) NOT NULL,
  `chemin` VARCHAR(255) NOT NULL,
  `taille` INT UNSIGNED NOT NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_attachments_ticket` FOREIGN KEY (`ticket_id`) REFERENCES `tickets` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ── Table: ticket_evaluations ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `ticket_evaluations` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `ticket_id` INT UNSIGNED NOT NULL,
  `user_id` INT UNSIGNED NOT NULL,
  `note` TINYINT UNSIGNED NOT NULL,
  `commentaire` TEXT DEFAULT NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_evaluations_ticket` FOREIGN KEY (`ticket_id`) REFERENCES `tickets` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_evaluations_user` FOREIGN KEY (`user_id`) REFERENCES `auth_users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ── Table: in_app_notifications ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `in_app_notifications` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id` INT UNSIGNED NOT NULL,
  `titre` VARCHAR(255) NOT NULL,
  `contenu` TEXT NOT NULL,
  `lu` TINYINT(1) NOT NULL DEFAULT 0,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_user_lu` (`user_id`, `lu`),
  CONSTRAINT `fk_notif_user` FOREIGN KEY (`user_id`) REFERENCES `auth_users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ── Seeding Demo Tickets ─────────────────────────────────────────────────────

SET foreign_key_checks = 0;
TRUNCATE TABLE `in_app_notifications`;
TRUNCATE TABLE `ticket_evaluations`;
TRUNCATE TABLE `ticket_pieces_jointes`;
TRUNCATE TABLE `ticket_historique`;
TRUNCATE TABLE `ticket_commentaires`;
TRUNCATE TABLE `tickets`;
SET foreign_key_checks = 1;

-- Ticket 1: Incident Critique (Serveur Down)
INSERT INTO `tickets` (numero, titre, description, type, priorite, statut, asset_id, createur_id, site, sla_deadline, created_at)
VALUES (
  'TKT-2026-0001',
  'Le serveur de base de données ne répond plus',
  'L''accès à la base de données ERP est coupé depuis ce matin. Tous les collaborateurs sont bloqués avec des erreurs de timeout. Urgent !',
  'incident',
  'critique',
  'ouvert',
  1, -- asset BKE-LT-001
  3, -- user id 3 (lecteur/BROU)
  'Bouaké',
  DATE_ADD(NOW(), INTERVAL 4 HOUR),
  DATE_SUB(NOW(), INTERVAL 1 HOUR)
);

-- Ticket 2: Demande de matériel en cours
INSERT INTO `tickets` (numero, titre, description, type, priorite, statut, asset_id, createur_id, technicien_id, site, sla_deadline, created_at)
VALUES (
  'TKT-2026-0002',
  'Demande d''écran supplémentaire 24"',
  'Bonjour, j''aimerais disposer d''un double écran pour faciliter le traitement des rapports comptables mensuels.',
  'demande_materiel',
  'moyenne',
  'en_cours',
  NULL,
  3, -- user id 3 (lecteur/BROU)
  2, -- user id 2 (technicien/KOUASSI)
  'Bouaké',
  DATE_ADD(NOW(), INTERVAL 3 DAY),
  DATE_SUB(NOW(), INTERVAL 1 DAY)
);

-- Comments for Ticket 2
INSERT INTO `ticket_commentaires` (ticket_id, auteur_id, contenu, type, created_at)
VALUES (
  2,
  2,
  'Bonjour, votre demande a bien été reçue. Nous vérifions le stock disponible à Bouaké.',
  'public',
  DATE_SUB(NOW(), INTERVAL 12 HOUR)
);

INSERT INTO `ticket_commentaires` (ticket_id, auteur_id, contenu, type, created_at)
VALUES (
  2,
  2,
  'Note interne : Écrans Samsung 24" disponibles en stock. Attribution validée, livraison prévue demain.',
  'interne',
  DATE_SUB(NOW(), INTERVAL 11 HOUR)
);

-- Ticket 3: Incident Résolu & Évalué
INSERT INTO `tickets` (numero, titre, description, type, priorite, statut, asset_id, createur_id, technicien_id, site, sla_deadline, temps_resolution_min, note_satisfaction, created_at, closed_at)
VALUES (
  'TKT-2026-0003',
  'Problème de connexion VPN',
  'Impossible de me connecter au VPN entreprise depuis hier soir. Message d''erreur: "Le serveur distant ne répond pas".',
  'acces_logiciel',
  'haute',
  'ferme',
  2, -- asset BKE-LT-002
  3, -- user id 3 (lecteur/BROU)
  2, -- user id 2 (technicien/KOUASSI)
  'Bouaké',
  DATE_SUB(NOW(), INTERVAL 4 HOUR),
  180,
  5,
  DATE_SUB(NOW(), INTERVAL 8 HOUR),
  DATE_SUB(NOW(), INTERVAL 5 HOUR)
);

-- Comments & Evaluation for Ticket 3
INSERT INTO `ticket_commentaires` (ticket_id, auteur_id, contenu, type, created_at)
VALUES (
  3,
  2,
  'Le problème venait d''une expiration de certificat sur le serveur VPN. Le service a été redémarré et le certificat renouvelé. Pouvez-vous tester à nouveau ?',
  'public',
  DATE_SUB(NOW(), INTERVAL 6 HOUR)
);

INSERT INTO `ticket_commentaires` (ticket_id, auteur_id, contenu, type, created_at)
VALUES (
  3,
  3,
  'Ça refonctionne parfaitement ! Merci pour la réactivité.',
  'public',
  DATE_SUB(NOW(), INTERVAL 5 HOUR)
);

INSERT INTO `ticket_evaluations` (ticket_id, user_id, note, commentaire, created_at)
VALUES (
  3,
  3,
  5,
  'Résolution ultra rapide, merci beaucoup !',
  DATE_SUB(NOW(), INTERVAL 5 HOUR)
);

-- Seed some in-app notifications
INSERT INTO `in_app_notifications` (user_id, titre, contenu, lu, created_at)
VALUES (
  3,
  'Ticket résolu: TKT-2026-0003',
  'Votre ticket "Problème de connexion VPN" a été marqué comme résolu par le technicien. Merci d''évaluer la prestation.',
  0,
  DATE_SUB(NOW(), INTERVAL 5 HOUR)
);

SET foreign_key_checks = 1;
