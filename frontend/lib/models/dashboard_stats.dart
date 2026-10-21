// ============================================
// lib/models/dashboard_stats.dart — Modèle Stats
// ============================================

import 'asset.dart';

int _parseInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

double _parseDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

class DashboardStats {
  final int total;
  final int enService;
  final int horsService;
  final int reforme;
  final int enMaintenance;
  final int enStock;

  final List<TypeStat> parType;
  final List<SiteStat> parSite;
  final List<DeptStat> parDepartement;

  final SecuriteStats securite;
  final int machinesWin10;
  final int nonConformes;

  final List<GarantieAlerte> alertesGaranties;
  final List<Asset> recents;

  // Nouveaux KPIs
  final int licencesExpirantBientot;
  final int stockCritique;
  final int maintenancesPlanifiees;

  DashboardStats({
    required this.total,
    required this.enService,
    required this.horsService,
    required this.reforme,
    required this.enMaintenance,
    required this.enStock,
    required this.parType,
    required this.parSite,
    required this.parDepartement,
    required this.securite,
    required this.machinesWin10,
    required this.nonConformes,
    required this.alertesGaranties,
    required this.recents,
    this.licencesExpirantBientot = 0,
    this.stockCritique = 0,
    this.maintenancesPlanifiees = 0,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    final totaux = json['totaux'] ?? {};
    final sec = json['securite'] ?? {};
    
    return DashboardStats(
      total: _parseInt(totaux['total']),
      enService: _parseInt(totaux['en_service']),
      horsService: _parseInt(totaux['hors_service']),
      reforme: _parseInt(totaux['reforme']),
      enMaintenance: _parseInt(totaux['en_maintenance']),
      enStock: _parseInt(totaux['en_stock']),
      
      parType: (json['par_type'] as List? ?? [])
          .map((item) => TypeStat.fromJson(item))
          .toList(),
      parSite: (json['par_site'] as List? ?? [])
          .map((item) => SiteStat.fromJson(item))
          .toList(),
      parDepartement: (json['par_departement'] as List? ?? [])
          .map((item) => DeptStat.fromJson(item))
          .toList(),
          
      securite: SecuriteStats.fromJson(sec),
      machinesWin10: _parseInt(json['machines_win10']),
      nonConformes: _parseInt(json['non_conformes']),
      
      alertesGaranties: (json['alertes_garanties'] as List? ?? [])
          .map((item) => GarantieAlerte.fromJson(item))
          .toList(),
      recents: (json['recents'] as List? ?? [])
          .map((item) => Asset.fromJson(item))
          .toList(),
      licencesExpirantBientot: _parseInt(json['licences_expirant_bientot']),
      stockCritique: _parseInt(json['stock_critique']),
      maintenancesPlanifiees: _parseInt(json['maintenances_planifiees']),
    );
  }
}

class TypeStat {
  final String type;
  final int count;

  TypeStat({required this.type, required this.count});

  factory TypeStat.fromJson(Map<String, dynamic> json) {
    return TypeStat(
      type: json['type'] ?? 'autre',
      count: _parseInt(json['count']),
    );
  }
}

class SiteStat {
  final String site;
  final int count;

  SiteStat({required this.site, required this.count});

  factory SiteStat.fromJson(Map<String, dynamic> json) {
    return SiteStat(
      site: json['site'] ?? 'Inconnu',
      count: _parseInt(json['count']),
    );
  }
}

class DeptStat {
  final String departement;
  final int count;

  DeptStat({required this.departement, required this.count});

  factory DeptStat.fromJson(Map<String, dynamic> json) {
    return DeptStat(
      departement: json['departement'] ?? 'Inconnu',
      count: _parseInt(json['count']),
    );
  }
}

class SecuriteStats {
  final int totalAvecSecurite;
  final int defenderOk;
  final int edrOk;
  final int intuneOk;
  final int entraIdOk;
  final int bitlockerOk;
  final int onedriveOk;
  final double scoreConformite;

  SecuriteStats({
    required this.totalAvecSecurite,
    required this.defenderOk,
    required this.edrOk,
    required this.intuneOk,
    required this.entraIdOk,
    required this.bitlockerOk,
    required this.onedriveOk,
    required this.scoreConformite,
  });

  factory SecuriteStats.fromJson(Map<String, dynamic> json) {
    return SecuriteStats(
      totalAvecSecurite: _parseInt(json['total_avec_securite']),
      defenderOk: _parseInt(json['defender_ok']),
      edrOk: _parseInt(json['edr_ok']),
      intuneOk: _parseInt(json['intune_ok']),
      entraIdOk: _parseInt(json['entra_id_ok']),
      bitlockerOk: _parseInt(json['bitlocker_ok']),
      onedriveOk: _parseInt(json['onedrive_ok']),
      scoreConformite: _parseDouble(json['score_conformite']),
    );
  }
}

class GarantieAlerte {
  final int id;
  final String assetTag;
  final String marque;
  final String? modele;
  final String type;
  final String? site;
  final String? finGarantie;
  final int joursRestants;

  GarantieAlerte({
    required this.id,
    required this.assetTag,
    required this.marque,
    this.modele,
    required this.type,
    this.site,
    this.finGarantie,
    required this.joursRestants,
  });

  factory GarantieAlerte.fromJson(Map<String, dynamic> json) {
    return GarantieAlerte(
      id: _parseInt(json['id']),
      assetTag: json['asset_tag'] ?? '',
      marque: json['marque'] ?? '',
      modele: json['modele'],
      type: json['type'] ?? 'autre',
      site: json['site'],
      finGarantie: json['fin_garantie'],
      joursRestants: _parseInt(json['jours_restants']),
    );
  }
}
