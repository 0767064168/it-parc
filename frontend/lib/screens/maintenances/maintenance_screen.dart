// ============================================
// lib/screens/maintenances/maintenance_screen.dart
// ============================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../core/theme.dart';
import '../../models/maintenance.dart';
import '../../models/asset.dart';
import '../../providers/maintenance_provider.dart';
import '../../providers/asset_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_navigation_layout.dart';

class MaintenanceScreen extends StatefulWidget {
  const MaintenanceScreen({super.key});

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _loadData() {
    Provider.of<MaintenanceProvider>(context, listen: false).fetchMaintenances(
      search: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
    );
    // Fetch assets for warranty tab (fetching a larger page to ensure we see them)
    Provider.of<AssetProvider>(context, listen: false).fetchAssets(page: 1, isRefresh: true);
  }

  void _showMaintenanceDialog(BuildContext context, {Maintenance? maintenance}) {
    final isEdit = maintenance != null;
    final assetProvider = Provider.of<AssetProvider>(context, listen: false);

    // Form inputs
    Asset? selectedAsset;
    if (isEdit) {
      selectedAsset = assetProvider.assets.firstWhere(
        (a) => a.id == maintenance.assetId,
        orElse: () => Asset(id: maintenance.assetId, assetTag: maintenance.assetTag ?? '', marque: '', type: '', statut: ''),
      );
    }
    
    final descController = TextEditingController(text: maintenance?.description);
    final notesController = TextEditingController(text: maintenance?.notes);
    final coutController = TextEditingController(text: maintenance?.cout.toString() ?? '0');
    String selectedType = maintenance?.type ?? 'preventive';
    String selectedStatut = maintenance?.statut ?? 'planifie';
    DateTime selectedDate = maintenance?.datePrevue != null
        ? DateTime.parse(maintenance!.datePrevue)
        : DateTime.now().add(const Duration(days: 7));

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateBuilder) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            isEdit ? 'Modifier la Maintenance' : 'Planifier une Maintenance',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700),
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 450,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Asset Selector
                  DropdownButtonFormField<Asset>(
                    initialValue: selectedAsset != null && assetProvider.assets.any((a) => a.id == selectedAsset!.id)
                        ? assetProvider.assets.firstWhere((a) => a.id == selectedAsset!.id)
                        : null,
                    decoration: const InputDecoration(labelText: 'Équipement *'),
                    items: assetProvider.assets.map((asset) {
                      return DropdownMenuItem<Asset>(
                        value: asset,
                        child: Text('${asset.assetTag} - ${asset.marque} ${asset.modele ?? ""}'),
                      );
                    }).toList(),
                    onChanged: isEdit
                        ? null // Disable changing asset on edit
                        : (val) => setStateBuilder(() => selectedAsset = val),
                  ),
                  const SizedBox(height: 12),
                  // Type & Statut
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedType,
                          decoration: const InputDecoration(labelText: 'Type'),
                          items: {
                            'preventive',
                            'curative',
                            selectedType,
                          }.map((val) => DropdownMenuItem(
                            value: val,
                            child: Text(val == 'preventive'
                                ? 'Préventive'
                                : val == 'curative'
                                    ? 'Curative'
                                    : val.replaceAll('_', ' ').toUpperCase()),
                          )).toList(),
                          onChanged: (val) => setStateBuilder(() => selectedType = val!),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedStatut,
                          decoration: const InputDecoration(labelText: 'Statut'),
                          items: {
                            'planifie',
                            'en_cours',
                            'realise',
                            'annule',
                            selectedStatut,
                          }.map((val) => DropdownMenuItem(
                            value: val,
                            child: Text(val == 'planifie'
                                ? 'Planifié'
                                : val == 'en_cours'
                                    ? 'En cours'
                                    : val == 'realise'
                                        ? 'Réalisé'
                                        : val == 'annule'
                                            ? 'Annulé'
                                            : val.replaceAll('_', ' ').toUpperCase()),
                          )).toList(),
                          onChanged: (val) => setStateBuilder(() => selectedStatut = val!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Date
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now().subtract(const Duration(days: 365)),
                        lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                      );
                      if (picked != null) {
                        setStateBuilder(() => selectedDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.borderColor),
                        borderRadius: BorderRadius.circular(12),
                        color: Theme.of(context).cardColor,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Date prévue: ${DateFormat('dd/MM/yyyy').format(selectedDate)}'),
                          const Icon(Icons.calendar_today_rounded, color: AppTheme.primaryColor, size: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Description
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(
                      labelText: 'Description des travaux *',
                      hintText: 'Ex: Nettoyage et changement pâte thermique',
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Coût
                  TextField(
                    controller: coutController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Coût estimé / réel',
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Notes
                  TextField(
                    controller: notesController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Notes additionnelles',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Annuler', style: GoogleFonts.inter(color: AppTheme.textSecondaryColor)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedAsset == null || descController.text.trim().isEmpty) return;

                final data = {
                  'asset_id': selectedAsset!.id,
                  'type': selectedType,
                  'date_prevue': DateFormat('yyyy-MM-dd').format(selectedDate),
                  'description': descController.text.trim(),
                  'cout': double.tryParse(coutController.text.trim()) ?? 0.0,
                  'notes': notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                  'statut': selectedStatut,
                  if (selectedStatut == 'realise') 'date_realisee': DateFormat('yyyy-MM-dd').format(DateTime.now()),
                };

                final provider = Provider.of<MaintenanceProvider>(context, listen: false);
                bool success = false;
                if (isEdit) {
                  success = await provider.updateMaintenance(maintenance.id, data);
                } else {
                  success = await provider.createMaintenance(data);
                }

                if (success && context.mounted) {
                  Navigator.pop(context);
                  _loadData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isEdit ? 'Maintenance modifiée' : 'Maintenance planifiée'),
                      backgroundColor: AppTheme.successColor,
                    ),
                  );
                }
              },
              child: Text(isEdit ? 'Enregistrer' : 'Planifier'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maintenanceProvider = Provider.of<MaintenanceProvider>(context);
    final assetProvider = Provider.of<AssetProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;
    final canManage = user?.role == 'admin' || user?.role == 'technicien';

    // Filter assets with active/near expiration warranty
    final assetsWithWarranty = assetProvider.assets.where((a) => a.finGarantie != null).toList();
    final criticalWarrantyAssets = assetsWithWarranty.where((a) {
      if (a.finGarantie == null) return false;
      final dateFin = DateTime.tryParse(a.finGarantie!);
      if (dateFin == null) return false;
      final diff = dateFin.difference(DateTime.now()).inDays;
      return diff >= 0 && diff < 30; // Under 30 days left
    }).toList();

    int plannedCount = maintenanceProvider.maintenances.where((m) => m.statut == 'planifie' || m.statut == 'en_cours').length;

    return AppNavigationLayout(
      title: 'Maintenances & Garanties',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: _loadData,
        ),
      ],
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => _showMaintenanceDialog(context),
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: Text('Planifier', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            )
          : null,
      child: Column(
        children: [
          // Stat Counters Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Card(
                    color: Theme.of(context).cardColor,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.build_circle_outlined, color: AppTheme.primaryColor, size: 24),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Maintenances en Cours',
                                  style: GoogleFonts.inter(color: AppTheme.textSecondaryColor, fontSize: 11),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$plannedCount tâches',
                                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Card(
                    color: Theme.of(context).cardColor,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: criticalWarrantyAssets.isNotEmpty
                                  ? AppTheme.errorColor.withValues(alpha: 0.1)
                                  : AppTheme.successColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.verified_user_outlined,
                              color: criticalWarrantyAssets.isNotEmpty ? AppTheme.errorColor : AppTheme.successColor,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Garanties Expirant <30j',
                                  style: GoogleFonts.inter(color: AppTheme.textSecondaryColor, fontSize: 11),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${criticalWarrantyAssets.length} équipements',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: criticalWarrantyAssets.isNotEmpty ? AppTheme.errorColor : AppTheme.successColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Tabs headers
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: const [
              Tab(icon: Icon(Icons.calendar_month_outlined), text: 'Calendrier'),
              Tab(icon: Icon(Icons.list_alt_outlined), text: 'Liste'),
              Tab(icon: Icon(Icons.verified_user_outlined), text: 'Garanties'),
            ],
            labelColor: AppTheme.primaryColor,
            indicatorColor: AppTheme.primaryColor,
          ),

          // Tabs Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 0: Calendrier interactif
                _buildCalendarTab(maintenanceProvider),

                // Tab 1: Liste des maintenances
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Rechercher par description, asset tag, notes...',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded),
                                  onPressed: () {
                                    _searchController.clear();
                                    _loadData();
                                  },
                                )
                              : null,
                        ),
                        onSubmitted: (_) => _loadData(),
                      ),
                    ),
                    Expanded(
                      child: maintenanceProvider.isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : maintenanceProvider.maintenances.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.build_outlined, size: 64, color: AppTheme.textSecondaryColor.withValues(alpha: 0.4)),
                                      const SizedBox(height: 16),
                                      Text('Aucune maintenance planifiée', style: GoogleFonts.inter(fontSize: 16, color: AppTheme.textSecondaryColor)),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  itemCount: maintenanceProvider.maintenances.length,
                                  itemBuilder: (context, index) {
                                    final maint = maintenanceProvider.maintenances[index];
                                    final dateText = DateFormat('dd/MM/yyyy').format(DateTime.parse(maint.datePrevue));
                                    final costText = NumberFormat.currency(symbol: 'XOF', decimalDigits: 0).format(maint.cout);

                                    Color statusColor = AppTheme.primaryColor;
                                    if (maint.statut == 'realise') statusColor = AppTheme.secondaryColor;
                                    if (maint.statut == 'annule') statusColor = AppTheme.errorColor;
                                    if (maint.statut == 'en_cours') statusColor = AppTheme.accentColor;

                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      child: ListTile(
                                        contentPadding: const EdgeInsets.all(16),
                                        leading: CircleAvatar(
                                          backgroundColor: maint.type == 'preventive'
                                              ? AppTheme.primaryLight
                                              : AppTheme.errorColor.withValues(alpha: 0.1),
                                          child: Icon(
                                            maint.type == 'preventive' ? Icons.health_and_safety_outlined : Icons.report_problem_outlined,
                                            color: maint.type == 'preventive' ? AppTheme.primaryColor : AppTheme.errorColor,
                                          ),
                                        ),
                                        title: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                maint.assetTag ?? 'Asset Inconnu',
                                                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: statusColor.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                maint.statut.toUpperCase(),
                                                style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: statusColor),
                                              ),
                                            ),
                                          ],
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const SizedBox(height: 6),
                                            Text(maint.description, style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textPrimaryColor)),
                                            const SizedBox(height: 4),
                                            Text('Prévue le : $dateText • Coût: $costText', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondaryColor)),
                                            if (maint.notes != null && maint.notes!.isNotEmpty) ...[
                                              const SizedBox(height: 4),
                                              Text('Notes : ${maint.notes}', style: GoogleFonts.inter(fontSize: 11, fontStyle: FontStyle.italic, color: AppTheme.textSecondaryColor)),
                                            ],
                                          ],
                                        ),
                                        trailing: canManage && maint.statut != 'realise' && maint.statut != 'annule'
                                            ? Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  IconButton(
                                                    icon: const Icon(Icons.check_circle_outline, color: AppTheme.successColor),
                                                    onPressed: () => _completeMaintenance(context, maint),
                                                    tooltip: 'Marquer comme terminée',
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.edit_outlined),
                                                    onPressed: () => _showMaintenanceDialog(context, maintenance: maint),
                                                  ),
                                                ],
                                              )
                                            : null,
                                      ),
                                    );
                                  },
                                ),
                    ),
                  ],
                ),


                // Tab 2: Asset Warranty tracking
                assetProvider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : assetsWithWarranty.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.verified_user_outlined, size: 64, color: AppTheme.textSecondaryColor.withValues(alpha: 0.4)),
                                const SizedBox(height: 16),
                                Text('Aucun équipement sous garantie', style: GoogleFonts.inter(fontSize: 16, color: AppTheme.textSecondaryColor)),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: assetsWithWarranty.length,
                            itemBuilder: (context, index) {
                              final asset = assetsWithWarranty[index];
                              final dateFin = DateTime.parse(asset.finGarantie!);
                              final diff = dateFin.difference(DateTime.now()).inDays;
                              final dateFinText = DateFormat('dd/MM/yyyy').format(dateFin);

                              final isNearExpiration = diff >= 0 && diff < 30;
                              final isExpired = diff < 0;

                              Color warrantyColor = AppTheme.successColor;
                              String statusText = 'Garantie active';
                              if (isNearExpiration) {
                                warrantyColor = AppTheme.warningColor;
                                statusText = 'Expire bientôt ($diff jours restants)';
                              } else if (isExpired) {
                                warrantyColor = AppTheme.errorColor;
                                statusText = 'Expirée (${diff.abs()} jours)';
                              } else {
                                statusText = '$diff jours restants';
                              }

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: warrantyColor.withValues(alpha: 0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(Icons.shield_outlined, color: warrantyColor),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${asset.assetTag} — ${asset.marque} ${asset.modele ?? ""}',
                                              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15),
                                            ),
                                            const SizedBox(height: 4),
                                            Text('Type : ${asset.type.toUpperCase()} • Site: ${asset.site ?? "Non spécifié"}', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondaryColor)),
                                            const SizedBox(height: 6),
                                            Text(
                                              'Fin de garantie : $dateFinText • $statusText',
                                              style: GoogleFonts.inter(fontSize: 13, color: warrantyColor, fontWeight: FontWeight.w600),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _completeMaintenance(BuildContext context, Maintenance maintenance) {
    final noteController = TextEditingController();
    final costController = TextEditingController(text: maintenance.cout.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clôturer la Maintenance'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Veuillez renseigner le coût final et les notes d\'intervention :'),
            const SizedBox(height: 12),
            TextField(
              controller: costController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Coût réel (XOF)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Notes d\'intervention (Ex: Pâte thermique changée)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              final data = {
                'statut': 'realise',
                'date_realisee': DateFormat('yyyy-MM-dd').format(DateTime.now()),
                'cout': double.tryParse(costController.text.trim()) ?? maintenance.cout,
                'notes': noteController.text.trim().isEmpty ? null : noteController.text.trim(),
              };

              final provider = Provider.of<MaintenanceProvider>(context, listen: false);
              final success = await provider.updateMaintenance(maintenance.id, data);
              if (success && context.mounted) {
                Navigator.pop(context);
                _loadData();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Maintenance clôturée avec succès'), backgroundColor: AppTheme.successColor),
                );
              }
            },
            child: const Text('Clôturer'),
          ),
        ],
      ),
    );
  }

  // ── Onglet Calendrier interactif ─────────────────────────────────────────────
  Widget _buildCalendarTab(dynamic maintenanceProvider) {
    // Grouper les maintenances par date
    final Map<DateTime, List<dynamic>> events = {};
    for (final maint in maintenanceProvider.maintenances) {
      try {
        final date = DateTime.parse(maint.datePrevue);
        final key = DateTime(date.year, date.month, date.day);
        events.putIfAbsent(key, () => []).add(maint);
      } catch (_) {}
    }

    List<dynamic> getEventsForDay(DateTime day) {
      final key = DateTime(day.year, day.month, day.day);
      return events[key] ?? [];
    }

    final selectedEvents = _selectedDay != null ? getEventsForDay(_selectedDay!) : [];

    return StatefulBuilder(
      builder: (context, setStateLocal) {
        return Column(
          children: [
            // Calendrier
            TableCalendar(
              locale: 'fr_FR',
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              eventLoader: getEventsForDay,
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
                selectedDecoration: const BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                ),
                markerDecoration: BoxDecoration(
                  color: AppTheme.warningColor,
                  shape: BoxShape.circle,
                ),
                outsideDaysVisible: false,
              ),
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              onPageChanged: (focusedDay) {
                _focusedDay = focusedDay;
              },
            ),
            const Divider(height: 1),
            // Liste des maintenances du jour sélectionné
            Expanded(
              child: selectedEvents.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.event_available_outlined, size: 40,
                              color: AppTheme.textSecondaryColor.withValues(alpha: 0.4)),
                          const SizedBox(height: 8),
                          Text(
                            _selectedDay == null
                                ? 'Sélectionnez un jour pour voir les maintenances'
                                : 'Aucune maintenance ce jour',
                            style: GoogleFonts.inter(color: AppTheme.textSecondaryColor, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: selectedEvents.length,
                      separatorBuilder: (_, _) => const Divider(height: 12),
                      itemBuilder: (context, index) {
                        final maint = selectedEvents[index];
                        Color statusColor = AppTheme.primaryColor;
                        if (maint.statut == 'realise') statusColor = AppTheme.successColor;
                        if (maint.statut == 'annule') statusColor = AppTheme.errorColor;
                        if (maint.statut == 'en_cours') statusColor = AppTheme.warningColor;
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          leading: Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.build_rounded, color: statusColor, size: 20),
                          ),
                          title: Text(
                            maint.assetTag ?? 'Asset Inconnu',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                          subtitle: Text(
                            maint.description,
                            style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondaryColor),
                            maxLines: 2,
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              maint.statut.replaceAll('_', ' ').toUpperCase(),
                              style: GoogleFonts.inter(color: statusColor, fontSize: 10, fontWeight: FontWeight.w700),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
