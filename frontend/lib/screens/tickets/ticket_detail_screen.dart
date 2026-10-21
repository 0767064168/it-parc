// ============================================
// lib/screens/tickets/ticket_detail_screen.dart
// ============================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:printing/printing.dart';

import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/ticket_provider.dart';
import '../../providers/user_provider.dart';
import '../../models/ticket.dart';
import '../../widgets/app_navigation_layout.dart';
import '../../utils/pdf_helper.dart';

class TicketDetailScreen extends StatefulWidget {
  final int ticketId;
  const TicketDetailScreen({super.key, required this.ticketId});

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _commentController = TextEditingController();
  bool _isInternalComment = false;
  
  // Timer Local pour le Technicien
  Timer? _stopwatchTimer;
  Duration _elapsedTime = Duration.zero;
  bool _isTimerRunning = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _refreshData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _commentController.dispose();
    _stopwatchTimer?.cancel();
    super.dispose();
  }

  void _refreshData() {
    Provider.of<TicketProvider>(context, listen: false).fetchTicketById(widget.ticketId);
    Provider.of<UserProvider>(context, listen: false).fetchUsers();
  }

  // Fonctions du Chronomètre
  void _startTimer() {
    if (_isTimerRunning) return;
    setState(() {
      _isTimerRunning = true;
    });
    _stopwatchTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _elapsedTime += const Duration(seconds: 1);
      });
    });
  }

  void _pauseTimer() {
    if (!_isTimerRunning) return;
    _stopwatchTimer?.cancel();
    setState(() {
      _isTimerRunning = false;
    });
  }

  void _resetTimer() {
    _stopwatchTimer?.cancel();
    setState(() {
      _elapsedTime = Duration.zero;
      _isTimerRunning = false;
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'ouvert': return const Color(0xFF0969DA);
      case 'en_cours': return const Color(0xFFFF9500);
      case 'en_attente': return const Color(0xFFFFD60A);
      case 'resolu': return const Color(0xFF34C759);
      case 'ferme': return const Color(0xFF1A7F37);
      case 'annule': return const Color(0xFF8E8E93);
      case 'rouvert': return const Color(0xFFFF3B30);
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

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty) return;
    final provider = Provider.of<TicketProvider>(context, listen: false);
    final comment = await provider.addComment(
      widget.ticketId,
      _commentController.text.trim(),
      type: _isInternalComment ? 'interne' : 'public',
    );
    if (comment != null) {
      _commentController.clear();
      setState(() {
        _isInternalComment = false;
      });
      _refreshData();
    }
  }

  Future<void> _pickAndUploadFile() async {
    // Capture context-dependent objects BEFORE any async gap
    final provider = Provider.of<TicketProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);

    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'pdf', 'docx', 'xlsx'],
    );

    if (!mounted) return;

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final success = await provider.uploadAttachment(
        widget.ticketId,
        file.bytes ?? [],
        file.name,
        filePath: file.path,
      );

      if (mounted) Navigator.pop(context); // fermer loader

      if (success) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Pièce jointe ajoutée avec succès')),
        );
        _refreshData();
      } else {
        messenger.showSnackBar(
          const SnackBar(content: Text('Échec de l\'envoi du fichier')),
        );
      }
    }
  }

  void _showChangeStatusDialog(String targetStatus) {
    final commentCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Changer le statut vers "${targetStatus.toUpperCase()}"'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Veuillez saisir un commentaire justificatif (obligatoire) :'),
            const SizedBox(height: 12),
            TextField(
              controller: commentCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Expliquez brièvement le motif du changement...',
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
                  const SnackBar(content: Text('Commentaire obligatoire')),
                );
                return;
              }
              final provider = Provider.of<TicketProvider>(context, listen: false);
              
              // Si on passe en Résolu et qu'un chronomètre tournait, on l'arrête
              if (targetStatus == 'resolu' && _isTimerRunning) {
                _pauseTimer();
              }

              final success = await provider.changeStatus(widget.ticketId, targetStatus, commentCtrl.text.trim());
              if (success) {
                if (context.mounted) Navigator.pop(context);
                _refreshData();
              }
            },
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  void _showEvaluationDialog() {
    int rating = 5;
    final commentCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateBuilder) => AlertDialog(
          title: const Text('Évaluation de la satisfaction'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Comment qualifiez-vous l\'intervention ?'),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final starVal = index + 1;
                  return IconButton(
                    icon: Icon(
                      starVal <= rating ? Icons.star : Icons.star_border,
                      color: AppTheme.accentColor,
                      size: 36,
                    ),
                    onPressed: () {
                      setStateBuilder(() {
                        rating = starVal;
                      });
                    },
                  );
                }),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: commentCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'Votre commentaire (optionnel)...',
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
                final provider = Provider.of<TicketProvider>(context, listen: false);
                final success = await provider.evaluateTicket(
                  widget.ticketId,
                  rating,
                  commentCtrl.text.trim().isEmpty ? null : commentCtrl.text.trim(),
                );
                if (success) {
                  if (context.mounted) Navigator.pop(context);
                  _refreshData();
                }
              },
              child: const Text('Envoyer'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAssignDialog() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final techs = userProvider.users.where((u) => u.role == 'technicien' || u.role == 'admin').toList();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Assigner à un technicien'),
        content: SizedBox(
          width: 320,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: techs.length,
            itemBuilder: (context, index) {
              final tech = techs[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                  child: Text(tech.prenom[0]),
                ),
                title: Text(tech.nomComplet),
                subtitle: Text(tech.role?.toUpperCase() ?? ''),
                onTap: () async {
                  final provider = Provider.of<TicketProvider>(context, listen: false);
                  final success = await provider.assignTicket(widget.ticketId, tech.id);
                  if (success) {
                    if (context.mounted) Navigator.pop(context);
                    _refreshData();
                  }
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final ticketProvider = Provider.of<TicketProvider>(context);
    
    final currentUser = authProvider.currentUser;
    final ticket = ticketProvider.selectedTicket;
    
    final isIT = currentUser?.role == 'admin' || currentUser?.role == 'technicien';

    if (ticketProvider.isLoading && ticket == null) {
      return const AppNavigationLayout(
        title: 'Détails du Ticket',
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (ticket == null) {
      return AppNavigationLayout(
        title: 'Détails du Ticket',
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppTheme.errorColor),
              const SizedBox(height: 12),
              const Text('Ticket introuvable ou erreur de chargement'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _refreshData,
                child: const Text('Actualiser'),
              ),
            ],
          ),
        ),
      );
    }

    // Calcul du SLA restant
    final isClosed = ['resolu', 'ferme', 'annule'].contains(ticket.statut);
    Duration? timeRemaining;
    bool isSlaBreached = false;
    if (!isClosed && ticket.slaDeadline != null) {
      timeRemaining = ticket.slaDeadline!.difference(DateTime.now());
      isSlaBreached = timeRemaining.isNegative;
    }

    return AppNavigationLayout(
      title: 'Ticket ${ticket.numero}',
      actions: [
        IconButton(
          icon: const Icon(Icons.picture_as_pdf_outlined),
          tooltip: 'Exporter en PDF',
          onPressed: () async {
            try {
              final pdfData = await PdfHelper.generateTicketIntervention(ticket);
              await Printing.layoutPdf(
                onLayout: (_) async => pdfData,
                name: 'Intervention_${ticket.numero}',
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
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _refreshData,
        ),
      ],
      child: RefreshIndicator(
        onRefresh: () async => _refreshData(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Banner SLA si applicable ────────────────────
              if (!isClosed && ticket.slaDeadline != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 16.0),
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  decoration: BoxDecoration(
                    color: isSlaBreached 
                        ? AppTheme.errorColor.withValues(alpha: 0.1) 
                        : AppTheme.primaryColor.withValues(alpha: 0.1),
                    border: Border.all(
                      color: isSlaBreached ? AppTheme.errorColor : AppTheme.primaryColor, 
                      width: 1.0
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSlaBreached ? Icons.warning_amber : Icons.timer_outlined,
                        color: isSlaBreached ? AppTheme.errorColor : AppTheme.primaryColor,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isSlaBreached 
                              ? 'SLA Dépassé ! Limite de résolution expirée.' 
                              : 'Temps restant pour résolution SLA : ${_formatDuration(timeRemaining!.abs())}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isSlaBreached ? AppTheme.errorColor : AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Panneau Principal (Détails, Description, PJ) ──────────────────
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Card d'infos de base
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(ticket.statut).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        ticket.statutLabel.toUpperCase(),
                                        style: TextStyle(
                                          color: _getStatusColor(ticket.statut),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: _getPriorityColor(ticket.priorite).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        ticket.prioriteLabel.toUpperCase(),
                                        style: TextStyle(
                                          color: _getPriorityColor(ticket.priorite),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      'Créé le ${DateFormat('dd/MM/yyyy HH:mm').format(ticket.createdAt)}',
                                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  ticket.titre,
                                  style: Theme.of(context).textTheme.headlineMedium,
                                ),
                                const SizedBox(height: 12),
                                const Divider(),
                                const SizedBox(height: 12),
                                const Text(
                                  'Description :',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimaryColor),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  ticket.description,
                                  style: const TextStyle(height: 1.5, color: AppTheme.textPrimaryColor),
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  children: [
                                    const Icon(Icons.category, size: 16, color: AppTheme.textSecondaryColor),
                                    const SizedBox(width: 6),
                                    Text('Type : ${ticket.typeLabel}', style: const TextStyle(color: AppTheme.textSecondaryColor)),
                                    const SizedBox(width: 20),
                                    const Icon(Icons.location_on, size: 16, color: AppTheme.textSecondaryColor),
                                    const SizedBox(width: 6),
                                    Text('Site : ${ticket.site ?? "Bouaké"}', style: const TextStyle(color: AppTheme.textSecondaryColor)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Card Équipement Lié (Asset)
                        if (ticket.assetId != null)
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.computer, color: AppTheme.primaryColor),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Équipement associé : ${ticket.assetTag ?? "N/A"}',
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        Text(
                                          '${ticket.assetMarque ?? ""} ${ticket.assetModele ?? ""}',
                                          style: const TextStyle(color: AppTheme.textSecondaryColor),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.open_in_new),
                                    onPressed: () => context.push('/assets/${ticket.assetId}'),
                                    tooltip: 'Voir la fiche équipement',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),

                        // Card Pièces Jointes
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Pièces jointes',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                    if (!isClosed)
                                      TextButton.icon(
                                        icon: const Icon(Icons.attach_file),
                                        label: const Text('Ajouter'),
                                        onPressed: _pickAndUploadFile,
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                if (ticket.piecesJointes.isEmpty)
                                  const Text('Aucune pièce jointe.', style: TextStyle(fontStyle: FontStyle.italic, color: AppTheme.textSecondaryColor))
                                else
                                  ListView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: ticket.piecesJointes.length,
                                    itemBuilder: (context, index) {
                                      final pj = ticket.piecesJointes[index];
                                      return ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: const Icon(Icons.insert_drive_file, color: AppTheme.primaryColor),
                                        title: Text(pj.nomFichier),
                                        subtitle: Text('${(pj.taille / 1024).toStringAsFixed(1)} Ko'),
                                        trailing: const Icon(Icons.file_download),
                                        onTap: () {
                                          // Simulation du téléchargement
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Téléchargement de ${pj.nomFichier} (Simulé)')),
                                          );
                                        },
                                      );
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Zone Timeline & Discussion
                        Card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TabBar(
                                controller: _tabController,
                                indicatorColor: AppTheme.primaryColor,
                                labelColor: AppTheme.primaryColor,
                                unselectedLabelColor: AppTheme.textSecondaryColor,
                                tabs: const [
                                  Tab(text: 'Discussion / Notes'),
                                  Tab(text: 'Historique'),
                                ],
                              ),
                              SizedBox(
                                height: 400,
                                child: TabBarView(
                                  controller: _tabController,
                                  children: [
                                    // Onglet Discussion
                                    _buildDiscussionTab(ticket, isIT),
                                    // Onglet Historique
                                    _buildHistoryTab(ticket),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),

                  // ── Panneau Latéral (Timer, Actions, Technicien) ──────────────────
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Card Attribution
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Intervenants', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(height: 16),
                                // Créateur
                                const Text('Demandeur :', style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12)),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                                      child: Text(ticket.createurPrenom != null && ticket.createurPrenom!.isNotEmpty ? ticket.createurPrenom![0] : 'U'),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(child: Text(ticket.createurNomComplet, style: const TextStyle(fontWeight: FontWeight.bold))),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                // Technicien
                                const Text('Technicien assigné :', style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12)),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: AppTheme.secondaryColor.withValues(alpha: 0.1),
                                      child: Icon(Icons.engineering, color: AppTheme.secondaryColor),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        ticket.technicienNomComplet,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: ticket.technicienId == null ? AppTheme.errorColor : AppTheme.textPrimaryColor
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (isIT && !isClosed) ...[
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      icon: const Icon(Icons.person_add_alt),
                                      label: const Text('Assigner'),
                                      onPressed: _showAssignDialog,
                                    ),
                                  ),
                                ]
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Card Chronomètre / Compteur Intervention (Seulement pour Technicien/Admin)
                        if (isIT && !isClosed && ticket.technicienId == currentUser?.id)
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Chronomètre d\'intervention', style: TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 16),
                                  Center(
                                    child: Text(
                                      _formatDuration(_elapsedTime),
                                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: [
                                      IconButton.filled(
                                        icon: Icon(_isTimerRunning ? Icons.pause : Icons.play_arrow),
                                        style: IconButton.styleFrom(
                                          backgroundColor: _isTimerRunning ? AppTheme.warningColor : AppTheme.secondaryColor,
                                        ),
                                        onPressed: _isTimerRunning ? _pauseTimer : _startTimer,
                                        tooltip: _isTimerRunning ? 'Pause' : 'Démarrer',
                                      ),
                                      IconButton.filled(
                                        icon: const Icon(Icons.stop),
                                        style: IconButton.styleFrom(
                                          backgroundColor: AppTheme.errorColor,
                                        ),
                                        onPressed: () {
                                          _pauseTimer();
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Temps accumulé : ${_elapsedTime.inMinutes} minutes.')),
                                          );
                                          _showChangeStatusDialog('resolu');
                                        },
                                        tooltip: 'Terminer & Résoudre',
                                      ),
                                      IconButton.outlined(
                                        icon: const Icon(Icons.refresh),
                                        onPressed: _resetTimer,
                                        tooltip: 'Réinitialiser',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),

                        // Card Actions
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Actions sur le ticket', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(height: 16),
                                // Actions Technicien/Admin
                                if (isIT && !isClosed) ...[
                                  if (ticket.statut != 'en_cours')
                                    _buildActionButton(
                                      label: 'Prendre en charge (En cours)',
                                      icon: Icons.play_circle_outline,
                                      color: AppTheme.secondaryColor,
                                      onPressed: () => _showChangeStatusDialog('en_cours'),
                                    ),
                                  if (ticket.statut != 'en_attente')
                                    _buildActionButton(
                                      label: 'Mettre en attente',
                                      icon: Icons.pause_circle_outline,
                                      color: AppTheme.warningColor,
                                      onPressed: () => _showChangeStatusDialog('en_attente'),
                                    ),
                                  _buildActionButton(
                                    label: 'Marquer comme résolu',
                                    icon: Icons.check_circle_outline,
                                    color: AppTheme.successColor,
                                    onPressed: () => _showChangeStatusDialog('resolu'),
                                  ),
                                  _buildActionButton(
                                    label: 'Annuler le ticket',
                                    icon: Icons.cancel_outlined,
                                    color: AppTheme.errorColor,
                                    onPressed: () => _showChangeStatusDialog('annule'),
                                  ),
                                ],

                                // Actions Demandeur
                                if (currentUser?.id == ticket.createurId) ...[
                                  if (ticket.statut == 'resolu') ...[
                                    _buildActionButton(
                                      label: 'Valider et Fermer',
                                      icon: Icons.check_circle,
                                      color: AppTheme.successColor,
                                      onPressed: _showEvaluationDialog,
                                    ),
                                    _buildActionButton(
                                      label: 'Réouvrir le ticket',
                                      icon: Icons.replay,
                                      color: AppTheme.errorColor,
                                      onPressed: () => _showChangeStatusDialog('rouvert'),
                                    ),
                                  ],
                                  if (!isClosed && ticket.statut != 'resolu')
                                    _buildActionButton(
                                      label: 'Fermer le ticket',
                                      icon: Icons.power_settings_new,
                                      color: AppTheme.errorColor,
                                      onPressed: () => _showChangeStatusDialog('ferme'),
                                    ),
                                ],
                                
                                if (isClosed)
                                  const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: Text(
                                        'Ce ticket est fermé ou résolu.',
                                        style: TextStyle(fontStyle: FontStyle.italic, color: AppTheme.textSecondaryColor),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        
                        // Card Évaluation Satisfaction de clôture
                        if (ticket.noteSatisfaction != null)
                          Card(
                            margin: const EdgeInsets.only(top: 16.0),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Satisfaction de clôture', style: TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: List.generate(5, (index) => Icon(
                                      index < ticket.noteSatisfaction! ? Icons.star : Icons.star_border,
                                      color: AppTheme.accentColor,
                                      size: 24,
                                    )),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text('Note attribuée par l\'utilisateur.', style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor)),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          icon: Icon(icon, color: Colors.white, size: 20),
          label: Text(label),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            padding: const EdgeInsets.symmetric(vertical: 12),
            textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          onPressed: onPressed,
        ),
      ),
    );
  }

  Widget _buildDiscussionTab(Ticket ticket, bool isIT) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        children: [
          // Liste des commentaires
          Expanded(
            child: ticket.commentaires.isEmpty
                ? const Center(child: Text('Aucun commentaire.', style: TextStyle(fontStyle: FontStyle.italic)))
                : ListView.builder(
                    itemCount: ticket.commentaires.length,
                    itemBuilder: (context, index) {
                      final comment = ticket.commentaires[index];
                      final isMe = comment.auteurId == Provider.of<AuthProvider>(context, listen: false).currentUser?.id;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12.0),
                        padding: const EdgeInsets.all(12.0),
                        decoration: BoxDecoration(
                          color: comment.isInternal 
                              ? const Color(0xFFFEF9C3) // Jaune clair pour notes internes IT
                              : (isMe ? AppTheme.primaryColor.withValues(alpha: 0.05) : AppTheme.surfaceColor),
                          border: Border.all(
                            color: comment.isInternal 
                                ? const Color(0xFFFDE047) 
                                : AppTheme.borderColor
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  comment.auteurNomComplet,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: comment.isInternal ? AppTheme.warningColor : AppTheme.textPrimaryColor
                                  ),
                                ),
                                Row(
                                  children: [
                                    if (comment.isInternal)
                                      Container(
                                        margin: const EdgeInsets.only(right: 8),
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppTheme.warningColor,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text('NOTE INTERNE IT', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                                      ),
                                    Text(
                                      DateFormat('dd/MM/yyyy HH:mm').format(comment.createdAt),
                                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(comment.contenu, style: const TextStyle(color: AppTheme.textPrimaryColor)),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const Divider(),
          // Formulaire d'envoi
          if (!['resolu', 'ferme', 'annule'].contains(ticket.statut))
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: const InputDecoration(
                      hintText: 'Écrire un commentaire...',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (isIT) ...[
                  IconButton(
                    icon: Icon(
                      _isInternalComment ? Icons.visibility_off : Icons.visibility,
                      color: _isInternalComment ? AppTheme.warningColor : AppTheme.textSecondaryColor,
                    ),
                    onPressed: () {
                      setState(() {
                        _isInternalComment = !_isInternalComment;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            _isInternalComment 
                                ? 'Note interne : visible uniquement par l\'équipe IT.' 
                                : 'Commentaire public : visible par le demandeur.'
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    tooltip: 'Changer la visibilité (Public / Interne IT)',
                  ),
                ],
                IconButton(
                  icon: const Icon(Icons.send, color: AppTheme.primaryColor),
                  onPressed: _addComment,
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab(Ticket ticket) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: ticket.historique.isEmpty
          ? const Center(child: Text('Aucun historique d\'audit disponible.', style: TextStyle(fontStyle: FontStyle.italic)))
          : ListView.builder(
              itemCount: ticket.historique.length,
              itemBuilder: (context, index) {
                final hist = ticket.historique[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.history, size: 16, color: AppTheme.textSecondaryColor),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RichText(
                              text: TextSpan(
                                style: const TextStyle(color: AppTheme.textPrimaryColor, fontSize: 13),
                                children: [
                                  TextSpan(text: hist.userNomComplet, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  const TextSpan(text: ' a modifié le champ '),
                                  TextSpan(text: hist.champModifie.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                                  const TextSpan(text: '.'),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (hist.ancienneValeur != null || hist.nouvelleValeur != null)
                              Text(
                                'Détail : ${hist.ancienneValeur ?? "Aucune"} ➜ ${hist.nouvelleValeur ?? "Aucune"}',
                                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor),
                              ),
                          ],
                        ),
                      ),
                      Text(
                        DateFormat('dd/MM HH:mm').format(hist.createdAt),
                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
