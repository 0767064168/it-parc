-- ============================================
-- 006_auth_users_email.sql — Ajout colonne email
-- ============================================

USE `gestionnaire_parc_it`;

SET foreign_key_checks = 0;

-- Rajout de la colonne email sur la table auth_users si elle n'existe pas
ALTER TABLE `auth_users` ADD COLUMN IF NOT EXISTS `email` VARCHAR(150) DEFAULT NULL;

-- Initialisation des adresses e-mail pour les comptes existants
UPDATE `auth_users` SET `email` = 'k.konan@entreprise.ci' WHERE `username` = 'admin';
UPDATE `auth_users` SET `email` = 'a.kouassi@entreprise.ci' WHERE `username` = 'technicien';
UPDATE `auth_users` SET `email` = 'a.brou@entreprise.ci' WHERE `username` = 'lecteur';

SET foreign_key_checks = 1;
