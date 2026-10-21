// ============================================
// lib/screens/assets/asset_form_screen.dart
// Formulaire de création / édition d'un équipement IT
// ============================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../providers/asset_provider.dart';

class AssetFormScreen extends StatefulWidget {
  /// null = création, non-null = édition
  final int? assetId;

  const AssetFormScreen({super.key, this.assetId});

  @override
  State<AssetFormScreen> createState() => _AssetFormScreenState();
}

class _AssetFormScreenState extends State<AssetFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  // --- Champs généraux ---
  final _assetTagCtrl     = TextEditingController();
  final _marqueCtrl       = TextEditingController();
  final _modeleCtrl       = TextEditingController();
  final _serialCtrl       = TextEditingController();
  final _siteCtrl         = TextEditingController();
  final _deptCtrl         = TextEditingController();
  final _notesCtrl        = TextEditingController();
  String _type   = 'laptop';
  String _statut = 'en_stock';

  // --- Spécifications techniques ---
  final _hostnameCtrl  = TextEditingController();
  final _osCtrl        = TextEditingController();
  final _versionOsCtrl = TextEditingController();
  final _cpuCtrl       = TextEditingController();
  final _ramCtrl       = TextEditingController();
  final _stockageCtrl  = TextEditingController();
  final _macCtrl       = TextEditingController();
  final _ipCtrl        = TextEditingController();
  final _imeiCtrl      = TextEditingController();

  // --- Sécurité ---
  bool _defender = false;
  bool _edr      = false;
  bool _intune   = false;
  bool _entraId  = false;
  bool _bitlocker = false;
  bool _onedrive  = false;

  // --- Financier / Garantie ---
  final _prixCtrl         = TextEditingController();
  final _deviseCtrl       = TextEditingController(text: 'XOF');
  final _fournisseurCtrl  = TextEditingController();
  final _bonCommandeCtrl  = TextEditingController();
  final _dateAcqCtrl      = TextEditingController();
  final _finGarantieCtrl  = TextEditingController();

  // Sections pliables
  bool _specsExpanded    = false;
  bool _securityExpanded = false;
  bool _financeExpanded  = false;

  bool _isLoading = false;

  bool get _isEditing => widget.assetId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _isLoading = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadAssetDetailsAndPrefill());
    }
  }

  Future<void> _loadAssetDetailsAndPrefill() async {
    final provider = Provider.of<AssetProvider>(context, listen: false);
    await provider.fetchAssetDetails(widget.assetId!);
    _prefillFromProvider();
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _prefillFromProvider() {
    final asset = Provider.of<AssetProvider>(context, listen: false).selectedAsset;
    if (asset == null) return;
    _assetTagCtrl.text  = asset.assetTag;
    _marqueCtrl.text    = asset.marque;
    _modeleCtrl.text    = asset.modele ?? '';
    _serialCtrl.text    = asset.serialNumber ?? '';
    _siteCtrl.text      = asset.site ?? '';
    _deptCtrl.text      = asset.departement ?? '';
    _notesCtrl.text     = asset.notes ?? '';
    setState(() {
      _type   = asset.type;
      _statut = asset.statut;
    });

    final s = asset.specs;
    if (s != null) {
      _hostnameCtrl.text  = s.hostname ?? '';
      _osCtrl.text        = s.os ?? '';
      _versionOsCtrl.text = s.versionOs ?? '';
      _cpuCtrl.text       = s.cpu ?? '';
      _ramCtrl.text       = s.ram ?? '';
      _stockageCtrl.text  = s.stockage ?? '';
      _macCtrl.text       = s.macAddress ?? '';
      _ipCtrl.text        = s.ipAddress ?? '';
      _imeiCtrl.text      = s.imei ?? '';
    }

    final sec = asset.securite;
    if (sec != null) {
      setState(() {
        _defender  = sec.defender;
        _edr       = sec.edr;
        _intune    = sec.intune;
        _entraId   = sec.entraId;
        _bitlocker = sec.bitlocker;
        _onedrive  = sec.onedrive;
      });
    }

    final c = asset.couts;
    if (c != null) {
      _prixCtrl.text        = c.prix?.toString() ?? '';
      _deviseCtrl.text      = c.devise;
      _fournisseurCtrl.text = c.fournisseur ?? '';
      _bonCommandeCtrl.text = c.bonCommande ?? '';
      _dateAcqCtrl.text     = c.dateAcquisition ?? '';
      _finGarantieCtrl.text = c.finGarantie ?? '';
    }
  }

  @override
  void dispose() {
    _assetTagCtrl.dispose(); _marqueCtrl.dispose(); _modeleCtrl.dispose();
    _serialCtrl.dispose();   _siteCtrl.dispose();   _deptCtrl.dispose();
    _notesCtrl.dispose();    _hostnameCtrl.dispose(); _osCtrl.dispose();
    _versionOsCtrl.dispose(); _cpuCtrl.dispose(); _ramCtrl.dispose();
    _stockageCtrl.dispose(); _macCtrl.dispose(); _ipCtrl.dispose();
    _prixCtrl.dispose(); _deviseCtrl.dispose(); _fournisseurCtrl.dispose();
    _bonCommandeCtrl.dispose(); _dateAcqCtrl.dispose(); _finGarantieCtrl.dispose();
    _imeiCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(TextEditingController ctrl) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2040),
    );
    if (picked != null) {
      ctrl.text = '${picked.year}-${picked.month.toString().padLeft(2,'0')}-${picked.day.toString().padLeft(2,'0')}';
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final payload = {
      'asset': {
        'asset_tag':     _assetTagCtrl.text.trim(),
        'marque':        _marqueCtrl.text.trim(),
        'modele':        _modeleCtrl.text.trim().isEmpty ? null : _modeleCtrl.text.trim(),
        'type':          _type,
        'statut':        _statut,
        'serial_number': _serialCtrl.text.trim().isEmpty ? null : _serialCtrl.text.trim(),
        'site':          _siteCtrl.text.trim().isEmpty ? null : _siteCtrl.text.trim(),
        'departement':   _deptCtrl.text.trim().isEmpty ? null : _deptCtrl.text.trim(),
        'notes':         _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      },
      'specs': {
        'hostname':    _hostnameCtrl.text.trim().isEmpty ? null : _hostnameCtrl.text.trim(),
        'os':          _osCtrl.text.trim().isEmpty ? null : _osCtrl.text.trim(),
        'version_os':  _versionOsCtrl.text.trim().isEmpty ? null : _versionOsCtrl.text.trim(),
        'cpu':         _cpuCtrl.text.trim().isEmpty ? null : _cpuCtrl.text.trim(),
        'ram':         _ramCtrl.text.trim().isEmpty ? null : _ramCtrl.text.trim(),
        'stockage':    _stockageCtrl.text.trim().isEmpty ? null : _stockageCtrl.text.trim(),
        'mac_address': _macCtrl.text.trim().isEmpty ? null : _macCtrl.text.trim(),
        'ip_address':  _ipCtrl.text.trim().isEmpty ? null : _ipCtrl.text.trim(),
        'imei':        _imeiCtrl.text.trim().isEmpty ? null : _imeiCtrl.text.trim(),
      },
      'securite': {
        'defender':  _defender,
        'edr':       _edr,
        'intune':    _intune,
        'entra_id':  _entraId,
        'bitlocker': _bitlocker,
        'onedrive':  _onedrive,
      },
      'couts': {
        'prix':             _prixCtrl.text.trim().isEmpty ? null : double.tryParse(_prixCtrl.text.trim()),
        'devise':           _deviseCtrl.text.trim().isEmpty ? 'XOF' : _deviseCtrl.text.trim(),
        'fournisseur':      _fournisseurCtrl.text.trim().isEmpty ? null : _fournisseurCtrl.text.trim(),
        'bon_commande':     _bonCommandeCtrl.text.trim().isEmpty ? null : _bonCommandeCtrl.text.trim(),
        'date_acquisition': _dateAcqCtrl.text.trim().isEmpty ? null : _dateAcqCtrl.text.trim(),
        'fin_garantie':     _finGarantieCtrl.text.trim().isEmpty ? null : _finGarantieCtrl.text.trim(),
      },
    };

    final provider = Provider.of<AssetProvider>(context, listen: false);
    bool success;
    if (_isEditing) {
      success = await provider.updateAsset(widget.assetId!, payload);
    } else {
      success = await provider.createAsset(payload);
    }

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? 'Équipement mis à jour avec succès' : 'Équipement créé avec succès'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        context.pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de l\'enregistrement. Vérifiez les données (tag unique, etc.)'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? 'Modifier l\'équipement' : 'Nouvel équipement'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Modifier l\'équipement' : 'Nouvel équipement'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: _isSubmitting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.0, color: AppTheme.primaryColor),
                  )
                : FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.save_outlined, size: 18.0),
                    label: Text(_isEditing ? 'Enregistrer' : 'Créer'),
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Section 1 : Informations Générales ──────────────────
              _buildSectionCard(
                title: 'Informations Générales',
                icon: Icons.info_outline,
                isExpanded: true,
                onToggle: null, // Toujours visible
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          ctrl: _assetTagCtrl,
                          label: 'Nom machine *',
                          hint: 'Ex: IT-BK-0042',
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Nom machine requis' : null,
                        ),
                      ),
                      const SizedBox(width: 16.0),
                      Expanded(
                        child: _buildDropdownField<String>(
                          label: 'Type *',
                          value: _type,
                          items: {
                            ...const [
                              'laptop',
                              'desktop',
                              'ecran',
                              'imprimante',
                              'scanner',
                              'telephone',
                              'tablette',
                              'pax_terminal',
                              'serveur',
                              'routeur',
                              'switch',
                              'autre'
                            ],
                            _type
                          }.toList(),
                          onChanged: (v) => setState(() => _type = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16.0),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          ctrl: _marqueCtrl,
                          label: 'Marque *',
                          hint: 'Ex: Dell, HP, Lenovo',
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Marque requise' : null,
                        ),
                      ),
                      const SizedBox(width: 16.0),
                      Expanded(
                        child: _buildTextField(
                          ctrl: _modeleCtrl,
                          label: 'Modèle',
                          hint: 'Ex: Latitude 5520',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16.0),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          ctrl: _serialCtrl,
                          label: 'Numéro de série',
                          hint: 'S/N constructeur',
                        ),
                      ),
                      const SizedBox(width: 16.0),
                      Expanded(
                        child: _buildDropdownField<String>(
                          label: 'Statut',
                          value: _statut,
                          items: {
                            ...const ['en_stock','en_service','en_maintenance','hors_service','reforme'],
                            _statut
                          }.toList(),
                          onChanged: (v) => setState(() => _statut = v!),
                          displayBuilder: (v) => v.replaceAll('_', ' ').toUpperCase(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16.0),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          ctrl: _siteCtrl,
                          label: 'Site géographique',
                          hint: 'Ex: Bouaké HQ, Abidjan',
                        ),
                      ),
                      const SizedBox(width: 16.0),
                      Expanded(
                        child: _buildTextField(
                          ctrl: _deptCtrl,
                          label: 'Département',
                          hint: 'Ex: DSI, DRH, Finance',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16.0),
                  _buildTextField(
                    ctrl: _notesCtrl,
                    label: 'Notes / Observations',
                    hint: 'Informations complémentaires...',
                    maxLines: 3,
                  ),
                ],
              ),
              const SizedBox(height: 16.0),

              // ── Section 2 : Spécifications Techniques ───────────────
              _buildSectionCard(
                title: 'Spécifications Techniques',
                icon: Icons.memory_outlined,
                isExpanded: _specsExpanded,
                onToggle: () => setState(() => _specsExpanded = !_specsExpanded),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          ctrl: _hostnameCtrl,
                          label: 'Nom d\'hôte (Hostname)',
                          hint: 'Ex: BKPC-042',
                        ),
                      ),
                      const SizedBox(width: 16.0),
                      Expanded(
                        child: _buildTextField(
                          ctrl: _ipCtrl,
                          label: 'Adresse IP',
                          hint: 'Ex: 192.168.1.42',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16.0),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          ctrl: _osCtrl,
                          label: 'Système d\'exploitation',
                          hint: 'Ex: Windows 11 Pro',
                        ),
                      ),
                      const SizedBox(width: 16.0),
                      Expanded(
                        child: _buildTextField(
                          ctrl: _versionOsCtrl,
                          label: 'Version OS',
                          hint: 'Ex: 23H2',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16.0),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          ctrl: _cpuCtrl,
                          label: 'Processeur (CPU)',
                          hint: 'Ex: Intel Core i5-1235U',
                        ),
                      ),
                      const SizedBox(width: 16.0),
                      Expanded(
                        child: _buildTextField(
                          ctrl: _ramCtrl,
                          label: 'Mémoire RAM',
                          hint: 'Ex: 16 Go DDR4',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16.0),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          ctrl: _stockageCtrl,
                          label: 'Stockage',
                          hint: 'Ex: SSD 512 Go NVMe',
                        ),
                      ),
                      const SizedBox(width: 16.0),
                      Expanded(
                        child: _buildTextField(
                          ctrl: _macCtrl,
                          label: 'Adresse MAC',
                          hint: 'Ex: AA:BB:CC:DD:EE:FF',
                        ),
                      ),
                    ],
                  ),
                  if (_type == 'telephone' || _type == 'tablette' || _type == 'pax_terminal') ...[
                    const SizedBox(height: 16.0),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            ctrl: _imeiCtrl,
                            label: 'Numéro IMEI',
                            hint: 'Ex: 359123456789012',
                          ),
                        ),
                        const SizedBox(width: 16.0),
                        const Expanded(child: SizedBox()),
                      ],
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16.0),

              // ── Section 3 : Conformité Sécurité ─────────────────────
              _buildSectionCard(
                title: 'Conformité Sécurité',
                icon: Icons.security_outlined,
                isExpanded: _securityExpanded,
                onToggle: () => setState(() => _securityExpanded = !_securityExpanded),
                children: [
                  const Text(
                    'Cochez les agents/configurations actifs sur cet équipement.',
                    style: TextStyle(fontSize: 12.0, color: AppTheme.textSecondaryColor),
                  ),
                  const SizedBox(height: 12.0),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 4.0,
                    children: [
                      _buildSecurityChip('Windows Defender', _defender, (v) => setState(() => _defender = v)),
                      _buildSecurityChip('EDR / Sentinel', _edr, (v) => setState(() => _edr = v)),
                      _buildSecurityChip('Microsoft Intune', _intune, (v) => setState(() => _intune = v)),
                      _buildSecurityChip('Entra ID / Azure AD', _entraId, (v) => setState(() => _entraId = v)),
                      _buildSecurityChip('BitLocker', _bitlocker, (v) => setState(() => _bitlocker = v)),
                      _buildSecurityChip('OneDrive actif', _onedrive, (v) => setState(() => _onedrive = v)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16.0),

              // ── Section 4 : Informations Financières ────────────────
              _buildSectionCard(
                title: 'Achat & Garantie',
                icon: Icons.receipt_long_outlined,
                isExpanded: _financeExpanded,
                onToggle: () => setState(() => _financeExpanded = !_financeExpanded),
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: _buildTextField(
                          ctrl: _prixCtrl,
                          label: 'Prix d\'acquisition',
                          hint: 'Ex: 850000',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 16.0),
                      Expanded(
                        flex: 1,
                        child: _buildTextField(
                          ctrl: _deviseCtrl,
                          label: 'Devise',
                          hint: 'XOF',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16.0),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          ctrl: _fournisseurCtrl,
                          label: 'Fournisseur',
                          hint: 'Ex: InfoTech CI',
                        ),
                      ),
                      const SizedBox(width: 16.0),
                      Expanded(
                        child: _buildTextField(
                          ctrl: _bonCommandeCtrl,
                          label: 'N° Bon de commande',
                          hint: 'Ex: BC-2024-0089',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16.0),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDateField(
                          ctrl: _dateAcqCtrl,
                          label: 'Date d\'acquisition',
                        ),
                      ),
                      const SizedBox(width: 16.0),
                      Expanded(
                        child: _buildDateField(
                          ctrl: _finGarantieCtrl,
                          label: 'Fin de garantie',
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 32.0),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers UI ────────────────────────────────────────────────────

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required bool isExpanded,
    required VoidCallback? onToggle,
    required List<Widget> children,
  }) {
    final alwaysVisible = onToggle == null;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header de section
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: Row(
                children: [
                  Icon(icon, color: AppTheme.primaryColor, size: 20.0),
                  const SizedBox(width: 12.0),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15.0,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimaryColor,
                    ),
                  ),
                  const Spacer(),
                  if (!alwaysVisible)
                    Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: AppTheme.textSecondaryColor,
                    ),
                ],
              ),
            ),
          ),

          // Corps de la section
          if (isExpanded || alwaysVisible)
            Padding(
              padding: const EdgeInsets.fromLTRB(20.0, 0.0, 20.0, 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Divider(color: AppTheme.borderColor),
                  const SizedBox(height: 16.0),
                  ...children,
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController ctrl,
    required String label,
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
      ),
    );
  }

  Widget _buildDropdownField<T>({
    required String label,
    required T value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
    String Function(T)? displayBuilder,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: items.map((item) {
        final display = displayBuilder != null
            ? displayBuilder(item)
            : item.toString().replaceAll('_', ' ').toUpperCase();
        return DropdownMenuItem<T>(value: item, child: Text(display, style: const TextStyle(fontSize: 13.0)));
      }).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildDateField({
    required TextEditingController ctrl,
    required String label,
  }) {
    return TextFormField(
      controller: ctrl,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        hintText: 'AAAA-MM-JJ',
        suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18.0),
      ),
      onTap: () => _pickDate(ctrl),
    );
  }

  Widget _buildSecurityChip(String label, bool isActive, ValueChanged<bool> onChanged) {
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 12.0)),
      selected: isActive,
      onSelected: onChanged,
      selectedColor: AppTheme.successColor.withValues(alpha: 0.15),
      checkmarkColor: AppTheme.successColor,
      labelStyle: TextStyle(
        color: isActive ? AppTheme.successColor : AppTheme.textSecondaryColor,
        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}
