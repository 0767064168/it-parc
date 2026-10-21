-- ============================================
-- 007_auth_users_avatar.sql — Ajout avatar utilisateur
-- ============================================

USE `gestionnaire_parc_it`;

ALTER TABLE `auth_users` ADD COLUMN IF NOT EXISTS `avatar_url` VARCHAR(255) DEFAULT NULL AFTER `email`;
