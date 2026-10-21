// ============================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../providers/asset_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/affectation_provider.dart';
import '../../models/asset.dart';
import '../../widgets/status_badge.dart';
import '../../utils/pdf_helper.dart';

class AssetDetailScreen extends StatefulWidget {
  final int assetId;

  const AssetDetailScreen({super.key, required this.assetId});

  @override
  State<AssetDetailScreen> createState() => _AssetDetailScreenState();
}

class _AssetDetailScreenState extends State<AssetDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = Provider.of<AssetProvider>(context, listen: false);
      provider.fetchAssetDetails(widget.assetId);
      provider.fetchAttachments(widget.assetId);
    });
  }

  // Affiche un dialogue pour l'archivage
  void _showArchiveDialog(BuildContext context, Asset asset) {
    final motifController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Archiver l\'équipement'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'L\'archivage va retirer définitivement l\'équipement de l\'inventaire actif et clore l\'affectation en cours.',
                style: TextStyle(fontSize: 13.0, color: AppTheme.textSecondaryColor),
              ),
              const SizedBox(height: 16.0),
              TextField(
                controller: motifController,
                decoration: const InputDecoration(
                  labelText: 'Motif de l\'archivage',
                  hintText: 'Ex: Hors service irréparable, Volé, Volontaire...',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
              onPressed: () async {
                if (motifController.text.trim().isEmpty) return;
                
                final messenger = ScaffoldMessenger.of(context);
                final router = GoRouter.of(context);
                final navigator = Navigator.of(context);

                final success = await Provider.of<AssetProvider>(context, listen: false)
                    .archiveAsset(asset.id, motifController.text.trim());

                navigator.pop();
                if (success) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('L\'équipement a été archivé avec succès')),
                  );
                  router.go('/assets'); // Retour à l'inventaire
                } else {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Erreur lors de l\'archivage')),
                  );
                }
              },
              child: const Text('Archiver'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AssetProvider>(context);
    final user = Provider.of<AuthProvider>(context).currentUser;
    final canManage = user?.role == 'admin' || user?.role == 'technicien';
    
    final asset = provider.selectedAsset;

    return Scaffold(
      appBar: AppBar(
        title: Text(asset != null ? 'Fiche ${asset.assetTag}' : 'Détails équipement'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (asset != null)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              tooltip: 'Exporter en PDF',
              onPressed: () async {
                try {
                  final pdfData = await PdfHelper.generateAssetPassport(asset);
                  await Printing.layoutPdf(
                    onLayout: (_) async => pdfData,
                    name: 'Passeport_${asset.assetTag}',
                  );
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erreur PDF : $e'), backgroundColor: AppTheme.errorColor),
                    );
                  }
                }
              },
            ),
          if (asset != null && canManage)
            PopupMenuButton<String>(
              onSelected: (val) {
                if (val == 'archive') {
                  _showArchiveDialog(context, asset);
                } else if (val == 'edit') {
                  context.push('/assets/${asset.id}/edit');
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, color: AppTheme.primaryColor, size: 20.0),
                      SizedBox(width: 8.0),
                      Text('Éditer l\'équipement', style: TextStyle(color: AppTheme.primaryColor)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'archive',
                  child: Row(
                    children: [
                      Icon(Icons.archive_outlined, color: AppTheme.errorColor, size: 20.0),
                      SizedBox(width: 8.0),
                      Text('Archiver (Réforme)', style: TextStyle(color: AppTheme.errorColor)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: provider.isLoadingDetails
          ? const Center(child: CircularProgressIndicator())
          : asset == null
              ? const Center(child: Text('Équipement introuvable.'))
              : DefaultTabController(
                  length: 7,
                  child: Column(
                    children: [
                      // En-tête rapide
                      _buildHeaderPanel(asset),
                      
                      // TabBar
                      const TabBar(
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        indicatorColor: AppTheme.primaryColor,
                        labelColor: AppTheme.primaryColor,
                        unselectedLabelColor: AppTheme.textSecondaryColor,
                        tabs: [
                          Tab(icon: Icon(Icons.info_outline), text: 'Fiche'),
                          Tab(icon: Icon(Icons.security), text: 'Sécurité'),
                          Tab(icon: Icon(Icons.payment), text: 'Achat & Gar.'),
                          Tab(icon: Icon(Icons.history), text: 'Affectations'),
                          Tab(icon: Icon(Icons.confirmation_number_outlined), text: 'Tickets'),
                          Tab(icon: Icon(Icons.build_outlined), text: 'Maintenances'),
                          Tab(icon: Icon(Icons.attach_file_rounded), text: 'Documents'),
                        ],
                      ),
                      
                      // TabBarView Content
                      Expanded(
                        child: TabBarView(
                          children: [
                            _buildInfoTab(asset),
                            _buildSecurityTab(asset),
                            _buildCostsTab(asset),
                            _buildHistoryTab(asset, canManage),
                            _buildLinkedTicketsTab(asset),
                            _buildLinkedMaintenancesTab(asset),
                            _buildAttachmentsTab(asset),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  // En-tête rapide de l'asset
  Widget _buildHeaderPanel(Asset asset) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      color: AppTheme.surfaceColor,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16.0),
            ),
            child: Icon(
              AppTheme.getTypeIcon(asset.type),
              color: AppTheme.primaryColor,
              size: 40.0,
            ),
          ),
          const SizedBox(width: 16.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        asset.assetTag,
                        style: const TextStyle(fontSize: 22.0, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    StatusBadge(statut: asset.statut),
                  ],
                ),
                const SizedBox(height: 4.0),
                Text(
                  '${asset.marque} ${asset.modele ?? ""}',
                  style: const TextStyle(fontSize: 16.0, color: AppTheme.textSecondaryColor),
                ),
                const SizedBox(height: 8.0),
                Row(
                  children: [
                    const Icon(Icons.person_outline, size: 16.0, color: AppTheme.textSecondaryColor),
                    const SizedBox(width: 6.0),
                    Text(
                      asset.utilisateurActuel ?? 'Aucune affectation active',
                      style: TextStyle(
                        fontSize: 13.0,
                        fontWeight: FontWeight.bold,
                        color: asset.utilisateurActuel != null ? AppTheme.textPrimaryColor : AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  // Onglet 1 : Infos Générales & Spécifications
  Widget _buildInfoTab(Asset asset) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Infos Générales
          _buildSectionTitle('Informations Générales'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildDetailRow('Marque', asset.marque),
                  _buildDetailRow('Modèle', asset.modele ?? '—'),
                  _buildDetailRow('Numéro de série', asset.serialNumber ?? '—'),
                  _buildDetailRow('Site géographique', asset.site ?? '—'),
                  _buildDetailRow('Département affecté', asset.departement ?? '—'),
                  _buildDetailRow('Notes/Détails', asset.notes ?? '—', isLongText: true),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20.0),

          // Section Spécifications
          _buildSectionTitle('Spécifications Techniques'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildDetailRow('Nom d\'hôte (Hostname)', asset.specs?.hostname ?? '—'),
                  _buildDetailRow('Système d\'exploitation', asset.specs?.os ?? '—'),
                  _buildDetailRow('Version OS', asset.specs?.versionOs ?? '—'),
                  _buildDetailRow('Processeur (CPU)', asset.specs?.cpu ?? '—'),
                  _buildDetailRow('Mémoire RAM', asset.specs?.ram ?? '—'),
                  _buildDetailRow('Espace de stockage', asset.specs?.stockage ?? '—'),
                  _buildDetailRow('Adresse MAC', asset.specs?.macAddress ?? '—'),
                  if ((asset.specs?.imei != null && asset.specs!.imei!.isNotEmpty) ||
                      ['telephone', 'tablette', 'pax_terminal'].contains(asset.type))
                    _buildDetailRow('Numéro IMEI', asset.specs?.imei ?? '—'),
                  _buildDetailRow('Adresse IP', asset.specs?.ipAddress ?? '—'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Onglet 2 : Sécurité & Conformité
  Widget _buildSecurityTab(Asset asset) {
    final sec = asset.securite;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Conformité de Sécurité'),
          const Text(
            'Statut des agents de sécurité et configurations requis par la politique IT de la Direction.',
            style: TextStyle(fontSize: 12.0, color: AppTheme.textSecondaryColor),
          ),
          const SizedBox(height: 16.0),
          if (sec == null)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Center(child: Text('Aucune information de sécurité disponible')),
              ),
            )
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildSecurityStatusRow('Windows Defender (Antivirus)', sec.defender),
                    _buildSecurityStatusRow('EDR / Sentinel (Protection menace)', sec.edr),
                    _buildSecurityStatusRow('Microsoft Intune (MDM)', sec.intune),
                    _buildSecurityStatusRow('Entra ID / Azure AD (Domaine)', sec.entraId),
                    _buildSecurityStatusRow('BitLocker (Chiffrement disque)', sec.bitlocker),
                    _buildSecurityStatusRow('OneDrive actif (Sauvegarde cloud)', sec.onedrive),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Onglet 3 : Financier & Garantie
  Widget _buildCostsTab(Asset asset) {
    final c = asset.couts;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Informations d\'Achat'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildDetailRow('Prix d\'acquisition', c?.prix != null ? '${c!.prix!.toStringAsFixed(0)} ${c.devise}' : '—'),
                  _buildDetailRow('Fournisseur', c?.fournisseur ?? '—'),
                  _buildDetailRow('Numéro Bon de commande', c?.bonCommande ?? '—'),
                  _buildDetailRow('Date d\'acquisition', c?.dateAcquisition ?? '—'),
                  _buildDetailRow('Fin de garantie', c?.finGarantie ?? '—'),
                  
                  // Statut Garantie
                  if (asset.statutGarantie != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Statut de la garantie', style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 14.0)),
                          _buildGarantieBadge(asset.statutGarantie!),
                        ],
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

  void _showAffectationDialog(BuildContext context, Asset asset) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    userProvider.fetchUsers();

    final dateCtrl = TextEditingController(
      text: DateTime.now().toIso8601String().split('T').first,
    );
    final motifCtrl = TextEditingController();
    final nomCtrl = TextEditingController();
    final prenomCtrl = TextEditingController();
    final departementCtrl = TextEditingController();

    UserItem? selectedUser;
    bool isNewUser = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final uProv = Provider.of<UserProvider>(context);
            return AlertDialog(
              title: const Text('Affecter l\'équipement'),
              content: uProv.isLoading
                  ? const SizedBox(
                      height: 100.0,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Nouveau collaborateur ?',
                                style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold),
                              ),
                              const Spacer(),
                              Switch(
                                value: isNewUser,
                                activeColor: AppTheme.primaryColor,
                                onChanged: (val) {
                                  setState(() => isNewUser = val);
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 12.0),
                          if (!isNewUser) ...[
                            const Text(
                              'Sélectionnez le collaborateur à qui affecter cet équipement.',
                              style: TextStyle(fontSize: 13.0, color: AppTheme.textSecondaryColor),
                            ),
                            const SizedBox(height: 12.0),
                            DropdownButtonFormField<UserItem>(
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Utilisateur *',
                              ),
                              value: selectedUser,
                              hint: const Text('Sélectionnez un collaborateur'),
                              items: uProv.users.map((u) {
                                return DropdownMenuItem<UserItem>(
                                  value: u,
                                  child: Text('${u.prenom} ${u.nom} (${u.departement ?? "Sans service"})'),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setState(() => selectedUser = val);
                              },
                            ),
                          ] else ...[
                            const Text(
                              'Saisissez les informations du nouveau collaborateur.',
                              style: TextStyle(fontSize: 13.0, color: AppTheme.textSecondaryColor),
                            ),
                            const SizedBox(height: 12.0),
                            TextFormField(
                              controller: prenomCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Prénom *',
                                hintText: 'Ex: Yves',
                              ),
                            ),
                            const SizedBox(height: 12.0),
                            TextFormField(
                              controller: nomCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Nom *',
                                hintText: 'Ex: Yao',
                              ),
                            ),
                            const SizedBox(height: 12.0),
                            TextFormField(
                              controller: departementCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Département / Service',
                                hintText: 'Ex: Comptabilité, IT...',
                              ),
                            ),
                          ],
                          const SizedBox(height: 16.0),
                          TextFormField(
                            controller: dateCtrl,
                            readOnly: true,
                            decoration: const InputDecoration(
                              labelText: 'Date d\'attribution *',
                              suffixIcon: Icon(Icons.calendar_today_outlined, size: 18.0),
                            ),
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2030),
                              );
                              if (picked != null) {
                                setState(() {
                                  dateCtrl.text = picked.toIso8601String().split('T').first;
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 16.0),
                          TextField(
                            controller: motifCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Motif (Optionnel)',
                              hintText: 'Ex: Nouvel arrivant, Remplacement...',
                            ),
                          ),
                        ],
                      ),
                    ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: uProv.isLoading ||
                          (!isNewUser && selectedUser == null) ||
                          (isNewUser && (prenomCtrl.text.trim().isEmpty || nomCtrl.text.trim().isEmpty))
                      ? null
                      : () async {
                          final success = await Provider.of<AffectationProvider>(context, listen: false)
                              .createAffectation(
                            assetId: asset.id,
                            userId: isNewUser ? null : selectedUser!.id,
                            nom: isNewUser ? nomCtrl.text.trim() : null,
                            prenom: isNewUser ? prenomCtrl.text.trim() : null,
                            departement: isNewUser ? departementCtrl.text.trim() : null,
                            dateAttribution: dateCtrl.text,
                            motif: motifCtrl.text.trim(),
                          );

                          if (context.mounted) {
                            Navigator.pop(context);
                            if (success) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('L\'équipement a été affecté avec succès')),
                              );
                              Provider.of<AssetProvider>(context, listen: false)
                                  .fetchAssetDetails(asset.id);
                            } else {
                              final affProvider = Provider.of<AffectationProvider>(context, listen: false);
                              final errMsg = affProvider.lastError ?? 'Erreur lors de l\'affectation';
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(errMsg),
                                  backgroundColor: Colors.red.shade700,
                                ),
                              );
                            }
                          }
                        },
                  child: const Text('Affecter'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showRetraitDialog(BuildContext context, Asset asset) {
    final motifCtrl = TextEditingController();
    String newStatus = 'en_stock';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Retrait de l\'équipement'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'L\'équipement sera retiré de son utilisateur actuel et réintégré dans le stock avec le statut choisi.',
                    style: TextStyle(fontSize: 13.0, color: AppTheme.textSecondaryColor),
                  ),
                  const SizedBox(height: 16.0),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Nouveau statut de l\'équipement *',
                    ),
                    initialValue: newStatus,
                    items: const [
                      DropdownMenuItem(value: 'en_stock', child: Text('En stock (Disponible)')),
                      DropdownMenuItem(value: 'en_maintenance', child: Text('En maintenance (En panne)')),
                      DropdownMenuItem(value: 'hors_service', child: Text('Hors service (À réformer)')),
                    ],
                    onChanged: (val) {
                      setState(() => newStatus = val!);
                    },
                  ),
                  const SizedBox(height: 16.0),
                  TextField(
                    controller: motifCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Motif du retrait (Optionnel)',
                      hintText: 'Ex: Départ, changement de poste, panne...',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
                  onPressed: () async {
                    final success = await Provider.of<AffectationProvider>(context, listen: false)
                        .retraitAffectation(
                      assetId: asset.id,
                      motif: motifCtrl.text.trim(),
                      nouveauStatut: newStatus,
                    );

                    if (context.mounted) {
                      Navigator.pop(context);
                      if (success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Le retrait a été effectué avec succès')),
                        );
                        Provider.of<AssetProvider>(context, listen: false)
                            .fetchAssetDetails(asset.id);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Erreur lors du retrait')),
                        );
                      }
                    }
                  },
                  child: const Text('Confirmer le retrait'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Onglet 4 : Historique
  Widget _buildHistoryTab(Asset asset, bool canManage) {
    final hist = asset.affectations ?? [];
    final activeAffectation = hist.cast<AffectationHistory?>().firstWhere(
          (a) => a != null && a.actif,
          orElse: () => null,
        );

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionTitle('Historique des affectations'),
              if (canManage)
                ElevatedButton.icon(
                  onPressed: activeAffectation != null
                      ? () => _showRetraitDialog(context, asset)
                      : () => _showAffectationDialog(context, asset),
                  icon: Icon(
                    activeAffectation != null
                        ? Icons.assignment_return_outlined
                        : Icons.assignment_ind_outlined,
                    size: 16.0,
                  ),
                  label: Text(activeAffectation != null ? 'Retirer' : 'Affecter'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        activeAffectation != null ? AppTheme.errorColor : AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8.0),
          Expanded(
            child: hist.isEmpty
                ? const Center(child: Text('Aucun historique d\'affectation enregistré'))
                : ListView.separated(
                    itemCount: hist.length,
                    separatorBuilder: (context, index) =>
                        const Divider(color: AppTheme.borderColor),
                    itemBuilder: (context, index) {
                      final item = hist[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Row(
                          children: [
                            Text(
                              item.utilisateurNom ?? 'Inconnu',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14.0,
                                  color: AppTheme.textPrimaryColor),
                            ),
                            const SizedBox(width: 8.0),
                            if (item.actif)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6.0, vertical: 2.0),
                                decoration: BoxDecoration(
                                  color: AppTheme.successColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4.0),
                                ),
                                child: const Text(
                                  'ACTIF',
                                  style: TextStyle(
                                      fontSize: 9.0,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.successColor),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4.0),
                            Text(
                                'Attribution: ${item.dateAttribution}${item.dateRetrait != null ? " | Retrait: ${item.dateRetrait}" : ""}'),
                            if (item.motif != null && item.motif!.isNotEmpty) ...[
                              const SizedBox(height: 2.0),
                              Text('Motif: ${item.motif}',
                                  style: const TextStyle(fontStyle: FontStyle.italic)),
                            ]
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // Row helper pour la fiche détaillée
  Widget _buildDetailRow(String label, String value, {bool isLongText = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: isLongText ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 14.0),
            ),
          ),
          const SizedBox(width: 12.0),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(color: AppTheme.textPrimaryColor, fontSize: 14.0, fontWeight: FontWeight.w500),
              textAlign: isLongText ? TextAlign.left : TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  // Row helper pour le statut de sécurité
  Widget _buildSecurityStatusRow(String label, bool isOk) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14.0, color: AppTheme.textPrimaryColor)),
          Row(
            children: [
              Text(
                isOk ? 'CONFORME' : 'NON CONFORME',
                style: TextStyle(
                  fontSize: 12.0,
                  fontWeight: FontWeight.bold,
                  color: isOk ? AppTheme.successColor : AppTheme.errorColor,
                ),
              ),
              const SizedBox(width: 8.0),
              Icon(
                isOk ? Icons.check_circle : Icons.cancel,
                color: isOk ? AppTheme.successColor : AppTheme.errorColor,
                size: 20.0,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Helper titre section
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, top: 4.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 15.0, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
      ),
    );
  }

  // Helper Badge Garantie
  Widget _buildGarantieBadge(String status) {
    Color color;
    String label;

    switch (status) {
      case 'expiree':
        color = AppTheme.errorColor;
        label = 'Expirée';
        break;
      case 'proche':
        color = AppTheme.warningColor;
        label = 'Proche de l\'expiration';
        break;
      default:
        color = AppTheme.successColor;
        label = 'Sous garantie (OK)';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6.0),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12.0, fontWeight: FontWeight.bold),
      ),
    );
  }

  // ── Onglet Tickets liés ──────────────────────────────────────────────────────
  Widget _buildLinkedTicketsTab(Asset asset) {
    final tickets = asset.tickets ?? [];
    if (tickets.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.confirmation_number_outlined, size: 48, color: AppTheme.textSecondaryColor),
            SizedBox(height: 12),
            Text('Aucun ticket lié à cet équipement', style: TextStyle(color: AppTheme.textSecondaryColor)),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: tickets.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final t = tickets[index] as Map<String, dynamic>;
        final statut = t['statut'] ?? 'ouvert';
        final priorite = t['priorite'] ?? 'normal';
        Color statutColor;
        switch (statut) {
          case 'resolu': statutColor = AppTheme.successColor; break;
          case 'en_cours': statutColor = AppTheme.warningColor; break;
          case 'ferme': statutColor = AppTheme.textSecondaryColor; break;
          default: statutColor = AppTheme.primaryColor;
        }
        Color prioriteColor;
        switch (priorite) {
          case 'critique': prioriteColor = AppTheme.errorColor; break;
          case 'haute': prioriteColor = AppTheme.warningColor; break;
          default: prioriteColor = AppTheme.textSecondaryColor;
        }
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: statutColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.confirmation_number_rounded, color: statutColor, size: 20),
          ),
          title: Text(
            t['titre'] ?? 'Ticket #${t['id']}',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            maxLines: 1, overflow: TextOverflow.ellipsis,
          ),
          subtitle: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statutColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(statut.replaceAll('_', ' ').toUpperCase(),
                  style: TextStyle(color: statutColor, fontSize: 9.5, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: prioriteColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(priorite.toUpperCase(),
                  style: TextStyle(color: prioriteColor, fontSize: 9.5, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          trailing: const Icon(Icons.chevron_right, size: 18, color: AppTheme.textSecondaryColor),
          onTap: () => context.push('/tickets/${t['id']}'),
        );
      },
    );
  }

  // ── Onglet Maintenances liées ────────────────────────────────────────────────
  Widget _buildLinkedMaintenancesTab(Asset asset) {
    final maintenances = asset.maintenances ?? [];
    if (maintenances.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.build_outlined, size: 48, color: AppTheme.textSecondaryColor),
            SizedBox(height: 12),
            Text('Aucune maintenance enregistrée pour cet équipement',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondaryColor)),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: maintenances.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final m = maintenances[index] as Map<String, dynamic>;
        final statut = m['statut'] ?? 'planifie';
        final type = m['type'] ?? 'preventive';
        Color statutColor;
        switch (statut) {
          case 'termine': statutColor = AppTheme.successColor; break;
          case 'en_cours': statutColor = AppTheme.warningColor; break;
          case 'annule': statutColor = AppTheme.textSecondaryColor; break;
          default: statutColor = AppTheme.primaryColor;
        }
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: statutColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.build_rounded, color: statutColor, size: 20),
          ),
          title: Text(
            m['description'] ?? 'Maintenance #${m['id']}',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            maxLines: 1, overflow: TextOverflow.ellipsis,
          ),
          subtitle: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statutColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(statut.replaceAll('_', ' ').toUpperCase(),
                  style: TextStyle(color: statutColor, fontSize: 9.5, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              Text(type.toUpperCase(),
                style: const TextStyle(fontSize: 9.5, color: AppTheme.textSecondaryColor, fontWeight: FontWeight.w600)),
              if (m['date_prevue'] != null) ...[
                const SizedBox(width: 8),
                Text(m['date_prevue'].toString().substring(0, 10),
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor)),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildAttachmentsTab(Asset asset) {
    final assetProvider = Provider.of<AssetProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;
    final canManage = user?.role == 'admin' || user?.role == 'technicien';

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Fichiers & Documents Joints',
                style: GoogleFonts.inter(fontSize: 16.0, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryColor),
              ),
              const SizedBox(width: 8.0),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${assetProvider.attachments.length}',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primaryColor),
                ),
              ),
              const Spacer(),
              if (canManage)
                assetProvider.isUploadingAttachment
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : ElevatedButton.icon(
                        onPressed: () => _uploadFile(asset.id),
                        icon: const Icon(Icons.upload_file, size: 16.0),
                        label: const Text('Téléverser'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                        ),
                      ),
            ],
          ),
          const SizedBox(height: 16.0),
          Expanded(
            child: assetProvider.isLoadingAttachments
                ? const Center(child: CircularProgressIndicator())
                : assetProvider.attachments.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.file_present_rounded,
                              size: 64,
                              color: AppTheme.textSecondaryColor.withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 16.0),
                            Text(
                              'Aucun document associé à cet équipement.',
                              style: GoogleFonts.inter(color: AppTheme.textSecondaryColor, fontSize: 14.0),
                            ),
                            if (canManage) ...[
                              const SizedBox(height: 8.0),
                              Text(
                                'Ajoutez des fiches techniques, factures, notices d\'utilisation, etc.',
                                style: GoogleFonts.inter(color: AppTheme.textSecondaryColor, fontSize: 12.0),
                              ),
                            ],
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: assetProvider.attachments.length,
                        separatorBuilder: (context, index) => const Divider(color: AppTheme.borderColor),
                        itemBuilder: (context, index) {
                          final att = assetProvider.attachments[index];
                          final ext = att.extension;
                          final isPdf = ext == 'pdf';

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                            leading: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: (isPdf ? Colors.red : AppTheme.primaryColor).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              child: Icon(
                                isPdf ? Icons.picture_as_pdf_outlined : Icons.insert_drive_file_outlined,
                                color: isPdf ? Colors.red.shade700 : AppTheme.primaryColor,
                                size: 22,
                              ),
                            ),
                            title: Text(
                              att.nomOriginal,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.0, color: AppTheme.textPrimaryColor),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${att.tailleLabel} • Ajouté par ${att.uploaderPrenom ?? ""} ${att.uploaderNom ?? "IT Team"} • le ${DateFormat('dd/MM/yyyy HH:mm').format(att.createdAt)}',
                              style: const TextStyle(fontSize: 11.0, color: AppTheme.textSecondaryColor),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.download_rounded, color: AppTheme.primaryColor, size: 20),
                                  tooltip: 'Télécharger',
                                  onPressed: () => _downloadFile(att),
                                ),
                                if (canManage)
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: AppTheme.errorColor, size: 20),
                                    tooltip: 'Supprimer',
                                    onPressed: () => _confirmDeleteAttachment(att),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadFile(int assetId) async {
    // Capture provider and messenger references before async gaps
    final provider = Provider.of<AssetProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);

    final result = await FilePicker.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: [
        'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx',
        'txt', 'md', 'csv',
        'png', 'jpg', 'jpeg', 'gif', 'svg',
        'zip', '7z',
      ],
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.path == null) return;

    final attachment = await provider.uploadAttachment(assetId, file.path!, file.name);

    if (attachment != null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Document importé avec succès'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } else {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Erreur lors de l\'import du fichier'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  Future<void> _downloadFile(AssetAttachment att) async {
    final provider = Provider.of<AssetProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);

    final url = provider.downloadUrl(att.id);

    final savePath = await FilePicker.saveFile(
      dialogTitle: 'Enregistrer le fichier',
      fileName: att.nomOriginal,
    );
    if (savePath == null) return;

    try {
      await provider.downloadTo(url, savePath);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Fichier sauvegardé : $savePath'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Erreur de téléchargement : $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  Future<void> _confirmDeleteAttachment(AssetAttachment att) async {
    final provider = Provider.of<AssetProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Supprimer la pièce jointe'),
        content: Text('Voulez-vous supprimer définitivement "${att.nomOriginal}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer', style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await provider.deleteAttachment(att.id);
      if (success) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Fichier supprimé'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      } else {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de la suppression'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }
}

