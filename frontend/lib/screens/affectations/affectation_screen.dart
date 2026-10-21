// ============================================
// lib/screens/affectations/affectation_screen.dart
// ============================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../providers/affectation_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_navigation_layout.dart';
import 'edit_affectation_dialog.dart';

class AffectationScreen extends StatefulWidget {
  const AffectationScreen({super.key});

  @override
  State<AffectationScreen> createState() => _AffectationScreenState();
}

class _AffectationScreenState extends State<AffectationScreen> {
  final _scrollController = ScrollController();
  // Filtre : null = tous, true = actifs, false = historique
  bool? _filterActif = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData(page: 1));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final p = Provider.of<AffectationProvider>(context, listen: false);
      if (!p.isLoading && p.affectations.length < p.total) {
        _loadData(page: p.currentPage + 1);
      }
    }
  }

  void _loadData({int page = 1}) {
    Provider.of<AffectationProvider>(context, listen: false).fetchAffectations(
      page: page,
      actif: _filterActif,
      isRefresh: page == 1,
    );
  }

  void _confirmDelete(AffectationItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer l\'affectation'),
        content: const Text('Voulez-vous vraiment supprimer cet historique d\'affectation ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final provider = Provider.of<AffectationProvider>(context, listen: false);
              final success = await provider.deleteAffectation(item.id);
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Affectation supprimée')),
                );
                _loadData(page: 1);
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Erreur lors de la suppression')),
                );
              }
            },
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AffectationProvider>(context);

    return AppNavigationLayout(
      title: 'Affectations',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () => _loadData(page: 1),
        ),
      ],
      child: Column(
        children: [
          // ── Filtres rapides ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const Text('Afficher : ', style: TextStyle(color: AppTheme.textSecondaryColor)),
                  const SizedBox(width: 12.0),
                  _buildFilterChip('Actives', true),
                  const SizedBox(width: 8.0),
                  _buildFilterChip('Historique', false),
                  const SizedBox(width: 8.0),
                  _buildFilterChip('Toutes', null),
                  const SizedBox(width: 12.0),
                  Text(
                    '${provider.total} affectation${provider.total > 1 ? 's' : ''}',
                    style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12.0),
                  ),
                ],
              ),
            ),
          ),

          // ── Liste ────────────────────────────────────────────────
          Expanded(
            child: provider.isLoading && provider.affectations.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : provider.errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, color: AppTheme.errorColor, size: 48),
                            const SizedBox(height: 16),
                            Text(provider.errorMessage!),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => _loadData(page: 1),
                              child: const Text('Réessayer'),
                            ),
                          ],
                        ),
                      )
                    : provider.affectations.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.assignment_outlined,
                                  size: 64,
                                  color: AppTheme.textSecondaryColor.withValues(alpha: 0.4),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Aucune affectation trouvée',
                                  style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 16.0),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                            itemCount: provider.affectations.length + (provider.isLoading ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == provider.affectations.length) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 24.0),
                                  child: Center(child: CircularProgressIndicator()),
                                );
                              }
                              return _buildAffectationCard(provider.affectations[index]);
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool? value) {
    final isSelected = _filterActif == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() => _filterActif = value);
        _loadData(page: 1);
      },
      selectedColor: AppTheme.primaryColor.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondaryColor,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12.0,
      ),
    );
  }

  Widget _buildAffectationCard(AffectationItem item) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final role = auth.currentUser?.role;
    final canEdit = role == 'admin' || role == 'technicien';
    final canDelete = role == 'admin';

    return Card(
      margin: const EdgeInsets.only(bottom: 8.0),
      child: InkWell(
        onTap: () => context.push('/assets/${item.assetId}'),
        borderRadius: BorderRadius.circular(12.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Indicateur actif/inactif
                  Container(
                    width: 4.0,
                    height: 60.0,
                    decoration: BoxDecoration(
                      color: item.actif ? AppTheme.successColor : AppTheme.borderColor,
                      borderRadius: BorderRadius.circular(4.0),
                    ),
                  ),
                  const SizedBox(width: 12.0),

                  // Infos équipement
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              item.assetTag,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14.0,
                                color: AppTheme.textPrimaryColor,
                              ),
                            ),
                            const SizedBox(width: 8.0),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                              decoration: BoxDecoration(
                                color: item.actif
                                    ? AppTheme.successColor.withValues(alpha: 0.12)
                                    : AppTheme.borderColor.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(4.0),
                              ),
                              child: Text(
                                item.actif ? 'ACTIVE' : 'CLÔTURÉE',
                                style: TextStyle(
                                  fontSize: 9.0,
                                  fontWeight: FontWeight.bold,
                                  color: item.actif ? AppTheme.successColor : AppTheme.textSecondaryColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4.0),
                        Text(
                          '${item.marque} ${item.modele ?? ''} · ${item.type.toUpperCase()}',
                          style: const TextStyle(fontSize: 12.0, color: AppTheme.textSecondaryColor),
                        ),
                      ],
                    ),
                  ),

                  // Infos utilisateur + dates
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.person_outline, size: 14.0, color: AppTheme.primaryColor),
                            const SizedBox(width: 4.0),
                            Flexible(
                              child: Text(
                                item.utilisateurNom,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13.0,
                                  color: AppTheme.textPrimaryColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.end,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4.0),
                        Text(
                          'Attribution: ${item.dateAttribution}',
                          style: const TextStyle(fontSize: 11.0, color: AppTheme.textSecondaryColor),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (item.dateRetrait != null)
                          Text(
                            'Retrait: ${item.dateRetrait}',
                            style: const TextStyle(fontSize: 11.0, color: AppTheme.textSecondaryColor),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (item.site != null)
                          Text(
                            item.site!,
                            style: const TextStyle(fontSize: 11.0, color: AppTheme.textSecondaryColor),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (canEdit || canDelete) ...[
                const SizedBox(height: 8.0),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (canEdit)
                      TextButton.icon(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Modifier'),
                        onPressed: () async {
                          final result = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => EditAffectationDialog(affectation: item),
                          );
                          if (result == true) {
                            _loadData(page: 1);
                          }
                        },
                      ),
                    if (canEdit) const SizedBox(width: 8),
                    if (canDelete)
                      TextButton.icon(
                        icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                        label: const Text('Supprimer', style: TextStyle(color: Colors.red)),
                        onPressed: () => _confirmDelete(item),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
