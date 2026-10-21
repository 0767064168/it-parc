import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/affectation_provider.dart';
import '../../providers/user_provider.dart';

class EditAffectationDialog extends StatefulWidget {
  final AffectationItem affectation;

  const EditAffectationDialog({super.key, required this.affectation});

  @override
  State<EditAffectationDialog> createState() => _EditAffectationDialogState();
}

class _EditAffectationDialogState extends State<EditAffectationDialog> {
  final _formKey = GlobalKey<FormState>();
  
  late int _selectedUserId;
  late TextEditingController _dateAttrController;
  late TextEditingController _dateRetraitController;
  late TextEditingController _motifController;
  late bool _actif;

  bool _isNewUser = false;
  final _prenomController = TextEditingController();
  final _nomController = TextEditingController();
  final _departementController = TextEditingController();
  
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedUserId = widget.affectation.userId;
    _dateAttrController = TextEditingController(text: widget.affectation.dateAttribution);
    _dateRetraitController = TextEditingController(text: widget.affectation.dateRetrait ?? '');
    _motifController = TextEditingController(text: widget.affectation.motif ?? '');
    _actif = widget.affectation.actif;
    
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final userProv = Provider.of<UserProvider>(context, listen: false);
    if (userProv.users.isEmpty) {
      await userProv.fetchUsers();
    }
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _dateAttrController.dispose();
    _dateRetraitController.dispose();
    _motifController.dispose();
    _prenomController.dispose();
    _nomController.dispose();
    _departementController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        controller.text = picked.toIso8601String().split('T').first;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isNewUser && (_prenomController.text.trim().isEmpty || _nomController.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez saisir le prénom et le nom du nouveau collaborateur.')),
      );
      return;
    }
    
    final Map<String, dynamic> data = {
      if (!_isNewUser) 'user_id': _selectedUserId,
      if (_isNewUser) 'nom': _nomController.text.trim(),
      if (_isNewUser) 'prenom': _prenomController.text.trim(),
      if (_isNewUser) 'departement': _departementController.text.trim(),
      'date_attribution': _dateAttrController.text,
      'actif': _actif,
    };
    if (_dateRetraitController.text.isNotEmpty) {
      data['date_retrait'] = _dateRetraitController.text;
    } else {
      data['date_retrait'] = null;
    }
    if (_motifController.text.isNotEmpty) {
      data['motif'] = _motifController.text;
    } else {
      data['motif'] = null;
    }

    final provider = Provider.of<AffectationProvider>(context, listen: false);
    final success = await provider.updateAffectation(widget.affectation.id, data);
    
    if (mounted) {
      if (success) {
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de la modification')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const AlertDialog(
        content: SizedBox(
          height: 100,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final users = Provider.of<UserProvider>(context).users;

    if (users.isNotEmpty && !users.any((u) => u.id == _selectedUserId)) {
      _selectedUserId = users.first.id;
    }

    return AlertDialog(
      title: const Text('Modifier l\'affectation'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Text(
                    'Nouveau collaborateur ?',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Switch(
                    value: _isNewUser,
                    onChanged: (val) => setState(() => _isNewUser = val),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (!_isNewUser) ...[
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(labelText: 'Utilisateur'),
                  initialValue: users.any((u) => u.id == _selectedUserId) ? _selectedUserId : null,
                  items: users.map((u) {
                    return DropdownMenuItem<int>(
                      value: u.id,
                      child: Text('${u.prenom} ${u.nom}'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedUserId = val);
                  },
                  validator: (val) => val == null ? 'Requis' : null,
                ),
              ] else ...[
                TextFormField(
                  controller: _prenomController,
                  decoration: const InputDecoration(
                    labelText: 'Prénom *',
                    hintText: 'Ex: Yves',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nomController,
                  decoration: const InputDecoration(
                    labelText: 'Nom *',
                    hintText: 'Ex: Yao',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _departementController,
                  decoration: const InputDecoration(
                    labelText: 'Département / Service',
                    hintText: 'Ex: Comptabilité, IT...',
                  ),
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _dateAttrController,
                decoration: const InputDecoration(
                  labelText: 'Date d\'attribution',
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                readOnly: true,
                onTap: () => _selectDate(_dateAttrController),
                validator: (val) => val == null || val.isEmpty ? 'Requis' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _dateRetraitController,
                decoration: const InputDecoration(
                  labelText: 'Date de retrait (optionnel)',
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                readOnly: true,
                onTap: () => _selectDate(_dateRetraitController),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _motifController,
                decoration: const InputDecoration(labelText: 'Motif (optionnel)'),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Affectation active'),
                value: _actif,
                onChanged: (val) => setState(() => _actif = val),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}
