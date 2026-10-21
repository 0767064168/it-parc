// ============================================
// lib/models/wiki.dart — Modèle Wiki / Articles
// ============================================

class WikiArticle {
  final int id;
  final String titre;
  final String contenu;
  final int auteurId;
  final String categorie;
  final bool estPublic;
  final String createdAt;
  final String updatedAt;
  final String? auteurNom;
  final String? auteurPrenom;

  WikiArticle({
    required this.id,
    required this.titre,
    required this.contenu,
    required this.auteurId,
    required this.categorie,
    required this.estPublic,
    required this.createdAt,
    required this.updatedAt,
    this.auteurNom,
    this.auteurPrenom,
  });

  factory WikiArticle.fromJson(Map<String, dynamic> json) {
    return WikiArticle(
      id: json['id'],
      titre: json['titre'] ?? '',
      contenu: json['contenu'] ?? '',
      auteurId: json['auteur_id'] ?? 0,
      categorie: json['categorie'] ?? 'Général',
      estPublic: json['est_public'] == 1 || json['est_public'] == true,
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
      auteurNom: json['auteur_nom'],
      auteurPrenom: json['auteur_prenom'],
    );
  }
}

// ─────────────────────────────────────────────────────
//  Pièce jointe d'un article Wiki
// ─────────────────────────────────────────────────────
class WikiAttachment {
  final int id;
  final int articleId;
  final String nomFichier;
  final String nomOriginal;
  final String chemin;
  final int taille;
  final String? typeMime;
  final int uploadedBy;
  final String? uploaderNom;
  final String? uploaderPrenom;
  final DateTime createdAt;

  WikiAttachment({
    required this.id,
    required this.articleId,
    required this.nomFichier,
    required this.nomOriginal,
    required this.chemin,
    required this.taille,
    this.typeMime,
    required this.uploadedBy,
    this.uploaderNom,
    this.uploaderPrenom,
    required this.createdAt,
  });

  /// Taille lisible (ex: 1.2 MB)
  String get tailleLabel {
    if (taille < 1024) return '$taille o';
    if (taille < 1024 * 1024) return '${(taille / 1024).toStringAsFixed(1)} Ko';
    return '${(taille / (1024 * 1024)).toStringAsFixed(1)} Mo';
  }

  /// Icône selon le type MIME / extension
  String get extension {
    final parts = nomOriginal.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : '?';
  }

  factory WikiAttachment.fromJson(Map<String, dynamic> json) {
    return WikiAttachment(
      id: json['id'],
      articleId: json['article_id'],
      nomFichier: json['nom_fichier'] ?? '',
      nomOriginal: json['nom_original'] ?? '',
      chemin: json['chemin'] ?? '',
      taille: json['taille'] ?? 0,
      typeMime: json['type_mime'],
      uploadedBy: json['uploaded_by'],
      uploaderNom: json['uploader_nom'],
      uploaderPrenom: json['uploader_prenom'],
      createdAt: DateTime.parse(json['created_at']).toLocal(),
    );
  }
}

