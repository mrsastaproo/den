import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/services/admin_service.dart';
import '../core/admin_core_widgets.dart';

class AnnouncementsTab extends ConsumerWidget {
  const AnnouncementsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminAnnouncementsProvider);
    return async.when(
      loading: () => const AdminLoader(),
      error: (e, _) => AdminErrorCard(message: e.toString()),
      data: (announcements) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
        physics: const BouncingScrollPhysics(),
        children: [
          AdminAddButton(
            label: 'New Announcement',
            onTap: () => _showAnnouncementForm(context, ref, null),
          ),
          const SizedBox(height: 10),
          ...announcements.asMap().entries.map((e) => _AnnouncementTile(
                ann: e.value,
                onEdit: () => _showAnnouncementForm(context, ref, e.value),
                onDelete: () async {
                  await ref.read(adminServiceProvider).deleteAnnouncement(e.value.id);
                },
                onToggle: (v) async {
                  await ref.read(adminServiceProvider).updateAnnouncement(e.value.id, isActive: v);
                },
              ).animate().fadeIn(delay: Duration(milliseconds: e.key * 40), duration: 280.ms)),
        ],
      ),
    );
  }

  void _showAnnouncementForm(BuildContext context, WidgetRef ref, AppAnnouncement? ann) {
    final titleCtrl = TextEditingController(text: ann?.title ?? '');
    final msgCtrl = TextEditingController(text: ann?.message ?? '');
    String type = ann?.type ?? 'info';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AdminFormSheet(
        title: ann == null ? 'New Announcement' : 'Edit Announcement',
        fields: [
          AdminFormField('Title', titleCtrl, hint: 'e.g. New Feature!'),
          AdminFormField('Message', msgCtrl, hint: 'Announcement body...', maxLines: 3),
        ],
        extraContent: StatefulBuilder(
          builder: (_, setS) {
            final types = [
              ('info', const Color(0xFF6C63FF), Icons.info_rounded),
              ('success', const Color(0xFF11D47B), Icons.check_circle_rounded),
              ('warning', const Color(0xFFF7971E), Icons.warning_rounded),
              ('promo', const Color(0xFFFF3366), Icons.local_offer_rounded),
            ];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Type', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: types.map((t) {
                    final sel = t.$1 == type;
                    return GestureDetector(
                      onTap: () => setS(() => type = t.$1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: sel ? t.$2.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: sel ? t.$2.withOpacity(0.5) : Colors.white.withOpacity(0.08)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(t.$3, color: sel ? t.$2 : Colors.white38, size: 13),
                            const SizedBox(width: 4),
                            Text(t.$1, style: TextStyle(color: sel ? t.$2 : Colors.white.withOpacity(0.4), fontSize: 11, fontWeight: sel ? FontWeight.w700 : FontWeight.w500)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            );
          },
        ),
        onSave: () async {
          if (ann == null) {
            await ref.read(adminServiceProvider).createAnnouncement(title: titleCtrl.text, message: msgCtrl.text, type: type);
          } else {
            await ref.read(adminServiceProvider).updateAnnouncement(ann.id, title: titleCtrl.text, message: msgCtrl.text, type: type);
          }
          if (context.mounted) Navigator.pop(context);
        },
      ),
    );
  }
}

class _AnnouncementTile extends StatelessWidget {
  final AppAnnouncement ann;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggle;

  const _AnnouncementTile({required this.ann, required this.onEdit, required this.onDelete, required this.onToggle});

  static const _typeColors = {
    'info': Color(0xFF6C63FF),
    'success': Color(0xFF11D47B),
    'warning': Color(0xFFF7971E),
    'promo': Color(0xFFFF3366),
  };

  static const _typeIcons = {
    'info': Icons.info_rounded,
    'success': Icons.check_circle_rounded,
    'warning': Icons.warning_rounded,
    'promo': Icons.local_offer_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final color = _typeColors[ann.type] ?? const Color(0xFF6C63FF);
    final icon = _typeIcons[ann.type] ?? Icons.info_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ann.isActive ? color.withOpacity(0.25) : Colors.white.withOpacity(0.07), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(ann.title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700))),
              Switch.adaptive(value: ann.isActive, onChanged: onToggle, activeColor: const Color(0xFF11D47B)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Text(ann.message, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12, height: 1.4)),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18))),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                child: Text(ann.type.toUpperCase(), style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w800)),
              ),
              const Spacer(),
              GestureDetector(onTap: onEdit, child: const Icon(Icons.edit_rounded, color: Color(0xFF6C63FF), size: 18)),
              const SizedBox(width: 12),
              GestureDetector(onTap: onDelete, child: const Icon(Icons.delete_rounded, color: Color(0xFFFF4444), size: 18)),
            ]),
          ),
        ],
      ),
    );
  }
}
