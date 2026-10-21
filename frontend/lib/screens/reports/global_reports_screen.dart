// ============================================
// lib/screens/reports/global_reports_screen.dart — Rapports Globaux Visuels
// ============================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../providers/reports_provider.dart';
import '../../widgets/app_navigation_layout.dart';

class GlobalReportsScreen extends StatefulWidget {
  const GlobalReportsScreen({super.key});

  @override
  State<GlobalReportsScreen> createState() => _GlobalReportsScreenState();
}

class _GlobalReportsScreenState extends State<GlobalReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ReportsProvider>(context, listen: false).fetchReports();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reportsProvider = Provider.of<ReportsProvider>(context);

    return AppNavigationLayout(
      title: 'Rapports Statistiques',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: () => reportsProvider.fetchReports(),
          tooltip: 'Actualiser les données',
        ),
      ],
      child: Column(
        children: [
          // Barre d'onglets
          Material(
            color: Theme.of(context).cardColor,
            elevation: 1,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: AppTheme.primaryColor,
              labelColor: AppTheme.primaryColor,
              unselectedLabelColor: AppTheme.textSecondaryColor,
              labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12),
              tabs: const [
                Tab(icon: Icon(Icons.inventory_rounded), text: 'Inventaire'),
                Tab(icon: Icon(Icons.monetization_on_rounded), text: 'Maintenances'),
                Tab(icon: Icon(Icons.vpn_key_rounded), text: 'Licences'),
                Tab(icon: Icon(Icons.shopping_cart_rounded), text: 'Consommables'),
              ],
            ),
          ),

          // Contenu des onglets
          Expanded(
            child: reportsProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : reportsProvider.errorMessage != null
                    ? Center(
                        child: Text(
                          reportsProvider.errorMessage!,
                          style: GoogleFonts.inter(color: AppTheme.errorColor, fontWeight: FontWeight.w600),
                        ),
                      )
                    : reportsProvider.reportsData == null
                        ? Center(
                            child: Text(
                              'Aucune donnée disponible',
                              style: GoogleFonts.inter(color: AppTheme.textSecondaryColor),
                            ),
                          )
                        : TabBarView(
                            controller: _tabController,
                            children: [
                              _buildInventoryTab(reportsProvider.reportsData!),
                              _buildMaintenanceTab(reportsProvider.reportsData!),
                              _buildLicenceTab(reportsProvider.reportsData!),
                              _buildConsommableTab(reportsProvider.reportsData!),
                            ],
                          ),
          ),
        ],
      ),
    );
  }

  // ── 1. Onglet Inventaire (Assets) ────────────────────────────────
  Widget _buildInventoryTab(Map<String, dynamic> data) {
    final List<dynamic> rawTypes = data['assets_by_type'] ?? [];
    final List<dynamic> rawStatuts = data['assets_by_statut'] ?? [];

    if (rawTypes.isEmpty && rawStatuts.isEmpty) {
      return const Center(child: Text('Aucune donnée d\'inventaire'));
    }

    // Préparation des données Types
    final List<PieChartSectionData> typeSections = [];
    final List<Color> typeColors = [
      AppTheme.primaryColor,
      Colors.purple.shade600,
      Colors.green.shade600,
      Colors.orange.shade600,
      Colors.teal.shade600,
      Colors.pink.shade600,
      Colors.indigo.shade600,
    ];

    double totalCount = 0;
    for (var t in rawTypes) {
      totalCount += (t['count'] ?? 0);
    }

    for (int i = 0; i < rawTypes.length; i++) {
      final t = rawTypes[i];
      final count = (t['count'] ?? 0).toDouble();
      final pct = totalCount > 0 ? (count * 100 / totalCount) : 0.0;
      typeSections.add(
        PieChartSectionData(
          color: typeColors[i % typeColors.length],
          value: count,
          title: '${pct.toStringAsFixed(0)}%',
          radius: 60,
          titleStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      );
    }

    // Préparation des données Statuts
    final List<PieChartSectionData> statutSections = [];
    final Map<String, Color> statusColors = {
      'en_service': AppTheme.successColor,
      'hors_service': AppTheme.errorColor,
      'reforme': AppTheme.textSecondaryColor,
      'en_maintenance': AppTheme.warningColor,
      'en_stock': Colors.blue.shade600,
    };

    double totalStatuts = 0;
    for (var s in rawStatuts) {
      totalStatuts += (s['count'] ?? 0);
    }

    for (var s in rawStatuts) {
      final statut = s['statut'] ?? 'autre';
      final count = (s['count'] ?? 0).toDouble();
      final pct = totalStatuts > 0 ? (count * 100 / totalStatuts) : 0.0;
      statutSections.add(
        PieChartSectionData(
          color: statusColors[statut] ?? Colors.grey,
          value: count,
          title: '${pct.toStringAsFixed(0)}%',
          radius: 50,
          titleStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Répartition par Type d'équipements
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    'Catégories d\'Équipements',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 200,
                    child: PieChart(
                      PieChartData(
                        sections: typeSections,
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Column(
                    children: List.generate(rawTypes.length, (index) {
                      final t = rawTypes[index];
                      final type = t['type'] ?? 'autre';
                      final count = t['count'] ?? 0;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: typeColors[index % typeColors.length],
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                type.toString().toUpperCase(),
                                style: GoogleFonts.inter(fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text('$count unités', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Répartition par État/Statut
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    'États d\'Équipements',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 200,
                    child: PieChart(
                      PieChartData(
                        sections: statutSections,
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Column(
                    children: rawStatuts.map((s) {
                      final statut = s['statut'] ?? 'autre';
                      final count = s['count'] ?? 0;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: statusColors[statut] ?? Colors.grey,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _formatStatut(statut),
                                style: GoogleFonts.inter(fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text('$count unités', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 2. Onglet Coûts Maintenances ──────────────────────────────────
  Widget _buildMaintenanceTab(Map<String, dynamic> data) {
    final List<dynamic> rawCosts = data['maintenances_costs'] ?? [];

    if (rawCosts.isEmpty) {
      return const Center(child: Text('Aucune maintenance planifiée ou réalisée'));
    }

    double totalCout = 0;
    int totalCount = 0;
    final List<FlSpot> spots = [];

    for (int i = 0; i < rawCosts.length; i++) {
      final c = rawCosts[i];
      final coutVal = double.tryParse(c['total_cout']?.toString() ?? '0') ?? 0.0;
      totalCout += coutVal;
      totalCount += int.tryParse(c['count']?.toString() ?? '0') ?? 0;
      spots.add(FlSpot(i.toDouble(), coutVal));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildKPIItem('Budget Total Dépensé', NumberFormat.currency(symbol: 'XOF ', decimalDigits: 0).format(totalCout), Icons.payment_rounded, AppTheme.primaryColor),
              const SizedBox(width: 24),
              _buildKPIItem('Nombre total d\'interventions', '$totalCount', Icons.build_rounded, AppTheme.warningColor),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Évolution des coûts de maintenance',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    height: 260,
                    child: LineChart(
                      LineChartData(
                        gridData: const FlGridData(show: true, drawVerticalLine: false),
                        titlesData: FlTitlesData(
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (val, _) {
                                final index = val.toInt();
                                if (index >= 0 && index < rawCosts.length) {
                                  final mois = rawCosts[index]['mois'] ?? '';
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(mois.substring(5), style: GoogleFonts.inter(fontSize: 10)),
                                  );
                                }
                                return const SizedBox();
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: spots,
                            isCurved: true,
                            color: AppTheme.primaryColor,
                            barWidth: 4,
                            isStrokeCapRound: true,
                            dotData: const FlDotData(show: true),
                            belowBarData: BarAreaData(
                              show: true,
                              color: AppTheme.primaryColor.withValues(alpha: 0.15),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKPIItem(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: GoogleFonts.inter(color: AppTheme.textSecondaryColor, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(value, style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 18, color: AppTheme.textPrimaryColor)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 3. Onglet Utilisation Licences ────────────────────────────────
  Widget _buildLicenceTab(Map<String, dynamic> data) {
    final List<dynamic> licences = data['licences_utilisation'] ?? [];

    if (licences.isEmpty) {
      return const Center(child: Text('Aucune licence logicielle enregistrée'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: licences.length,
      itemBuilder: (context, index) {
        final lic = licences[index];
        final name = lic['nom'] ?? 'Licence';
        final editeur = lic['editeur'] ?? 'Éditeur';
        final quota = int.tryParse(lic['quota_max']?.toString() ?? '0') ?? 0;
        final allocated = int.tryParse(lic['allocated']?.toString() ?? '0') ?? 0;

        final double usageRate = quota > 0 ? (allocated / quota) : 0.0;
        Color progressColor = AppTheme.primaryColor;
        if (usageRate >= 0.9) {
          progressColor = AppTheme.errorColor;
        } else if (usageRate >= 0.7) {
          progressColor = AppTheme.warningColor;
        } else if (usageRate > 0) {
          progressColor = AppTheme.successColor;
        }

        return Card(
          elevation: 1.5,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            editeur,
                            style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondaryColor),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$allocated / $quota attribués',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: usageRate,
                    minHeight: 12,
                    backgroundColor: AppTheme.borderColor,
                    valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Taux d\'attribution: ${(usageRate * 100).toStringAsFixed(1)}%',
                  style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondaryColor),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── 4. Onglet Stock Consommables ─────────────────────────────────
  Widget _buildConsommableTab(Map<String, dynamic> data) {
    final List<dynamic> consommables = data['consommables_stock'] ?? [];

    if (consommables.isEmpty) {
      return const Center(child: Text('Aucun consommable enregistré'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Niveau des Stocks vs Seuils Critiques',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 24),
              Table(
                columnWidths: const {
                  0: FlexColumnWidth(3),
                  1: FlexColumnWidth(2),
                  2: FlexColumnWidth(2),
                  3: FlexColumnWidth(2),
                },
                children: [
                  TableRow(
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: AppTheme.borderColor, width: 1.5)),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Text('Consommable', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Text('Qté stock', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Text('Seuil alerte', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Text('Statut', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                  ...consommables.map((c) {
                    final nom = c['nom'] ?? 'Consommable';
                    final qty = int.tryParse(c['quantite']?.toString() ?? '0') ?? 0;
                    final alert = int.tryParse(c['seuil_alerte']?.toString() ?? '0') ?? 5;
                    final bool isLow = qty <= alert;

                    return TableRow(
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: AppTheme.borderColor, width: 1)),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10.0),
                          child: Text(nom, style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textPrimaryColor), maxLines: 2, overflow: TextOverflow.ellipsis),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10.0),
                          child: Text('$qty u.', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10.0),
                          child: Text('$alert u.', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondaryColor)),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Container(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: isLow ? AppTheme.errorColor.withValues(alpha: 0.1) : AppTheme.successColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isLow ? 'CRITIQUE' : 'OK',
                                style: GoogleFonts.inter(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: isLow ? AppTheme.errorColor : AppTheme.successColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers de formatage ─────────────────────────
  String _formatStatut(String s) {
    switch (s) {
      case 'en_service': return 'En Service';
      case 'hors_service': return 'Hors Service';
      case 'reforme': return 'Réformé';
      case 'en_maintenance': return 'En Maintenance';
      case 'en_stock': return 'En Stock';
      default: return s;
    }
  }
}
