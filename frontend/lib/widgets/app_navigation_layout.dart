// ============================================
// lib/widgets/app_navigation_layout.dart — Layout réutilisable
// ============================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/ticket_provider.dart';
import '../providers/theme_provider.dart';
import '../services/socket_service.dart';

class AppNavigationLayout extends StatefulWidget {
  final Widget child;
  final String title;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  const AppNavigationLayout({
    super.key,
    required this.child,
    required this.title,
    this.actions,
    this.floatingActionButton,
  });

  @override
  State<AppNavigationLayout> createState() => _AppNavigationLayoutState();
}

class _AppNavigationLayoutState extends State<AppNavigationLayout> {
  Timer? _pollingTimer;
  StreamSubscription<Map<String, dynamic>>? _socketSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _fetchNotifications();
      _pollingTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
        if (!mounted) return;
        _fetchNotifications();
      });
      _connectSocket();
    });
  }

  void _connectSocket() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userId = auth.currentUser?.id;
    final token = auth.token;
    if (userId == null || token == null) return;

    final socketService = SocketService();
    socketService.connect(userId.toString(), token);

    _socketSub = socketService.onNotification.listen((data) {
      if (!mounted) return;
      // Rafraîchit le compteur de notifications
      Provider.of<TicketProvider>(context, listen: false).fetchNotifications();
      // Affiche une SnackBar d'alerte
      final titre = data['titre'] ?? 'Nouvelle notification';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  titre,
                  style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: AppTheme.primaryColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 4),
        ),
      );
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _socketSub?.cancel();
    SocketService().disconnect();
    super.dispose();
  }

  void _fetchNotifications() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.isAuthenticated) {
      Provider.of<TicketProvider>(context, listen: false).fetchNotifications();
    }
  }

  void _showNotificationsDialog(BuildContext context, TicketProvider provider) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateBuilder) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.notifications_rounded, color: AppTheme.primaryColor, size: 20),
              ),
              const SizedBox(width: 12),
              Text('Notifications', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18)),
            ],
          ),
          content: SizedBox(
            width: 360,
            child: provider.notifications.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inbox_rounded, size: 48, color: AppTheme.textSecondaryColor.withValues(alpha: 0.4)),
                        const SizedBox(height: 12),
                        Text(
                          'Aucune notification',
                          style: GoogleFonts.inter(color: AppTheme.textSecondaryColor, fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: provider.notifications.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final notif = provider.notifications[index];
                      return ListTile(
                        tileColor: Colors.transparent,
                        contentPadding: const EdgeInsets.symmetric(vertical: 4),
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: notif.lu
                                ? AppTheme.borderColor
                                : AppTheme.primaryColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            notif.lu ? Icons.mail_outline_rounded : Icons.mark_as_unread_rounded,
                            size: 18,
                            color: notif.lu ? AppTheme.textSecondaryColor : AppTheme.primaryColor,
                          ),
                        ),
                        title: Text(
                          notif.titre,
                          style: GoogleFonts.inter(
                            fontWeight: notif.lu ? FontWeight.w400 : FontWeight.w600,
                            fontSize: 13,
                            color: AppTheme.textPrimaryColor,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 3),
                            Text(notif.contenu, style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondaryColor)),
                            const SizedBox(height: 3),
                            Text(
                              DateFormat('dd/MM/yyyy HH:mm').format(notif.createdAt),
                              style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textSecondaryColor),
                            ),
                          ],
                        ),
                        trailing: notif.lu
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.check_circle_outline, size: 18, color: AppTheme.successColor),
                                onPressed: () async {
                                  final success = await provider.markNotificationAsRead(notif.id);
                                  if (success) setStateBuilder(() {});
                                },
                                tooltip: 'Marquer comme lu',
                              ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Fermer', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationBell(BuildContext context, TicketProvider ticketProvider) {
    final count = ticketProvider.unreadNotificationsCount;
    return Badge(
      isLabelVisible: count > 0,
      label: Text('$count', style: const TextStyle(fontSize: 10)),
      backgroundColor: AppTheme.errorColor,
      child: IconButton(
        icon: const Icon(Icons.notifications_outlined),
        onPressed: () => _showNotificationsDialog(context, ticketProvider),
        tooltip: 'Notifications',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final ticketProvider = Provider.of<TicketProvider>(context);

    final user = authProvider.currentUser;
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 900;

    final isAdmin = user?.role == 'admin';
    final canManage = isAdmin || user?.role == 'technicien';

    final currentRoute = GoRouterState.of(context).matchedLocation;
    int selectedIndex = 0;
    if (currentRoute.startsWith('/assets')) {
      selectedIndex = 1;
    } else if (currentRoute.startsWith('/licences')) {
      selectedIndex = 2;
    } else if (currentRoute.startsWith('/consommables')) {
      selectedIndex = 3;
    } else if (currentRoute.startsWith('/maintenances')) {
      selectedIndex = 4;
    } else if (currentRoute.startsWith('/affectations')) {
      selectedIndex = 5;
    } else if (currentRoute.startsWith('/tickets')) {
      selectedIndex = 6;
    } else if (currentRoute.startsWith('/wiki')) {
      selectedIndex = 7;
    } else if (currentRoute.startsWith('/reports')) {
      selectedIndex = 8;
    } else if (currentRoute.startsWith('/import-export')) {
      selectedIndex = 9;
    } else if (currentRoute.startsWith('/users')) {
      selectedIndex = 10;
    } else if (currentRoute.startsWith('/profile')) {
      selectedIndex = 11;
    }

    final unreadCount = ticketProvider.unreadNotificationsCount;

    void onNavigate(int index) {
      switch (index) {
        case 0: context.go('/'); break;
        case 1: context.go('/assets'); break;
        case 2: context.go('/licences'); break;
        case 3: context.go('/consommables'); break;
        case 4: context.go('/maintenances'); break;
        case 5: context.go('/affectations'); break;
        case 6: context.go('/tickets'); break;
        case 7: context.go('/wiki'); break;
        case 8: context.go('/reports'); break;
        case 9: context.go('/import-export'); break;
        case 10: context.go('/users'); break;
        case 11: context.go('/profile'); break;
      }
    }

    int mobileSelectedIndex = 0;
    if (currentRoute == '/') {
      mobileSelectedIndex = 0;
    } else if (currentRoute.startsWith('/assets')) {
      mobileSelectedIndex = 1;
    } else if (currentRoute.startsWith('/affectations')) {
      mobileSelectedIndex = 2;
    } else if (currentRoute.startsWith('/tickets')) {
      mobileSelectedIndex = 3;
    }

    void onNavigateMobile(int index) {
      final List<String> mobileRoutes = [
        '/',
        '/assets',
        '/affectations',
        '/tickets',
      ];
      if (index >= 0 && index < mobileRoutes.length) {
        context.go(mobileRoutes[index]);
      }
    }

    if (isDesktop) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: Row(
          children: [
            // ── Sidebar sombre ───────────────────────────────────
            _buildDarkSidebar(
              user: user,
              selectedIndex: selectedIndex,
              unreadCount: unreadCount,
              isAdmin: isAdmin,
              canManage: canManage,
              onNavigate: onNavigate,
              authProvider: authProvider,
            ),

            // ── Corps principal ──────────────────────────────────
            Expanded(
              child: Scaffold(
                backgroundColor: AppTheme.backgroundColor,
                appBar: _buildAppBar(context, ticketProvider),
                body: widget.child,
                floatingActionButton: widget.floatingActionButton,
              ),
            ),
          ],
        ),
      );
    } else {
      // ── Mobile — bottom nav ──────────────────────────────────────
      final List<NavigationDestination> destinations = [
        const NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard_rounded),
          label: 'Dashboard',
        ),
        const NavigationDestination(
          icon: Icon(Icons.inventory_2_outlined),
          selectedIcon: Icon(Icons.inventory_2_rounded),
          label: 'Inventaire',
        ),
        const NavigationDestination(
          icon: Icon(Icons.assignment_outlined),
          selectedIcon: Icon(Icons.assignment_rounded),
          label: 'Affectations',
        ),
        NavigationDestination(
          icon: unreadCount > 0
              ? Badge(label: Text('$unreadCount'), child: const Icon(Icons.confirmation_number_outlined))
              : const Icon(Icons.confirmation_number_outlined),
          selectedIcon: const Icon(Icons.confirmation_number_rounded),
          label: 'Tickets',
        ),
      ];

      return Scaffold(
        appBar: _buildAppBar(context, ticketProvider),
        drawer: _buildMobileDrawer(user, authProvider, context),
        body: widget.child,
        bottomNavigationBar: NavigationBar(
          selectedIndex: mobileSelectedIndex,
          onDestinationSelected: onNavigateMobile,
          destinations: destinations,
          elevation: 0,
          height: 65,
        ),
        floatingActionButton: widget.floatingActionButton,
      );
    }
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, TicketProvider ticketProvider) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return AppBar(
      title: Text(
        widget.title,
        style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface),
      ),
      backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      elevation: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: Theme.of(context).dividerColor, height: 1),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search_rounded),
          onPressed: () => context.push('/search'),
          tooltip: 'Recherche globale',
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: Icon(themeProvider.isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
          onPressed: () => themeProvider.toggleTheme(),
          tooltip: themeProvider.isDarkMode ? 'Mode clair' : 'Mode sombre',
        ),
        const SizedBox(width: 4),
        _buildNotificationBell(context, ticketProvider),
        const SizedBox(width: 8),
        if (widget.actions != null) ...widget.actions!,
      ],
    );
  }

  Widget _buildDarkSidebar({
    required dynamic user,
    required int selectedIndex,
    required int unreadCount,
    required bool isAdmin,
    required bool canManage,
    required void Function(int) onNavigate,
    required AuthProvider authProvider,
  }) {
    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: AppTheme.sidebarBg,
        border: Border(right: BorderSide(color: AppTheme.sidebarBorder, width: 1)),
      ),
      child: Column(
        children: [
          // ── Logo header ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: AppGradients.heroBanner,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.lan_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'IT PARC',
                      style: GoogleFonts.inter(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      'Bouaké Direction IT',
                      style: GoogleFonts.inter(fontSize: 11, color: AppTheme.sidebarText),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(height: 1, color: AppTheme.sidebarBorder),
          const SizedBox(height: 12),

          // ── Menu Items ───────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _darkNavItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard_rounded,
                      label: 'Tableau de bord', isSelected: selectedIndex == 0, onTap: () => onNavigate(0)),
                  _darkNavItem(icon: Icons.inventory_2_outlined, activeIcon: Icons.inventory_2_rounded,
                      label: 'Inventaire Parc', isSelected: selectedIndex == 1, onTap: () => onNavigate(1)),
                  _darkNavItem(icon: Icons.vpn_key_outlined, activeIcon: Icons.vpn_key_rounded,
                      label: 'Gestion Licences', isSelected: selectedIndex == 2, onTap: () => onNavigate(2)),
                  _darkNavItem(icon: Icons.category_outlined, activeIcon: Icons.category_rounded,
                      label: 'Stocks & Consommables', isSelected: selectedIndex == 3, onTap: () => onNavigate(3)),
                  _darkNavItem(icon: Icons.build_outlined, activeIcon: Icons.build_rounded,
                      label: 'Maintenances & Garanties', isSelected: selectedIndex == 4, onTap: () => onNavigate(4)),
                  _darkNavItem(icon: Icons.assignment_outlined, activeIcon: Icons.assignment_rounded,
                      label: 'Affectations', isSelected: selectedIndex == 5, onTap: () => onNavigate(5)),
                  _darkNavItem(
                    icon: Icons.confirmation_number_outlined,
                    activeIcon: Icons.confirmation_number_rounded,
                    label: 'Tickets IT',
                    isSelected: selectedIndex == 6,
                    onTap: () => onNavigate(6),
                    badge: unreadCount > 0 ? unreadCount : null,
                  ),
                  _darkNavItem(icon: Icons.menu_book_outlined, activeIcon: Icons.menu_book_rounded,
                      label: 'Base de Connaissances', isSelected: selectedIndex == 7, onTap: () => onNavigate(7)),
                  _darkNavItem(icon: Icons.bar_chart_rounded, activeIcon: Icons.bar_chart_rounded,
                      label: 'Rapports Globaux', isSelected: selectedIndex == 8, onTap: () => onNavigate(8)),

                  if (canManage) ...[
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      child: Text(
                        'ADMINISTRATION',
                        style: GoogleFonts.inter(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.sidebarText.withValues(alpha: 0.5),
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    _darkNavItem(icon: Icons.upload_file_outlined, activeIcon: Icons.upload_file_rounded,
                        label: 'Import / Export', isSelected: selectedIndex == 9, onTap: () => onNavigate(9)),
                    if (isAdmin)
                      _darkNavItem(icon: Icons.people_outline, activeIcon: Icons.people_rounded,
                          label: 'Utilisateurs', isSelected: selectedIndex == 10, onTap: () => onNavigate(10)),
                  ],

                  _darkNavItem(icon: Icons.manage_accounts_outlined, activeIcon: Icons.manage_accounts_rounded,
                      label: 'Mon Profil', isSelected: selectedIndex == 11, onTap: () => onNavigate(11)),
                ],
              ),
            ),
          ),

          // ── Profil utilisateur bas de sidebar ────────────────
          Container(height: 1, color: AppTheme.sidebarBorder),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar gradient
                Builder(
                  builder: (context) {
                    final apiBaseUrl = authProvider.getServerUrl();
                    final avatarUrl = user?.avatarUrl;
                    final fullAvatarUrl = avatarUrl != null ? '${apiBaseUrl.replaceAll('/api', '')}$avatarUrl' : null;

                    return Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        gradient: fullAvatarUrl == null ? AppGradients.avatarGradient : null,
                        borderRadius: BorderRadius.circular(12),
                        image: fullAvatarUrl != null
                            ? DecorationImage(image: NetworkImage(fullAvatarUrl), fit: BoxFit.cover)
                            : null,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: fullAvatarUrl == null
                          ? Center(
                              child: Text(
                                user != null && user.prenom.isNotEmpty ? user.prenom[0].toUpperCase() : 'U',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          : null,
                    );
                  }
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        user?.nomComplet ?? 'Utilisateur',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          user?.role?.toUpperCase() ?? 'LECTEUR',
                          style: GoogleFonts.inter(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF93C5FD),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.logout_rounded, size: 18, color: Color(0xFFFCA5A5)),
                  onPressed: () => authProvider.logout(),
                  tooltip: 'Déconnexion',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _darkNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    int? badge,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.primaryColor.withValues(alpha: 0.20)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: isSelected
                  ? Border(
                      left: BorderSide(
                        color: AppTheme.primaryColor.withValues(alpha: 0.90),
                        width: 3,
                      ),
                    )
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  isSelected ? activeIcon : icon,
                  size: 20,
                  color: isSelected ? const Color(0xFF93C5FD) : AppTheme.sidebarText,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected ? Colors.white : AppTheme.sidebarText,
                    ),
                  ),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$badge',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileDrawer(dynamic user, AuthProvider authProvider, BuildContext context) {
    return Drawer(
      backgroundColor: AppTheme.sidebarBg,
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: AppTheme.sidebarBg),
            child: Row(
              children: [
                Builder(
                  builder: (context) {
                    final apiBaseUrl = authProvider.getServerUrl();
                    final avatarUrl = user?.avatarUrl;
                    final fullAvatarUrl = avatarUrl != null ? '${apiBaseUrl.replaceAll('/api', '')}$avatarUrl' : null;

                    return Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: fullAvatarUrl == null ? AppGradients.avatarGradient : null,
                        borderRadius: BorderRadius.circular(14),
                        image: fullAvatarUrl != null
                            ? DecorationImage(image: NetworkImage(fullAvatarUrl), fit: BoxFit.cover)
                            : null,
                      ),
                      child: fullAvatarUrl == null
                          ? Center(
                              child: Text(
                                user != null && user.prenom.isNotEmpty ? user.prenom[0].toUpperCase() : 'U',
                                style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
                              ),
                            )
                          : null,
                    );
                  }
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.nomComplet ?? 'Utilisateur',
                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '@${user?.username ?? ''}',
                        style: GoogleFonts.inter(fontSize: 12, color: AppTheme.sidebarText),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            tileColor: Colors.transparent,
            leading: const Icon(Icons.vpn_key_outlined, color: AppTheme.sidebarText),
            title: Text('Gestion Licences', style: GoogleFonts.inter(color: Colors.white)),
            onTap: () { Navigator.pop(context); context.go('/licences'); },
          ),
          ListTile(
            tileColor: Colors.transparent,
            leading: const Icon(Icons.category_outlined, color: AppTheme.sidebarText),
            title: Text('Stocks & Consommables', style: GoogleFonts.inter(color: Colors.white)),
            onTap: () { Navigator.pop(context); context.go('/consommables'); },
          ),
          ListTile(
            tileColor: Colors.transparent,
            leading: const Icon(Icons.build_outlined, color: AppTheme.sidebarText),
            title: Text('Maintenances & Garanties', style: GoogleFonts.inter(color: Colors.white)),
            onTap: () { Navigator.pop(context); context.go('/maintenances'); },
          ),
          ListTile(
            tileColor: Colors.transparent,
            leading: const Icon(Icons.menu_book_outlined, color: AppTheme.sidebarText),
            title: Text('Base de Connaissances', style: GoogleFonts.inter(color: Colors.white)),
            onTap: () { Navigator.pop(context); context.go('/wiki'); },
          ),
          ListTile(
            tileColor: Colors.transparent,
            leading: const Icon(Icons.bar_chart_rounded, color: AppTheme.sidebarText),
            title: Text('Rapports Globaux', style: GoogleFonts.inter(color: Colors.white)),
            onTap: () { Navigator.pop(context); context.go('/reports'); },
          ),
          if (authProvider.currentUser?.role == 'admin' || authProvider.currentUser?.role == 'technicien')
            ListTile(
              tileColor: Colors.transparent,
              leading: const Icon(Icons.upload_file_outlined, color: AppTheme.sidebarText),
              title: Text('Import / Export', style: GoogleFonts.inter(color: Colors.white)),
              onTap: () { Navigator.pop(context); context.go('/import-export'); },
            ),
          if (authProvider.currentUser?.role == 'admin')
            ListTile(
              tileColor: Colors.transparent,
              leading: const Icon(Icons.people_outline, color: AppTheme.sidebarText),
              title: Text('Utilisateurs', style: GoogleFonts.inter(color: Colors.white)),
              onTap: () { Navigator.pop(context); context.go('/users'); },
            ),
          const Divider(color: AppTheme.sidebarBorder),
          ListTile(
            tileColor: Colors.transparent,
            leading: const Icon(Icons.manage_accounts_rounded, color: AppTheme.sidebarText),
            title: Text('Mon Profil', style: GoogleFonts.inter(color: Colors.white)),
            onTap: () { Navigator.pop(context); context.go('/profile'); },
          ),
          ListTile(
            tileColor: Colors.transparent,
            leading: const Icon(Icons.logout_rounded, color: Color(0xFFFCA5A5)),
            title: Text('Déconnexion', style: GoogleFonts.inter(color: const Color(0xFFFCA5A5))),
            onTap: () { Navigator.pop(context); authProvider.logout(); },
          ),
        ],
      ),
    );
  }
}
