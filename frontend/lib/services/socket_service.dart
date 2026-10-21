// ============================================
// lib/services/socket_service.dart — Gestion Socket.io
// ============================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../core/constants.dart';

class SocketService {
  // ── Singleton ────────────────────────────────────────────────────────────────
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  io.Socket? _socket;
  bool _isConnected = false;

  // ── Streams de notifications ─────────────────────────────────────────────────
  final _notificationController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onNotification => _notificationController.stream;

  // ── Connexion ────────────────────────────────────────────────────────────────
  void connect(String userId, String token) {
    if (_isConnected) return;

    _socket = io.io(
      AppConstants.apiBaseUrl.replaceAll('/api', ''),
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setExtraHeaders({'Authorization': 'Bearer $token'})
          .build(),
    );

    _socket!.connect();

    _socket!.onConnect((_) {
      _isConnected = true;
      if (kDebugMode) debugPrint('[Socket] Connecté – jointure room user_$userId');
      _socket!.emit('join', {'userId': userId});
    });

    _socket!.on('notification', (data) {
      if (kDebugMode) debugPrint('[Socket] Notification reçue (user): $data');
      if (data is Map<String, dynamic>) {
        _notificationController.add(data);
      }
    });

    _socket!.on('new_notification', (data) {
      if (kDebugMode) debugPrint('[Socket] Nouvelle notification reçue: $data');
      if (data is Map<String, dynamic>) {
        _notificationController.add(data);
      }
    });

    _socket!.onDisconnect((_) {
      _isConnected = false;
      if (kDebugMode) debugPrint('[Socket] Déconnecté');
    });

    _socket!.onError((err) {
      if (kDebugMode) debugPrint('[Socket] Erreur: $err');
    });
  }

  // ── Déconnexion ──────────────────────────────────────────────────────────────
  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
    if (kDebugMode) debugPrint('[Socket] Service déconnecté');
  }

  bool get isConnected => _isConnected;

  void dispose() {
    disconnect();
    _notificationController.close();
  }
}
