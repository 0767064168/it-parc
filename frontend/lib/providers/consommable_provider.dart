import 'package:flutter/material.dart';
import '../data/api_client.dart';
import '../models/consommable.dart';

class ConsommableProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();

  List<Consommable> _consommables = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Derniers filtres appliqués
  String? _lastSearch;

  List<Consommable> get consommables => _consommables;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchConsommables({String? search}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _lastSearch = search;

    try {
      final Map<String, dynamic>? params = (search != null && search.isNotEmpty) ? {'search': search} : null;
      final response = await _api.get('/consommables', queryParameters: params);
      if (response.data['success'] == true) {
        final List raw = response.data['data'] ?? [];
        _consommables = raw.map((j) => Consommable.fromJson(j)).toList();
      } else {
        _errorMessage = response.data['message'] ?? 'Erreur de chargement des consommables';
      }
    } catch (e) {
      _errorMessage = 'Erreur réseau';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Rafraîchir la liste courante avec les derniers filtres appliqués
  Future<void> refreshCurrentList() async {
    await fetchConsommables(search: _lastSearch);
  }

  Future<bool> createConsommable(Map<String, dynamic> data) async {
    try {
      final response = await _api.post('/consommables', data: data);
      if (response.data['success'] == true) {
        await refreshCurrentList();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateConsommable(int id, Map<String, dynamic> data) async {
    try {
      final response = await _api.put('/consommables/$id', data: data);
      if (response.data['success'] == true) {
        await refreshCurrentList();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteConsommable(int id) async {
    try {
      final response = await _api.delete('/consommables/$id');
      if (response.data['success'] == true) {
        await refreshCurrentList();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> adjustStock(int id, int diff) async {
    try {
      final response = await _api.patch('/consommables/$id/adjust', data: {'diff': diff});
      if (response.data['success'] == true) {
        await refreshCurrentList();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
