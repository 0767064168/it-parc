// ============================================
// lib/providers/asset_provider.dart — Gestion Assets
// ============================================

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../data/api_client.dart';
import '../models/asset.dart';

class AssetProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();

  List<Asset> _assets = [];
  int _totalAssets = 0;
  int _currentPage = 1;
  final int _limit = 20;
  bool _isLoading = false;
  String? _errorMessage;

  Asset? _selectedAsset;
  bool _isLoadingDetails = false;

  // Options de filtres dynamiques récupérées depuis la DB
  List<String> _availableTypes = [];
  List<String> _availableSites = [];
  List<String> _availableDepartements = [];
  List<String> _availableStatuts = [];

  List<AssetAttachment> _attachments = [];
  bool _isLoadingAttachments = false;
  bool _isUploadingAttachment = false;

  // Derniers filtres appliqués
  String? _lastType;
  String? _lastStatut;
  String? _lastSite;
  String? _lastDepartement;
  String? _lastSearch;

  List<Asset> get assets => _assets;
  int get totalAssets => _totalAssets;
  int get currentPage => _currentPage;
  int get limit => _limit;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Asset? get selectedAsset => _selectedAsset;
  bool get isLoadingDetails => _isLoadingDetails;

  List<String> get availableTypes => _availableTypes;
  List<String> get availableSites => _availableSites;
  List<String> get availableDepartements => _availableDepartements;
  List<String> get availableStatuts => _availableStatuts;

  List<AssetAttachment> get attachments => _attachments;
  bool get isLoadingAttachments => _isLoadingAttachments;
  bool get isUploadingAttachment => _isUploadingAttachment;

  // Récupérer la liste paginée et filtrée
  Future<void> fetchAssets({
    int page = 1,
    String? type,
    String? statut,
    String? site,
    String? departement,
    String? search,
    bool isRefresh = false,
  }) async {
    if (_isLoading) return;

    _isLoading = true;
    _errorMessage = null;
    if (isRefresh || page == 1) {
      _assets = [];
      _currentPage = 1;
      _lastType = type;
      _lastStatut = statut;
      _lastSite = site;
      _lastDepartement = departement;
      _lastSearch = search;
    }
    notifyListeners();

    try {
      final Map<String, dynamic> queryParams = {
        'page': page,
        'limit': _limit,
      };

      if (type != null && type.isNotEmpty) queryParams['type'] = type;
      if (statut != null && statut.isNotEmpty) queryParams['statut'] = statut;
      if (site != null && site.isNotEmpty) queryParams['site'] = site;
      if (departement != null && departement.isNotEmpty) queryParams['departement'] = departement;
      if (search != null && search.isNotEmpty) queryParams['search'] = search;

      final response = await _api.get('/assets', queryParameters: queryParams);

      if (response.data['success'] == true) {
        final data = response.data['data'];
        final List rawAssets = data['rows'] ?? [];
        final parsedAssets = rawAssets.map((json) => Asset.fromJson(json)).toList();

        if (page == 1) {
          _assets = parsedAssets;
        } else {
          _assets.addAll(parsedAssets);
        }

        _totalAssets = data['total'] ?? _assets.length;
        _currentPage = page;
      } else {
        _errorMessage = response.data['message'] ?? 'Erreur lors du chargement des assets';
      }
    } catch (e) {
      _errorMessage = 'Erreur réseau lors de la récupération des assets';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Récupérer les détails d'un asset spécifique
  Future<Asset?> fetchAssetDetails(int id) async {
    _isLoadingDetails = true;
    _selectedAsset = null;
    notifyListeners();

    try {
      final response = await _api.get('/assets/$id');

      if (response.data['success'] == true) {
        _selectedAsset = Asset.fromJson(response.data['data']);
      }
    } catch (e) {
      _errorMessage = 'Erreur lors de la récupération des détails de l\'équipement';
    } finally {
      _isLoadingDetails = false;
      notifyListeners();
    }
    return _selectedAsset;
  }

  // Récupérer les options de filtres
  Future<void> fetchFilterOptions() async {
    try {
      final response = await _api.get('/assets/filter-options');
      if (response.data['success'] == true) {
        final data = response.data['data'];
        
        _availableTypes = List<String>.from(data['types'] ?? []);
        _availableSites = List<String>.from(data['sites'] ?? []);
        _availableDepartements = List<String>.from(data['departements'] ?? []);
        _availableStatuts = List<String>.from(data['statuts'] ?? []);
        
        notifyListeners();
      }
    } catch (_) {
      // Échec silencieux pour les filtres
    }
  }

  // Rafraîchir la liste courante avec les derniers filtres appliqués
  Future<void> refreshCurrentList() async {
    await fetchAssets(
      page: 1,
      type: _lastType,
      statut: _lastStatut,
      site: _lastSite,
      departement: _lastDepartement,
      search: _lastSearch,
      isRefresh: true,
    );
  }

  // Créer un nouvel asset (avec specs, securite, couts optionnels)
  Future<bool> createAsset(Map<String, dynamic> data) async {
    try {
      final response = await _api.post('/assets', data: data);
      if (response.data['success'] == true) {
        await refreshCurrentList();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Mettre à jour un asset existant
  Future<bool> updateAsset(int id, Map<String, dynamic> data) async {
    try {
      final response = await _api.put('/assets/$id', data: data);
      if (response.data['success'] == true) {
        // Rafraîchir les détails si c'est l'asset sélectionné
        if (_selectedAsset?.id == id) {
          await fetchAssetDetails(id);
        }
        await refreshCurrentList();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Archiver un asset (Motif d'archivage)
  Future<bool> archiveAsset(int id, String motif) async {
    try {
      final response = await _api.delete('/assets/$id', data: {'motif': motif});
      if (response.data['success'] == true) {
        await refreshCurrentList();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // ─── Pièces Jointes Assets ──────────────────────────
  Future<void> fetchAttachments(int assetId) async {
    _isLoadingAttachments = true;
    notifyListeners();
    try {
      final response = await _api.get('/assets/$assetId/attachments');
      if (response.data['success'] == true) {
        final List raw = response.data['data'] ?? [];
        _attachments = raw.map((j) => AssetAttachment.fromJson(j)).toList();
      } else {
        _attachments = [];
      }
    } catch (_) {
      _attachments = [];
    } finally {
      _isLoadingAttachments = false;
      notifyListeners();
    }
  }

  void clearAttachments() {
    _attachments = [];
    notifyListeners();
  }

  Future<AssetAttachment?> uploadAttachment(int assetId, String filePath, String fileName) async {
    _isUploadingAttachment = true;
    notifyListeners();
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath, filename: fileName),
      });

      final response = await _api.dio.post(
        '/assets/$assetId/attachments',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );

      if (response.data['success'] == true) {
        final attachment = AssetAttachment.fromJson(response.data['data']);
        _attachments.insert(0, attachment);
        notifyListeners();
        return attachment;
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      _isUploadingAttachment = false;
      notifyListeners();
    }
  }

  Future<bool> deleteAttachment(int attachmentId) async {
    try {
      final response = await _api.delete('/assets/attachments/$attachmentId');
      if (response.data['success'] == true) {
        _attachments.removeWhere((a) => a.id == attachmentId);
        notifyListeners();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  String downloadUrl(int attachmentId) {
    return '${_api.dio.options.baseUrl}/assets/attachments/$attachmentId/download';
  }

  Future<void> downloadTo(String url, String savePath) async {
    await _api.dio.download(url, savePath);
  }
}
