import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/services/database_service.dart';
import '../../core/providers/music_providers.dart';
import '../../core/theme/app_theme.dart';

class RecentlyPlayedSection extends ConsumerWidget {
  const RecentlyPlayedSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(historyProvider);

    return historyAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (songs) {
        if (songs.isEmpty) return const SizedBox.shrink();
        final recent = songs.take(5).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 14),
              child: Row(
                children: [
                  ShaderMask(
                    shaderCallback: (b) =>
                      AppTheme.primaryGradient.createShader(b),
                    child: const Icon(Icons.history_rounded,
                      color: Colors.white, size: 22)),
                  const SizedBox(width: 8),
                  const Text('Recently Played',
                    style: TextStyle(color: Colors.white,
                      fontSize: 20, fontWeight: FontWeight.w700)),
                ],
              ),
            ).animate().fadeIn(duration: 500.ms),

            SizedBox(
              height: 110,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: recent.length,
                itemBuilder: (context, index) {
                  final song = recent[index];
                  return GestureDetector(
                    onTap: () {
                      playQueue(ref, recent, index);
                      ref.read(databaseServiceProvider)
                        .addToHistory(song);
                    },
                    child: Container(
                      width: 90,
                      margin: const EdgeInsets.only(right: 12),
                      child: Column(
                        children: [
                          // Album art with glow
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.pink.withOpacity(0.3),
                                  blurRadius: 12, spreadRadius: -3),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: CachedNetworkImage(
                                imageUrl: song.image,
                                width: 72, height: 72,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => Container(
                                  width: 72, height: 72,
                                  decoration: BoxDecoration(
                                    gradient: AppTheme.primaryGradient,
                                    borderRadius:
                                      BorderRadius.circular(18)),
                                  child: const Icon(Icons.music_note,
                                    color: Colors.white, size: 28),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(song.title,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 10,
                              fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                  ).animate()
                    .fadeIn(duration: 400.ms,
                      delay: (index * 80).ms)
                    .scale(begin: const Offset(0.8, 0.8),
                      duration: 400.ms,
                      delay: (index * 80).ms,
                      curve: Curves.easeOutBack);
                },
              ),
            ),
          ],
        );
      },
    );
  }
}