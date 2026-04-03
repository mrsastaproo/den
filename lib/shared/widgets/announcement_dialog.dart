import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/admin_service.dart';
import '../../core/theme/app_theme.dart';

class AnnouncementDialog extends ConsumerWidget {
  final AppAnnouncement announcement;

  const AnnouncementDialog({super.key, required this.announcement});

  static Future<void> showIfNeeded(BuildContext context, WidgetRef ref) async {
    final activeAnnouncements = ref.watch(activeAnnouncementsProvider).value;
    if (activeAnnouncements == null || activeAnnouncements.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final latestAnn = activeAnnouncements.first;
    
    // Key used to track if this specific announcement has been seen
    final key = 'announcement_seen_${latestAnn.id}';
    final alreadySeen = prefs.getBool(key) ?? false;

    if (!alreadySeen && context.mounted) {
      await showDialog(
        context: context,
        barrierDismissible: true,
        builder: (_) => AnnouncementDialog(announcement: latestAnn),
      );
      await prefs.setBool(key, true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _getTypeColor(announcement.type);

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.85),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: color.withOpacity(0.3), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.15),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon Header
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(_getTypeIcon(announcement.type), color: color, size: 30),
              ),
              const SizedBox(height: 20),
              
              // Title
              Text(
                announcement.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              
              // Message
              Text(
                announcement.message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              
              // Primary Action
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [color, color.withAlpha(180)]),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.35),
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'Got it',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'warning': return Colors.orangeAccent;
      case 'success': return const Color(0xFF11D47B);
      case 'promo': return AppTheme.pink;
      default: return AppTheme.pink;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'warning': return Icons.warning_rounded;
      case 'success': return Icons.check_circle_rounded;
      case 'promo': return Icons.celebration_rounded;
      default: return Icons.campaign_rounded;
    }
  }
}
