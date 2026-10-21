// ============================================
// lib/models/user.dart — Modèle Utilisateur
// ============================================

class User {
  final int id;
  final String nom;
  final String prenom;
  final String? departement;
  final String? site;
  final String? email;
  final String? telephone;
  final bool actif;
  final String? username;
  final String? role;
  final String? avatarUrl;

  User({
    required this.id,
    required this.nom,
    required this.prenom,
    this.departement,
    this.site,
    this.email,
    this.telephone,
    required this.actif,
    this.username,
    this.role,
    this.avatarUrl,
  });

  String get nomComplet => '$prenom $nom';

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      nom: json['nom'] ?? '',
      prenom: json['prenom'] ?? '',
      departement: json['departement'],
      site: json['site'],
      email: json['email'],
      telephone: json['telephone'],
      actif: json['actif'] == 1 || json['actif'] == true,
      username: json['username'],
      role: json['role'],
      avatarUrl: json['avatarUrl'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nom': nom,
      'prenom': prenom,
      'departement': departement,
      'site': site,
      'email': email,
      'telephone': telephone,
      'actif': actif ? 1 : 0,
      'username': username,
      'role': role,
      'avatarUrl': avatarUrl,
    };
  }
}
