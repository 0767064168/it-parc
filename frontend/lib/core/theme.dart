// ============================================
// lib/core/theme.dart — Thème et Design System
// ============================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Palette principale ────────────────────────────────────────────
  static const Color backgroundColor    = Color(0xFFF4F6FA);
  static const Color surfaceColor       = Color(0xFFFFFFFF);
  static const Color primaryColor       = Color(0xFF2563EB); // Bleu royal vif
  static const Color primaryVariantColor= Color(0xFF1D4ED8); // Bleu foncé
  static const Color primaryLight       = Color(0xFFDBEAFE); // Bleu très clair
  static const Color secondaryColor     = Color(0xFF059669); // Vert émeraude
  static const Color accentColor        = Color(0xFFF59E0B); // Ambre/Or

  static const Color successColor       = Color(0xFF059669);
  static const Color errorColor         = Color(0xFFDC2626);
  static const Color warningColor       = Color(0xFFD97706);
  static const Color infoColor          = Color(0xFF6B7280);

  static const Color textPrimaryColor   = Color(0xFF111827);
  static const Color textSecondaryColor = Color(0xFF6B7280);
  static const Color borderColor        = Color(0xFFE5E7EB);
  static const Color dividerColor       = Color(0xFFF3F4F6);

  // ── Couleurs Sidebar sombre ───────────────────────────────────────
  static const Color sidebarBg         = Color(0xFF0F172A); // Slate 900
  static const Color sidebarActive     = Color(0xFF1E40AF); // Blue 800
  static const Color sidebarText       = Color(0xFFCBD5E1); // Slate 300
  static const Color sidebarTextActive = Color(0xFFFFFFFF);
  static const Color sidebarBorder     = Color(0xFF1E293B); // Slate 800

  // ── Couleurs par type d'équipement ───────────────────────────────
  static const Color colorLaptop       = Color(0xFF2563EB);
  static const Color colorDesktop      = Color(0xFF059669);
  static const Color colorEcran        = Color(0xFFF59E0B);
  static const Color colorImprimante   = Color(0xFFEA580C);
  static const Color colorServeur      = Color(0xFF7C3AED);
  static const Color colorReseau       = Color(0xFF0891B2);
  static const Color colorDefault      = Color(0xFF6B7280);

  static Color getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'laptop':      return colorLaptop;
      case 'desktop':     return colorDesktop;
      case 'ecran':       return colorEcran;
      case 'imprimante':  return colorImprimante;
      case 'serveur':     return colorServeur;
      case 'routeur':
      case 'switch':      return colorReseau;
      default:            return colorDefault;
    }
  }

  static IconData getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'laptop':      return Icons.laptop_rounded;
      case 'desktop':     return Icons.computer_rounded;
      case 'ecran':       return Icons.monitor_rounded;
      case 'imprimante':  return Icons.print_rounded;
      case 'scanner':     return Icons.scanner;
      case 'telephone':   return Icons.phone_android_rounded;
      case 'tablette':    return Icons.tablet_mac_rounded;
      case 'serveur':     return Icons.dns_rounded;
      case 'switch':
      case 'routeur':     return Icons.router_rounded;
      default:            return Icons.devices_other_rounded;
    }
  }

  // ── ThemeData ─────────────────────────────────────────────────────
  static ThemeData get lightTheme {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,
      cardColor: surfaceColor,
      dividerColor: borderColor,

      colorScheme: const ColorScheme.light(
        primary:    primaryColor,
        secondary:  secondaryColor,
        surface:    surfaceColor,
        error:      errorColor,
        onPrimary:  Colors.white,
        onSecondary:Colors.white,
        onSurface:  textPrimaryColor,
        onError:    Colors.white,
      ),

      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
          side: const BorderSide(color: borderColor, width: 1.0),
        ),
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceColor,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: borderColor,
        centerTitle: false,
        iconTheme: IconThemeData(color: textPrimaryColor),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        hintStyle: const TextStyle(color: textSecondaryColor, fontSize: 14.0),
        labelStyle: const TextStyle(color: textSecondaryColor, fontSize: 14.0),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: const BorderSide(color: borderColor, width: 1.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: const BorderSide(color: borderColor, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: const BorderSide(color: primaryColor, width: 2.0),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: const BorderSide(color: errorColor, width: 1.0),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceColor,
        indicatorColor: primaryLight,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primaryColor);
          }
          return const TextStyle(fontSize: 12, color: textSecondaryColor);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primaryColor);
          }
          return const IconThemeData(color: textSecondaryColor);
        }),
      ),
    );

    // Injecter la typographie Inter via Google Fonts
    return base.copyWith(
      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        headlineLarge:  GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w800, color: textPrimaryColor),
        headlineMedium: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w700, color: textPrimaryColor),
        titleLarge:     GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w600, color: textPrimaryColor),
        titleMedium:    GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimaryColor),
        titleSmall:     GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimaryColor),
        bodyLarge:      GoogleFonts.inter(fontSize: 16, color: textPrimaryColor),
        bodyMedium:     GoogleFonts.inter(fontSize: 14, color: textSecondaryColor),
        bodySmall:      GoogleFonts.inter(fontSize: 12, color: textSecondaryColor),
        labelLarge:     GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: primaryColor),
      ),
    );
  }

  static ThemeData get darkTheme {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: const Color(0xFF0F172A),
      cardColor: const Color(0xFF1E293B),
      dividerColor: const Color(0xFF334155),

      colorScheme: const ColorScheme.dark(
        primary:    primaryColor,
        secondary:  secondaryColor,
        surface:    Color(0xFF1E293B),
        error:      errorColor,
        onPrimary:  Colors.white,
        onSecondary:Colors.white,
        onSurface:  Color(0xFFF1F5F9),
        onError:    Colors.white,
      ),

      cardTheme: CardThemeData(
        color: const Color(0xFF1E293B),
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
          side: const BorderSide(color: Color(0xFF334155), width: 1.0),
        ),
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1E293B),
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: Color(0xFF334155),
        centerTitle: false,
        iconTheme: IconThemeData(color: Color(0xFFF1F5F9)),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1E293B),
        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14.0),
        labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14.0),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: const BorderSide(color: Color(0xFF334155), width: 1.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: const BorderSide(color: Color(0xFF334155), width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: const BorderSide(color: primaryColor, width: 2.0),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: const BorderSide(color: errorColor, width: 1.0),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF1E293B),
        indicatorColor: primaryColor.withValues(alpha: 0.2),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primaryColor);
          }
          return const TextStyle(fontSize: 12, color: Color(0xFF94A3B8));
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primaryColor);
          }
          return const IconThemeData(color: Color(0xFF94A3B8));
        }),
      ),
    );

    return base.copyWith(
      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        headlineLarge:  GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w800, color: const Color(0xFFF1F5F9)),
        headlineMedium: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w700, color: const Color(0xFFF1F5F9)),
        titleLarge:     GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w600, color: const Color(0xFFF1F5F9)),
        titleMedium:    GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFFF1F5F9)),
        titleSmall:     GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFFF1F5F9)),
        bodyLarge:      GoogleFonts.inter(fontSize: 16, color: const Color(0xFFF1F5F9)),
        bodyMedium:     GoogleFonts.inter(fontSize: 14, color: const Color(0xFF94A3B8)),
        bodySmall:      GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
        labelLarge:     GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: primaryColor),
      ),
    );
  }
}

// ── Gradients ─────────────────────────────────────────────────────────
class AppGradients {
  /// Fond de l'écran de connexion
  static const LinearGradient loginBackground = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0F172A), Color(0xFF1E1B4B), Color(0xFF1E3A8A)],
    stops: [0.0, 0.5, 1.0],
  );

  /// Gradient pour les héros / bannières
  static const LinearGradient heroBanner = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
  );

  /// Gradient de l'avatar sidebar
  static const LinearGradient avatarGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
  );

  /// Gradient bleu doux pour les icônes KPI
  static LinearGradient iconGradient(Color color) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [color.withValues(alpha: 0.15), color.withValues(alpha: 0.05)],
  );

  /// Gradient vert succès
  static const LinearGradient success = LinearGradient(
    colors: [Color(0xFF059669), Color(0xFF10B981)],
  );

  /// Gradient rouge erreur
  static const LinearGradient error = LinearGradient(
    colors: [Color(0xFFDC2626), Color(0xFFEF4444)],
  );
}
