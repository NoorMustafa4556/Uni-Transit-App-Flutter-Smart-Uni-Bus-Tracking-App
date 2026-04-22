import 'package:flutter/material.dart';
import 'package:uni_transit/core/constants/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';

class NotificationService {
  static final GlobalKey<ScaffoldMessengerState> messengerKey = GlobalKey<ScaffoldMessengerState>();

  static void show({
    required String title,
    required String message,
    NotificationType type = NotificationType.info,
  }) {
    final Color bgColor = _getBgColor(type);
    final IconData icon = _getIcon(type);

    messengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                    Text(message, style: GoogleFonts.poppins(fontSize: 11, color: Colors.white.withValues(alpha: 0.9))),
                  ],
                ),
              ),
            ],
          ),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: bgColor,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: const EdgeInsets.all(16),
        elevation: 10,
      ),
    );
  }

  static Color _getBgColor(NotificationType type) {
    switch (type) {
      case NotificationType.success: return Colors.green[700]!;
      case NotificationType.warning: return Colors.orange[800]!;
      case NotificationType.error: return Colors.red[700]!;
      case NotificationType.proximity: return AppColors.primaryNavy;
      case NotificationType.info: return AppColors.primaryNavy;
    }
  }

  static IconData _getIcon(NotificationType type) {
    switch (type) {
      case NotificationType.success: return Icons.check_circle_rounded;
      case NotificationType.warning: return Icons.warning_rounded;
      case NotificationType.error: return Icons.error_rounded;
      case NotificationType.proximity: return Icons.directions_bus_rounded;
      case NotificationType.info: return Icons.info_rounded;
    }
  }
}

enum NotificationType { success, warning, error, proximity, info }
