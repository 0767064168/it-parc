// ============================================
// lib/widgets/asset_card.dart — Carte Équipement
// ============================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../models/asset.dart';
import '../providers/auth_provider.dart';
import '../providers/asset_provider.dart';
import 'status_badge.dart';

class AssetCard extends StatefulWidget {
  final Asset asset;

  const AssetCard({super.key, required this.asset});

  @override
  State<AssetCard> createState() => _AssetCardState();
}

class _AssetCardState extends State<AssetCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scaleAnim;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.975)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }



  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer l\'équipement'),
        content: const Text('Voulez-vous vraiment supprimer/archiver cet équipement ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final provider = Provider.of<AssetProvider>(context, listen: false);
              final success = await provider.archiveAsset(widget.asset.id, 'Suppression depuis la carte');
              if (success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Équipement archivé')),
                );
                provider.fetchAssets(isRefresh: true);
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
    final typeColor = AppTheme.getTypeColor(widget.asset.type);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final role = auth.currentUser?.role;
    final canEdit = role == 'admin' || role == 'technicien';
    final canDelete = role == 'admin';

    return AnimatedBuilder(
      animation: _scaleAnim,
      builder: (_, child) => Transform.scale(
        scale: _scaleAnim.value,
        child: child,
      ),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit:  (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTapDown: (_) => _ctrl.forward(),
          onTapUp:   (_) {
            _ctrl.reverse();
            context.push('/assets/${widget.asset.id}');
          },
          onTapCancel: () => _ctrl.reverse(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _hovered ? typeColor.withValues(alpha: 0.40) : AppTheme.borderColor,
                width: _hovered ? 1.5 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: _hovered
                      ? typeColor.withValues(alpha: 0.12)
                      : Colors.black.withValues(alpha: 0.04),
                  blurRadius: _hovered ? 20 : 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Colored left accent bar
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 4,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            typeColor,
                            typeColor.withValues(alpha: 0.5),
                          ],
                        ),
                      ),
                    ),

                    // Content
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Top row: icon + tag + status
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(7),
                                        decoration: BoxDecoration(
                                          color: typeColor.withValues(alpha: 0.10),
                                          borderRadius: BorderRadius.circular(9),
                                        ),
                                        child: Icon(
                                          AppTheme.getTypeIcon(widget.asset.type),
                                          color: typeColor,
                                          size: 18,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              widget.asset.assetTag,
                                              style: GoogleFonts.inter(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                                color: AppTheme.textPrimaryColor,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (widget.asset.serialNumber != null)
                                              Text(
                                                'S/N: ${widget.asset.serialNumber}',
                                                style: GoogleFonts.inter(
                                                  fontSize: 11.5,
                                                  color: AppTheme.textSecondaryColor,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (canEdit)
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 18),
                                        padding: const EdgeInsets.all(4),
                                        constraints: const BoxConstraints(),
                                        onPressed: () {
                                          context.push('/assets/${widget.asset.id}/edit');
                                        },
                                      ),
                                    if (canDelete)
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                        padding: const EdgeInsets.all(4),
                                        constraints: const BoxConstraints(),
                                        onPressed: () => _confirmDelete(context),
                                      ),
                                    const SizedBox(width: 4),
                                    StatusBadge(statut: widget.asset.statut),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Marque / Modèle
                            Text(
                              '${widget.asset.marque} ${widget.asset.modele ?? ''}',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimaryColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 10),

                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        const Icon(Icons.person_outline_rounded, size: 14, color: AppTheme.textSecondaryColor),
                                        const SizedBox(width: 5),
                                        Expanded(
                                          child: Text(
                                            widget.asset.utilisateurActuel ?? 'Non affecté',
                                            style: GoogleFonts.inter(
                                              fontSize: 12.5,
                                              color: widget.asset.utilisateurActuel != null
                                                  ? AppTheme.textPrimaryColor
                                                  : AppTheme.textSecondaryColor,
                                              fontWeight: widget.asset.utilisateurActuel != null
                                                  ? FontWeight.w500
                                                  : FontWeight.w400,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (widget.asset.site != null)
                                    Expanded(
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          const Icon(Icons.place_outlined, size: 14, color: AppTheme.textSecondaryColor),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              widget.asset.site!,
                                              style: GoogleFonts.inter(
                                                fontSize: 12.5,
                                                color: AppTheme.textSecondaryColor,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
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
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
