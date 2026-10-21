// ============================================
// lib/screens/profile/profile_screen.dart
// Profil utilisateur & changement de mot de passe
// ============================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';

import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_navigation_layout.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  bool _isUploadingAvatar = false;
  String? _successMessage;
  String? _errorMessage;

  Future<void> _selectAndUploadAvatar() async {
    final messenger = ScaffoldMessenger.of(context);
    final auth = Provider.of<AuthProvider>(context, listen: false);

    try {
      final result = await FilePicker.pickFiles(
        allowMultiple: false,
        type: FileType.image,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.path == null) return;

      setState(() => _isUploadingAvatar = true);

      final ok = await auth.uploadAvatar(file.path!, file.name);

      if (ok) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Photo de profil mise à jour avec succès.'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      } else {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de la mise à jour de la photo de profil.'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
      }
    }
  }

  @override
  void dispose() {
    _currentPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _successMessage = null;
      _errorMessage = null;
    });

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final ok = await auth.changePassword(
      _currentPassCtrl.text.trim(),
      _newPassCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (ok) {
        _successMessage = 'Mot de passe modifié avec succès.';
        _currentPassCtrl.clear();
        _newPassCtrl.clear();
        _confirmPassCtrl.clear();
      } else {
        _errorMessage = 'Mot de passe actuel incorrect ou erreur serveur.';
      }
    });
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
          onPressed: onToggle,
          tooltip: obscure ? 'Afficher' : 'Masquer',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.currentUser;
    final apiBaseUrl = auth.getServerUrl();
    final avatarUrl = user?.avatarUrl;
    final fullAvatarUrl = avatarUrl != null ? '${apiBaseUrl.replaceAll('/api', '')}$avatarUrl' : null;

    return AppNavigationLayout(
      title: 'Mon Profil',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Carte identité ──────────────────────────────────────
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppTheme.borderColor),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Row(
                      children: [
                        Stack(
                          children: [
                            GestureDetector(
                              onTap: _isUploadingAvatar ? null : _selectAndUploadAvatar,
                              child: Tooltip(
                                message: 'Modifier la photo de profil',
                                child: CircleAvatar(
                                  radius: 40,
                                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                                  backgroundImage: fullAvatarUrl != null
                                      ? NetworkImage(fullAvatarUrl)
                                      : null,
                                  child: fullAvatarUrl == null
                                      ? Text(
                                          user != null && user.prenom.isNotEmpty
                                              ? user.prenom[0].toUpperCase()
                                              : 'U',
                                          style: const TextStyle(
                                            fontSize: 32,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.primaryColor,
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                            ),
                            if (_isUploadingAvatar)
                              Positioned.fill(
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(
                                    child: SizedBox(
                                      width: 24, height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            else
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: AppTheme.primaryColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.nomComplet ?? 'Utilisateur',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimaryColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              _InfoRow(icon: Icons.alternate_email, text: '@${user?.username ?? '—'}'),
                              const SizedBox(height: 2),
                              _InfoRow(
                                icon: Icons.shield_outlined,
                                text: _roleLabel(user?.role),
                                color: _roleColor(user?.role),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // ── Changement de mot de passe ──────────────────────────
                const Text(
                  'Changer le mot de passe',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Utilisez un mot de passe fort d\'au moins 8 caractères.',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondaryColor),
                ),
                const SizedBox(height: 20),

                if (_successMessage != null)
                  _Banner(message: _successMessage!, isError: false),
                if (_errorMessage != null)
                  _Banner(message: _errorMessage!, isError: true),

                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppTheme.borderColor),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          _buildPasswordField(
                            controller: _currentPassCtrl,
                            label: 'Mot de passe actuel',
                            obscure: _obscureCurrent,
                            onToggle: () => setState(() => _obscureCurrent = !_obscureCurrent),
                            validator: (v) => (v == null || v.isEmpty)
                                ? 'Champ requis'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          _buildPasswordField(
                            controller: _newPassCtrl,
                            label: 'Nouveau mot de passe',
                            obscure: _obscureNew,
                            onToggle: () => setState(() => _obscureNew = !_obscureNew),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Champ requis';
                              if (v.length < 8) return 'Minimum 8 caractères';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          _buildPasswordField(
                            controller: _confirmPassCtrl,
                            label: 'Confirmer le nouveau mot de passe',
                            obscure: _obscureConfirm,
                            onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Champ requis';
                              if (v != _newPassCtrl.text) {
                                return 'Les mots de passe ne correspondent pas';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _isLoading ? null : _changePassword,
                              icon: _isLoading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.save_outlined),
                              label: Text(_isLoading
                                  ? 'Modification en cours…'
                                  : 'Enregistrer le nouveau mot de passe'),
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
        ),
      ),
    );
  }

  String _roleLabel(String? role) {
    switch (role) {
      case 'admin':
        return 'Administrateur IT';
      case 'technicien':
        return 'Technicien IT';
      default:
        return 'Utilisateur Lecteur';
    }
  }

  Color _roleColor(String? role) {
    switch (role) {
      case 'admin':
        return AppTheme.errorColor;
      case 'technicien':
        return AppTheme.warningColor;
      default:
        return AppTheme.textSecondaryColor;
    }
  }
}

// ── Petits widgets helpers ───────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;

  const _InfoRow({required this.icon, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color ?? AppTheme.textSecondaryColor),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: color ?? AppTheme.textSecondaryColor,
            fontWeight: color != null ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  final String message;
  final bool isError;

  const _Banner({required this.message, required this.isError});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isError
            ? AppTheme.errorColor.withValues(alpha: 0.1)
            : AppTheme.successColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isError ? AppTheme.errorColor : AppTheme.successColor,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: isError ? AppTheme.errorColor : AppTheme.successColor,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: isError ? AppTheme.errorColor : AppTheme.successColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
