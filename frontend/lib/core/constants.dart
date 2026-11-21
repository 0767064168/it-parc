// ============================================
// lib/core/constants.dart — Constantes globales
// ============================================

import 'package:flutter/foundation.dart';

class AppConstants {
  static const String _configuredApiBaseUrl =
      String.fromEnvironment('API_BASE_URL');

  static String get apiBaseUrl {
    final configuredUrl = _configuredApiBaseUrl.trim();
    if (configuredUrl.isNotEmpty) {
      return configuredUrl.replaceFirst(RegExp(r'/+$'), '');
    }

    if (kIsWeb) {
      final pageUri = Uri.base;
      if (isLocalHost(pageUri.host)) {
        final host = pageUri.host.contains(':')
            ? '[${pageUri.host}]'
            : pageUri.host;
        return 'http://$host:3000/api';
      }
      return '${pageUri.origin}/api';
    }

    // Pour un téléphone sur le même Wi-Fi, définir API_BASE_URL avec l'IP du serveur.
    // Pour l'émulateur Android, définir API_BASE_URL à http://10.0.2.2:3000/api.
    return 'http://localhost:3000/api';
  }

  static bool get isHostedWeb =>
      kIsWeb && !isLocalHost(Uri.base.host);

  static bool isLocalHost(String host) =>
      host == 'localhost' || host == '127.0.0.1' || host == '::1';

  
  // Clés SharedPreferences
  static const String keyToken = 'auth_token';
  static const String keyUser = 'auth_user';

  // Rôles utilisateurs
  static const String roleAdmin = 'admin';
  static const String roleTechnicien = 'technicien';
  static const String roleLecteur = 'lecteur';
}
