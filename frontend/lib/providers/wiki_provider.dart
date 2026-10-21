// ============================================
// lib/providers/wiki_provider.dart
// ============================================
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import '../data/api_client.dart';
import '../models/wiki.dart';

class WikiProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();

  List<WikiArticle> _articles = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Pièces jointes de l'article courant
  List<WikiAttachment> _attachments = [];
  bool _isLoadingAttachments = false;
  bool _isUploading = false;

  // Derniers filtres appliqués
  String? _lastSearch;

  List<WikiArticle> get articles => _articles;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<WikiAttachment> get attachments => _attachments;
  bool get isLoadingAttachments => _isLoadingAttachments;
  bool get isUploading => _isUploading;

  // ─── Articles ─────────────────────────────────────
  Future<void> fetchArticles({String? search}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _lastSearch = search;

    try {
      final Map<String, dynamic>? params =
          (search != null && search.isNotEmpty) ? {'search': search} : null;
      final response = await _api.get('/wiki', queryParameters: params);
      if (response.data['success'] == true) {
        final List raw = response.data['data'] ?? [];
        _articles = raw.map((j) => WikiArticle.fromJson(j)).toList();
      } else {
        _errorMessage = response.data['message'] ?? 'Erreur de chargement du Wiki';
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
    await fetchArticles(search: _lastSearch);
  }

  Future<WikiArticle?> getArticleById(int id) async {
    try {
      final response = await _api.get('/wiki/$id');
      if (response.data['success'] == true) {
        return WikiArticle.fromJson(response.data['data']);
      }
    } catch (_) {}
    return null;
  }

  Future<bool> createArticle(Map<String, dynamic> data) async {
    try {
      final response = await _api.post('/wiki', data: data);
      if (response.data['success'] == true) {
        await refreshCurrentList();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateArticle(int id, Map<String, dynamic> data) async {
    try {
      final response = await _api.put('/wiki/$id', data: data);
      if (response.data['success'] == true) {
        await refreshCurrentList();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteArticle(int id) async {
    try {
      final response = await _api.delete('/wiki/$id');
      if (response.data['success'] == true) {
        await refreshCurrentList();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // ─── Pièces Jointes ───────────────────────────────
  Future<void> fetchAttachments(int articleId) async {
    _isLoadingAttachments = true;
    notifyListeners();
    try {
      final response = await _api.get('/wiki/$articleId/attachments');
      if (response.data['success'] == true) {
        final List raw = response.data['data'] ?? [];
        _attachments = raw.map((j) => WikiAttachment.fromJson(j)).toList();
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

  /// Upload d'un fichier (multipart/form-data)
  /// [filePath] : chemin local du fichier
  /// [fileName] : nom original du fichier
  Future<WikiAttachment?> uploadAttachment(int articleId, String filePath, String fileName) async {
    _isUploading = true;
    notifyListeners();
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath, filename: fileName),
      });

      // NE PAS passer Options(contentType:...) car ça écrase les headers
      // de l'intercepteur Dio (notamment le token JWT).
      // Dio détecte automatiquement le multipart/form-data quand data est un FormData.
      final response = await _api.dio.post(
        '/wiki/$articleId/attachments',
        data: formData,
      );

      if (response.data['success'] == true) {
        final attachment = WikiAttachment.fromJson(response.data['data']);
        _attachments.insert(0, attachment);
        notifyListeners();
        return attachment;
      }
      return null;
    } catch (e) {
      debugPrint('Upload wiki error: $e');
      return null;
    } finally {
      _isUploading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteAttachment(int attachmentId) async {
    try {
      final response = await _api.delete('/wiki/attachments/$attachmentId');
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

  /// Retourne l'URL de téléchargement pour un attachmentId
  String downloadUrl(int attachmentId) {
    // Utilise la même base URL que le Dio (ex: http://192.168.x.x:3000/api)
    final base = _api.dio.options.baseUrl.replaceAll(RegExp(r'/+$'), '');
    return '$base/wiki/attachments/$attachmentId/download';
  }

  /// Télécharge un fichier depuis [url] et le sauvegarde dans [savePath]
  /// Ajoute automatiquement le token JWT depuis SharedPreferences
  Future<void> downloadTo(String url, String savePath) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.keyToken);
    await _api.dio.download(
      url,
      savePath,
      options: Options(
        headers: token != null ? {'Authorization': 'Bearer $token'} : null,
        receiveTimeout: const Duration(minutes: 5),
      ),
    );
  }
}
