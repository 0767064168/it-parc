// ============================================
// lib/models/maintenance.dart — Modèle Maintenance
// ============================================

class Maintenance {
  final int id;
  final int assetId;
  final int? technicienId;
  final String type; // 'preventive', 'curative'
  final String datePrevue;
  final String? dateRealisee;
  final String description;
  final double cout;
  final String? notes;
  final String statut; // 'planifie', 'en_cours', 'realise', 'annule'
  final String? assetTag;
  final String? assetMarque;
  final String? assetModele;
  final String? techNom;
  final String? techPrenom;

  Maintenance({
    required this.id,
    required this.assetId,
    this.technicienId,
    required this.type,
    required this.datePrevue,
    this.dateRealisee,
    required this.description,
    required this.cout,
    this.notes,
    required this.statut,
    this.assetTag,
    this.assetMarque,
    this.assetModele,
    this.techNom,
    this.techPrenom,
  });

  factory Maintenance.fromJson(Map<String, dynamic> json) {
    return Maintenance(
      id: json['id'],
      assetId: json['asset_id'],
      technicienId: json['technicien_id'],
      type: json['type'] ?? 'preventive',
      datePrevue: json['date_prevue'] ?? '',
      dateRealisee: json['date_realisee'],
      description: json['description'] ?? '',
      cout: json['cout'] != null ? double.tryParse(json['cout'].toString()) ?? 0.0 : 0.0,
      notes: json['notes'],
      statut: json['statut'] ?? 'planifie',
      assetTag: json['asset_tag'],
      assetMarque: json['asset_marque'],
      assetModele: json['asset_modele'],
      techNom: json['tech_nom'],
      techPrenom: json['tech_prenom'],
    );
  }
}
