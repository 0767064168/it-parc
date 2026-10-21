// ============================================
// lib/widgets/status_badge.dart — Badge de statut
// ============================================

import 'package:flutter/material.dart';
import '../core/theme.dart';

class StatusBadge extends StatelessWidget {
  final String statut;

  const StatusBadge({super.key, required this.statut});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;

    switch (statut) {
      case 'en_service':
        color = AppTheme.successColor;
        label = 'En service';
        break;
      case 'hors_service':
        color = AppTheme.errorColor;
        label = 'Hors service';
        break;
      case 'reforme':
        color = AppTheme.infoColor;
        label = 'Réformé';
        break;
      case 'en_maintenance':
        color = AppTheme.warningColor;
        label = 'En maintenance';
        break;
      case 'en_stock':
        color = AppTheme.primaryColor;
        label = 'En stock';
        break;
      default:
        color = Colors.grey;
        label = statut;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6.0),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12.0,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
