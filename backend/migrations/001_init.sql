-- ============================================
-- 001_init.sql — Schéma base de données
-- Gestionnaire de Parc Informatique
-- Version 1.0 — Direction IT Bouaké
-- ============================================

SET NAMES utf8mb4;
SET time_zone = '+00:00';
SET foreign_key_checks = 0;

-- ── Créer et sélectionner la base ────────────────────────────────────────────
CREATE DATABASE IF NOT EXISTS `gestionnaire_parc_it`
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE `gestionnaire_parc_it`;

-- ── Table: utilisateurs ───────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `utilisateurs` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `nom`         VARCHAR(100) NOT NULL,
  `prenom`      VARCHAR(100) NOT NULL,
  `departement` VARCHAR(100) DEFAULT NULL,
  `site`        VARCHAR(100) DEFAULT NULL,
  `email`       VARCHAR(150) DEFAULT NULL,
  `telephone`   VARCHAR(30)  DEFAULT NULL,
  `actif`       TINYINT(1)   NOT NULL DEFAULT 1,
  `created_at`  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_email` (`email`),
  KEY `idx_site` (`site`),
  KEY `idx_departement` (`departement`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ── Table: assets (équipements) ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `assets` (
  `id`            INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `Nom Machine`   VARCHAR(50)  NOT NULL,
  `serial_number` VARCHAR(100) DEFAULT NULL,
  `marque`        VARCHAR(100) DEFAULT NULL,
  `modele`        VARCHAR(150) DEFAULT NULL,
  `type`          ENUM(
    'laptop','desktop','ecran','imprimante','scanner','telephone',
    'tablette','pax_terminal','serveur','switch','routeur','autre'
  ) NOT NULL DEFAULT 'autre',
  `statut`        ENUM(
    'en_service','hors_service','reforme','en_maintenance','en_stock'
  ) NOT NULL DEFAULT 'en_service',
  `site`          VARCHAR(100) DEFAULT NULL,
  `departement`   VARCHAR(100) DEFAULT NULL,
  `notes`         TEXT         DEFAULT NULL,
  `created_at`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted_at`    DATETIME     DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_asset_tag` (`Nom Machine`),
  KEY `idx_type`        (`type`),
  KEY `idx_statut`      (`statut`),
  KEY `idx_site`        (`site`),
  KEY `idx_departement` (`departement`),
  KEY `idx_deleted`     (`deleted_at`),
  FULLTEXT KEY `ft_search` (`Nom Machine`, `serial_number`, `marque`, `modele`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ── Table: specs (spécifications techniques) ──────────────────────────────────
CREATE TABLE IF NOT EXISTS `specs` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `asset_id`    INT UNSIGNED NOT NULL,
  `ram`         VARCHAR(50)  DEFAULT NULL COMMENT 'Ex: 8 Go, 16 Go',
  `stockage`    VARCHAR(100) DEFAULT NULL COMMENT 'Ex: SSD 256 Go, HDD 1 To',
  `cpu`         VARCHAR(200) DEFAULT NULL COMMENT 'Ex: Intel Core i5-1135G7',
  `os`          VARCHAR(100) DEFAULT NULL COMMENT 'Ex: Windows 11 Pro',
  `version_os`  VARCHAR(50)  DEFAULT NULL,
  `mac_address` VARCHAR(20)  DEFAULT NULL,
  `imei`        VARCHAR(50)  DEFAULT NULL,
  `ip_address`  VARCHAR(45)  DEFAULT NULL,
  `hostname`    VARCHAR(100) DEFAULT NULL,
  `ecran_taille`VARCHAR(20)  DEFAULT NULL COMMENT 'Pour écrans: 24", 27"',
  `resolution`  VARCHAR(20)  DEFAULT NULL COMMENT 'Pour écrans: 1920x1080',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_asset_id` (`asset_id`),
  CONSTRAINT `fk_specs_asset` FOREIGN KEY (`asset_id`) REFERENCES `assets` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ── Table: affectations (historique) ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `affectations` (
  `id`               INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `asset_id`         INT UNSIGNED NOT NULL,
  `user_id`          INT UNSIGNED NOT NULL,
  `date_attribution` DATE         NOT NULL,
  `date_retrait`     DATE         DEFAULT NULL,
  `motif`            VARCHAR(255) DEFAULT NULL,
  `actif`            TINYINT(1)   NOT NULL DEFAULT 1,
  `created_at`       DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_asset_id` (`asset_id`),
  KEY `idx_user_id`  (`user_id`),
  KEY `idx_actif`    (`actif`),
  CONSTRAINT `fk_aff_asset` FOREIGN KEY (`asset_id`) REFERENCES `assets` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_aff_user`  FOREIGN KEY (`user_id`)  REFERENCES `utilisateurs` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ── Table: securite (conformité sécurité) ────────────────────────────────────
CREATE TABLE IF NOT EXISTS `securite` (
  `id`        INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `asset_id`  INT UNSIGNED NOT NULL,
  `defender`  TINYINT(1)   NOT NULL DEFAULT 0 COMMENT 'Windows Defender actif',
  `edr`       TINYINT(1)   NOT NULL DEFAULT 0 COMMENT 'Agent EDR déployé',
  `intune`    TINYINT(1)   NOT NULL DEFAULT 0 COMMENT 'Microsoft Intune enrollé',
  `entra_id`  TINYINT(1)   NOT NULL DEFAULT 0 COMMENT 'Azure AD / Entra ID joiné',
  `bitlocker` TINYINT(1)   NOT NULL DEFAULT 0 COMMENT 'BitLocker activé',
  `onedrive`  TINYINT(1)   NOT NULL DEFAULT 0 COMMENT 'OneDrive actif',
  `updated_at`DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_asset_id` (`asset_id`),
  CONSTRAINT `fk_sec_asset` FOREIGN KEY (`asset_id`) REFERENCES `assets` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ── Table: couts (informations financières) ───────────────────────────────────
CREATE TABLE IF NOT EXISTS `couts` (
  `id`               INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  `asset_id`         INT UNSIGNED  NOT NULL,
  `prix`             DECIMAL(12,2) DEFAULT NULL,
  `fournisseur`      VARCHAR(150)  DEFAULT NULL,
  `bon_commande`     VARCHAR(100)  DEFAULT NULL,
  `date_acquisition` DATE          DEFAULT NULL,
  `fin_garantie`     DATE          DEFAULT NULL,
  `devise`           VARCHAR(10)   DEFAULT 'XOF',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_asset_id` (`asset_id`),
  KEY `idx_fin_garantie` (`fin_garantie`),
  CONSTRAINT `fk_couts_asset` FOREIGN KEY (`asset_id`) REFERENCES `assets` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ── Table: auth_users (comptes d'accès) ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS `auth_users` (
  `id`            INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `username`      VARCHAR(50)  NOT NULL,
  `password_hash` VARCHAR(255) NOT NULL,
  `role`          ENUM('admin','technicien','lecteur') NOT NULL DEFAULT 'lecteur',
  `nom`           VARCHAR(100) DEFAULT NULL,
  `prenom`        VARCHAR(100) DEFAULT NULL,
  `actif`         TINYINT(1)   NOT NULL DEFAULT 1,
  `last_login`    DATETIME     DEFAULT NULL,
  `created_at`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_username` (`username`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ── Table: activity_logs (audit trail) ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS `activity_logs` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id`     INT UNSIGNED DEFAULT NULL,
  `action`      VARCHAR(50)  NOT NULL,
  `entity_type` VARCHAR(50)  DEFAULT NULL,
  `entity_id`   INT UNSIGNED DEFAULT NULL,
  `details`     JSON         DEFAULT NULL,
  `ip_address`  VARCHAR(45)  DEFAULT NULL,
  `created_at`  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_user_id`     (`user_id`),
  KEY `idx_action`      (`action`),
  KEY `idx_entity`      (`entity_type`, `entity_id`),
  KEY `idx_created_at`  (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SET foreign_key_checks = 1;
