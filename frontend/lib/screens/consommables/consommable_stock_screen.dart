// ============================================
// lib/screens/consommables/consommable_stock_screen.dart
// ============================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme.dart';
import '../../models/consommable.dart';
import '../../providers/consommable_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_navigation_layout.dart';

class ConsommableStockScreen extends StatefulWidget {
  const ConsommableStockScreen({super.key});

  @override
  State<ConsommableStockScreen> createState() => _ConsommableStockScreenState();
}

class _ConsommableStockScreenState extends State<ConsommableStockScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadData() {
    Provider.of<ConsommableProvider>(context, listen: false).fetchConsommables(
      search: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
    );
  }

  void _showConsommableDialog(BuildContext context, {Consommable? consommable}) {
    final isEdit = consommable != null;
    final nomController = TextEditingController(text: consommable?.nom);
    final catController = TextEditingController(text: consommable?.categorie);
    final quantiteController = TextEditingController(text: consommable?.quantite.toString() ?? '0');
    final seuilController = TextEditingController(text: consommable?.seuilAlerte.toString() ?? '5');
    final empController = TextEditingController(text: consommable?.emplacement);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          isEdit ? 'Modifier le Consommable' : 'Nouveau Consommable',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nomController,
                  decoration: const InputDecoration(
                    labelText: 'Nom du consommable *',
                    hintText: 'Ex: Cartouche HP 85A Noir',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: catController,
                  decoration: const InputDecoration(
                    labelText: 'Catégorie',
                    hintText: 'Ex: Cartouche d\'encre, Câble',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: quantiteController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Quantité Initiale',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: seuilController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Seuil d\'alerte',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: empController,
                  decoration: const InputDecoration(
                    labelText: 'Emplacement / Armoire',
                    hintText: 'Ex: Armoire B - Rayon 3',
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
              if (nomController.text.trim().isEmpty) return;

              final data = {
                'nom': nomController.text.trim(),
                'categorie': catController.text.trim().isEmpty ? null : catController.text.trim(),
                'quantite': int.tryParse(quantiteController.text.trim()) ?? 0,
                'seuil_alerte': int.tryParse(seuilController.text.trim()) ?? 5,
                'emplacement': empController.text.trim().isEmpty ? null : empController.text.trim(),
              };

              final provider = Provider.of<ConsommableProvider>(context, listen: false);
              bool success = false;
              if (isEdit) {
                success = await provider.updateConsommable(consommable.id, data);
              } else {
                success = await provider.createConsommable(data);
              }

              if (success && context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isEdit ? 'Consommable mis à jour' : 'Consommable enregistré'),
                    backgroundColor: AppTheme.successColor,
                  ),
                );
              }
            },
            child: Text(isEdit ? 'Enregistrer' : 'Créer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final consommableProvider = Provider.of<ConsommableProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;
    final canManage = user?.role == 'admin' || user?.role == 'technicien';

    // Analytics computation
    int totalItems = 0;
    int alertCount = 0;
    for (var c in consommableProvider.consommables) {
      totalItems += c.quantite;
      if (c.estAlerteStock) alertCount++;
    }

    return AppNavigationLayout(
      title: 'Stocks & Consommables',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: _loadData,
        ),
      ],
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => _showConsommableDialog(context),
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: Text('Ajouter article', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            )
          : null,
      child: Column(
        children: [
          // Stock Statistics Header
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
                            child: const Icon(Icons.inventory_2_outlined, color: AppTheme.primaryColor, size: 24),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Articles en Stock',
                                  style: GoogleFonts.inter(color: AppTheme.textSecondaryColor, fontSize: 11),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$totalItems unités',
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
                              color: alertCount > 0
                                  ? AppTheme.errorColor.withValues(alpha: 0.1)
                                  : AppTheme.successColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.warning_amber_rounded,
                              color: alertCount > 0 ? AppTheme.errorColor : AppTheme.successColor,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Alertes de Rupture',
                                  style: GoogleFonts.inter(color: AppTheme.textSecondaryColor, fontSize: 11),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$alertCount articles',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: alertCount > 0 ? AppTheme.errorColor : AppTheme.successColor,
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

          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher par nom de consommable, catégorie...',
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

          // Consumables Grid
          Expanded(
            child: consommableProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : consommableProvider.consommables.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.category_outlined, size: 64, color: AppTheme.textSecondaryColor.withValues(alpha: 0.4)),
                            const SizedBox(height: 16),
                            Text(
                              'Aucun consommable enregistré',
                              style: GoogleFonts.inter(fontSize: 16, color: AppTheme.textSecondaryColor),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 350,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          mainAxisExtent: 180,
                        ),
                        itemCount: consommableProvider.consommables.length,
                        itemBuilder: (context, index) {
                          final item = consommableProvider.consommables[index];
                          final isLowStock = item.estAlerteStock;

                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: AppTheme.borderColor,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          item.categorie ?? 'Général',
                                          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textSecondaryColor),
                                        ),
                                      ),
                                      if (isLowStock)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: AppTheme.errorColor.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            'SEUIL BAS',
                                            style: GoogleFonts.inter(fontSize: 9, color: AppTheme.errorColor, fontWeight: FontWeight.w700),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    item.nom,
                                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Emplacement : ${item.emplacement ?? "Non spécifié"}',
                                    style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondaryColor),
                                  ),
                                  const Spacer(),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Quantité :', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondaryColor)),
                                          Text(
                                            '${item.quantite} pièces',
                                            style: GoogleFonts.inter(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: isLowStock ? AppTheme.errorColor : AppTheme.secondaryColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                      // Quick action buttons for storage manager
                                      if (canManage)
                                        Row(
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.remove_circle_outline, color: AppTheme.errorColor, size: 24),
                                              onPressed: item.quantite <= 0
                                                  ? null
                                                  : () => consommableProvider.adjustStock(item.id, -1),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.add_circle_outline, color: AppTheme.secondaryColor, size: 24),
                                              onPressed: () => consommableProvider.adjustStock(item.id, 1),
                                            ),
                                            const SizedBox(width: 8),
                                            PopupMenuButton<String>(
                                              icon: const Icon(Icons.more_vert_rounded, size: 20),
                                              onSelected: (val) {
                                                if (val == 'edit') {
                                                  _showConsommableDialog(context, consommable: item);
                                                } else if (val == 'delete') {
                                                  showDialog(
                                                    context: context,
                                                    builder: (context) => AlertDialog(
                                                      title: const Text('Supprimer l\'article'),
                                                      content: Text('Voulez-vous supprimer l\'article "${item.nom}" du stock ?'),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () => Navigator.pop(context),
                                                          child: const Text('Annuler'),
                                                        ),
                                                        TextButton(
                                                          onPressed: () async {
                                                            Navigator.pop(context);
                                                            await consommableProvider.deleteConsommable(item.id);
                                                          },
                                                          child: const Text('Supprimer', style: TextStyle(color: AppTheme.errorColor)),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                }
                                              },
                                              itemBuilder: (context) => [
                                                const PopupMenuItem(
                                                  value: 'edit',
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.edit_outlined, size: 18),
                                                      SizedBox(width: 8),
                                                      Text('Modifier'),
                                                    ],
                                                  ),
                                                ),
                                                const PopupMenuItem(
                                                  value: 'delete',
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.delete_outline, size: 18, color: AppTheme.errorColor),
                                                      SizedBox(width: 8),
                                                      Text('Supprimer', style: TextStyle(color: AppTheme.errorColor)),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
