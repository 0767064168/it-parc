// ============================================
// lib/providers/affectation_provider.dart
// ============================================

import 'package:flutter/material.dart';
import '../data/api_client.dart';

class AffectationItem {
  final int id;
  final int assetId;
  final int userId;
  final String assetTag;
  final String marque;
  final String? modele;
  final String type;
  final String statut;
  final String utilisateurNom;
  final String? departement;
  final String? site;
  final String? email;
  final String dateAttribution;
  final String? dateRetrait;
  final String? motif;
  final bool actif;

  AffectationItem({
    required this.id,
    required this.assetId,
    required this.userId,
    required this.assetTag,
    required this.marque,
    this.modele,
    required this.type,
    required this.statut,
    required this.utilisateurNom,
    this.departement,
    this.site,
    this.email,
    required this.dateAttribution,
    this.dateRetrait,
    this.motif,
    required this.actif,
  });

  factory AffectationItem.fromJson(Map<String, dynamic> json) {
    return AffectationItem(
      id:               json['id'] ?? 0,
      assetId:          json['asset_id'] ?? 0,
      userId:           json['user_id'] ?? 0,
      assetTag:         json['asset_tag'] ?? '',
      marque:           json['marque'] ?? '',
      modele:           json['modele'],
      type:             json['type'] ?? '',
      statut:           json['statut'] ?? '',
      utilisateurNom:   json['utilisateur_nom'] ?? '',
      departement:      json['departement'],
      site:             json['site'],
      email:            json['email'],
      dateAttribution:  json['date_attribution']?.toString().split('T').first ?? '',
      dateRetrait:      json['date_retrait']?.toString().split('T').first,
      motif:            json['motif'],
      actif:            json['actif'] == 1 || json['actif'] == true,
    );
  }
}

class AffectationProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();

  List<AffectationItem> _affectations = [];
  int _total = 0;
  int _currentPage = 1;
  bool _isLoading = false;
  String? _errorMessage;
  String? _lastError; // Dernière erreur de mutation (create/update/delete)

  // Derniers filtres appliqués
  int? _lastAssetId;
  int? _lastUserId;
  bool? _lastActif;

  List<AffectationItem> get affectations => _affectations;
  int get total => _total;
  int get currentPage => _currentPage;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get lastError => _lastError;

  Future<void> fetchAffectations({
    int page = 1,
    int? assetId,
    int? userId,
    bool? actif,
    bool isRefresh = false,
  }) async {
    if (_isLoading) return;
    _isLoading = true;
    _errorMessage = null;
    if (isRefresh || page == 1) {
      _affectations = [];
      _currentPage = 1;
      _lastAssetId = assetId;
      _lastUserId = userId;
      _lastActif = actif;
    }
    notifyListeners();

    try {
      final Map<String, dynamic> params = {'page': page, 'limit': 20};
      if (assetId != null) params['asset_id'] = assetId;
      if (userId != null)  params['user_id']  = userId;
      if (actif != null)   params['actif']    = actif ? 'true' : 'false';

      final response = await _api.get('/affectations', queryParameters: params);

      if (response.data['success'] == true) {
        final data = response.data['data'];
        final List raw = data['rows'] ?? [];
        final parsed = raw.map((j) => AffectationItem.fromJson(j)).toList();

        if (page == 1) {
          _affectations = parsed;
        } else {
          _affectations.addAll(parsed);
        }
        _total = data['total'] ?? _affectations.length;
        _currentPage = page;
      } else {
        _errorMessage = response.data['message'] ?? 'Erreur de chargement';
      }
    } catch (e) {
      _errorMessage = 'Erreur réseau lors du chargement des affectations';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Rafraîchir la liste courante avec les derniers filtres appliqués
  Future<void> refreshCurrentList() async {
    await fetchAffectations(
      page: 1,
      assetId: _lastAssetId,
      userId: _lastUserId,
      actif: _lastActif,
      isRefresh: true,
    );
  }

  Future<bool> createAffectation({
    required int assetId,
    int? userId,
    required String dateAttribution,
    String? motif,
    String? nom,
    String? prenom,
    String? departement,
  }) async {
    _lastError = null;
    try {
      final response = await _api.post('/affectations', data: {
        'asset_id':         assetId,
        if (userId != null) 'user_id': userId,
        'date_attribution': dateAttribution,
        if (motif != null && motif.isNotEmpty) 'motif': motif,
        if (nom != null && nom.isNotEmpty) 'nom': nom,
        if (prenom != null && prenom.isNotEmpty) 'prenom': prenom,
        if (departement != null && departement.isNotEmpty) 'departement': departement,
      });
      if (response.data['success'] == true) {
        await refreshCurrentList();
        return true;
      }
      _lastError = response.data['message'] ?? 'Erreur lors de l\'affectation';
      return false;
    } on Exception catch (e) {
      _lastError = e.toString();
      return false;
    }
  }

  Future<bool> retraitAffectation({
    required int assetId,
    String? motif,
    String nouveauStatut = 'hors_service',
  }) async {
    _lastError = null;
    try {
      final response = await _api.post('/affectations/retrait', data: {
        'asset_id':      assetId,
        'nouveau_statut': nouveauStatut,
        if (motif != null && motif.isNotEmpty) 'motif': motif,
      });
      if (response.data['success'] == true) {
        await refreshCurrentList();
        return true;
      }
      _lastError = response.data['message'] ?? 'Erreur lors du retrait';
      return false;
    } on Exception catch (e) {
      _lastError = e.toString();
      return false;
    }
  }

  Future<bool> updateAffectation(int id, Map<String, dynamic> data) async {
    _lastError = null;
    try {
      final response = await _api.put('/affectations/$id', data: data);
      if (response.data['success'] == true) {
        await refreshCurrentList();
        return true;
      }
      _lastError = response.data['message'] ?? 'Erreur lors de la mise à jour';
      return false;
    } on Exception catch (e) {
      _lastError = e.toString();
      return false;
    }
  }

  Future<bool> deleteAffectation(int id) async {
    _lastError = null;
    try {
      final response = await _api.delete('/affectations/$id');
      if (response.data['success'] == true) {
        await refreshCurrentList();
        return true;
      }
      _lastError = response.data['message'] ?? 'Erreur lors de la suppression';
      return false;
    } on Exception catch (e) {
      _lastError = e.toString();
      return false;
    }
  }
}
