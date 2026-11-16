// ============================================
// lib/core/constants.dart — Constantes globales
// ============================================

class AppConstants {
  // Pour un vrai téléphone sur le même réseau Wi-Fi, utiliser l'IP de la machine serveur.
  // Pour l'émulateur Android : utiliser 10.0.2.2 (alias de localhost).
  static const String apiBaseUrl = 'https://parc-it.vercel.app/api';

  
  // Clés SharedPreferences
  static const String keyToken = 'auth_token';
  static const String keyUser = 'auth_user';

  // Rôles utilisateurs
  static const String roleAdmin = 'admin';
  static const String roleTechnicien = 'technicien';
  static const String roleLecteur = 'lecteur';
}
