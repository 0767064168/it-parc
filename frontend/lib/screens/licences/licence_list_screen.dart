// ============================================
// lib/screens/licences/licence_list_screen.dart
// ============================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../models/licence.dart';
import '../../providers/licence_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/app_navigation_layout.dart';

class LicenceListScreen extends StatefulWidget {
  const LicenceListScreen({super.key});

  @override
  State<LicenceListScreen> createState() => _LicenceListScreenState();
}

class _LicenceListScreenState extends State<LicenceListScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
      Provider.of<UserProvider>(context, listen: false).fetchUsers();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadData() {
    Provider.of<LicenceProvider>(context, listen: false).fetchLicences(
      search: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
    );
  }

  void _showLicenceDialog(BuildContext context, {Licence? licence}) {
    final isEdit = licence != null;
    final nomController = TextEditingController(text: licence?.nom);
    final editeurController = TextEditingController(text: licence?.editeur);
    final cleController = TextEditingController(text: licence?.cleActivation);
    final notesController = TextEditingController(text: licence?.notes);
    final quotaController = TextEditingController(text: licence?.quotaMax?.toString());
    final coutController = TextEditingController(text: licence?.cout.toString());

    DateTime? selectedDate = licence?.dateExpiration != null
        ? DateTime.tryParse(licence!.dateExpiration!)
        : null;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateBuilder) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            isEdit ? 'Modifier la Licence' : 'Nouvelle Licence',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700),
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 450,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nomController,
                    decoration: const InputDecoration(
                      labelText: 'Nom de la licence *',
                      hintText: 'Ex: Microsoft Office 365 Pro',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: editeurController,
                    decoration: const InputDecoration(
                      labelText: 'Éditeur',
                      hintText: 'Ex: Microsoft',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: cleController,
                    decoration: const InputDecoration(
                      labelText: 'Clé d\'activation',
                      hintText: 'XXXXX-XXXXX-XXXXX-XXXXX',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: quotaController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Quota Max',
                            hintText: 'Vide = illimité',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: coutController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Coût (€/FCAF)',
                            hintText: 'Ex: 150000',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate ?? DateTime.now().add(const Duration(days: 365)),
                        firstDate: DateTime.now().subtract(const Duration(days: 365)),
                        lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
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
                          Text(
                            selectedDate == null
                                ? 'Pas de date d\'expiration'
                                : 'Expire le: ${DateFormat('dd/MM/yyyy').format(selectedDate!)}',
                            style: GoogleFonts.inter(
                              color: selectedDate == null
                                  ? AppTheme.textSecondaryColor
                                  : AppTheme.textPrimaryColor,
                            ),
                          ),
                          const Icon(Icons.calendar_today_rounded, color: AppTheme.primaryColor, size: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Notes / Détails',
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
                  'editeur': editeurController.text.trim().isEmpty ? null : editeurController.text.trim(),
                  'cle_activation': cleController.text.trim().isEmpty ? null : cleController.text.trim(),
                  'quota_max': int.tryParse(quotaController.text.trim()),
                  'cout': double.tryParse(coutController.text.trim()) ?? 0.0,
                  'date_expiration': selectedDate != null
                      ? DateFormat('yyyy-MM-dd').format(selectedDate!)
                      : null,
                  'notes': notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                };

                final provider = Provider.of<LicenceProvider>(context, listen: false);
                bool success = false;
                if (isEdit) {
                  success = await provider.updateLicence(licence.id, data);
                } else {
                  success = await provider.createLicence(data);
                }

                if (success && context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isEdit ? 'Licence mise à jour avec succès' : 'Licence créée avec succès'),
                      backgroundColor: AppTheme.successColor,
                    ),
                  );
                }
              },
              child: Text(isEdit ? 'Enregistrer' : 'Créer'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAllocationDialog(BuildContext context, Licence licence) async {
    final provider = Provider.of<LicenceProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final fullLicence = await provider.getLicenceById(licence.id);

    if (fullLicence == null) return;

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateBuilder) {
          final allocatedUserIds = fullLicence.allocations?.map((a) => a.userId).toSet() ?? {};
          final availableUsers = userProvider.users.where((u) => !allocatedUserIds.contains(u.id)).toList();

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(licence.nom, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18)),
                const SizedBox(height: 4),
                Text('Allocations et attributions', style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondaryColor)),
              ],
            ),
            content: SizedBox(
              width: 500,
              height: 400,
              child: Column(
                children: [
                  // Quota info
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Utilisées: ${fullLicence.nbUtilisations} seats', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                        Text(
                          'Max: ${fullLicence.quotaMax == null ? "Illimité" : "${fullLicence.quotaMax} seats"}',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppTheme.primaryColor),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: DefaultTabController(
                      length: 2,
                      child: Column(
                        children: [
                          const TabBar(
                            tabs: [
                              Tab(text: 'Attribué à'),
                              Tab(text: 'Nouvel utilisateur'),
                            ],
                            labelColor: AppTheme.primaryColor,
                            indicatorColor: AppTheme.primaryColor,
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: TabBarView(
                              children: [
                                // Tab 1: Allocated Users
                                (fullLicence.allocations?.isEmpty ?? true)
                                    ? Center(child: Text('Aucun utilisateur assigné.', style: GoogleFonts.inter(color: AppTheme.textSecondaryColor)))
                                    : ListView.builder(
                                        itemCount: fullLicence.allocations!.length,
                                        itemBuilder: (context, index) {
                                          final alloc = fullLicence.allocations![index];
                                          return ListTile(
                                            leading: CircleAvatar(
                                              backgroundColor: AppTheme.borderColor,
                                              child: const Icon(Icons.person, color: AppTheme.textSecondaryColor),
                                            ),
                                            title: Text('${alloc.userPrenom} ${alloc.userNom}'),
                                            subtitle: Text(alloc.userDepartement ?? 'Sans département'),
                                            trailing: IconButton(
                                              icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.errorColor),
                                              onPressed: () async {
                                                final success = await provider.deallocateLicence(licence.id, alloc.id);
                                                if (success) {
                                                  final updated = await provider.getLicenceById(licence.id);
                                                  if (updated != null) {
                                                    setStateBuilder(() {
                                                      fullLicence.allocations!.clear();
                                                      fullLicence.allocations!.addAll(updated.allocations ?? []);
                                                    });
                                                  }
                                                }
                                              },
                                            ),
                                          );
                                        },
                                      ),
                                // Tab 2: Allocate to User
                                availableUsers.isEmpty
                                    ? Center(child: Text('Tous les utilisateurs ont cette licence.', style: GoogleFonts.inter(color: AppTheme.textSecondaryColor)))
                                    : ListView.builder(
                                        itemCount: availableUsers.length,
                                        itemBuilder: (context, index) {
                                          final user = availableUsers[index];
                                          return ListTile(
                                            leading: CircleAvatar(
                                              backgroundColor: AppTheme.primaryLight,
                                              child: Text(user.prenom[0], style: const TextStyle(color: AppTheme.primaryColor)),
                                            ),
                                            title: Text(user.nomComplet),
                                            subtitle: Text(user.departement ?? 'Sans département'),
                                            trailing: const Icon(Icons.add_circle_outline_rounded, color: AppTheme.primaryColor),
                                            onTap: () async {
                                              if (licence.quotaMax != null && licence.nbUtilisations >= licence.quotaMax!) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(
                                                    content: Text('Limite de quota atteinte pour cette licence.'),
                                                    backgroundColor: AppTheme.errorColor,
                                                  ),
                                                );
                                                return;
                                              }
                                              final success = await provider.allocateLicence(licence.id, user.id);
                                              if (success) {
                                                final updated = await provider.getLicenceById(licence.id);
                                                if (updated != null) {
                                                  setStateBuilder(() {
                                                    fullLicence.allocations!.clear();
                                                    fullLicence.allocations!.addAll(updated.allocations ?? []);
                                                  });
                                                }
                                              }
                                            },
                                          );
                                        },
                                      ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Fermer', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final licenceProvider = Provider.of<LicenceProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;
    final canManage = user?.role == 'admin' || user?.role == 'technicien';

    return AppNavigationLayout(
      title: 'Gestion des Licences',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: _loadData,
        ),
      ],
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => _showLicenceDialog(context),
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: Text('Nouvelle Licence', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            )
          : null,
      child: Column(
        children: [
          // Search & Metrics Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Rechercher par nom, éditeur...',
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
              ],
            ),
          ),
          Expanded(
            child: licenceProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : licenceProvider.licences.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.vpn_key_outlined, size: 64, color: AppTheme.textSecondaryColor.withValues(alpha: 0.4)),
                            const SizedBox(height: 16),
                            Text(
                              'Aucune licence trouvée',
                              style: GoogleFonts.inter(fontSize: 16, color: AppTheme.textSecondaryColor),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 400,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          mainAxisExtent: 220,
                        ),
                        itemCount: licenceProvider.licences.length,
                        itemBuilder: (context, index) {
                          final licence = licenceProvider.licences[index];
                          final quotaText = licence.quotaMax == null ? 'Illimité' : '${licence.quotaMax} seats';
                          final dateExpText = licence.dateExpiration != null
                              ? DateFormat('dd/MM/yyyy').format(DateTime.parse(licence.dateExpiration!))
                              : 'Permanent';

                          // Expiration check
                          bool isExpired = false;
                          if (licence.dateExpiration != null) {
                            isExpired = DateTime.parse(licence.dateExpiration!).isBefore(DateTime.now());
                          }

                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          licence.nom,
                                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (isExpired)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppTheme.errorColor.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text('Expiré', style: GoogleFonts.inter(fontSize: 10, color: AppTheme.errorColor, fontWeight: FontWeight.bold)),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    licence.editeur ?? 'Éditeur inconnu',
                                    style: GoogleFonts.inter(color: AppTheme.textSecondaryColor, fontSize: 12),
                                  ),
                                  const Spacer(),
                                  // Stats rows
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Utilisation :', style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondaryColor)),
                                      Text('${licence.nbUtilisations} / $quotaText', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Expiration :', style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondaryColor)),
                                      Text(dateExpText, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: isExpired ? AppTheme.errorColor : null)),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Coût :', style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondaryColor)),
                                      Text(
                                        NumberFormat.currency(symbol: 'XOF', decimalDigits: 0).format(licence.cout),
                                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.secondaryColor),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 20),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton.icon(
                                        icon: const Icon(Icons.people_alt_outlined, size: 16),
                                        label: const Text('Assigner'),
                                        onPressed: () => _showAllocationDialog(context, licence),
                                      ),
                                      if (canManage) ...[
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, size: 18),
                                          onPressed: () => _showLicenceDialog(context, licence: licence),
                                          tooltip: 'Modifier',
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.errorColor),
                                          onPressed: () => showDialog(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: const Text('Supprimer la Licence'),
                                              content: Text('Voulez-vous supprimer la licence "${licence.nom}" ? Cette action est irréversible.'),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(context),
                                                  child: const Text('Annuler'),
                                                ),
                                                TextButton(
                                                  onPressed: () async {
                                                    Navigator.pop(context);
                                                    final success = await licenceProvider.deleteLicence(licence.id);
                                                    if (success && context.mounted) {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        const SnackBar(content: Text('Licence supprimée')),
                                                      );
                                                    }
                                                  },
                                                  child: const Text('Supprimer', style: TextStyle(color: AppTheme.errorColor)),
                                                ),
                                              ],
                                            ),
                                          ),
                                          tooltip: 'Supprimer',
                                        ),
                                      ],
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
