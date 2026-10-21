// ============================================
// lib/providers/ticket_provider.dart — State Management Tickets
// ============================================

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../data/api_client.dart';
import '../models/ticket.dart';

class TicketProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();

  List<Ticket> _tickets = [];
  Ticket? _selectedTicket;
  bool _isLoading = false;
  String? _errorMessage;
  
  // Stats & Reports
  Map<String, dynamic>? _dashboardStats;
  Map<String, dynamic>? _reportsData;
  List<InAppNotification> _notifications = [];

  // Derniers filtres appliqués
  String? _lastStatut;
  String? _lastPriorite;
  String? _lastType;
  String? _lastSite;
  String? _lastTechnicienId;
  String? _lastSearch;

  List<Ticket> get tickets => _tickets;
  Ticket? get selectedTicket => _selectedTicket;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Map<String, dynamic>? get dashboardStats => _dashboardStats;
  Map<String, dynamic>? get reportsData => _reportsData;
  List<InAppNotification> get notifications => _notifications;

  int get unreadNotificationsCount => _notifications.where((n) => !n.lu).length;

  // 1. Récupérer la liste des tickets avec filtres
  Future<void> fetchTickets({
    String? statut,
    String? priorite,
    String? type,
    String? site,
    String? technicienId,
    String? search,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _lastStatut = statut;
    _lastPriorite = priorite;
    _lastType = type;
    _lastSite = site;
    _lastTechnicienId = technicienId;
    _lastSearch = search;

    try {
      final queryParams = <String, dynamic>{
        if (statut != null && statut.isNotEmpty) 'statut': statut,
        if (priorite != null && priorite.isNotEmpty) 'priorite': priorite,
        if (type != null && type.isNotEmpty) 'type': type,
        if (site != null && site.isNotEmpty) 'site': site,
        if (technicienId != null && technicienId.isNotEmpty) 'technicien_id': technicienId,
        if (search != null && search.isNotEmpty) 'search': search,
      };

      final response = await _api.get('/tickets', queryParameters: queryParams);

      if (response.data['success'] == true) {
        final List rows = response.data['data']['rows'] ?? [];
        _tickets = rows.map((json) => Ticket.fromJson(json)).toList();
      } else {
        _errorMessage = response.data['message'] ?? 'Erreur de récupération des tickets';
      }
    } catch (e) {
      debugPrint('TicketProvider.fetchTickets error: $e');
      _errorMessage = 'Erreur réseau lors de la récupération des tickets';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 2. Récupérer un ticket par son ID
  Future<Ticket?> fetchTicketById(int id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _api.get('/tickets/$id');

      if (response.data['success'] == true) {
        _selectedTicket = Ticket.fromJson(response.data['data']);
        return _selectedTicket;
      } else {
        _errorMessage = response.data['message'] ?? 'Ticket introuvable';
      }
    } catch (e) {
      debugPrint('TicketProvider.fetchTicketById error: $e');
      _errorMessage = 'Erreur réseau';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return null;
  }

  // Rafraîchir la liste courante avec les derniers filtres appliqués
  Future<void> refreshCurrentList() async {
    await fetchTickets(
      statut: _lastStatut,
      priorite: _lastPriorite,
      type: _lastType,
      site: _lastSite,
      technicienId: _lastTechnicienId,
      search: _lastSearch,
    );
  }

  // 3. Créer un ticket
  Future<Ticket?> createTicket({
    required String titre,
    required String description,
    required String type,
    required String priorite,
    int? assetId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _api.post('/tickets', data: {
        'titre': titre,
        'description': description,
        'type': type,
        'priorite': priorite,
        'asset_id': assetId,
      });

      if (response.data['success'] == true) {
        final newTicket = Ticket.fromJson(response.data['data']);
        _tickets.insert(0, newTicket);
        await refreshCurrentList();
        await fetchDashboardStats();
        _isLoading = false;
        notifyListeners();
        return newTicket;
      } else {
        _errorMessage = response.data['message'] ?? 'Erreur lors de la création';
      }
    } catch (e) {
      _errorMessage = 'Erreur réseau';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return null;
  }

  // 4. Modifier le statut d'un ticket
  Future<bool> changeStatus(int id, String statut, String commentaire) async {
    try {
      final response = await _api.patch('/tickets/$id/statut', data: {
        'statut': statut,
        'commentaire': commentaire,
      });

      if (response.data['success'] == true) {
        if (_selectedTicket != null && _selectedTicket!.id == id) {
          await fetchTicketById(id);
        }
        await refreshCurrentList();
        await fetchDashboardStats();
        return true;
      }
    } catch (e) {
      debugPrint('TicketProvider.changeStatus error: $e');
    }
    return false;
  }

  // 5. Assigner un technicien
  Future<bool> assignTicket(int id, int technicienId) async {
    try {
      final response = await _api.patch('/tickets/$id/assigner', data: {
        'technicien_id': technicienId,
      });

      if (response.data['success'] == true) {
        if (_selectedTicket != null && _selectedTicket!.id == id) {
          await fetchTicketById(id);
        }
        await refreshCurrentList();
        await fetchDashboardStats();
        return true;
      }
    } catch (e) {
      debugPrint('TicketProvider.assignTicket error: $e');
    }
    return false;
  }

  // 6. Ajouter un commentaire
  Future<TicketComment?> addComment(int ticketId, String contenu, {String type = 'public'}) async {
    try {
      final response = await _api.post('/tickets/$ticketId/commentaires', data: {
        'contenu': contenu,
        'type': type,
      });

      if (response.data['success'] == true) {
        final comment = TicketComment.fromJson(response.data['data']);
        if (_selectedTicket != null && _selectedTicket!.id == ticketId) {
          _selectedTicket!.commentaires.add(comment);
          notifyListeners();
        }
        return comment;
      }
    } catch (e) {
      debugPrint('TicketProvider.addComment error: $e');
    }
    return null;
  }

  // 7. Évaluer la satisfaction
  Future<bool> evaluateTicket(int id, int note, String? commentaire) async {
    try {
      final response = await _api.post('/tickets/$id/evaluer', data: {
        'note': note,
        'commentaire': commentaire,
      });

      if (response.data['success'] == true) {
        if (_selectedTicket != null && _selectedTicket!.id == id) {
          await fetchTicketById(id);
        }
        await refreshCurrentList();
        await fetchDashboardStats();
        return true;
      }
    } catch (e) {
      debugPrint('TicketProvider.evaluateTicket error: $e');
    }
    return false;
  }

  // 8. Uploader une pièce jointe
  Future<bool> uploadAttachment(int ticketId, List<int> fileBytes, String fileName, {String? filePath}) async {
    try {
      MultipartFile file;
      if (filePath != null && filePath.isNotEmpty) {
        file = await MultipartFile.fromFile(filePath, filename: fileName);
      } else {
        file = MultipartFile.fromBytes(fileBytes, filename: fileName);
      }

      final formData = FormData.fromMap({
        'file': file,
      });

      final response = await _api.dio.post('/tickets/$ticketId/pieces-jointes', data: formData);

      if (response.data['success'] == true) {
        if (_selectedTicket != null && _selectedTicket!.id == ticketId) {
          await fetchTicketById(ticketId);
        }
        await refreshCurrentList();
        return true;
      }
    } catch (e) {
      debugPrint('TicketProvider.uploadAttachment error: $e');
    }
    return false;
  }

  // 9. Récupérer les stats temps réel du dashboard IT
  Future<void> fetchDashboardStats() async {
    try {
      final response = await _api.get('/tickets/stats/dashboard');
      if (response.data['success'] == true) {
        _dashboardStats = response.data['data'];
        notifyListeners();
      }
    } catch (e) {
      debugPrint('TicketProvider.fetchDashboardStats error: $e');
    }
  }

  // 10. Récupérer les stats pour les rapports IT
  Future<void> fetchReports({String? startDate, String? endDate}) async {
    _isLoading = true;
    notifyListeners();
 
    try {
      final queryParams = <String, dynamic>{
        'start_date': startDate,
        'end_date': endDate,
      };
      final response = await _api.get('/tickets/stats/rapports', queryParameters: queryParams);
      if (response.data['success'] == true) {
        _reportsData = response.data['data'];
      }
    } catch (e) {
      debugPrint('TicketProvider.fetchReports error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 11. Récupérer les notifications de l'utilisateur
  Future<void> fetchNotifications() async {
    try {
      final response = await _api.get('/tickets/notifications');
      if (response.data['success'] == true) {
        final List rows = response.data['data'] ?? [];
        _notifications = rows.map((json) => InAppNotification.fromJson(json)).toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('TicketProvider.fetchNotifications error: $e');
    }
  }

  // 12. Marquer une notification comme lue
  Future<bool> markNotificationAsRead(int notificationId) async {
    try {
      final response = await _api.patch('/tickets/notifications/$notificationId/lu');
      if (response.data['success'] == true) {
        // Mettre à jour l'état local
        final idx = _notifications.indexWhere((n) => n.id == notificationId);
        if (idx != -1) {
          final n = _notifications[idx];
          _notifications[idx] = InAppNotification(
            id: n.id,
            userId: n.userId,
            titre: n.titre,
            contenu: n.contenu,
            lu: true,
            createdAt: n.createdAt,
          );
          notifyListeners();
        }
        return true;
      }
    } catch (e) {
      debugPrint('TicketProvider.markNotificationAsRead error: $e');
    }
    return false;
  }
}
