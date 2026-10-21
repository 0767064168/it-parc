// ============================================
// lib/screens/tickets/ticket_form_screen.dart
// ============================================

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';

import '../../core/theme.dart';
import '../../providers/ticket_provider.dart';
import '../../providers/asset_provider.dart';
import '../../models/asset.dart';
import '../../widgets/app_navigation_layout.dart';

class TicketFormScreen extends StatefulWidget {
  const TicketFormScreen({super.key});

  @override
  State<TicketFormScreen> createState() => _TicketFormScreenState();
}

class _TicketFormScreenState extends State<TicketFormScreen> {
  int _currentStep = 0;
  
  // Step 1 Controllers
  final _formKeyStep1 = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  String _selectedType = 'incident';
  String _selectedPriority = 'moyenne';

  // Step 2 Selection
  Asset? _selectedAsset;
  bool _showScannerSim = false;

  // Step 3 Attachments
  final List<PlatformFile> _selectedFiles = [];

  // Debounce timer pour la recherche d'asset
  Timer? _assetSearchDebounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AssetProvider>(context, listen: false).fetchAssets();
    });
  }

  @override
  void dispose() {
    _assetSearchDebounce?.cancel();
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep == 0) {
      if (_formKeyStep1.currentState!.validate()) {
        setState(() => _currentStep = 1);
      }
    } else if (_currentStep == 1) {
      setState(() => _currentStep = 2);
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  Future<void> _pickFiles() async {
    if (_selectedFiles.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Limite de 5 fichiers atteinte')),
      );
      return;
    }

    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      withData: true,
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'pdf', 'docx', 'xlsx'],
    );

    if (result != null) {
      setState(() {
        for (var file in result.files) {
          if (_selectedFiles.length < 5) {
            // Limiter taille à 10 Mo
            if (file.size <= 10 * 1024 * 1024) {
              _selectedFiles.add(file);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Fichier ${file.name} dépasse la limite de 10 Mo')),
              );
            }
          }
        }
      });
    }
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  Future<void> _submitTicket() async {
    final ticketProvider = Provider.of<TicketProvider>(context, listen: false);

    // 1. Créer le ticket
    final newTicket = await ticketProvider.createTicket(
      titre: _titleController.text,
      description: _descController.text,
      type: _selectedType,
      priorite: _selectedPriority,
      assetId: _selectedAsset?.id,
    );

    if (newTicket != null) {
      // 2. Uploader les fichiers joints séquentiellement
      for (var file in _selectedFiles) {
        final bytes = file.bytes ?? Uint8List(0);
        await ticketProvider.uploadAttachment(
          newTicket.id,
          bytes,
          file.name,
          filePath: file.path,
        );
      }

      // Dialogue succès
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: AppTheme.successColor, size: 28),
                SizedBox(width: 8),
                Text('Ticket Soumis !'),
              ],
            ),
            content: Text('Votre ticket numéro ${newTicket.numero} a été créé avec succès.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  context.go('/tickets'); // Navigate to tickets list
                },
                child: const Text('OK'),
              )
            ],
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ticketProvider.errorMessage ?? 'Erreur lors de la création')),
        );
      }
    }
  }

  // Simulation scan QR premium
  void _startScannerSimulation() {
    setState(() => _showScannerSim = true);
    
    // Simuler un scan réussi après 1.8 secondes
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (!mounted || !_showScannerSim) return;
      
      final assetProvider = Provider.of<AssetProvider>(context, listen: false);
      if (assetProvider.assets.isNotEmpty) {
        // Sélectionner le premier asset dispo pour la simulation
        setState(() {
          _selectedAsset = assetProvider.assets.first;
          _showScannerSim = false;
          _currentStep = 2; // Aller directement à l''étape 3
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.successColor,
            content: Text('QR Code Scanné avec succès : ${_selectedAsset!.assetTag} (${_selectedAsset!.modele})'),
          ),
        );
      } else {
        setState(() => _showScannerSim = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aucun asset trouvé pour simuler le scan.')),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppNavigationLayout(
      title: 'Ouvrir un ticket d\'assistance',
      child: Stack(
        children: [
          Column(
            children: [
              // Indicateur d'étape custom
              _buildStepIndicator(),
              const Divider(color: AppTheme.borderColor, height: 1),
              
              // Contenu dynamique de l'étape
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 800),
                      child: _buildCurrentStepContent(),
                    ),
                  ),
                ),
              ),

              // Barre d'actions en bas
              _buildBottomActionsBar(),
            ],
          ),
          
          if (_showScannerSim) _buildScannerOverlay(),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    final steps = ['1. Problème', '2. Équipement', '3. Pièces Jointes'];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(steps.length, (index) {
          final isCompleted = _currentStep > index;
          final isActive = _currentStep == index;
          
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCompleted
                      ? AppTheme.successColor
                      : (isActive ? AppTheme.primaryColor : Colors.grey[300]),
                ),
                child: Center(
                  child: isCompleted
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: isActive || isCompleted ? Colors.white : AppTheme.textSecondaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                steps[index],
                style: TextStyle(
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  color: isActive ? AppTheme.textPrimaryColor : AppTheme.textSecondaryColor,
                ),
              ),
              if (index < steps.length - 1) ...[
                const SizedBox(width: 24),
                Icon(Icons.chevron_right, size: 16, color: Colors.grey[400]),
              ],
            ],
          );
        }),
      ),
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStep1ProblemForm();
      case 1:
        return _buildStep2AssetSelector();
      case 2:
        return _buildStep3Attachments();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStep1ProblemForm() {
    return Form(
      key: _formKeyStep1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Décrivez le problème rencontré',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryColor),
          ),
          const SizedBox(height: 8),
          const Text(
            'Remplissez le titre et détaillez l\'anomalie ou le besoin afin de faciliter le diagnostic par notre équipe support.',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondaryColor),
          ),
          const SizedBox(height: 24),

          // Titre
          TextFormField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Titre du ticket *',
              hintText: 'Ex: Impossible d\'imprimer sur l\'imprimante compta',
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) return 'Le titre est obligatoire';
              if (val.length > 200) return 'Le titre ne doit pas dépasser 200 caractères';
              return null;
            },
          ),
          const SizedBox(height: 20),

          // Catégorie / Type
          DropdownButtonFormField<String>(
            initialValue: _selectedType,
            decoration: const InputDecoration(labelText: 'Catégorie du problème *'),
            items: const [
              DropdownMenuItem(value: 'incident', child: Text('Incident (panne, anomalie)')),
              DropdownMenuItem(value: 'demande_materiel', child: Text('Demande de matériel')),
              DropdownMenuItem(value: 'maintenance', child: Text('Maintenance préventive')),
              DropdownMenuItem(value: 'acces_logiciel', child: Text('Accès logiciel / VPN / Mot de passe')),
            ],
            onChanged: (val) => setState(() => _selectedType = val!),
          ),
          const SizedBox(height: 20),

          // Priorité suggérée
          DropdownButtonFormField<String>(
            initialValue: _selectedPriority,
            decoration: const InputDecoration(
              labelText: 'Priorité suggérée *',
              helperText: 'La priorité finale sera validée par le triage IT.',
            ),
            items: const [
              DropdownMenuItem(value: 'basse', child: Text('Basse (pas de blocage métier)')),
              DropdownMenuItem(value: 'moyenne', child: Text('Moyenne (gênant mais contournable)')),
              DropdownMenuItem(value: 'haute', child: Text('Haute (poste de travail bloqué)')),
              DropdownMenuItem(value: 'critique', child: Text('Critique (panne générale de service)')),
            ],
            onChanged: (val) => setState(() => _selectedPriority = val!),
          ),
          const SizedBox(height: 20),

          // Description détaillée
          TextFormField(
            controller: _descController,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Description détaillée *',
              hintText: 'Précisez le message d\'erreur, les circonstances de la panne, et les actions déjà tentées...',
              alignLabelWithHint: true,
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) return 'La description est obligatoire';
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStep2AssetSelector() {
    final assetProvider = Provider.of<AssetProvider>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Associer un équipement (Optionnel)',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryColor),
        ),
        const SizedBox(height: 8),
        const Text(
          'Lier le ticket à un matériel de l\'inventaire (ex: votre ordinateur portable, écran, etc.) accélère la prise en charge et le suivi de l\'historique.',
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondaryColor),
        ),
        const SizedBox(height: 24),

        // Sélections d'actions pour l'asset
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _startScannerSimulation,
                icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                label: const Text('Simuler Scan QR Code'),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Barre de recherche d'asset
        TextField(
          decoration: const InputDecoration(
            labelText: 'Rechercher un équipement',
            hintText: 'Saisir l\'Asset Tag (BKE-LT-...) ou modèle...',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (val) {
            _assetSearchDebounce?.cancel();
            _assetSearchDebounce = Timer(const Duration(milliseconds: 400), () {
              assetProvider.fetchAssets(search: val.trim().isEmpty ? null : val.trim());
            });
          },
        ),
        const SizedBox(height: 16),

        // Si équipement déjà sélectionné
        if (_selectedAsset != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primaryColor),
            ),
            child: Row(
              children: [
                const Icon(Icons.devices, color: AppTheme.primaryColor, size: 36),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedAsset!.assetTag,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryColor),
                      ),
                      Text('${_selectedAsset!.marque} ${_selectedAsset!.modele ?? ""} | ${_selectedAsset!.type.toUpperCase()}'),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppTheme.errorColor),
                  onPressed: () => setState(() => _selectedAsset = null),
                )
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Liste des assets filtrés
        const Text('Sélectionner dans la liste :', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          height: 250,
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.borderColor),
            borderRadius: BorderRadius.circular(12),
          ),
          child: assetProvider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.separated(
                  itemCount: assetProvider.assets.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final asset = assetProvider.assets[index];
                    final isSelected = _selectedAsset?.id == asset.id;

                    return ListTile(
                      title: Text(asset.assetTag, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${asset.marque} ${asset.modele ?? ""} | ${asset.site ?? ""}'),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle, color: AppTheme.successColor)
                          : const Icon(Icons.circle_outlined),
                      selected: isSelected,
                      onTap: () {
                        setState(() {
                          _selectedAsset = isSelected ? null : asset;
                        });
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildStep3Attachments() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ajouter des captures d\'écran ou photos (Optionnel)',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryColor),
        ),
        const SizedBox(height: 8),
        const Text(
          'Vous pouvez uploader jusqu\'à 5 captures d\'écran du message d\'erreur ou photos du matériel en panne (Max 10 Mo par fichier).',
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondaryColor),
        ),
        const SizedBox(height: 24),

        // Bouton d'upload
        Center(
          child: InkWell(
            onTap: _pickFiles,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
              height: 150,
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.primaryColor, style: BorderStyle.solid),
                borderRadius: BorderRadius.circular(16),
                color: AppTheme.primaryColor.withValues(alpha: 0.03),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_upload_outlined, size: 48, color: AppTheme.primaryColor),
                  SizedBox(height: 12),
                  Text(
                    'Parcourir les fichiers...',
                    style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 4),
                  Text('Images (PNG, JPG), PDF, Word, Excel autorisés', style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Liste des fichiers sélectionnés
        if (_selectedFiles.isNotEmpty) ...[
          const Text('Fichiers sélectionnés :', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _selectedFiles.length,
            itemBuilder: (context, index) {
              final file = _selectedFiles[index];
              final kbSize = (file.size / 1024).toStringAsFixed(1);

              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: AppTheme.borderColor),
                ),
                child: ListTile(
                  leading: const Icon(Icons.insert_drive_file, color: AppTheme.primaryColor),
                  title: Text(file.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('$kbSize Ko'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: AppTheme.errorColor),
                    onPressed: () => _removeFile(index),
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildBottomActionsBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Bouton Retour
          if (_currentStep > 0)
            OutlinedButton(
              onPressed: _prevStep,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Retour'),
            )
          else
            OutlinedButton(
              onPressed: () => context.pop(),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Annuler'),
            ),

          // Bouton Suivant / Soumettre
          if (_currentStep < 2)
            ElevatedButton(
              onPressed: _nextStep,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              child: const Text('Continuer'),
            )
          else
            ElevatedButton(
              onPressed: _submitTicket,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.successColor,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              child: const Text('Soumettre le Ticket'),
            ),
        ],
      ),
    );
  }

  // Scanner Simulator overlay
  Widget _buildScannerOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.8),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.qr_code_scanner, color: Colors.green, size: 72),
            const SizedBox(height: 24),
            const Text(
              'Alignez le QR code de l\'Asset dans le cadre',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '(Simulation de caméra en cours...)',
              style: TextStyle(color: Colors.white60, fontSize: 13),
            ),
            const SizedBox(height: 40),
            // Frame mockup
            Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.green, width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Stack(
                children: [
                  // Laser line simulation
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 240.0),
                    duration: const Duration(seconds: 1),
                    builder: (context, value, child) {
                      return Positioned(
                        top: value,
                        left: 10,
                        right: 10,
                        child: Container(
                          height: 2,
                          color: Colors.green,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            OutlinedButton(
              onPressed: () => setState(() => _showScannerSim = false),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white38),
              ),
              child: const Text('Annuler le scan'),
            )
          ],
        ),
      ),
    );
  }
}
