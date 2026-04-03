import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/services/admin_service.dart';
import '../core/admin_core_widgets.dart';

class LogsTab extends ConsumerWidget {
  const LogsTab({super.key});

  static const _actionIcons = <String, IconData>{
    'ban_user': Icons.block_rounded,
    'unban_user': Icons.check_circle_rounded,
    'delete_user_data': Icons.delete_forever_rounded,
    'sync_all_stats': Icons.sync_rounded,
    'refresh_stats': Icons.refresh_rounded,
    'send_broadcast': Icons.send_rounded,
    'delete_broadcast': Icons.notifications_off_rounded,
    'create_announcement': Icons.campaign_rounded,
    'delete_announcement': Icons.remove_circle_rounded,
    'update_config': Icons.settings_rounded,
    'create_banner': Icons.image_rounded,
    'delete_banner': Icons.image_not_supported_rounded,
    'create_curated_section': Icons.playlist_add_rounded,
    'delete_curated_section': Icons.playlist_remove_rounded,
  };

  static const _actionColors = <String, Color>{
    'ban_user': Color(0xFFFF4444),
    'unban_user': Color(0xFF11D47B),
    'delete_user_data': Color(0xFFFF4444),
    'sync_all_stats': Color(0xFF6C63FF),
    'refresh_stats': Color(0xFF6C63FF),
    'send_broadcast': Color(0xFF6C63FF),
    'update_config': Color(0xFFF7971E),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminActivityProvider);
    return async.when(
      loading: () => const AdminLoader(),
      error: (e, _) => AdminErrorCard(message: e.toString()),
      data: (logs) {
        if (logs.isEmpty) {
          return const Center(child: Text('No activity logs yet', style: TextStyle(color: Colors.white54)));
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          physics: const BouncingScrollPhysics(),
          itemCount: logs.length,
          itemBuilder: (_, i) {
            final log = logs[i];
            final ts = (log['timestamp'] as Timestamp?)?.toDate();
            final action = log['action'] as String? ?? '';
            final color = _actionColors[action] ?? const Color(0xFF6C63FF);
            final icon = _actionIcons[action] ?? Icons.bolt_rounded;
            final details = log['details'] as Map<String, dynamic>? ?? {};

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        action.replaceAll('_', ' ').toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                      ),
                      if (details.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          details.entries.take(2).map((e) => '${e.key}: ${e.value}').join(' · '),
                          style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 10),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (ts != null)
                        Text(ts.toString(), style: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 10)),
                    ],
                  ),
                ),
                if (log['adminEmail'] != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
                    child: Text('admin', style: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 9, fontWeight: FontWeight.w600)),
                  ),
              ]),
            ).animate().fadeIn(delay: Duration(milliseconds: i * 20), duration: 250.ms);
          },
        );
      },
    );
  }
}
