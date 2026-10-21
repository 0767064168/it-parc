// ============================================
// lib/screens/importexport/import_export_screen.dart
// ============================================

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';

import '../../core/theme.dart';
import '../../data/api_client.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_navigation_layout.dart';
import '../../utils/file_saver.dart';

class ImportExportScreen extends StatefulWidget {
  const ImportExportScreen({super.key});

  @override
  State<ImportExportScreen> createState() => _ImportExportScreenState();
}

class _ImportExportScreenState extends State<ImportExportScreen> {
  final ApiClient _api = ApiClient();

  // État Export
  bool _isExporting = false;
  String? _exportMessage;
  bool _exportSuccess = false;

  // État Import
  bool _isImporting = false;
  String? _selectedFileName;
  PlatformFile? _selectedFile;
  Map<String, dynamic>? _importResult;

  Future<void> _doExport() async {
    setState(() {
      _isExporting = true;
      _exportMessage = null;
    });

    try {
      final response = await _api.dio.get(
        '/import-export/export/excel',
        options: Options(responseType: ResponseType.bytes),
      );

      final bytes = response.data as List<int>;
      final fileName = 'inventaire_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      
      final fileSaver = FileSaver();
      final pathOrStatus = await fileSaver.saveFile(bytes, fileName);

      setState(() {
        _exportSuccess = true;
        if (kIsWeb) {
          _exportMessage = 'Export réussi. $pathOrStatus';
        } else {
          _exportMessage = 'Fichier exporté dans vos téléchargements : $pathOrStatus';
        }
      });
    } catch (e) {
      setState(() {
        _exportSuccess = false;
        _exportMessage = 'Erreur lors de l\'export : $e';
      });
    } finally {
      setState(() => _isExporting = false);
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'csv'],
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _selectedFile = result.files.first;
        _selectedFileName = _selectedFile!.name;
        _importResult = null;
      });
    }
  }

  Future<void> _doImport() async {
    if (_selectedFile == null) return;

    setState(() {
      _isImporting = true;
      _importResult = null;
    });

    try {
      FormData formData;

      if (kIsWeb) {
        // Sur le web, utiliser les bytes
        formData = FormData.fromMap({
          'file': MultipartFile.fromBytes(
            _selectedFile!.bytes!,
            filename: _selectedFile!.name,
          ),
        });
      } else {
        // Sur native, utiliser le chemin de fichier
        formData = FormData.fromMap({
          'file': await MultipartFile.fromFile(
            _selectedFile!.path!,
            filename: _selectedFile!.name,
          ),
        });
      }

      final response = await _api.dio.post(
        '/import-export/import/excel',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );

      setState(() {
        _importResult = response.data['data'] ?? response.data;
      });
    } catch (e) {
      setState(() {
        _importResult = {'error': 'Erreur lors de l\'import : $e'};
      });
    } finally {
      setState(() => _isImporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).currentUser;
    final canImport = user?.role == 'admin' || user?.role == 'technicien';

    return AppNavigationLayout(
      title: 'Import / Export',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Info Banner ────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12.0),
                border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppTheme.primaryColor, size: 20.0),
                  SizedBox(width: 12.0),
                  Expanded(
                    child: Text(
                      'Gérez votre inventaire en masse grâce à l\'import/export Excel. '
                      'Les fichiers acceptés sont .xlsx, .xls et .csv.',
                      style: TextStyle(fontSize: 13.0, color: AppTheme.textSecondaryColor),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24.0),

            // ── Section Export ─────────────────────────────────────
            _buildSectionCard(
              title: 'Exporter l\'inventaire',
              icon: Icons.download_outlined,
              iconColor: AppTheme.successColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Téléchargez l\'intégralité de l\'inventaire actif au format Excel (.xlsx). '
                    'Le fichier contient toutes les informations : équipements, spécifications, sécurité et historique d\'affectations.',
                    style: TextStyle(fontSize: 13.0, color: AppTheme.textSecondaryColor),
                  ),
                  const SizedBox(height: 20.0),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.successColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 14.0),
                    ),
                    onPressed: _isExporting ? null : _doExport,
                    icon: _isExporting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.0, color: Colors.white),
                          )
                        : const Icon(Icons.download),
                    label: Text(_isExporting ? 'Export en cours...' : 'Télécharger l\'inventaire Excel'),
                  ),
                  if (_exportMessage != null) ...[
                    const SizedBox(height: 16.0),
                    _buildResultMessage(
                      message: _exportMessage!,
                      isSuccess: _exportSuccess,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16.0),

            // ── Section Import ─────────────────────────────────────
            if (canImport)
              _buildSectionCard(
                title: 'Importer des équipements',
                icon: Icons.upload_outlined,
                iconColor: AppTheme.primaryColor,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Importez en masse des équipements depuis un fichier Excel ou CSV. '
                      'Utilisez le modèle d\'import pour être sûr du format attendu.',
                      style: TextStyle(fontSize: 13.0, color: AppTheme.textSecondaryColor),
                    ),
                    const SizedBox(height: 16.0),

                    // Colonnes attendues
                    _buildExpectedColumnsInfo(),
                    const SizedBox(height: 20.0),

                    // Sélecteur de fichier
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: _isImporting ? null : _pickFile,
                          icon: const Icon(Icons.attach_file),
                          label: const Text('Choisir un fichier'),
                        ),
                        const SizedBox(width: 16.0),
                        if (_selectedFileName != null)
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceColor,
                                borderRadius: BorderRadius.circular(8.0),
                                border: Border.all(color: AppTheme.borderColor),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.insert_drive_file_outlined,
                                    size: 16.0, color: AppTheme.primaryColor),
                                  const SizedBox(width: 8.0),
                                  Expanded(
                                    child: Text(
                                      _selectedFileName!,
                                      style: const TextStyle(
                                        fontSize: 13.0,
                                        color: AppTheme.textPrimaryColor,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close, size: 16.0),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () => setState(() {
                                      _selectedFile = null;
                                      _selectedFileName = null;
                                      _importResult = null;
                                    }),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16.0),

                    // Bouton import
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 14.0),
                      ),
                      onPressed: (_selectedFile == null || _isImporting) ? null : _doImport,
                      icon: _isImporting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2.0, color: Colors.white),
                            )
                          : const Icon(Icons.upload),
                      label: Text(_isImporting ? 'Import en cours...' : 'Lancer l\'import'),
                    ),

                    // Résultats import
                    if (_importResult != null) ...[
                      const SizedBox(height: 20.0),
                      _buildImportResults(_importResult!),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget child,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Icon(icon, color: iconColor, size: 20.0),
                ),
                const SizedBox(width: 12.0),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16.0,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16.0),
            const Divider(color: AppTheme.borderColor),
            const SizedBox(height: 16.0),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildResultMessage({required String message, required bool isSuccess}) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: (isSuccess ? AppTheme.successColor : AppTheme.errorColor).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(
          color: (isSuccess ? AppTheme.successColor : AppTheme.errorColor).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isSuccess ? Icons.check_circle_outline : Icons.error_outline,
            color: isSuccess ? AppTheme.successColor : AppTheme.errorColor,
            size: 18.0,
          ),
          const SizedBox(width: 8.0),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13.0,
                color: isSuccess ? AppTheme.successColor : AppTheme.errorColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImportResults(Map<String, dynamic> result) {
    if (result.containsKey('error')) {
      return _buildResultMessage(message: result['error'], isSuccess: false);
    }

    final created  = result['created']  ?? result['inserted'] ?? 0;
    final updated  = result['updated']  ?? 0;
    final skipped  = result['skipped']  ?? 0;
    final errors   = result['errors']   ?? result['erreurs'] ?? [];
    final total    = result['total']    ?? (created + updated + skipped);

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Résultats de l\'import',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.0, color: AppTheme.textPrimaryColor),
          ),
          const SizedBox(height: 16.0),
          Row(
            children: [
              _buildResultStat('Total', total.toString(), AppTheme.textSecondaryColor),
              const SizedBox(width: 24.0),
              _buildResultStat('Créés', created.toString(), AppTheme.successColor),
              const SizedBox(width: 24.0),
              _buildResultStat('Mis à jour', updated.toString(), AppTheme.primaryColor),
              const SizedBox(width: 24.0),
              _buildResultStat('Ignorés', skipped.toString(), AppTheme.warningColor),
              if (errors is List && errors.isNotEmpty) ...[
                const SizedBox(width: 24.0),
                _buildResultStat('Erreurs', errors.length.toString(), AppTheme.errorColor),
              ],
            ],
          ),

          // Lignes en erreur
          if (errors is List && errors.isNotEmpty) ...[
            const SizedBox(height: 16.0),
            const Divider(color: AppTheme.borderColor),
            const SizedBox(height: 8.0),
            const Text(
              'Lignes avec erreurs :',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.0, color: AppTheme.errorColor),
            ),
            const SizedBox(height: 8.0),
            ...errors.take(10).map((e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2.0),
              child: Text(
                '• ${e is Map ? (e['message'] ?? e.toString()) : e.toString()}',
                style: const TextStyle(fontSize: 12.0, color: AppTheme.textSecondaryColor),
              ),
            )),
            if (errors.length > 10)
              Text(
                '...et ${errors.length - 10} autres erreurs.',
                style: const TextStyle(fontSize: 12.0, color: AppTheme.textSecondaryColor),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildResultStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 22.0, fontWeight: FontWeight.bold, color: color),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11.0, color: AppTheme.textSecondaryColor),
        ),
      ],
    );
  }

  Widget _buildExpectedColumnsInfo() {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: const Text(
        'Voir les colonnes attendues dans le fichier Excel',
        style: TextStyle(fontSize: 13.0, color: AppTheme.primaryColor),
      ),
      iconColor: AppTheme.primaryColor,
      children: [
        Container(
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Colonnes obligatoires :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.0)),
              SizedBox(height: 4.0),
              Text('asset_tag, marque, type', style: TextStyle(fontSize: 12.0, color: AppTheme.successColor)),
              SizedBox(height: 8.0),
              Text('Colonnes optionnelles :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.0)),
              SizedBox(height: 4.0),
              Text(
                'modele, serial_number, statut, site, departement, notes,\n'
                'hostname, os, version_os, cpu, ram, stockage, mac_address, ip_address,\n'
                'prix, devise, fournisseur, bon_commande, date_acquisition, fin_garantie,\n'
                'defender, edr, intune, entra_id, bitlocker, onedrive',
                style: TextStyle(fontSize: 11.0, color: AppTheme.textSecondaryColor),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
