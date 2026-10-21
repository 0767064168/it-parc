// ============================================
// lib/screens/tickets/ticket_reports_screen.dart
// ============================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../core/theme.dart';
import '../../providers/ticket_provider.dart';
import '../../widgets/app_navigation_layout.dart';
import '../../utils/file_saver.dart';
import '../../data/api_client.dart';

class TicketReportsScreen extends StatefulWidget {
  const TicketReportsScreen({super.key});

  @override
  State<TicketReportsScreen> createState() => _TicketReportsScreenState();
}

class _TicketReportsScreenState extends State<TicketReportsScreen> {
  final ApiClient _api = ApiClient();
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isDownloadingExcel = false;
  bool _isDownloadingPdf = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadReports();
    });
  }

  void _loadReports() {
    final startStr = _startDate != null ? DateFormat('yyyy-MM-dd').format(_startDate!) : null;
    final endStr = _endDate != null ? DateFormat('yyyy-MM-dd').format(_endDate!) : null;
    Provider.of<TicketProvider>(context, listen: false).fetchReports(
      startDate: startStr,
      endDate: endStr,
    );
  }

  Future<void> _downloadExcel() async {
    setState(() => _isDownloadingExcel = true);
    try {
      final response = await _api.dio.get(
        '/tickets/export/excel',
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = response.data as List<int>;
      final fileName = 'rapport_tickets_it_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final fileSaver = FileSaver();
      final pathOrStatus = await fileSaver.saveFile(bytes, fileName);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rapport Excel enregistré : $pathOrStatus')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors du téléchargement Excel : $e')),
        );
      }
    } finally {
      setState(() => _isDownloadingExcel = false);
    }
  }

  Future<void> _downloadPdf() async {
    setState(() => _isDownloadingPdf = true);
    try {
      final response = await _api.dio.get(
        '/tickets/export/pdf',
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = response.data as List<int>;
      final fileName = 'rapport_performance_it_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final fileSaver = FileSaver();
      final pathOrStatus = await fileSaver.saveFile(bytes, fileName);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rapport PDF enregistré : $pathOrStatus')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors du téléchargement PDF : $e')),
        );
      }
    } finally {
      setState(() => _isDownloadingPdf = false);
    }
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now().subtract(const Duration(days: 30)),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
      });
      _loadReports();
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
      _loadReports();
    }
  }

  void _clearDates() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
    _loadReports();
  }

  @override
  Widget build(BuildContext context) {
    final ticketProvider = Provider.of<TicketProvider>(context);
    final reports = ticketProvider.reportsData;

    return AppNavigationLayout(
      title: 'Rapports & Statistiques IT',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _loadReports,
          tooltip: 'Actualiser',
        ),
      ],
      child: Column(
        children: [
          // ── Zone de filtres date et boutons exports ─────────────────────
          Card(
            margin: const EdgeInsets.all(16.0),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Ligne 1 : sélection de période
                  Row(
                    children: [
                      const Icon(Icons.date_range_rounded, size: 16, color: AppTheme.textSecondaryColor),
                      const SizedBox(width: 6),
                      const Text('Période :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today, size: 14),
                          label: Text(
                            _startDate == null ? 'Début' : DateFormat('dd/MM/yy').format(_startDate!),
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                          onPressed: _selectStartDate,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Text('→', style: TextStyle(color: AppTheme.textSecondaryColor)),
                      ),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today, size: 14),
                          label: Text(
                            _endDate == null ? 'Fin' : DateFormat('dd/MM/yy').format(_endDate!),
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                          onPressed: _selectEndDate,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          ),
                        ),
                      ),
                      if (_startDate != null || _endDate != null)
                        IconButton(
                          icon: const Icon(Icons.clear, color: AppTheme.errorColor, size: 18),
                          onPressed: _clearDates,
                          tooltip: 'Réinitialiser',
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Ligne 2 : boutons d'export
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: _isDownloadingExcel
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.download_for_offline, size: 16),
                          label: const Text('Export Excel', style: TextStyle(fontSize: 12)),
                          onPressed: _isDownloadingExcel ? null : _downloadExcel,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.secondaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: _isDownloadingPdf
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.picture_as_pdf, size: 16),
                          label: const Text('Rapport PDF', style: TextStyle(fontSize: 12)),
                          onPressed: _isDownloadingPdf ? null : _downloadPdf,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.errorColor,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Dashboard Metrics & Charts ──────────────────────────────────
          Expanded(
            child: ticketProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : (reports == null
                    ? const Center(child: Text('Erreur de chargement des statistiques.'))
                    : SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Ligne 1 : KPI Cards
                            _buildKpiMetrics(reports),
                            const SizedBox(height: 16),

                            // Ligne 2 : Graphiques principaux
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final isNarrow = constraints.maxWidth < 600;
                                if (isNarrow) {
                                  return Column(
                                    children: [
                                      _buildVolumeChartCard(reports['volumeParPeriode']),
                                      const SizedBox(height: 16),
                                      _buildTypePieChartCard(reports['parType']),
                                    ],
                                  );
                                }
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: _buildVolumeChartCard(reports['volumeParPeriode']),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      flex: 1,
                                      child: _buildTypePieChartCard(reports['parType']),
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 16),

                            // Ligne 3 : MTTR et Assets défaillants
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final isNarrow = constraints.maxWidth < 600;
                                if (isNarrow) {
                                  return Column(
                                    children: [
                                      _buildMttrBarChartCard(reports['mttr']),
                                      const SizedBox(height: 16),
                                      _buildTopAssetsCard(reports['topAssetsDefaillants']),
                                    ],
                                  );
                                }
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 1,
                                      child: _buildMttrBarChartCard(reports['mttr']),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      flex: 1,
                                      child: _buildTopAssetsCard(reports['topAssetsDefaillants']),
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      )),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiMetrics(Map<String, dynamic> reports) {
    final slaRaw = reports['tauxSla'];
    final tauxSla = slaRaw is num ? slaRaw.toInt() : int.tryParse(slaRaw?.toString() ?? '100') ?? 100;
    
    final noteRaw = reports['satisfaction'];
    final satisfaction = noteRaw is num ? noteRaw.toDouble() : double.tryParse(noteRaw?.toString() ?? '0') ?? 0.0;
    
    // Calculer le MTTR global moyen
    final List mttrList = reports['mttr'] ?? [];
    double mttrSum = 0;
    int mttrCount = 0;
    for (var m in mttrList) {
      if (m['mttr_min'] != null) {
        final val = m['mttr_min'];
        mttrSum += val is num ? val.toDouble() : double.tryParse(val.toString()) ?? 0.0;
        mttrCount++;
      }
    }
    final mttrAvg = mttrCount > 0 ? (mttrSum / mttrCount).round() : 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 500;
        if (isNarrow) {
          // 2 colonnes sur mobile
          return Column(
            children: [
              Row(
                children: [
                  _buildMetricCard(
                    title: 'Respect SLA',
                    value: '$tauxSla %',
                    subtitle: 'Dans les délais',
                    icon: Icons.verified_user,
                    color: tauxSla >= 85 ? AppTheme.successColor : AppTheme.warningColor,
                  ),
                  const SizedBox(width: 8),
                  _buildMetricCard(
                    title: 'MTTR Moyen',
                    value: mttrAvg > 60 ? '${(mttrAvg / 60).toStringAsFixed(1)} h' : '$mttrAvg min',
                    subtitle: 'Tps résolution',
                    icon: Icons.timer,
                    color: AppTheme.primaryColor,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildMetricCard(
                    title: 'Satisfaction',
                    value: '$satisfaction / 5',
                    subtitle: 'Note globale',
                    icon: Icons.star_rate_rounded,
                    color: AppTheme.accentColor,
                  ),
                  const Expanded(child: SizedBox()),
                ],
              ),
            ],
          );
        }
        // 3 colonnes sur écran large
        return Row(
          children: [
            _buildMetricCard(
              title: 'Respect SLA',
              value: '$tauxSla %',
              subtitle: 'Dans les délais requis',
              icon: Icons.verified_user,
              color: tauxSla >= 85 ? AppTheme.successColor : AppTheme.warningColor,
            ),
            const SizedBox(width: 16),
            _buildMetricCard(
              title: 'MTTR Moyen',
              value: mttrAvg > 60 ? '${(mttrAvg / 60).toStringAsFixed(1)} h' : '$mttrAvg min',
              subtitle: 'Temps moyen de résolution',
              icon: Icons.timer,
              color: AppTheme.primaryColor,
            ),
            const SizedBox(width: 16),
            _buildMetricCard(
              title: 'Satisfaction',
              value: '$satisfaction / 5',
              subtitle: 'Note satisfaction globale',
              icon: Icons.star_rate_rounded,
              color: AppTheme.accentColor,
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
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
                    Text(title, style: const TextStyle(fontSize: 14, color: AppTheme.textSecondaryColor)),
                    const SizedBox(height: 4),
                    Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryColor)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVolumeChartCard(List? volumeData) {
    if (volumeData == null || volumeData.isEmpty) {
      return const Card(
        child: SizedBox(
          height: 300,
          child: Center(child: Text('Données d\'historique indisponibles')),
        ),
      );
    }

    final List<FlSpot> spots = [];
    final List<String> labels = [];
    for (int i = 0; i < volumeData.length; i++) {
      final val = volumeData[i];
      final countRaw = val['count'];
      final count = countRaw is num ? countRaw.toDouble() : double.tryParse(countRaw?.toString() ?? '0') ?? 0.0;
      spots.add(FlSpot(i.toDouble(), count));
      labels.add(val['periode'] ?? '');
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Volume mensuel des tickets', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: true, drawVerticalLine: false),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (val, meta) {
                          final idx = val.toInt();
                          if (idx >= 0 && idx < labels.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(labels[idx], style: const TextStyle(fontSize: 10, color: AppTheme.textSecondaryColor)),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: true, border: Border.all(color: AppTheme.borderColor, width: 1.0)),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: AppTheme.primaryColor,
                      barWidth: 4,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(show: true, color: AppTheme.primaryColor.withValues(alpha: 0.1)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypePieChartCard(List? typeData) {
    if (typeData == null || typeData.isEmpty) {
      return const Card(
        child: SizedBox(
          height: 300,
          child: Center(child: Text('Aucun ticket enregistré')),
        ),
      );
    }

    final List<PieChartSectionData> sections = [];
    final colors = [
      AppTheme.primaryColor,
      AppTheme.secondaryColor,
      AppTheme.warningColor,
      AppTheme.errorColor,
    ];

    double total = 0;
    for (var t in typeData) {
      final countRaw = t['count'];
      total += countRaw is num ? countRaw.toDouble() : double.tryParse(countRaw?.toString() ?? '0') ?? 0.0;
    }

    for (int i = 0; i < typeData.length; i++) {
      final val = typeData[i];
      final countRaw = val['count'];
      final count = countRaw is num ? countRaw.toDouble() : double.tryParse(countRaw?.toString() ?? '0') ?? 0.0;
      final pct = total > 0 ? (count / total * 100).round() : 0;
      final type = val['type'] ?? '';
      
      String label = type;
      if (type == 'incident') label = 'Inc';
      if (type == 'demande_materiel') label = 'Mat';
      if (type == 'maintenance') label = 'Maint';
      if (type == 'acces_logiciel') label = 'Acc';

      sections.add(
        PieChartSectionData(
          color: colors[i % colors.length],
          value: count,
          title: '$label ($pct%)',
          radius: 60,
          titleStyle: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Répartition par type', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            SizedBox(
              height: 220,
              child: PieChart(
                PieChartData(
                  sections: sections,
                  centerSpaceRadius: 40,
                  sectionsSpace: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMttrBarChartCard(List? mttrData) {
    if (mttrData == null || mttrData.isEmpty) {
      return const Card(
        child: SizedBox(
          height: 300,
          child: Center(child: Text('Données de résolution insuffisantes')),
        ),
      );
    }

    final List<BarChartGroupData> groups = [];
    final List<String> priorities = [];
    for (int i = 0; i < mttrData.length; i++) {
      final val = mttrData[i];
      final mttrRaw = val['mttr_min'];
      final mttrVal = mttrRaw is num ? mttrRaw.toDouble() : double.tryParse(mttrRaw?.toString() ?? '0') ?? 0.0;
      priorities.add((val['priorite'] as String).toUpperCase());
      
      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: mttrVal,
              color: AppTheme.primaryColor,
              width: 22,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('MTTR (minutes) par priorité', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (val, meta) {
                          final idx = val.toInt();
                          if (idx >= 0 && idx < priorities.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(priorities[idx], style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.textSecondaryColor)),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: true, border: Border.all(color: AppTheme.borderColor)),
                  barGroups: groups,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopAssetsCard(List? topAssets) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Top 10 des équipements défaillants', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (topAssets == null || topAssets.isEmpty)
              const SizedBox(
                height: 228,
                child: Center(
                  child: Text('Aucun incident enregistré sur les équipements.', style: TextStyle(fontStyle: FontStyle.italic)),
                ),
              )
            else
              SizedBox(
                height: 228,
                child: SingleChildScrollView(
                  child: Table(
                    columnWidths: const {
                      0: FlexColumnWidth(2),
                      1: FlexColumnWidth(3),
                      2: FlexColumnWidth(1),
                    },
                    children: [
                      const TableRow(
                        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.borderColor))),
                        children: [
                          Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Asset Tag', style: TextStyle(fontWeight: FontWeight.bold))),
                          Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Modèle', style: TextStyle(fontWeight: FontWeight.bold))),
                          Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Incidents', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                        ],
                      ),
                      ...topAssets.map((asset) => TableRow(
                            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.borderColor, width: 0.5))),
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: InkWell(
                                  onTap: () => context.push('/assets/${asset['id']}'),
                                  child: Text(asset['asset_tag'] ?? '', style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                                ),
                              ),
                              Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('${asset['marque'] ?? ""} ${asset['modele'] ?? ""}')),
                              Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('${asset['nb_incidents']}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.errorColor))),
                            ],
                          )),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
