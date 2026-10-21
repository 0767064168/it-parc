// ============================================
// lib/screens/assets/asset_list_screen.dart
// ============================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme.dart';
import '../../providers/asset_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_navigation_layout.dart';
import '../../widgets/asset_card.dart';

class AssetListScreen extends StatefulWidget {
  const AssetListScreen({super.key});

  @override
  State<AssetListScreen> createState() => _AssetListScreenState();
}

class _AssetListScreenState extends State<AssetListScreen>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  String? _selectedType;
  String? _selectedStatut;
  String? _selectedSite;
  String? _selectedDept;
  bool _filtersVisible = false;

  late final AnimationController _filterAnimCtrl;
  late final Animation<double> _filterHeightAnim;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    _filterAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _filterHeightAnim = CurvedAnimation(
      parent: _filterAnimCtrl,
      curve: Curves.easeOutCubic,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<AssetProvider>(context, listen: false);
      provider.fetchFilterOptions();
      _loadData(page: 1);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _filterAnimCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final provider = Provider.of<AssetProvider>(context, listen: false);
      if (!provider.isLoading && provider.assets.length < provider.totalAssets) {
        _loadData(page: provider.currentPage + 1);
      }
    }
  }

  void _loadData({int page = 1}) {
    Provider.of<AssetProvider>(context, listen: false).fetchAssets(
      page: page,
      type: _selectedType,
      statut: _selectedStatut,
      site: _selectedSite,
      departement: _selectedDept,
      search: _searchController.text.trim().isEmpty
          ? null
          : _searchController.text.trim(),
      isRefresh: page == 1,
    );
  }

  void _resetFilters() {
    setState(() {
      _selectedType   = null;
      _selectedStatut = null;
      _selectedSite   = null;
      _selectedDept   = null;
      _searchController.clear();
    });
    _loadData(page: 1);
  }

  void _toggleFilters() {
    setState(() => _filtersVisible = !_filtersVisible);
    if (_filtersVisible) {
      _filterAnimCtrl.forward();
    } else {
      _filterAnimCtrl.reverse();
    }
  }

  bool get _hasActiveFilters =>
      _selectedType != null ||
      _selectedStatut != null ||
      _selectedSite != null ||
      _selectedDept != null;

  @override
  Widget build(BuildContext context) {
    final assetProvider = Provider.of<AssetProvider>(context);
    final authProvider  = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;
    final canManage = user?.role == 'admin' || user?.role == 'technicien';

    return AppNavigationLayout(
      title: 'Inventaire du Parc',
      actions: [
        // Filtre toggle avec badge actif
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  _filtersVisible ? Icons.filter_alt : Icons.filter_alt_outlined,
                  key: ValueKey(_filtersVisible),
                  color: _filtersVisible ? AppTheme.primaryColor : null,
                ),
              ),
              onPressed: _toggleFilters,
              tooltip: 'Filtres',
            ),
            if (_hasActiveFilters)
              Positioned(
                top: 6, right: 6,
                child: Container(
                  width: 8, height: 8,
                  decoration: const BoxDecoration(
                    color: AppTheme.errorColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: () => _loadData(page: 1),
          tooltip: 'Actualiser',
        ),
      ],
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/assets/new'),
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: Text('Ajouter', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              elevation: 4,
            )
          : null,
      child: Column(
        children: [
          // ── Barre de recherche ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Rechercher par tag, S/N, marque, modèle…',
                      prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textSecondaryColor, size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, color: AppTheme.textSecondaryColor, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                _loadData(page: 1);
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _loadData(page: 1),
                    style: GoogleFonts.inter(fontSize: 14),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  ),
                  onPressed: () => _loadData(page: 1),
                  child: Text('Chercher', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),

          // ── Chips des filtres actifs ─────────────────────────────
          if (_hasActiveFilters)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    if (_selectedType != null)
                      _ActiveFilterChip(
                        label: 'Type: ${_selectedType!}',
                        color: AppTheme.primaryColor,
                        onRemove: () { setState(() => _selectedType = null); _loadData(page: 1); },
                      ),
                    if (_selectedStatut != null)
                      _ActiveFilterChip(
                        label: 'Statut: ${_selectedStatut!}',
                        color: AppTheme.successColor,
                        onRemove: () { setState(() => _selectedStatut = null); _loadData(page: 1); },
                      ),
                    if (_selectedSite != null)
                      _ActiveFilterChip(
                        label: 'Site: ${_selectedSite!}',
                        color: AppTheme.warningColor,
                        onRemove: () { setState(() => _selectedSite = null); _loadData(page: 1); },
                      ),
                    if (_selectedDept != null)
                      _ActiveFilterChip(
                        label: 'Dép.: ${_selectedDept!}',
                        color: const Color(0xFF7C3AED),
                        onRemove: () { setState(() => _selectedDept = null); _loadData(page: 1); },
                      ),
                    const SizedBox(width: 4),
                    TextButton.icon(
                      onPressed: _resetFilters,
                      icon: const Icon(Icons.close_rounded, size: 14),
                      label: Text('Tout effacer', style: GoogleFonts.inter(fontSize: 12)),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.errorColor,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Panel filtres avancés (animé) ────────────────────────
          SizeTransition(
            sizeFactor: _filterHeightAnim,
            child: _buildFiltersPanel(assetProvider),
          ),

          // ── Infos comptage ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${assetProvider.totalAssets} équipements',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Liste des équipements ─────────────────────────────────
          Expanded(
            child: assetProvider.assets.isEmpty && !assetProvider.isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 56,
                          color: AppTheme.textSecondaryColor.withValues(alpha: 0.35),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Aucun équipement trouvé.',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            color: AppTheme.textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: assetProvider.assets.length +
                        (assetProvider.isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == assetProvider.assets.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      return AssetCard(asset: assetProvider.assets[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersPanel(AssetProvider provider) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.20)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune_rounded, size: 14, color: AppTheme.primaryColor),
              const SizedBox(width: 6),
              Text(
                'Filtres avancés',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildDropdown(
                label: 'Type', value: _selectedType,
                items: provider.availableTypes,
                onChanged: (val) { setState(() => _selectedType = val); _loadData(page: 1); },
              ),
              _buildDropdown(
                label: 'Statut', value: _selectedStatut,
                items: provider.availableStatuts,
                onChanged: (val) { setState(() => _selectedStatut = val); _loadData(page: 1); },
              ),
              _buildDropdown(
                label: 'Site', value: _selectedSite,
                items: provider.availableSites,
                onChanged: (val) { setState(() => _selectedSite = val); _loadData(page: 1); },
              ),
              _buildDropdown(
                label: 'Département', value: _selectedDept,
                items: provider.availableDepartements,
                onChanged: (val) { setState(() => _selectedDept = val); _loadData(page: 1); },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final width = screenWidth >= 600 ? (screenWidth - 80) / 4 : (screenWidth - 48);

    return SizedBox(
      width: width,
      child: DropdownButtonFormField<String>(
        initialValue: (value != null && items.contains(value)) ? value : null,
        decoration: InputDecoration(
          labelText: label,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          isDense: true,
        ),
        style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textPrimaryColor),
        items: [
          DropdownMenuItem<String>(
            value: null,
            child: Text(
              'Tous',
              style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondaryColor),
            ),
          ),
          ...items.map((item) => DropdownMenuItem<String>(
            value: item,
            child: Text(
              item.replaceAll('_', ' ').toUpperCase(),
              style: GoogleFonts.inter(fontSize: 13),
            ),
          )),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

// ── Chip filtre actif ──────────────────────────────────────────────────────────
class _ActiveFilterChip extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onRemove;

  const _ActiveFilterChip({
    required this.label,
    required this.color,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.fromLTRB(10, 4, 6, 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(10),
            child: Icon(Icons.close_rounded, size: 14, color: color),
          ),
        ],
      ),
    );
  }
}
