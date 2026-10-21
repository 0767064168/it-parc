// ============================================
// lib/providers/reports_provider.dart — State Management pour les Rapports Avancés
// ============================================

import 'package:flutter/material.dart';
import '../data/api_client.dart';

class ReportsProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();

  Map<String, dynamic>? _reportsData;
  bool _isLoading = false;
  String? _errorMessage;

  Map<String, dynamic>? get reportsData => _reportsData;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Récupérer les rapports statistiques avancés
  Future<void> fetchReports() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _api.get('/dashboard/reports');

      if (response.data['success'] == true) {
        _reportsData = response.data['data'];
      } else {
        _errorMessage = response.data['message'] ?? 'Erreur lors du calcul des rapports';
      }
    } catch (e) {
      debugPrint('ReportsProvider.fetchReports error: $e');
      _errorMessage = 'Erreur réseau lors de la récupération des rapports';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
