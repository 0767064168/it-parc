// ============================================
// lib/data/api_client.dart — Client HTTP Dio
// ============================================

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';

class ApiClient {
  late final Dio dio;

  /// Called when the server returns 401 (token expired / invalid).
  /// AuthProvider registers its logout() here so the whole app reacts.
  static void Function()? onUnauthorized;

  // Instance unique (Singleton)
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  ApiClient._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.apiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Intercepteur pour ajouter le token JWT et intercepter les erreurs 401
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString(AppConstants.keyToken);
          
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          if (e.response?.statusCode == 401 && !e.requestOptions.path.contains('/auth/login')) {
            // Token expiré ou invalide -> déconnexion automatique
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove(AppConstants.keyToken);
            await prefs.remove(AppConstants.keyUser);
            // Notifier l'AuthProvider pour rediriger vers /login
            onUnauthorized?.call();
          }
          return handler.next(e);
        },
      ),
    );
  }

  // Méthodes HTTP raccourcies
  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) async {
    return await dio.get(path, queryParameters: queryParameters);
  }

  Future<Response> post(String path, {dynamic data}) async {
    return await dio.post(path, data: data);
  }

  Future<Response> put(String path, {dynamic data}) async {
    return await dio.put(path, data: data);
  }

  Future<Response> delete(String path, {dynamic data}) async {
    return await dio.delete(path, data: data);
  }

  Future<Response> patch(String path, {dynamic data}) async {
    return await dio.patch(path, data: data);
  }
}
