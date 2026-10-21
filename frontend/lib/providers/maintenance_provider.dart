import 'package:flutter/material.dart';
import '../data/api_client.dart';
import '../models/maintenance.dart';

class MaintenanceProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();

  List<Maintenance> _maintenances = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Derniers filtres appliqués
  int? _lastAssetId;
  String? _lastSearch;

  List<Maintenance> get maintenances => _maintenances;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchMaintenances({int? assetId, String? search}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _lastAssetId = assetId;
    _lastSearch = search;

    try {
      final Map<String, dynamic> params = {};
      if (assetId != null) params['asset_id'] = assetId;
      if (search != null && search.isNotEmpty) params['search'] = search;

      final response = await _api.get('/maintenances', queryParameters: params.isEmpty ? null : params);
      if (response.data['success'] == true) {
        final List raw = response.data['data'] ?? [];
        _maintenances = raw.map((j) => Maintenance.fromJson(j)).toList();
      } else {
        _errorMessage = response.data['message'] ?? 'Erreur de chargement des maintenances';
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
    await fetchMaintenances(assetId: _lastAssetId, search: _lastSearch);
  }

  Future<bool> createMaintenance(Map<String, dynamic> data) async {
    try {
      final response = await _api.post('/maintenances', data: data);
      if (response.data['success'] == true) {
        await refreshCurrentList();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateMaintenance(int id, Map<String, dynamic> data) async {
    try {
      final response = await _api.put('/maintenances/$id', data: data);
      if (response.data['success'] == true) {
        await refreshCurrentList();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteMaintenance(int id) async {
    try {
      final response = await _api.delete('/maintenances/$id');
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
