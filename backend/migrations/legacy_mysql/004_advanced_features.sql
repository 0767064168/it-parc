-- ============================================
-- 004_advanced_features.sql — Fonctionnalités avancées
-- Licences, Consommables, Maintenances, Wiki, Garanties
-- ============================================

USE `gestionnaire_parc_it`;

SET foreign_key_checks = 0;

-- ── Table: licences ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `licences` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `nom` VARCHAR(150) NOT NULL,
  `editeur` VARCHAR(100) DEFAULT NULL,
  `cle_activation` VARCHAR(255) DEFAULT NULL,
  `date_expiration` DATE DEFAULT NULL,
  `quota_max` INT UNSIGNED DEFAULT NULL COMMENT 'NULL = illimité',
  `cout` DECIMAL(10,2) DEFAULT 0.00,
  `notes` TEXT DEFAULT NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ── Table: licence_allocations ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `licence_allocations` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `licence_id` INT UNSIGNED NOT NULL,
  `user_id` INT UNSIGNED NOT NULL,
  `date_allocation` DATE NOT NULL,
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_alloc_licence` FOREIGN KEY (`licence_id`) REFERENCES `licences` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_alloc_user` FOREIGN KEY (`user_id`) REFERENCES `utilisateurs` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ── Table: consommables ────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `consommables` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `nom` VARCHAR(150) NOT NULL,
  `categorie` VARCHAR(100) DEFAULT NULL COMMENT 'Ex: Cartouche d''encre, Câble, Périphérique',
  `quantite` INT NOT NULL DEFAULT 0,
  `seuil_alerte` INT NOT NULL DEFAULT 5,
  `emplacement` VARCHAR(100) DEFAULT NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ── Table: maintenances ────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `maintenances` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `asset_id` INT UNSIGNED NOT NULL,
  `technicien_id` INT UNSIGNED DEFAULT NULL,
  `type` ENUM('preventive', 'curative') NOT NULL DEFAULT 'preventive',
  `date_prevue` DATE NOT NULL,
  `date_realisee` DATE DEFAULT NULL,
  `description` VARCHAR(255) NOT NULL,
  `cout` DECIMAL(10,2) DEFAULT 0.00,
  `notes` TEXT DEFAULT NULL,
  `statut` ENUM('planifie', 'en_cours', 'realise', 'annule') NOT NULL DEFAULT 'planifie',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_maint_asset` FOREIGN KEY (`asset_id`) REFERENCES `assets` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_maint_tech` FOREIGN KEY (`technicien_id`) REFERENCES `auth_users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ── Table: wiki_articles ────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `wiki_articles` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `titre` VARCHAR(200) NOT NULL,
  `contenu` TEXT NOT NULL,
  `auteur_id` INT UNSIGNED NOT NULL,
  `categorie` VARCHAR(100) NOT NULL DEFAULT 'Général',
  `est_public` TINYINT(1) NOT NULL DEFAULT 0 COMMENT '0 = équipe IT seulement, 1 = tout le monde',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_wiki_auteur` FOREIGN KEY (`auteur_id`) REFERENCES `auth_users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Rajout de la colonne date_fin_garantie sur la table assets
ALTER TABLE `assets` ADD COLUMN IF NOT EXISTS `date_fin_garantie` DATE DEFAULT NULL;

SET foreign_key_checks = 1;
