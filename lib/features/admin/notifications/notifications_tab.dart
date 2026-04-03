import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/services/admin_service.dart';
import '../core/admin_core_widgets.dart';

class NotificationsTab extends ConsumerWidget {
  const NotificationsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final broadcastsAsync = ref.watch(adminBroadcastsProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      physics: const BouncingScrollPhysics(),
      children: [
        const AdminSectionHeader(title: 'Push Notifications', icon: Icons.notifications_active_rounded),
        const SizedBox(height: 10),
        AdminGlassCard(children: [
          GestureDetector(
            onTap: () => _showBroadcastForm(context, ref),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0xFF6C63FF).withOpacity(0.08), borderRadius: BorderRadius.circular(16)),
              child: const Row(children: [
                Icon(Icons.send_rounded, color: Color(0xFF6C63FF), size: 18),
                SizedBox(width: 8),
                Text('Send New Broadcast', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 24),
        const AdminSectionHeader(title: 'Broadcast History', icon: Icons.history_rounded),
        const SizedBox(height: 10),
        broadcastsAsync.when(
          loading: () => const AdminLoader(),
          error: (e, _) => AdminErrorCard(message: e.toString()),
          data: (broadcasts) {
            if (broadcasts.isEmpty) return const Center(child: Text('No broadcasts sent yet', style: TextStyle(color: Colors.white54)));
            return Column(
              children: broadcasts.asMap().entries.map((e) => _BroadcastHistoryTile(
                    broadcast: e.value,
                    onDelete: () async {
                      await ref.read(adminServiceProvider).deleteBroadcast(e.value.id);
                    },
                  ).animate().fadeIn(delay: Duration(milliseconds: e.key * 30), duration: 260.ms)).toList(),
            );
          },
        ),
      ],
    );
  }

  void _showBroadcastForm(BuildContext context, WidgetRef ref) {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    final imgCtrl = TextEditingController();
    final linkCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AdminFormSheet(
        title: 'Send Broadcast',
        fields: [
          AdminFormField('Title', titleCtrl, hint: 'Notification heading...'),
          AdminFormField('Message Body', bodyCtrl, hint: 'What users will see...', maxLines: 3),
          AdminFormField('Image URL (Optional)', imgCtrl, hint: 'https://...'),
          AdminFormField('Link / Action (Optional)', linkCtrl, hint: 'den://playlist/...'),
        ],
        onSave: () async {
          if (titleCtrl.text.isEmpty || bodyCtrl.text.isEmpty) return;
          HapticFeedback.mediumImpact();
          await ref.read(adminServiceProvider).sendBroadcastNotification(
                title: titleCtrl.text,
                body: bodyCtrl.text,
                imageUrl: imgCtrl.text.isEmpty ? null : imgCtrl.text,
                link: linkCtrl.text.isEmpty ? null : linkCtrl.text,
              );
          if (context.mounted) Navigator.pop(context);
        },
      ),
    );
  }
}

class _BroadcastHistoryTile extends StatelessWidget {
  final BroadcastNotification broadcast;
  final VoidCallback onDelete;

  const _BroadcastHistoryTile({required this.broadcast, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (broadcast.status) {
      'sent' => const Color(0xFF11D47B),
      'failed' => const Color(0xFFFF4444),
      _ => const Color(0xFFF7971E),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.07), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: const Color(0xFF6C63FF).withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.send_rounded, color: Color(0xFF6C63FF), size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(broadcast.title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                  if (broadcast.sentAt != null)
                    Text(broadcast.sentAt.toString(), style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
              child: Text(broadcast.status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 8),
            GestureDetector(onTap: onDelete, child: Icon(Icons.delete_outline_rounded, color: Colors.white.withOpacity(0.3), size: 18)),
          ]),
          const SizedBox(height: 8),
          Text(broadcast.body, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
