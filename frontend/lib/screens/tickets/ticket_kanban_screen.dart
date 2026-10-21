// ============================================
// lib/screens/tickets/ticket_kanban_screen.dart
// ============================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../providers/ticket_provider.dart';
import '../../models/ticket.dart';
import '../../widgets/app_navigation_layout.dart';

class TicketKanbanScreen extends StatefulWidget {
  const TicketKanbanScreen({super.key});

  @override
  State<TicketKanbanScreen> createState() => _TicketKanbanScreenState();
}

class _TicketKanbanScreenState extends State<TicketKanbanScreen> {
  final List<String> _columns = ['ouvert', 'en_cours', 'en_attente', 'resolu'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTickets();
    });
  }

  void _loadTickets() {
    Provider.of<TicketProvider>(context, listen: false).fetchTickets();
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'ouvert': return const Color(0xFF0969DA);
      case 'en_cours': return const Color(0xFFFF9500);
      case 'en_attente': return const Color(0xFFFFD60A);
      case 'resolu': return const Color(0xFF34C759);
      default: return Colors.grey;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'critique': return const Color(0xFFCF222E);
      case 'haute': return const Color(0xFFFF3B30);
      case 'moyenne': return const Color(0xFFFF9500);
      case 'basse': return const Color(0xFF8E8E93);
      default: return Colors.grey;
    }
  }

  String _getColumnTitle(String col) {
    switch (col) {
      case 'ouvert': return 'Ouvert';
      case 'en_cours': return 'En cours';
      case 'en_attente': return 'En attente';
      case 'resolu': return 'Résolu';
      default: return col.toUpperCase();
    }
  }

  void _showMoveDialog(Ticket ticket, String targetStatus) {
    final commentCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Changer statut: ${ticket.numero} ➔ ${_getColumnTitle(targetStatus)}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Déplacement du ticket "${ticket.titre}"'),
            const SizedBox(height: 12),
            const Text('Commentaire obligatoire de transition :'),
            const SizedBox(height: 8),
            TextField(
              controller: commentCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Saisissez la raison ou la mise à jour...',
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
            onPressed: () async {
              if (commentCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Un commentaire de transition est obligatoire')),
                );
                return;
              }
              final provider = Provider.of<TicketProvider>(context, listen: false);
              final success = await provider.changeStatus(ticket.id, targetStatus, commentCtrl.text.trim());
              if (success) {
                if (context.mounted) Navigator.pop(context);
                _loadTickets();
              }
            },
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ticketProvider = Provider.of<TicketProvider>(context);
    final tickets = ticketProvider.tickets;

    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 900;

    return AppNavigationLayout(
      title: 'Console Kanban Tickets IT',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _loadTickets,
          tooltip: 'Actualiser',
        ),
      ],
      child: ticketProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ── Info Header ─────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(12),
                  color: AppTheme.primaryColor.withValues(alpha: 0.05),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: AppTheme.primaryColor, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Glissez-déposez les cartes ou utilisez le menu de la carte (⋮) pour changer le statut des tickets.',
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Columns Container ───────────────────────────
                Expanded(
                  child: isDesktop 
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _columns.map((col) => Expanded(
                            flex: 1,
                            child: _buildKanbanColumn(col, tickets),
                          )).toList(),
                        )
                      : ListView(
                          scrollDirection: Axis.horizontal,
                          children: _columns.map((col) => SizedBox(
                            width: size.width * 0.8,
                            child: _buildKanbanColumn(col, tickets),
                          )).toList(),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildKanbanColumn(String status, List<Ticket> allTickets) {
    final colTickets = allTickets.where((t) => t.statut == status).toList();

    return DragTarget<Ticket>(
        onWillAcceptWithDetails: (details) => details.data.statut != status,
        onAcceptWithDetails: (details) {
          _showMoveDialog(details.data, status);
        },
        builder: (context, candidateData, rejectedData) {
          final isOver = candidateData.isNotEmpty;
          return Container(
            margin: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: isOver ? AppTheme.borderColor.withValues(alpha: 0.3) : AppTheme.backgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isOver ? AppTheme.primaryColor : AppTheme.borderColor,
                width: 1.0,
              ),
            ),
            child: Column(
              children: [
                // Column Header
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _getStatusColor(status),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _getColumnTitle(status),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.borderColor.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${colTickets.length}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                
                // Column Cards List
                Expanded(
                  child: colTickets.isEmpty
                      ? const Center(
                          child: Text(
                            'Aucun ticket',
                            style: TextStyle(fontStyle: FontStyle.italic, color: AppTheme.textSecondaryColor, fontSize: 12),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(8.0),
                          itemCount: colTickets.length,
                          itemBuilder: (context, index) {
                            final ticket = colTickets[index];
                            return _buildTicketCard(ticket);
                          },
                        ),
                ),
              ],
            ),
          );
        },
      );
  }

  Widget _buildTicketCard(Ticket ticket) {
    final cardContent = Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  ticket.numero,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primaryColor),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getPriorityColor(ticket.priorite).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    ticket.prioriteLabel,
                    style: TextStyle(fontSize: 9, color: _getPriorityColor(ticket.priorite), fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              ticket.titre,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textPrimaryColor),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.person, size: 12, color: AppTheme.textSecondaryColor),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    ticket.createurNomComplet,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor),
                  ),
                ),
              ],
            ),
            if (ticket.assetTag != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.computer, size: 12, color: AppTheme.textSecondaryColor),
                  const SizedBox(width: 4),
                  Text(
                    ticket.assetTag!,
                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('dd MMM').format(ticket.createdAt),
                  style: const TextStyle(fontSize: 10, color: AppTheme.textSecondaryColor),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 16, color: AppTheme.textSecondaryColor),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onSelected: (targetStatus) {
                    if (targetStatus == 'detail') {
                      context.push('/tickets/${ticket.id}');
                    } else {
                      _showMoveDialog(ticket, targetStatus);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'detail',
                      child: Row(
                        children: [
                          Icon(Icons.open_in_new, size: 16),
                          SizedBox(width: 8),
                          Text('Ouvrir les détails'),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    ..._columns.where((c) => c != ticket.statut).map((col) => PopupMenuItem(
                          value: col,
                          child: Text('Déplacer vers : ${_getColumnTitle(col)}'),
                        )),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );

    // Rendre la carte Draggable
    return LongPressDraggable<Ticket>(
      data: ticket,
      feedback: SizedBox(
        width: 250,
        child: Material(
          color: Colors.transparent,
          child: cardContent,
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.4,
        child: cardContent,
      ),
      child: cardContent,
    );
  }
}
