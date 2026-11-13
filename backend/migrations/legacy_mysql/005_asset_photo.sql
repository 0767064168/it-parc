-- ============================================
-- 005_asset_photo.sql — Ajout photo d'équipement
-- ============================================

USE `gestionnaire_parc_it`;

ALTER TABLE `assets` ADD COLUMN IF NOT EXISTS `photo_url` VARCHAR(255) DEFAULT NULL AFTER `notes`;
