// ============================================
// lib/models/ticket.dart — Modèles Ticket IT
// ============================================

class Ticket {
  final int id;
  final String numero;
  final String titre;
  final String description;
  final String type;
  final String priorite;
  final String statut;
  final int? assetId;
  final String? assetTag;
  final String? assetMarque;
  final String? assetModele;
  final int createurId;
  final String? createurUsername;
  final String? createurNom;
  final String? createurPrenom;
  final int? technicienId;
  final String? technicienUsername;
  final String? technicienNom;
  final String? technicienPrenom;
  final String? site;
  final DateTime? slaDeadline;
  final int tempsResolutionMin;
  final int? noteSatisfaction;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? closedAt;
  final List<TicketComment> commentaires;
  final List<TicketHistory> historique;
  final List<TicketAttachment> piecesJointes;

  Ticket({
    required this.id,
    required this.numero,
    required this.titre,
    required this.description,
    required this.type,
    required this.priorite,
    required this.statut,
    this.assetId,
    this.assetTag,
    this.assetMarque,
    this.assetModele,
    required this.createurId,
    this.createurUsername,
    this.createurNom,
    this.createurPrenom,
    this.technicienId,
    this.technicienUsername,
    this.technicienNom,
    this.technicienPrenom,
    this.site,
    this.slaDeadline,
    required this.tempsResolutionMin,
    this.noteSatisfaction,
    required this.createdAt,
    required this.updatedAt,
    this.closedAt,
    this.commentaires = const [],
    this.historique = const [],
    this.piecesJointes = const [],
  });

  String get typeLabel {
    switch (type) {
      case 'incident': return 'Incident';
      case 'demande_materiel': return 'Demande Matériel';
      case 'maintenance': return 'Maintenance';
      case 'acces_logiciel': return 'Accès / Logiciel';
      default: return type;
    }
  }

  String get prioriteLabel {
    switch (priorite) {
      case 'critique': return 'Critique';
      case 'haute': return 'Haute';
      case 'moyenne': return 'Moyenne';
      case 'basse': return 'Basse';
      default: return priorite;
    }
  }

  String get statutLabel {
    switch (statut) {
      case 'ouvert': return 'Ouvert';
      case 'en_cours': return 'En cours';
      case 'en_attente': return 'En attente';
      case 'resolu': return 'Résolu';
      case 'ferme': return 'Fermé';
      case 'annule': return 'Annulé';
      case 'rouvert': return 'Réouvert';
      default: return statut;
    }
  }

  String get createurNomComplet {
    if (createurPrenom != null && createurNom != null) {
      return '$createurPrenom $createurNom';
    }
    return 'Utilisateur #$createurId';
  }

  String get technicienNomComplet {
    if (technicienPrenom != null && technicienNom != null) {
      return '$technicienPrenom $technicienNom';
    }
    return technicienId != null ? 'Technicien #$technicienId' : 'Non assigné';
  }

  factory Ticket.fromJson(Map<String, dynamic> json) {
    var listComm = json['commentaires'] as List?;
    var listHist = json['historique'] as List?;
    var listPJ = json['piecesJointes'] as List?;

    return Ticket(
      id: json['id'],
      numero: json['numero'] ?? '',
      titre: json['titre'] ?? '',
      description: json['description'] ?? '',
      type: json['type'] ?? 'incident',
      priorite: json['priorite'] ?? 'moyenne',
      statut: json['statut'] ?? 'ouvert',
      assetId: json['asset_id'],
      assetTag: json['asset_tag'],
      assetMarque: json['asset_marque'],
      assetModele: json['asset_modele'],
      createurId: json['createur_id'],
      createurUsername: json['createur_username'],
      createurNom: json['createur_nom'],
      createurPrenom: json['createur_prenom'],
      technicienId: json['technicien_id'],
      technicienUsername: json['technicien_username'],
      technicienNom: json['technicien_nom'],
      technicienPrenom: json['technicien_prenom'],
      site: json['site'],
      slaDeadline: json['sla_deadline'] != null ? DateTime.tryParse(json['sla_deadline'])?.toLocal() : null,
      tempsResolutionMin: json['temps_resolution_min'] ?? 0,
      noteSatisfaction: json['note_satisfaction'],
      createdAt: DateTime.parse(json['created_at']).toLocal(),
      updatedAt: DateTime.parse(json['updated_at']).toLocal(),
      closedAt: json['closed_at'] != null ? DateTime.tryParse(json['closed_at'])?.toLocal() : null,
      commentaires: listComm != null ? listComm.map((i) => TicketComment.fromJson(i)).toList() : [],
      historique: listHist != null ? listHist.map((i) => TicketHistory.fromJson(i)).toList() : [],
      piecesJointes: listPJ != null ? listPJ.map((i) => TicketAttachment.fromJson(i)).toList() : [],
    );
  }
}

