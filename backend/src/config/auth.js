'use strict';

function getJwtSecret() {
  const secret = (process.env.JWT_SECRET || '').trim();
  const insecurePlaceholder = /^REMPLACER_PAR_|^parc_it_default_|^change-me/i.test(secret);

  if (!secret || insecurePlaceholder || secret.length < 32) {
    throw new Error('JWT_SECRET doit être défini avec au moins 32 caractères aléatoires');
  }

  return secret;
}

module.exports = { getJwtSecret };
