// ============================================
// lib/models/asset.dart — Modèle Asset (Équipement)
// ============================================

class Asset {
  final int id;
  final String assetTag;
  final String? serialNumber;
  final String marque;
  final String? modele;
  final String type;
  final String statut;
  final String? site;
  final String? departement;
  final String? notes;
  final String? utilisateurActuel;
  final String? utilisateurEmail;
  final String? dateAcquisition;
  final String? finGarantie;
  final String? statutGarantie;
  
  final Specs? specs;
  final Securite? securite;
  final Couts? couts;
  final List<AffectationHistory>? affectations;
  final String? photoUrl;
  final List<dynamic>? tickets;
  final List<dynamic>? maintenances;

  Asset({
    required this.id,
    required this.assetTag,
    this.serialNumber,
    required this.marque,
    this.modele,
    required this.type,
    required this.statut,
    this.site,
    this.departement,
    this.notes,
    this.utilisateurActuel,
    this.utilisateurEmail,
    this.dateAcquisition,
    this.finGarantie,
    this.statutGarantie,
    this.specs,
    this.securite,
    this.couts,
    this.affectations,
    this.photoUrl,
    this.tickets,
    this.maintenances,
  });

  factory Asset.fromJson(Map<String, dynamic> json) {
    return Asset(
      id: json['id'],
      assetTag: json['asset_tag'] ?? '',
      serialNumber: json['serial_number'],
      marque: json['marque'] ?? '',
      modele: json['modele'],
      type: json['type'] ?? 'autre',
      statut: json['statut'] ?? 'en_service',
      site: json['site'],
      departement: json['departement'],
      notes: json['notes'],
      utilisateurActuel: json['utilisateur_actuel'],
      utilisateurEmail: json['utilisateur_email'],
      dateAcquisition: json['date_acquisition'],
      finGarantie: json['fin_garantie'],
      statutGarantie: json['statut_garantie'],
      specs: json['specs'] != null ? Specs.fromJson(json['specs']) : null,
      securite: json['securite'] != null ? Securite.fromJson(json['securite']) : null,
      couts: json['couts'] != null ? Couts.fromJson(json['couts']) : null,
      affectations: json['affectations'] != null
          ? (json['affectations'] as List)
              .map((a) => AffectationHistory.fromJson(a))
              .toList()
          : null,
      photoUrl: json['photo_url'],
      tickets: json['tickets'] as List<dynamic>?,
      maintenances: json['maintenances'] as List<dynamic>?,
    );
  }
}

class Specs {
  final String? ram;
  final String? stockage;
  final String? cpu;
  final String? os;
  final String? versionOs;
  final String? macAddress;
  final String? imei;
  final String? ipAddress;
  final String? hostname;

  Specs({
    this.ram,
    this.stockage,
    this.cpu,
    this.os,
    this.versionOs,
    this.macAddress,
    this.imei,
    this.ipAddress,
    this.hostname,
  });

  factory Specs.fromJson(Map<String, dynamic> json) {
    return Specs(
      ram: json['ram'],
      stockage: json['stockage'],
      cpu: json['cpu'],
      os: json['os'],
      versionOs: json['version_os'],
      macAddress: json['mac_address'],
      imei: json['imei'],
      ipAddress: json['ip_address'],
      hostname: json['hostname'],
    );
  }
}

class Securite {
  final bool defender;
  final bool edr;
  final bool intune;
  final bool entraId;
  final bool bitlocker;
  final bool onedrive;

  Securite({
    required this.defender,
    required this.edr,
    required this.intune,
    required this.entraId,
    required this.bitlocker,
    required this.onedrive,
  });

  factory Securite.fromJson(Map<String, dynamic> json) {
    return Securite(
      defender: json['defender'] == 1 || json['defender'] == true,
      edr: json['edr'] == 1 || json['edr'] == true,
      intune: json['intune'] == 1 || json['intune'] == true,
      entraId: json['entra_id'] == 1 || json['entra_id'] == true,
      bitlocker: json['bitlocker'] == 1 || json['bitlocker'] == true,
      onedrive: json['onedrive'] == 1 || json['onedrive'] == true,
    );
  }
}

class Couts {
  final double? prix;
  final String? fournisseur;
  final String? bonCommande;
  final String? dateAcquisition;
  final String? finGarantie;
  final String devise;

  Couts({
    this.prix,
    this.fournisseur,
    this.bonCommande,
    this.dateAcquisition,
    this.finGarantie,
    this.devise = 'XOF',
  });

  factory Couts.fromJson(Map<String, dynamic> json) {
    return Couts(
      prix: json['prix'] != null ? double.tryParse(json['prix'].toString()) : null,
      fournisseur: json['fournisseur'],
      bonCommande: json['bon_commande'],
      dateAcquisition: json['date_acquisition'],
      finGarantie: json['fin_garantie'],
      devise: json['devise'] ?? 'XOF',
    );
  }
}

class AffectationHistory {
  final int id;
  final int assetId;
  final int userId;
  final String dateAttribution;
  final String? dateRetrait;
  final String? motif;
  final bool actif;
  final String? utilisateurNom;
  final String? email;

  AffectationHistory({
    required this.id,
    required this.assetId,
    required this.userId,
    required this.dateAttribution,
    this.dateRetrait,
    this.motif,
    required this.actif,
    this.utilisateurNom,
    this.email,
  });

  factory AffectationHistory.fromJson(Map<String, dynamic> json) {
    return AffectationHistory(
      id: json['id'],
      assetId: json['asset_id'],
      userId: json['user_id'],
      dateAttribution: json['date_attribution'] ?? '',
      dateRetrait: json['date_retrait'],
      motif: json['motif'],
      actif: json['actif'] == 1 || json['actif'] == true,
      utilisateurNom: json['utilisateur_nom'],
      email: json['email'],
    );
  }
}

class AssetAttachment {
  final int id;
  final int assetId;
  final String nomFichier;
  final String nomOriginal;
  final String chemin;
  final int taille;
  final String? typeMime;
  final int uploadedBy;
  final String? uploaderNom;
  final String? uploaderPrenom;
  final DateTime createdAt;

  AssetAttachment({
    required this.id,
    required this.assetId,
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

  String get tailleLabel {
    if (taille < 1024) return '$taille o';
    if (taille < 1024 * 1024) return '${(taille / 1024).toStringAsFixed(1)} Ko';
    return '${(taille / (1024 * 1024)).toStringAsFixed(1)} Mo';
  }

  String get extension {
    final parts = nomOriginal.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : '?';
  }

  factory AssetAttachment.fromJson(Map<String, dynamic> json) {
    return AssetAttachment(
      id: json['id'],
      assetId: json['asset_id'],
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


