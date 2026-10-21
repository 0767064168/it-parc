// ============================================
// lib/core/router.dart — Routage avec GoRouter
// ============================================

import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/assets/asset_list_screen.dart';
import '../screens/assets/asset_detail_screen.dart';
import '../screens/assets/asset_form_screen.dart';
import '../screens/affectations/affectation_screen.dart';
import '../screens/users/user_management_screen.dart';
import '../screens/importexport/import_export_screen.dart';
import '../screens/tickets/ticket_list_screen.dart';
import '../screens/tickets/ticket_form_screen.dart';
import '../screens/tickets/ticket_detail_screen.dart';
import '../screens/tickets/ticket_kanban_screen.dart';
import '../screens/tickets/ticket_reports_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/licences/licence_list_screen.dart';
import '../screens/consommables/consommable_stock_screen.dart';
import '../screens/maintenances/maintenance_screen.dart';
import '../screens/wiki/wiki_screen.dart';
import '../screens/search/global_search_screen.dart';
import '../screens/reports/global_reports_screen.dart';

class AppRouter {
  static GoRouter router(AuthProvider authProvider) {
    return GoRouter(
      initialLocation: '/',
      refreshListenable: authProvider,
      redirect: (context, state) {
        final isAuthenticated = authProvider.isAuthenticated;
        final isLoggingIn = state.matchedLocation == '/login';

        // Attendre que l'authentification soit initialisée
        if (authProvider.isLoading) return null;

        // Si l'utilisateur n'est pas connecté et n'est pas sur la page de connexion
        if (!isAuthenticated && !isLoggingIn) {
          return '/login';
        }

        // Si l'utilisateur est connecté et est sur la page de connexion
        if (isAuthenticated && isLoggingIn) {
          return '/';
        }

        return null;
      },
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/',
          builder: (context, state) => const DashboardScreen(),
        ),

        // ── Assets ──────────────────────────────────────────────
        GoRoute(
          path: '/assets',
          builder: (context, state) => const AssetListScreen(),
        ),
        GoRoute(
          path: '/assets/new',
          builder: (context, state) => const AssetFormScreen(assetId: null),
        ),
        GoRoute(
          path: '/assets/:id',
          builder: (context, state) {
            final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
            return AssetDetailScreen(assetId: id);
          },
        ),
        GoRoute(
          path: '/assets/:id/edit',
          builder: (context, state) {
            final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
            return AssetFormScreen(assetId: id);
          },
        ),

        // ── Affectations ─────────────────────────────────────────
        GoRoute(
          path: '/affectations',
          builder: (context, state) => const AffectationScreen(),
        ),

        // ── Import / Export ──────────────────────────────────────
        GoRoute(
          path: '/import-export',
          builder: (context, state) => const ImportExportScreen(),
        ),

        GoRoute(
          path: '/users',
          builder: (context, state) => const UserManagementScreen(),
        ),

        // ── Tickets ──────────────────────────────────────────────
        GoRoute(
          path: '/tickets',
          builder: (context, state) => const TicketListScreen(),
        ),
        GoRoute(
          path: '/tickets/new',
          builder: (context, state) => const TicketFormScreen(),
        ),
        GoRoute(
          path: '/tickets/kanban',
          builder: (context, state) => const TicketKanbanScreen(),
        ),
        GoRoute(
          path: '/tickets/reports',
          builder: (context, state) => const TicketReportsScreen(),
        ),
        GoRoute(
          path: '/tickets/:id',
          builder: (context, state) {
            final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
            return TicketDetailScreen(ticketId: id);
          },
        ),

        // ── Licences ─────────────────────────────────────────────
        GoRoute(
          path: '/licences',
          builder: (context, state) => const LicenceListScreen(),
        ),

        // ── Consommables ─────────────────────────────────────────
        GoRoute(
          path: '/consommables',
          builder: (context, state) => const ConsommableStockScreen(),
        ),

        // ── Maintenances ─────────────────────────────────────────
        GoRoute(
          path: '/maintenances',
          builder: (context, state) => const MaintenanceScreen(),
        ),

        // ── Wiki ─────────────────────────────────────────────────
        GoRoute(
          path: '/wiki',
          builder: (context, state) => const WikiScreen(),
        ),

        // ── Recherche globale ─────────────────────────────────────
        GoRoute(
          path: '/search',
          builder: (context, state) => const GlobalSearchScreen(),
        ),

        // ── Rapports Globaux ──────────────────────────────────────
        GoRoute(
          path: '/reports',
          builder: (context, state) => const GlobalReportsScreen(),
        ),

        // ── Profil ─────────────────────────────────────────────
        GoRoute(
          path: '/profile',
          builder: (context, state) => const ProfileScreen(),
        ),
      ],
    );
  }
}
