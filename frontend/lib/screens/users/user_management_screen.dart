// ============================================
// lib/screens/users/user_management_screen.dart
// ============================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/app_navigation_layout.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<UserProvider>(context, listen: false).fetchUsers();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<UserItem> _filtered(List<UserItem> all) {
    if (_searchQuery.isEmpty) return all;
    final q = _searchQuery.toLowerCase();
    return all.where((u) =>
      u.nomComplet.toLowerCase().contains(q) ||
      (u.email?.toLowerCase().contains(q) ?? false) ||
      (u.departement?.toLowerCase().contains(q) ?? false) ||
      (u.site?.toLowerCase().contains(q) ?? false)
    ).toList();
  }

  void _showUserForm({UserItem? user}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _UserFormDialog(user: user),
    );
  }

  void _confirmDeleteUser(UserItem user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer l\'utilisateur'),
        content: Text('Voulez-vous vraiment supprimer l\'utilisateur ${user.nomComplet} ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final ok = await Provider.of<UserProvider>(context, listen: false).deleteUser(user.id);
              if (mounted) {
                if (ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Utilisateur supprimé')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Impossible de supprimer cet utilisateur (il a peut-être des éléments liés)'),
                      backgroundColor: AppTheme.errorColor,
                    ),
                  );
                }
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
    final provider = Provider.of<UserProvider>(context);
    final filtered = _filtered(provider.users);

    return AppNavigationLayout(
      title: 'Gestion des Utilisateurs',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () => Provider.of<UserProvider>(context, listen: false).fetchUsers(),
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showUserForm(),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Nouvel utilisateur'),
      ),
      child: Column(
        children: [
          // Barre de recherche
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Rechercher par nom, email, département...',
                prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondaryColor),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: AppTheme.textSecondaryColor),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
            ),
          ),

          // Compteur
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Row(
              children: [
                Text(
                  '${filtered.length} utilisateur${filtered.length > 1 ? 's' : ''}',
                  style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12.0),
                ),
              ],
            ),
          ),

          // Liste
          Expanded(
            child: provider.isLoading
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
                              onPressed: () => Provider.of<UserProvider>(context, listen: false).fetchUsers(),
                              child: const Text('Réessayer'),
                            ),
                          ],
                        ),
                      )
                    : filtered.isEmpty
                        ? const Center(
                            child: Text(
                              'Aucun utilisateur trouvé',
                              style: TextStyle(color: AppTheme.textSecondaryColor),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                            itemCount: filtered.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 8.0),
                            itemBuilder: (context, index) {
                              return _buildUserCard(filtered[index]);
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(UserItem user) {
    final initials = '${user.prenom.isNotEmpty ? user.prenom[0] : ''}${user.nom.isNotEmpty ? user.nom[0] : ''}'.toUpperCase();
    final authProv = Provider.of<AuthProvider>(context, listen: false);
    final isAdmin = authProv.currentUser?.role == 'admin';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 24.0,
              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
              foregroundColor: AppTheme.primaryColor,
              child: Text(
                initials,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
              ),
            ),
            const SizedBox(width: 16.0),

            // Infos
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        user.nomComplet,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15.0,
                          color: AppTheme.textPrimaryColor,
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      // Badge rôle
                      if (user.role != null)
                        _buildRoleBadge(user.role!),
                    ],
                  ),
                  const SizedBox(height: 4.0),
                  if (user.email != null)
                    Text(
                      user.email!,
                      style: const TextStyle(fontSize: 12.0, color: AppTheme.textSecondaryColor),
                    ),
                  const SizedBox(height: 4.0),
                  Row(
                    children: [
                      if (user.departement != null) ...[
                        const Icon(Icons.business_outlined, size: 12.0, color: AppTheme.textSecondaryColor),
                        const SizedBox(width: 4.0),
                        Text(
                          user.departement!,
                          style: const TextStyle(fontSize: 11.0, color: AppTheme.textSecondaryColor),
                        ),
                        const SizedBox(width: 12.0),
                      ],
                      if (user.site != null) ...[
                        const Icon(Icons.location_on_outlined, size: 12.0, color: AppTheme.textSecondaryColor),
                        const SizedBox(width: 4.0),
                        Text(
                          user.site!,
                          style: const TextStyle(fontSize: 11.0, color: AppTheme.textSecondaryColor),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Actions
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Statut compte d'auth
                if (user.authUserId != null)
                  GestureDetector(
                    onTap: () async {
                      final ok = await Provider.of<UserProvider>(context, listen: false)
                          .toggleAuthUser(user.authUserId!);
                      if (mounted && ok) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Compte mis à jour')),
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                      decoration: BoxDecoration(
                        color: (user.authActif ?? false)
                            ? AppTheme.successColor.withValues(alpha: 0.12)
                            : AppTheme.errorColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6.0),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            (user.authActif ?? false) ? Icons.lock_open_outlined : Icons.lock_outlined,
                            size: 12.0,
                            color: (user.authActif ?? false) ? AppTheme.successColor : AppTheme.errorColor,
                          ),
                          const SizedBox(width: 4.0),
                          Text(
                            (user.authActif ?? false) ? 'Actif' : 'Désactivé',
                            style: TextStyle(
                              fontSize: 10.0,
                              fontWeight: FontWeight.bold,
                              color: (user.authActif ?? false) ? AppTheme.successColor : AppTheme.errorColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 8.0),
                // Boutons d'action
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18.0),
                      color: AppTheme.textSecondaryColor,
                      onPressed: () => _showUserForm(user: user),
                      tooltip: 'Modifier',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    if (isAdmin) const SizedBox(width: 8.0),
                    if (isAdmin)
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18.0),
                        color: AppTheme.errorColor,
                        onPressed: () => _confirmDeleteUser(user),
                        tooltip: 'Supprimer',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleBadge(String role) {
    Color color;
    switch (role) {
      case 'admin':   color = AppTheme.errorColor; break;
      case 'technicien': color = AppTheme.primaryColor; break;
      default: color = AppTheme.textSecondaryColor;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4.0),
      ),
      child: Text(
        role.toUpperCase(),
        style: TextStyle(fontSize: 9.0, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}

// ── Dialogue Création / Édition ────────────────────────────────────
class _UserFormDialog extends StatefulWidget {
  final UserItem? user;
  const _UserFormDialog({this.user});

  @override
  State<_UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<_UserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  late TextEditingController _nomCtrl;
  late TextEditingController _prenomCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _siteCtrl;
  late TextEditingController _deptCtrl;
  late TextEditingController _usernameCtrl;
  late TextEditingController _passwordCtrl;
  String _role = 'lecteur';

  bool get _isEditing => widget.user != null;

  @override
  void initState() {
    super.initState();
    final u = widget.user;
    _nomCtrl    = TextEditingController(text: u?.nom ?? '');
    _prenomCtrl = TextEditingController(text: u?.prenom ?? '');
    _emailCtrl  = TextEditingController(text: u?.email ?? '');
    _siteCtrl   = TextEditingController(text: u?.site ?? '');
    _deptCtrl   = TextEditingController(text: u?.departement ?? '');
    _usernameCtrl = TextEditingController();
    _passwordCtrl = TextEditingController();
    _role = u?.role ?? 'lecteur';
  }

  @override
  void dispose() {
    _nomCtrl.dispose();
    _prenomCtrl.dispose();
    _emailCtrl.dispose();
    _siteCtrl.dispose();
    _deptCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final data = {
      'nom':         _nomCtrl.text.trim(),
      'prenom':      _prenomCtrl.text.trim(),
      'email':       _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      'role':        _role,
      'site':        _siteCtrl.text.trim().isEmpty ? null : _siteCtrl.text.trim(),
      'departement': _deptCtrl.text.trim().isEmpty ? null : _deptCtrl.text.trim(),
      'username':    _usernameCtrl.text.trim().isEmpty ? null : _usernameCtrl.text.trim(),
      'password':    _passwordCtrl.text.trim().isEmpty ? null : _passwordCtrl.text.trim(),
    };

    final provider = Provider.of<UserProvider>(context, listen: false);
    bool success;
    if (_isEditing) {
      success = await provider.updateUser(widget.user!.id, data);
    } else {
      success = await provider.createUser(data);
    }

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? 'Utilisateur mis à jour' : 'Utilisateur créé avec succès'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de l\'enregistrement'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Modifier l\'utilisateur' : 'Nouvel utilisateur'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _prenomCtrl,
                        decoration: const InputDecoration(labelText: 'Prénom *'),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
                      ),
                    ),
                    const SizedBox(width: 12.0),
                    Expanded(
                      child: TextFormField(
                        controller: _nomCtrl,
                        decoration: const InputDecoration(labelText: 'Nom *'),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12.0),
                TextFormField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12.0),
                DropdownButtonFormField<String>(
                  initialValue: _role,
                  decoration: const InputDecoration(labelText: 'Rôle'),
                  items: {
                    'admin',
                    'technicien',
                    'lecteur',
                    _role,
                  }.map((val) => DropdownMenuItem(
                    value: val,
                    child: Text(val == 'admin'
                        ? 'Administrateur'
                        : val == 'technicien'
                            ? 'Technicien'
                            : val == 'lecteur'
                                ? 'Lecteur'
                                : val.toUpperCase()),
                  )).toList(),
                  onChanged: (v) => setState(() => _role = v!),
                ),
                const SizedBox(height: 12.0),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _siteCtrl,
                        decoration: const InputDecoration(labelText: 'Site'),
                      ),
                    ),
                    const SizedBox(width: 12.0),
                    Expanded(
                      child: TextFormField(
                        controller: _deptCtrl,
                        decoration: const InputDecoration(labelText: 'Département'),
                      ),
                    ),
                  ],
                ),
                if (!_isEditing) ...[
                  const SizedBox(height: 16.0),
                  const Divider(height: 1),
                  const SizedBox(height: 12.0),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _usernameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Identifiant de connexion',
                            hintText: 'Optionnel',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12.0),
                      Expanded(
                        child: TextFormField(
                          controller: _passwordCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Mot de passe',
                            hintText: 'Optionnel',
                          ),
                          obscureText: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        if (_isSubmitting)
          const SizedBox(
            width: 24, height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.0),
          )
        else
          FilledButton(
            onPressed: _submit,
            child: Text(_isEditing ? 'Enregistrer' : 'Créer'),
          ),
      ],
    );
  }
}
