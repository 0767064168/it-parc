// ============================================
// lib/screens/search/global_search_screen.dart
// ============================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../providers/auth_provider.dart';

class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  bool _isLoading = false;
  Map<String, dynamic>? _results;
  String? _error;

  int get _totalResults {
    if (_results == null) return 0;
    return (_results!['assets']?.length ?? 0) +
        (_results!['tickets']?.length ?? 0) +
        (_results!['maintenances']?.length ?? 0) +
        (_results!['licences']?.length ?? 0) +
        (_results!['wiki']?.length ?? 0);
  }

  Future<void> _search(String query) async {
    if (query.trim().length < 2) return;
    setState(() { _isLoading = true; _error = null; });

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final dio = Dio(BaseOptions(
        baseUrl: AppConstants.apiBaseUrl.replaceAll('/api', ''),
        headers: {'Authorization': 'Bearer ${auth.token}'},
      ));
      final response = await dio.get('/api/search', queryParameters: {'q': query.trim()});
      setState(() {
        _results = response.data['data'] as Map<String, dynamic>?;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Erreur lors de la recherche. Vérifiez votre connexion.';
        _isLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: TextField(
          controller: _searchController,
          focusNode: _focusNode,
          decoration: InputDecoration(
            hintText: 'Rechercher dans tout le parc IT...',
            hintStyle: GoogleFonts.inter(color: AppTheme.textSecondaryColor, fontSize: 15),
            border: InputBorder.none,
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() { _results = null; });
                    },
                  )
                : null,
          ),
          style: GoogleFonts.inter(fontSize: 15),
          onSubmitted: _search,
          textInputAction: TextInputAction.search,
          onChanged: (v) => setState(() {}),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.search_rounded, size: 18),
            label: const Text('Chercher'),
            onPressed: () => _search(_searchController.text),
          ),
        ],
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Theme.of(context).dividerColor, height: 1),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 48, color: AppTheme.errorColor),
            const SizedBox(height: 12),
            Text(_error!, style: GoogleFonts.inter(color: AppTheme.textSecondaryColor)),
          ],
        ),
      );
    }
    if (_results == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.manage_search_rounded, size: 72,
                color: AppTheme.textSecondaryColor.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text('Entrez un terme pour rechercher\ndans tous les modules',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 15, color: AppTheme.textSecondaryColor)),
            const SizedBox(height: 8),
            Text('Équipements, tickets, maintenances, licences, wiki…',
              style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondaryColor.withValues(alpha: 0.6))),
          ],
        ),
      );
    }
    if (_totalResults == 0) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 64, color: AppTheme.textSecondaryColor.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text('Aucun résultat pour "${_searchController.text}"',
              style: GoogleFonts.inter(color: AppTheme.textSecondaryColor, fontSize: 14)),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Résumé
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$_totalResults résultat${_totalResults > 1 ? 's' : ''} pour "${_searchController.text}"',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppTheme.primaryColor),
          ),
        ),

        // Assets
        ..._buildSection(
          icon: Icons.devices_rounded,
          label: 'Équipements',
          color: AppTheme.primaryColor,
          items: _results!['assets'] as List? ?? [],
          titleKey: 'asset_tag',
          subtitleBuilder: (item) => '${item['marque'] ?? ''} ${item['modele'] ?? ''} • ${item['statut'] ?? ''}',
          onTap: (item) => context.push('/assets/${item['id']}'),
        ),

        // Tickets
        ..._buildSection(
          icon: Icons.confirmation_number_rounded,
          label: 'Tickets IT',
          color: const Color(0xFF7C3AED),
          items: _results!['tickets'] as List? ?? [],
          titleKey: 'titre',
          subtitleBuilder: (item) => '${item['statut'] ?? ''} • ${item['priorite'] ?? ''}',
          onTap: (item) => context.push('/tickets/${item['id']}'),
        ),

        // Maintenances
        ..._buildSection(
          icon: Icons.build_rounded,
          label: 'Maintenances',
          color: AppTheme.warningColor,
          items: _results!['maintenances'] as List? ?? [],
          titleKey: 'description',
          subtitleBuilder: (item) => '${item['type'] ?? ''} • ${item['statut'] ?? ''}',
          onTap: (item) => context.go('/maintenances'),
        ),

        // Licences
        ..._buildSection(
          icon: Icons.vpn_key_rounded,
          label: 'Licences',
          color: const Color(0xFF0891B2),
          items: _results!['licences'] as List? ?? [],
          titleKey: 'nom',
          subtitleBuilder: (item) => '${item['editeur'] ?? ''} • ${item['statut'] ?? ''}',
          onTap: (item) => context.go('/licences'),
        ),

        // Wiki
        ..._buildSection(
          icon: Icons.menu_book_rounded,
          label: 'Base de Connaissances',
          color: AppTheme.successColor,
          items: _results!['wiki'] as List? ?? [],
          titleKey: 'titre',
          subtitleBuilder: (item) => item['categorie'] ?? '',
          onTap: (item) => context.go('/wiki'),
        ),
      ],
    );
  }

  List<Widget> _buildSection({
    required IconData icon,
    required String label,
    required Color color,
    required List items,
    required String titleKey,
    required String Function(Map<String, dynamic>) subtitleBuilder,
    required void Function(Map<String, dynamic>) onTap,
  }) {
    if (items.isEmpty) return [];
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 15, color: color),
            ),
            const SizedBox(width: 8),
            Text(
              '$label (${items.length})',
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimaryColor),
            ),
          ],
        ),
      ),
      Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: items.length,
          separatorBuilder: (_, _) => Divider(height: 1, color: AppTheme.borderColor),
          itemBuilder: (context, idx) {
            final item = items[idx] as Map<String, dynamic>;
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              title: Text(
                item[titleKey]?.toString() ?? '–',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                subtitleBuilder(item),
                style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondaryColor),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.chevron_right_rounded, size: 18, color: AppTheme.textSecondaryColor),
              onTap: () => onTap(item),
            );
          },
        ),
      ),
    ];
  }
}
