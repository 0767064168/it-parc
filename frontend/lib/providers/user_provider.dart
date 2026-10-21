// ============================================
// lib/providers/user_provider.dart
// ============================================

import 'package:flutter/material.dart';
import '../data/api_client.dart';

class UserItem {
  final int id;
  final String nom;
  final String prenom;
  final String? email;
  final String? role;
  final String? site;
  final String? departement;
  final bool actif;
  // Compte d'auth associé
  final int? authUserId;
  final bool? authActif;
  final String? authUsername;

  UserItem({
    required this.id,
    required this.nom,
    required this.prenom,
    this.email,
    this.role,
    this.site,
    this.departement,
    required this.actif,
    this.authUserId,
    this.authActif,
    this.authUsername,
  });

  String get nomComplet => '$prenom $nom';

  factory UserItem.fromJson(Map<String, dynamic> json) {
    return UserItem(
      id:           json['id'] ?? 0,
      nom:          json['nom'] ?? '',
      prenom:       json['prenom'] ?? '',
      email:        json['email'],
      role:         json['role'],
      site:         json['site'],
      departement:  json['departement'],
      actif:        json['actif'] == 1 || json['actif'] == true,
      authUserId:   json['auth_user_id'],
      authActif:    json['auth_actif'] == 1 || json['auth_actif'] == true,
      authUsername: json['auth_username'],
    );
  }
}

class UserProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();

  List<UserItem> _users = [];
  int _total = 0;
  bool _isLoading = false;
  String? _errorMessage;

  List<UserItem> get users => _users;
  int get total => _total;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchUsers() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _api.get('/users', queryParameters: {'limit': 200});
      if (response.data['success'] == true) {
        final data = response.data['data'];
        final List raw = (data is Map) ? (data['rows'] ?? data['items'] ?? []) : (data is List ? data : []);
        _users = raw.map((j) => UserItem.fromJson(j)).toList();
        _total = (data is Map) ? (data['total'] ?? _users.length) : _users.length;
      } else {
        _errorMessage = response.data['message'] ?? 'Erreur de chargement';
      }
    } catch (e) {
      _errorMessage = 'Erreur réseau';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createUser(Map<String, dynamic> data) async {
    try {
      final response = await _api.post('/users', data: data);
      if (response.data['success'] == true) {
        await fetchUsers();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateUser(int id, Map<String, dynamic> data) async {
    try {
      final response = await _api.put('/users/$id', data: data);
      if (response.data['success'] == true) {
        await fetchUsers();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> toggleAuthUser(int authId) async {
    try {
      final response = await _api.patch('/users/auth-accounts/$authId/toggle', data: {});
      if (response.data['success'] == true) {
        await fetchUsers();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteUser(int id) async {
    try {
      final response = await _api.delete('/users/$id');
      if (response.data['success'] == true) {
        await fetchUsers();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
