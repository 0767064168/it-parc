// ============================================
// lib/screens/dashboard/dashboard_screen.dart
// ============================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_navigation_layout.dart';
import '../../widgets/stat_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _staggerCtrl;

  @override
  void initState() {
    super.initState();
    _staggerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Provider.of<DashboardProvider>(context, listen: false)
          .fetchStats()
          .then((_) {
        if (mounted) _staggerCtrl.forward();
      });
    });
  }

  @override
  void dispose() {
    _staggerCtrl.dispose();
    super.dispose();
  }

  // Intervalle d'animation décalé pour chaque index
  Animation<double> _staggered(int index, {int total = 6}) {
    final start = (index / total * 0.6).clamp(0.0, 0.8);
    final end   = (start + 0.4).clamp(0.0, 1.0);
    return CurvedAnimation(
      parent: _staggerCtrl,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statsProvider = Provider.of<DashboardProvider>(context);
    final authProvider  = Provider.of<AuthProvider>(context);
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 1000;

    return AppNavigationLayout(
      title: 'Tableau de bord',
      child: RefreshIndicator(
        onRefresh: () async {
          await statsProvider.fetchStats();
          _staggerCtrl.reset();
          _staggerCtrl.forward();
        },
        child: statsProvider.isLoading && statsProvider.stats == null
            ? _buildSkeleton(isDesktop)
            : statsProvider.errorMessage != null
                ? _buildError(statsProvider)
                : _buildContent(context, statsProvider, authProvider, isDesktop),
      ),
    );
  }

  Widget _buildSkeleton(bool isDesktop) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Greeting skeleton
          Container(
            height: 90,
            decoration: BoxDecoration(
              color: AppTheme.borderColor,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          const SizedBox(height: 24),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: isDesktop ? 4 : 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: isDesktop ? 1.9 : 2.2,
            children: List.generate(4, (_) => _skeletonBox()),
          ),
        ],
      ),
    );
  }

  Widget _skeletonBox() => Container(
    decoration: BoxDecoration(
      color: AppTheme.borderColor,
      borderRadius: BorderRadius.circular(16),
    ),
  );

  Widget _buildError(DashboardProvider statsProvider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.errorColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.error_outline_rounded, color: AppTheme.errorColor, size: 48),
          ),
          const SizedBox(height: 16),
          Text(
            statsProvider.errorMessage!,
            style: GoogleFonts.inter(fontSize: 15, color: AppTheme.textSecondaryColor),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => statsProvider.fetchStats(),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    DashboardProvider provider,
    AuthProvider authProvider,
    bool isDesktop,
  ) {
    final stats = provider.stats;
    if (stats == null) return const SizedBox.shrink();

    final scoreValue = stats.securite.scoreConformite;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Bannière de bienvenue ──────────────────────────────
          _buildGreetingBanner(authProvider, stats),
          const SizedBox(height: 24),

          // ── Section titre ──────────────────────────────────────
          _sectionHeader(icon: Icons.analytics_outlined, label: 'Aperçu du parc'),
          const SizedBox(height: 16),

          // ── KPI Cards avec animation décalée ──────────────────
          GridView.count(
            crossAxisCount: isDesktop ? 4 : (MediaQuery.of(context).size.width >= 600 ? 2 : 1),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: isDesktop ? 1.9 : 2.2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _staggeredItem(0, StatCard(
                title: 'Total Équipements',
                value: stats.total.toString(),
                icon: Icons.devices_rounded,
                iconColor: AppTheme.primaryColor,
                subtitle: '${stats.enStock} en stock · ${stats.reforme} réformés',
              )),
              _staggeredItem(1, StatCard(
                title: 'En service',
                value: stats.enService.toString(),
                icon: Icons.play_circle_rounded,
                iconColor: AppTheme.successColor,
                subtitle: 'Opérationnel dans le parc',
              )),
              _staggeredItem(2, StatCard(
                title: 'En maintenance',
                value: stats.enMaintenance.toString(),
                icon: Icons.build_rounded,
                iconColor: AppTheme.warningColor,
                subtitle: 'En réparation ou révision',
              )),
              _staggeredItem(3, StatCard(
                title: 'Score Sécurité',
                value: '$scoreValue%',
                icon: Icons.shield_rounded,
                iconColor: scoreValue >= 80 ? AppTheme.successColor : AppTheme.warningColor,
                subtitle: '${stats.nonConformes} machines non conformes',
              )),
            ],
          ),
          const SizedBox(height: 28),

          // ── Nouvelles alertes opérationnelles ─────────────────
          _sectionHeader(icon: Icons.warning_amber_rounded, label: 'Alertes opérationnelles'),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: isDesktop ? 3 : (MediaQuery.of(context).size.width >= 600 ? 2 : 1),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: isDesktop ? 2.2 : 2.4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _staggeredItem(4, StatCard(
                title: 'Licences à renouveler',
                value: stats.licencesExpirantBientot.toString(),
                icon: Icons.vpn_key_rounded,
                iconColor: const Color(0xFF7C3AED),
                subtitle: 'Expirant dans les 90 jours',
                onTap: () => context.go('/licences'),
              )),
              _staggeredItem(5, StatCard(
                title: 'Stock critique',
                value: stats.stockCritique.toString(),
                icon: Icons.inventory_2_rounded,
                iconColor: AppTheme.errorColor,
                subtitle: 'Articles sous le seuil minimum',
                onTap: () => context.go('/consommables'),
              )),
              _staggeredItem(6, StatCard(
                title: 'Maintenances planifiées',
                value: stats.maintenancesPlanifiees.toString(),
                icon: Icons.build_circle_rounded,
                iconColor: AppTheme.warningColor,
                subtitle: 'Interventions à venir',
                onTap: () => context.go('/maintenances'),
              )),
            ],
          ),
          const SizedBox(height: 28),

          // ── Graphiques ─────────────────────────────────────────
          _sectionHeader(icon: Icons.pie_chart_outline_rounded, label: 'Répartition & Alertes'),
          const SizedBox(height: 16),

          if (isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: _buildDistributionCard(stats)),
                const SizedBox(width: 20),
                Expanded(flex: 2, child: _buildGarantieAlertesCard(context, stats)),
              ],
            )
          else ...[
            _buildDistributionCard(stats),
            const SizedBox(height: 20),
            _buildGarantieAlertesCard(context, stats),
          ],
          const SizedBox(height: 28),

          // ── Récents & Sites ────────────────────────────────────
          _sectionHeader(icon: Icons.history_rounded, label: 'Activités & Géographie'),
          const SizedBox(height: 16),

          if (isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: _buildRecentsCard(context, stats)),
                const SizedBox(width: 20),
                Expanded(flex: 2, child: _buildSiteDistributionCard(stats)),
              ],
            )
          else ...[
            _buildRecentsCard(context, stats),
            const SizedBox(height: 20),
            _buildSiteDistributionCard(stats),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── Bannière de bienvenue ──────────────────────────────────────────
  Widget _buildGreetingBanner(AuthProvider authProvider, dynamic stats) {
    final user = authProvider.currentUser;
    final prenom = user?.prenom ?? 'Bienvenue';
    final now = DateTime.now();
    final hour = now.hour;
    final greeting = hour < 12 ? 'Bonjour' : (hour < 18 ? 'Bon après-midi' : 'Bonsoir');
    final dateStr = DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(now);

    return AnimatedBuilder(
      animation: _staggerCtrl,
      builder: (_, child) {
        final anim = CurvedAnimation(
          parent: _staggerCtrl,
          curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
        );
        return Transform.translate(
          offset: Offset(0, (1 - anim.value) * 20),
          child: Opacity(opacity: anim.value, child: child),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          gradient: AppGradients.heroBanner,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withValues(alpha: 0.30),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$greeting, $prenom 👋',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateStr,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),
            // Mini stat rapide
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    '${stats.total}',
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'équipements',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Titre de section ───────────────────────────────────────────────
  Widget _sectionHeader({required IconData icon, required String label}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: AppTheme.primaryColor),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimaryColor,
          ),
        ),
      ],
    );
  }

  // ── Staggered wrapper ──────────────────────────────────────────────
  Widget _staggeredItem(int index, Widget child) {
    final anim = _staggered(index);
    return AnimatedBuilder(
      animation: _staggerCtrl,
      builder: (_, c) => Transform.translate(
        offset: Offset(0, (1 - anim.value) * 30),
        child: Opacity(opacity: anim.value, child: c),
      ),
      child: child,
    );
  }

  // ── Répartition par type (Pie Chart) ──────────────────────────────
  Widget _buildDistributionCard(dynamic stats) {
    final List<dynamic> types = stats.parType;
    final total = stats.total > 0 ? stats.total.toDouble() : 1.0;
    final isSmall = MediaQuery.of(context).size.width < 600;

    return _PremiumCard(
      title: 'Répartition par type d\'équipement',
      icon: Icons.donut_large_rounded,
      child: types.isEmpty
          ? _emptyState('Aucune donnée disponible')
          : isSmall
              ? Column(
                  children: [
                    SizedBox(
                      height: 180,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 3,
                          centerSpaceRadius: 40,
                          pieTouchData: PieTouchData(enabled: true),
                          sections: types.map((item) {
                            final count = item.count.toDouble();
                            final pct = (count / total) * 100;
                            return PieChartSectionData(
                              color: AppTheme.getTypeColor(item.type),
                              value: count,
                              title: '${pct.toStringAsFixed(0)}%',
                              radius: 46,
                              titleStyle: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            );
                          }).toList(),
                        ),
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.easeOutCubic,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: types.take(6).map((item) {
                        final color = AppTheme.getTypeColor(item.type);
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(2.5),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${item.type.toUpperCase()} (${item.count})',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                color: AppTheme.textSecondaryColor,
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: SizedBox(
                        height: 200,
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 3,
                            centerSpaceRadius: 44,
                            pieTouchData: PieTouchData(enabled: true),
                            sections: types.map((item) {
                              final count = item.count.toDouble();
                              final pct = (count / total) * 100;
                              return PieChartSectionData(
                                color: AppTheme.getTypeColor(item.type),
                                value: count,
                                title: '${pct.toStringAsFixed(0)}%',
                                radius: 54,
                                titleStyle: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              );
                            }).toList(),
                          ),
                          duration: const Duration(milliseconds: 800),
                          curve: Curves.easeOutCubic,
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: types.take(6).map((item) {
                          final color = AppTheme.getTypeColor(item.type);
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: color,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${item.type.toUpperCase()}  (${item.count})',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: AppTheme.textSecondaryColor,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
    );
  }

  // ── Top sites géographiques ────────────────────────────────────────
  Widget _buildSiteDistributionCard(dynamic stats) {
    final List<dynamic> sites = stats.parSite;
    return _PremiumCard(
      title: 'Top sites géographiques',
      icon: Icons.place_rounded,
      child: sites.isEmpty
          ? _emptyState('Aucun site enregistré')
          : ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sites.take(5).length,
              itemBuilder: (context, index) {
                final item = sites[index];
                final maxVal = sites.first.count > 0 ? sites.first.count : 1;
                final pct = item.count / maxVal;
                final color = [
                  AppTheme.primaryColor,
                  AppTheme.successColor,
                  AppTheme.warningColor,
                  const Color(0xFF7C3AED),
                  const Color(0xFF0891B2),
                ][index % 5];

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                item.site,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textPrimaryColor,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '${item.count}',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: pct),
                          duration: Duration(milliseconds: 600 + index * 100),
                          curve: Curves.easeOutCubic,
                          builder: (context, val, child) => LinearProgressIndicator(
                            value: val,
                            backgroundColor: AppTheme.borderColor,
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                            minHeight: 7,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  // ── Alertes garanties ─────────────────────────────────────────────
  Widget _buildGarantieAlertesCard(BuildContext context, dynamic stats) {
    final List<dynamic> alertes = stats.alertesGaranties;
    return _PremiumCard(
      title: 'Garanties expirant bientôt',
      icon: Icons.warning_amber_rounded,
      iconColor: AppTheme.warningColor,
      trailing: alertes.isNotEmpty
          ? _PulsingBadge(count: alertes.length)
          : null,
      child: alertes.isEmpty
          ? _emptyState('Aucune fin de garantie proche (< 90 jours)')
          : SizedBox(
              height: 220,
              child: ListView.separated(
                itemCount: alertes.length,
                separatorBuilder: (context, index) => Divider(
                  color: AppTheme.borderColor,
                  height: 1,
                ),
                itemBuilder: (context, index) {
                  final alerte = alertes[index];
                  final expired = alerte.joursRestants <= 0;
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      alerte.assetTag,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimaryColor,
                        fontSize: 13,
                      ),
                    ),
                    subtitle: Text(
                      '${alerte.marque} ${alerte.modele ?? ''} | ${alerte.site ?? 'Non spécifié'}',
                      style: GoogleFonts.inter(fontSize: 11.5, color: AppTheme.textSecondaryColor),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: expired
                            ? AppTheme.errorColor.withValues(alpha: 0.1)
                            : AppTheme.warningColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            expired ? 'Expirée' : 'Dans ${alerte.joursRestants}j',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: expired ? AppTheme.errorColor : AppTheme.warningColor,
                            ),
                          ),
                          if (alerte.finGarantie != null)
                            Text(
                              alerte.finGarantie!,
                              style: GoogleFonts.inter(
                                fontSize: 9.5,
                                color: AppTheme.textSecondaryColor,
                              ),
                            ),
                        ],
                      ),
                    ),
                    onTap: () => context.push('/assets/${alerte.id}'),
                  );
                },
              ),
            ),
    );
  }

  // ── Modifications récentes ─────────────────────────────────────────
  Widget _buildRecentsCard(BuildContext context, dynamic stats) {
    final List<dynamic> recents = stats.recents;
    return _PremiumCard(
      title: 'Modifications récentes',
      icon: Icons.history_rounded,
      child: recents.isEmpty
          ? _emptyState('Aucune activité enregistrée')
          : SizedBox(
              height: 280,
              child: ListView.separated(
                itemCount: recents.length,
                separatorBuilder: (context, index) => Divider(color: AppTheme.borderColor, height: 1),
                itemBuilder: (context, index) {
                  final asset = recents[index];
                  final typeColor = AppTheme.getTypeColor(asset.type);
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        AppTheme.getTypeIcon(asset.type),
                        color: typeColor,
                        size: 18,
                      ),
                    ),
                    title: Text(
                      asset.assetTag,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                    subtitle: Text(
                      '${asset.marque} ${asset.modele ?? ''} – ${asset.site ?? 'Sans site'}',
                      style: GoogleFonts.inter(fontSize: 11.5, color: AppTheme.textSecondaryColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            asset.statut.replaceAll('_', ' ').toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right_rounded, size: 16, color: AppTheme.textSecondaryColor),
                      ],
                    ),
                    onTap: () => context.push('/assets/${asset.id}'),
                  );
                },
              ),
            ),
    );
  }

  Widget _emptyState(String message) {
    return SizedBox(
      height: 120,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_rounded, size: 36, color: AppTheme.textSecondaryColor.withValues(alpha: 0.4)),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: AppTheme.textSecondaryColor, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Card premium réutilisable ──────────────────────────────────────────────────
class _PremiumCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color? iconColor;
  final Widget? trailing;
  final Widget child;

  const _PremiumCard({
    required this.title,
    required this.icon,
    this.iconColor,
    this.trailing,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? AppTheme.primaryColor;
    return Material(
      color: AppTheme.surfaceColor,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(icon, size: 15, color: color),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            title,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimaryColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // ignore: use_null_aware_elements
                  if (trailing != null) ...[
                    const SizedBox(width: 8),
                    trailing!,
                  ],
                ],
              ),
              const SizedBox(height: 18),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

// ── Badge avec animation pulsante ─────────────────────────────────────────────
class _PulsingBadge extends StatefulWidget {
  final int count;
  const _PulsingBadge({required this.count});

  @override
  State<_PulsingBadge> createState() => _PulsingBadgeState();
}

class _PulsingBadgeState extends State<_PulsingBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _scale = Tween<double>(begin: 1.0, end: 1.15)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.errorColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              '${widget.count} alertes',
              style: GoogleFonts.inter(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
