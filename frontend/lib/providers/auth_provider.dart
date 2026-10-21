// ============================================
// lib/providers/auth_provider.dart — Gestion Auth
// ============================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/api_client.dart';
import '../core/constants.dart';
import '../models/user.dart';
import 'package:dio/dio.dart';

class AuthProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();
  
  bool _isAuthenticated = false;
  bool _isLoading = true;
  String? _token;
  User? _currentUser;
  String? _errorMessage;

  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get token => _token;
  User? get currentUser => _currentUser;
  String? get errorMessage => _errorMessage;

  AuthProvider() {
    // Wire up the 401 auto-logout: any expired token in any API call
    // will call logout() which clears state and triggers GoRouter redirect.
    ApiClient.onUnauthorized = () => logout();
    checkAuth();
  }

  // Vérifier la session stockée au démarrage de l'app
  // La session n'est PAS restaurée : l'utilisateur doit se reconnecter à chaque ouverture.
  Future<void> checkAuth() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Charger et appliquer l'URL du serveur personnalisée si elle existe
      final savedUrl = prefs.getString('server_url');
      if (savedUrl != null && savedUrl.isNotEmpty) {
        _api.dio.options.baseUrl = savedUrl;
      }

      // Supprimer la session précédente à chaque démarrage de l'app.
      // L'utilisateur doit saisir ses identifiants à chaque ouverture.
      await prefs.remove(AppConstants.keyToken);
      await prefs.remove(AppConstants.keyUser);

      _token = null;
      _currentUser = null;
      _isAuthenticated = false;
    } catch (e) {
      _isAuthenticated = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Obtenir l'URL du serveur actuelle
  String getServerUrl() {
    return _api.dio.options.baseUrl;
  }

  // Mettre à jour l'URL du serveur
  Future<void> updateServerUrl(String newUrl) async {
    _api.dio.options.baseUrl = newUrl;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_url', newUrl);
    notifyListeners();
  }

  // Se connecter
  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _api.post('/auth/login', data: {
        'username': username,
        'password': password,
      });

      if (response.data['success'] == true) {
        final data = response.data['data'];
        _token = data['token'];
        _currentUser = User.fromJson(data['user']);
        _isAuthenticated = true;

        // Stocker localement
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(AppConstants.keyToken, _token!);
        await prefs.setString(AppConstants.keyUser, jsonEncode(data['user']));
        
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = response.data['message'] ?? 'Erreur d\'identification';
      }
    } catch (e) {
      if (e is DioException && e.response != null) {
        final resData = e.response!.data;
        if (resData is Map && resData['message'] != null) {
          _errorMessage = resData['message'];
        } else {
          _errorMessage = 'Erreur serveur (${e.response!.statusCode})';
        }
      } else {
        _errorMessage = 'Identifiants incorrects ou serveur injoignable';
      }
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  // Se déconnecter
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _api.post('/auth/logout');
    } catch (_) {
      // Ignorer l'erreur réseau lors de la déconnexion
    }

    _token = null;
    _currentUser = null;
    _isAuthenticated = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.keyToken);
    await prefs.remove(AppConstants.keyUser);

    _isLoading = false;
    notifyListeners();
  }

  // Changer de mot de passe
  Future<bool> changePassword(String currentPassword, String newPassword) async {
    try {
      final response = await _api.post('/auth/change-password', data: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      });
      return response.data['success'] == true;
    } catch (e) {
      return false;
    }
  }

  // Mettre à jour l'avatar de l'utilisateur
  Future<bool> uploadAvatar(String filePath, String fileName) async {
    try {
      final formData = FormData.fromMap({
        'avatar': await MultipartFile.fromFile(filePath, filename: fileName),
      });

      final response = await _api.dio.post(
        '/auth/avatar',
        data: formData,
      );

      if (response.data['success'] == true) {
        final newAvatarUrl = response.data['data']['avatarUrl'];
        if (_currentUser != null) {
          final updatedUser = User(
            id: _currentUser!.id,
            nom: _currentUser!.nom,
            prenom: _currentUser!.prenom,
            departement: _currentUser!.departement,
            site: _currentUser!.site,
            email: _currentUser!.email,
            telephone: _currentUser!.telephone,
            actif: _currentUser!.actif,
            username: _currentUser!.username,
            role: _currentUser!.role,
            avatarUrl: newAvatarUrl,
          );
          _currentUser = updatedUser;

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(AppConstants.keyUser, jsonEncode(updatedUser.toJson()));
          notifyListeners();
        }
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