class TicketComment {
  final int id;
  final int ticketId;
  final int auteurId;
  final String contenu;
  final String type;
  final DateTime createdAt;
  final String auteurNom;
  final String auteurPrenom;
  final String auteurRole;

  TicketComment({
    required this.id,
    required this.ticketId,
    required this.auteurId,
    required this.contenu,
    required this.type,
    required this.createdAt,
    required this.auteurNom,
    required this.auteurPrenom,
    required this.auteurRole,
  });

  String get auteurNomComplet => '$auteurPrenom $auteurNom';
  bool get isInternal => type == 'interne';

  factory TicketComment.fromJson(Map<String, dynamic> json) {
    return TicketComment(
      id: json['id'],
      ticketId: json['ticket_id'],
      auteurId: json['auteur_id'],
      contenu: json['contenu'] ?? '',
      type: json['type'] ?? 'public',
      createdAt: DateTime.parse(json['created_at']).toLocal(),
      auteurNom: json['auteur_nom'] ?? '',
      auteurPrenom: json['auteur_prenom'] ?? '',
      auteurRole: json['auteur_role'] ?? 'lecteur',
    );
  }
}

class TicketHistory {
  final int id;
  final int ticketId;
  final int userId;
  final String champModifie;
  final String? ancienneValeur;
  final String? nouvelleValeur;
  final DateTime createdAt;
  final String userNom;
  final String userPrenom;

  TicketHistory({
    required this.id,
    required this.ticketId,
    required this.userId,
    required this.champModifie,
    this.ancienneValeur,
    this.nouvelleValeur,
    required this.createdAt,
    required this.userNom,
    required this.userPrenom,
  });

  String get userNomComplet => '$userPrenom $userNom';

  factory TicketHistory.fromJson(Map<String, dynamic> json) {
    return TicketHistory(
      id: json['id'],
      ticketId: json['ticket_id'],
      userId: json['user_id'],
      champModifie: json['champ_modifie'] ?? '',
      ancienneValeur: json['ancienne_valeur'],
      nouvelleValeur: json['nouvelle_valeur'],
      createdAt: DateTime.parse(json['created_at']).toLocal(),
      userNom: json['user_nom'] ?? '',
      userPrenom: json['user_prenom'] ?? '',
    );
  }
}

class TicketAttachment {
  final int id;
  final int ticketId;
  final String nomFichier;
  final String chemin;
  final int taille;
  final DateTime createdAt;

  TicketAttachment({
    required this.id,
    required this.ticketId,
    required this.nomFichier,
    required this.chemin,
    required this.taille,
    required this.createdAt,
  });

  factory TicketAttachment.fromJson(Map<String, dynamic> json) {
    return TicketAttachment(
      id: json['id'],
      ticketId: json['ticket_id'],
      nomFichier: json['nom_fichier'] ?? '',
      chemin: json['chemin'] ?? '',
      taille: json['taille'] ?? 0,
      createdAt: DateTime.parse(json['created_at']).toLocal(),
    );
  }
}

class InAppNotification {
  final int id;
  final int userId;
  final String titre;
  final String contenu;
  final bool lu;
  final DateTime createdAt;

  InAppNotification({
    required this.id,
    required this.userId,
    required this.titre,
    required this.contenu,
    required this.lu,
    required this.createdAt,
  });

  factory InAppNotification.fromJson(Map<String, dynamic> json) {
    return InAppNotification(
      id: json['id'],
      userId: json['user_id'],
      titre: json['titre'] ?? '',
      contenu: json['contenu'] ?? '',
      lu: json['lu'] == 1 || json['lu'] == true,
      createdAt: DateTime.parse(json['created_at']).toLocal(),
    );
  }
}
