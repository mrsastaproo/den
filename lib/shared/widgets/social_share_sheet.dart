import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/chat_service.dart';
import '../../core/services/social_service.dart';
import '../../core/theme/app_theme.dart';

class SocialShareSheet extends ConsumerWidget {
  final String type;
  final Map<String, dynamic> metadata;

  const SocialShareSheet({
    super.key,
    required this.type,
    required this.metadata,
  });

  static void show(BuildContext context, {required String type, required Map<String, dynamic> metadata}) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => SocialShareSheet(type: type, metadata: metadata),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
        child: Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
          padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).padding.bottom + 24),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.84),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border.all(color: Colors.white.withOpacity(0.08), width: 0.8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Share with Friends',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Flexible(
                child: Consumer(
                  builder: (context, ref, child) {
                    final friendsAsync = ref.watch(friendsListProvider);
                    return friendsAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.pink)),
                      error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.white70))),
                      data: (friends) {
                        if (friends.isEmpty) {
                          return const Center(child: Text('Add friends to share music', style: TextStyle(color: Colors.white30)));
                        }
                        return ListView.builder(
                          shrinkWrap: true,
                          itemCount: friends.length,
                          itemBuilder: (c, i) => ListTile(
                            leading: const CircleAvatar(backgroundColor: AppTheme.purple, child: Icon(Icons.person, color: Colors.white)),
                            title: Text(friends[i]['username'] ?? 'Friend', style: const TextStyle(color: Colors.white)),
                            trailing: const Icon(Icons.send_rounded, color: AppTheme.pink),
                            onTap: () {
                              ref.read(chatServiceProvider).shareMedia(friends[i]['uid'], type, metadata);
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Shared with ${friends[i]['username'] ?? 'friend'}')),
                              );
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
