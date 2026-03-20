import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/music_providers.dart';
import '../../core/services/player_service.dart';
import '../../core/services/database_service.dart';
import '../../core/services/api_service.dart';
import '../../core/models/song.dart';

// Provider
final timeBasedSongsProvider = FutureProvider<List<Song>>((ref) async {
  final hour = DateTime.now().hour;
  String query;
  if (hour >= 5 && hour < 12) {
    query = 'morning fresh hindi songs';
  } else if (hour >= 12 && hour < 17) {
    query = 'afternoon energetic hindi songs';
  } else if (hour >= 17 && hour < 21) {
    query = 'evening romantic hindi songs';
  } else {
    query = 'night sad chill hindi songs';
  }
  return ref.read(apiServiceProvider).searchSongs(query, page: 1);
});

class TimeBasedSection extends ConsumerWidget {
  const TimeBasedSection({super.key});

  Map<String, dynamic> get _timeConfig {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return {
        'title': 'Morning Vibes ☀️',
        'subtitle': 'Start your day right',
        'colors': [const Color(0xFFFFB3C6), const Color(0xFFFFD4A8)],
        'icon': Icons.wb_sunny_rounded,
      };
    } else if (hour >= 12 && hour < 17) {
      return {
        'title': 'Afternoon Energy ⚡',
        'subtitle': 'Keep the momentum going',
        'colors': [const Color(0xFFD4B8FF), const Color(0xFFFFB3C6)],
        'icon': Icons.bolt_rounded,
      };
    } else if (hour >= 17 && hour < 21) {
      return {
        'title': 'Evening Feels 🌅',
        'subtitle': 'Wind down beautifully',
        'colors': [const Color(0xFFFF85A1), const Color(0xFFD4B8FF)],
        'icon': Icons.nights_stay_rounded,
      };
    } else {
      return {
        'title': 'Perfect for ${DateTime.now().hour}AM 🌙',
        'subtitle': 'Late night soul music',
        'colors': [const Color(0xFF8B5CF6), const Color(0xFFFFB3C6)],
        'icon': Icons.bedtime_rounded,
      };
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = _timeConfig;
    final colors = config['colors'] as List<Color>;
    final songsAsync = ref.watch(timeBasedSongsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 28, 16, 14),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colors[0].withOpacity(0.2),
                      colors[1].withOpacity(0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: colors[0].withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    // Icon
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: colors),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: colors[0].withOpacity(0.4),
                            blurRadius: 12, spreadRadius: -2),
                        ],
                      ),
                      child: Icon(config['icon'] as IconData,
                        color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(config['title'] as String,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800)),
                          const SizedBox(height: 2),
                          Text(config['subtitle'] as String,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 13)),
                        ],
                      ),
                    ),
                    // Play all button
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: colors),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: colors[0].withOpacity(0.4),
                            blurRadius: 12, spreadRadius: -3),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.play_arrow_rounded,
                            color: Colors.white, size: 16),
                          SizedBox(width: 4),
                          Text('Play All',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.1),

        // Songs horizontal scroll
        SizedBox(
          height: 80,
          child: songsAsync.when(
            loading: () => _buildShimmer(),
            error: (_, __) => const SizedBox.shrink(),
            data: (songs) => ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: songs.take(10).length,
              itemBuilder: (context, index) => _TimeBasedSongChip(
                song: songs[index],
                colors: colors,
                onTap: () {
                  ref.read(currentSongProvider.notifier)
                    .state = songs[index];
                  ref.read(playerServiceProvider)
                    .playSong(songs[index]);
                  ref.read(databaseServiceProvider)
                    .addToHistory(songs[index]);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildShimmer() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 5,
      itemBuilder: (_, __) => Container(
        width: 200,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14)),
      ).animate(onPlay: (c) => c.repeat())
        .shimmer(duration: 1200.ms,
          color: Colors.white.withOpacity(0.05)),
    );
  }
}

class _TimeBasedSongChip extends StatelessWidget {
  final Song song;
  final List<Color> colors;
  final VoidCallback onTap;

  const _TimeBasedSongChip({
    required this.song,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 200,
            margin: const EdgeInsets.only(right: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colors[0].withOpacity(0.15),
                  colors[1].withOpacity(0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: colors[0].withOpacity(0.2)),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    song.image,
                    width: 46, height: 46,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 46, height: 46,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: colors),
                        borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.music_note,
                        color: Colors.white, size: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(song.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(song.artist,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Icon(Icons.play_arrow_rounded,
                  color: colors[0], size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}