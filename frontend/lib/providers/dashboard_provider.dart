// ============================================
// lib/providers/dashboard_provider.dart — Stats
// ============================================

import 'package:flutter/material.dart';
import '../data/api_client.dart';
import '../models/dashboard_stats.dart';

class DashboardProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();

  DashboardStats? _stats;
  bool _isLoading = false;
  String? _errorMessage;

  DashboardStats? get stats => _stats;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Récupérer les statistiques globales
  Future<void> fetchStats() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _api.get('/dashboard/stats');

      if (response.data['success'] == true) {
        _stats = DashboardStats.fromJson(response.data['data']);
      } else {
        _errorMessage = response.data['message'] ?? 'Erreur lors du calcul des statistiques';
      }
    } catch (e, stack) {
      debugPrint('DashboardProvider.fetchStats error: $e');
      debugPrint('$stack');
      _errorMessage = 'Erreur réseau lors de la récupération des statistiques';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
