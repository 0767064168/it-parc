// ============================================
// lib/models/consommable.dart — Modèle Consommables
// ============================================

class Consommable {
  final int id;
  final String nom;
  final String? categorie;
  final int quantite;
  final int seuilAlerte;
  final String? emplacement;
  final String? createdAt;

  Consommable({
    required this.id,
    required this.nom,
    this.categorie,
    required this.quantite,
    required this.seuilAlerte,
    this.emplacement,
    this.createdAt,
  });

  bool get estAlerteStock => quantite <= seuilAlerte;

  factory Consommable.fromJson(Map<String, dynamic> json) {
    return Consommable(
      id: json['id'],
      nom: json['nom'] ?? '',
      categorie: json['categorie'],
      quantite: json['quantite'] ?? 0,
      seuilAlerte: json['seuil_alerte'] ?? 5,
      emplacement: json['emplacement'],
      createdAt: json['created_at'],
    );
  }
}
