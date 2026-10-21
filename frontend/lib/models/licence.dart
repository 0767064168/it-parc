// ============================================
// lib/models/licence.dart — Modèle Licences
// ============================================

class Licence {
  final int id;
  final String nom;
  final String? editeur;
  final String? cleActivation;
  final String? dateExpiration;
  final int? quotaMax;
  final double cout;
  final String? notes;
  final int nbUtilisations;
  final List<LicenceAllocation>? allocations;

  Licence({
    required this.id,
    required this.nom,
    this.editeur,
    this.cleActivation,
    this.dateExpiration,
    this.quotaMax,
    required this.cout,
    this.notes,
    required this.nbUtilisations,
    this.allocations,
  });

  factory Licence.fromJson(Map<String, dynamic> json) {
    return Licence(
      id: json['id'],
      nom: json['nom'] ?? '',
      editeur: json['editeur'],
      cleActivation: json['cle_activation'],
      dateExpiration: json['date_expiration'],
      quotaMax: json['quota_max'],
      cout: json['cout'] != null ? double.tryParse(json['cout'].toString()) ?? 0.0 : 0.0,
      notes: json['notes'],
      nbUtilisations: json['nb_utilisations'] != null ? int.tryParse(json['nb_utilisations'].toString()) ?? 0 : 0,
      allocations: json['allocations'] != null
          ? (json['allocations'] as List)
              .map((a) => LicenceAllocation.fromJson(a))
              .toList()
          : null,
    );
  }
}

class LicenceAllocation {
  final int id;
  final int userId;
  final String dateAllocation;
  final String userNom;
  final String userPrenom;
  final String? userDepartement;
  final String? userSite;

  LicenceAllocation({
    required this.id,
    required this.userId,
    required this.dateAllocation,
    required this.userNom,
    required this.userPrenom,
    this.userDepartement,
    this.userSite,
  });

  factory LicenceAllocation.fromJson(Map<String, dynamic> json) {
    return LicenceAllocation(
      id: json['allocation_id'] ?? json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      dateAllocation: json['date_allocation'] ?? '',
      userNom: json['nom'] ?? '',
      userPrenom: json['prenom'] ?? '',
      userDepartement: json['departement'],
      userSite: json['site'],
    );
  }
}
