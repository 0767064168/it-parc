// ============================================
// lib/screens/tickets/ticket_list_screen.dart
// ============================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/ticket_provider.dart';
import '../../widgets/app_navigation_layout.dart';
import '../../models/ticket.dart';

class TicketListScreen extends StatefulWidget {
  const TicketListScreen({super.key});

  @override
  State<TicketListScreen> createState() => _TicketListScreenState();
}

class _TicketListScreenState extends State<TicketListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedStatus = '';
  String _selectedPriority = '';
  String _selectedType = '';
  String _selectedSite = '';
  String _selectedTech = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTickets();
    });
  }

  void _loadTickets() {
    Provider.of<TicketProvider>(context, listen: false).fetchTickets(
      statut: _selectedStatus,
      priorite: _selectedPriority,
      type: _selectedType,
      site: _selectedSite,
      technicienId: _selectedTech,
      search: _searchController.text,
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'ouvert': return const Color(0xFF0969DA); // Bleu
      case 'en_cours': return const Color(0xFFFF9500); // Orange
      case 'en_attente': return const Color(0xFFFFD60A); // Jaune
      case 'resolu': return const Color(0xFF34C759); // Vert clair
      case 'ferme': return const Color(0xFF1A7F37); // Vert foncé
      case 'annule': return const Color(0xFF8E8E93); // Gris
      case 'rouvert': return const Color(0xFFFF3B30); // Rouge
      default: return Colors.grey;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'critique': return const Color(0xFFCF222E); // Rouge vif
      case 'haute': return const Color(0xFFFF3B30); // Rouge
      case 'moyenne': return const Color(0xFFFF9500); // Orange
      case 'basse': return const Color(0xFF8E8E93); // Gris
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final ticketProvider = Provider.of<TicketProvider>(context);
    final user = authProvider.currentUser;
    final isIT = user?.role == 'admin' || user?.role == 'technicien';
    final isAdmin = user?.role == 'admin';

    final size = MediaQuery.of(context).size;
    final isWide = size.width >= 800;

    return AppNavigationLayout(
      title: 'Gestion des Tickets IT',
      actions: [
        if (isIT) ...[
          IconButton(
            icon: const Icon(Icons.view_kanban_outlined),
            onPressed: () => context.push('/tickets/kanban'),
            tooltip: 'Tableau Kanban',
          ),
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.analytics_outlined),
              onPressed: () => context.push('/tickets/reports'),
              tooltip: 'Rapports & Stats',
            ),
        ],
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/tickets/new'),
        icon: const Icon(Icons.add),
        label: const Text('Nouveau Ticket'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      child: Column(
        children: [
          // ── Zone de filtres ─────────────────────────────────
          Card(
            margin: const EdgeInsets.all(16.0),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Ligne 1 : Barre de recherche
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Rechercher par numéro, titre, tag équipement...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {});
                                      _loadTickets();
                                    },
                                  )
                                : null,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) => _loadTickets(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _loadTickets,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        child: const Text('Rechercher'),
                      ),
                    ],
                  ),
                  
                  if (isIT) ...[
                    const SizedBox(height: 12),
                    // Ligne 2 : Sélections des filtres avancés (si IT)
                    Wrap(
                      spacing: 12.0,
                      runSpacing: 8.0,
                      children: [
                        _buildDropdownFilter(
                          label: 'Statut',
                          value: _selectedStatus,
                          items: {
                            '': 'Tous les statuts',
                            'ouvert': 'Ouvert',
                            'en_cours': 'En cours',
                            'en_attente': 'En attente',
                            'resolu': 'Résolu',
                            'ferme': 'Fermé',
                            'annule': 'Annulé',
                            'rouvert': 'Réouvert',
                          },
                          onChanged: (val) {
                            setState(() => _selectedStatus = val!);
                            _loadTickets();
                          },
                        ),
                        _buildDropdownFilter(
                          label: 'Priorité',
                          value: _selectedPriority,
                          items: {
                            '': 'Toutes priorités',
                            'critique': 'Critique',
                            'haute': 'Haute',
                            'moyenne': 'Moyenne',
                            'basse': 'Basse',
                          },
                          onChanged: (val) {
                            setState(() => _selectedPriority = val!);
                            _loadTickets();
                          },
                        ),
                        _buildDropdownFilter(
                          label: 'Type',
                          value: _selectedType,
                          items: {
                            '': 'Tous types',
                            'incident': 'Incident',
                            'demande_materiel': 'Demande Matériel',
                            'maintenance': 'Maintenance',
                            'acces_logiciel': 'Accès / Logiciel',
                          },
                          onChanged: (val) {
                            setState(() => _selectedType = val!);
                            _loadTickets();
                          },
                        ),
                        _buildDropdownFilter(
                          label: 'Site',
                          value: _selectedSite,
                          items: {
                            '': 'Tous sites',
                            'Bouaké': 'Bouaké',
                            'Abidjan': 'Abidjan',
                            'Azaguié': 'Azaguié',
                            'Djeboa': 'Djeboa',
                            'Katiola': 'Katiola',
                          },
                          onChanged: (val) {
                            setState(() => _selectedSite = val!);
                            _loadTickets();
                          },
                        ),
                        _buildDropdownFilter(
                          label: 'Technicien',
                          value: _selectedTech,
                          items: {
                            '': 'Tous techniciens',
                            'null': 'Non assignés',
                            '2': 'Tech KOUASSI',
                            '1': 'Admin KONAN',
                          },
                          onChanged: (val) {
                            setState(() => _selectedTech = val!);
                            _loadTickets();
                          },
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ── Liste des tickets ──────────────────────────────
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => _loadTickets(),
              child: ticketProvider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ticketProvider.errorMessage != null
                      ? Center(child: Text(ticketProvider.errorMessage!))
                      : ticketProvider.tickets.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.confirmation_number_outlined, size: 64, color: AppTheme.borderColor),
                                  const SizedBox(height: 16),
                                  const Text('Aucun ticket trouvé', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 8),
                                  ElevatedButton(
                                    onPressed: () => context.push('/tickets/new'),
                                    child: const Text('Créer le premier ticket'),
                                  )
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 80.0),
                              itemCount: ticketProvider.tickets.length,
                              itemBuilder: (context, index) {
                                final ticket = ticketProvider.tickets[index];
                                return _buildTicketCard(ticket, isWide, isIT);
                              },
                            ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownFilter({
    required String label,
    required String value,
    required Map<String, String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      constraints: const BoxConstraints(minWidth: 150),
      child: DropdownButtonFormField<String>(
        initialValue: items.containsKey(value) ? value : items.keys.first,
        decoration: InputDecoration(
          labelText: label,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        items: items.entries.map((e) {
          return DropdownMenuItem(
            value: e.key,
            child: Text(e.value, style: const TextStyle(fontSize: 13)),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildTicketCard(Ticket ticket, bool isWide, bool isIT) {
    final statusColor = _getStatusColor(ticket.statut);
    final priorityColor = _getPriorityColor(ticket.priorite);
    final format = DateFormat('dd/MM/yyyy HH:mm');

    // Vérification SLA en retard
    final bool isBreached = ticket.slaDeadline != null &&
        ticket.slaDeadline!.isBefore(DateTime.now()) &&
        !['resolu', 'ferme', 'annule'].contains(ticket.statut);

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      child: InkWell(
        onTap: () => context.push('/tickets/${ticket.id}'),
        borderRadius: BorderRadius.circular(16.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header du ticket
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          ticket.numero,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor, fontSize: 15),
                        ),
                        const SizedBox(width: 8),
                        // Badge Type
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.borderColor.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              ticket.typeLabel,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppTheme.textSecondaryColor),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Badge Status
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor, width: 1.0),
                    ),
                    child: Text(
                      ticket.statutLabel.toUpperCase(),
                      style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Titre
              Text(
                ticket.titre,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryColor),
              ),
              const SizedBox(height: 6),

              // Description abrégée
              Text(
                ticket.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondaryColor),
              ),
              const SizedBox(height: 12),
              const Divider(color: AppTheme.borderColor, height: 1),
              const SizedBox(height: 12),

              // Footer du ticket avec infos d'assignation
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Infos de création / site
                  Expanded(
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.person_outline, size: 14, color: AppTheme.textSecondaryColor),
                            const SizedBox(width: 4),
                            Text(isIT ? ticket.createurNomComplet : 'Moi', style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.place_outlined, size: 14, color: AppTheme.textSecondaryColor),
                            const SizedBox(width: 4),
                            Text(ticket.site ?? 'Bouaké', style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                        if (ticket.assetTag != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.devices, size: 14, color: AppTheme.textSecondaryColor),
                              const SizedBox(width: 4),
                              Text(ticket.assetTag!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                      ],
                    ),
                  ),

                  // SLA et Technicien
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Badge Priorité
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: priorityColor),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            ticket.prioriteLabel,
                            style: TextStyle(color: priorityColor, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // SLA Warning
                      if (isBreached)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.errorColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'SLA DÉPASSÉ',
                            style: TextStyle(color: AppTheme.errorColor, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        )
                      else if (ticket.slaDeadline != null && !['resolu', 'ferme', 'annule'].contains(ticket.statut))
                        Text(
                          'SLA: ${format.format(ticket.slaDeadline!)}',
                          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
