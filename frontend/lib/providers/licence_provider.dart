import 'package:flutter/material.dart';
import '../data/api_client.dart';
import '../models/licence.dart';

class LicenceProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();

  List<Licence> _licences = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Derniers filtres appliqués
  String? _lastSearch;

  List<Licence> get licences => _licences;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchLicences({String? search}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _lastSearch = search;

    try {
      final Map<String, dynamic>? params = (search != null && search.isNotEmpty) ? {'search': search} : null;
      final response = await _api.get('/licences', queryParameters: params);
      if (response.data['success'] == true) {
        final List raw = response.data['data'] ?? [];
        _licences = raw.map((j) => Licence.fromJson(j)).toList();
      } else {
        _errorMessage = response.data['message'] ?? 'Erreur de chargement des licences';
      }
    } catch (e) {
      _errorMessage = 'Erreur réseau';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Licence?> getLicenceById(int id) async {
    try {
      final response = await _api.get('/licences/$id');
      if (response.data['success'] == true) {
        return Licence.fromJson(response.data['data']);
      }
    } catch (_) {}
    return null;
  }

  // Rafraîchir la liste courante avec les derniers filtres appliqués
  Future<void> refreshCurrentList() async {
    await fetchLicences(search: _lastSearch);
  }

  Future<bool> createLicence(Map<String, dynamic> data) async {
    try {
      final response = await _api.post('/licences', data: data);
      if (response.data['success'] == true) {
        await refreshCurrentList();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateLicence(int id, Map<String, dynamic> data) async {
    try {
      final response = await _api.put('/licences/$id', data: data);
      if (response.data['success'] == true) {
        await refreshCurrentList();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteLicence(int id) async {
    try {
      final response = await _api.delete('/licences/$id');
      if (response.data['success'] == true) {
        await refreshCurrentList();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> allocateLicence(int licenceId, int userId) async {
    try {
      final response = await _api.post('/licences/$licenceId/allocate', data: {'userId': userId});
      if (response.data['success'] == true) {
        await refreshCurrentList();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deallocateLicence(int licenceId, int allocationId) async {
    try {
      final response = await _api.delete('/licences/$licenceId/deallocate/$allocationId');
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
