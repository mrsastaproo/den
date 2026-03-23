import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/music_providers.dart';
import '../../core/services/database_service.dart';
import '../../core/models/song.dart';

class MoodMixSection extends ConsumerWidget {
  const MoodMixSection({super.key});

  static const _moods = [
    {'label': 'Happy', 'emoji': '😊',
      'colors': [Color(0xFFFFB3C6), Color(0xFFFFD4A8)]},
    {'label': 'Sad', 'emoji': '😢',
      'colors': [Color(0xFF8B5CF6), Color(0xFFB794FF)]},
    {'label': 'Hype', 'emoji': '🔥',
      'colors': [Color(0xFFFF85A1), Color(0xFFFFB3C6)]},
    {'label': 'Chill', 'emoji': '😌',
      'colors': [Color(0xFFD4B8FF), Color(0xFF8B5CF6)]},
    {'label': 'Focus', 'emoji': '🎯',
      'colors': [Color(0xFFFFB3C6), Color(0xFFD4B8FF)]},
    {'label': 'Love', 'emoji': '❤️',
      'colors': [Color(0xFFFF85A1), Color(0xFFD4B8FF)]},
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMood = ref.watch(selectedMoodProvider);
    final mixAsync = ref.watch(moodMixProvider);

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
                child: const Icon(Icons.auto_awesome_rounded,
                  color: Colors.white, size: 22)),
              const SizedBox(width: 8),
              const Text('Mood Mix',
                style: TextStyle(color: Colors.white,
                  fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(8)),
                child: const Text('AI',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 500.ms),

        // Instruction
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
          child: Text('Tap a mood to generate your mix',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 13)),
        ),

        // Mood bubbles
        SizedBox(
          height: 50,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _moods.length,
            itemBuilder: (context, index) {
              final mood = _moods[index];
              final colors = mood['colors'] as List<Color>;
              final isSelected = selectedMood == mood['label'];

              return GestureDetector(
                onTap: () => ref.read(
                  selectedMoodProvider.notifier)
                  .state = mood['label'] as String,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: isSelected
                      ? LinearGradient(colors: colors) : null,
                    color: isSelected
                      ? null
                      : Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: isSelected
                        ? Colors.transparent
                        : Colors.white.withOpacity(0.12)),
                    boxShadow: isSelected ? [
                      BoxShadow(
                        color: colors[0].withOpacity(0.4),
                        blurRadius: 12, spreadRadius: -3),
                    ] : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(mood['emoji'] as String,
                        style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Text(mood['label'] as String,
                        style: TextStyle(
                          color: isSelected
                            ? Colors.white
                            : Colors.white.withOpacity(0.5),
                          fontSize: 13,
                          fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w400)),
                    ],
                  ),
                ),
              ).animate()
                .fadeIn(duration: 300.ms,
                  delay: (index * 50).ms)
                .slideX(begin: 0.2, end: 0,
                  duration: 300.ms,
                  delay: (index * 50).ms);
            },
          ),
        ),

        const SizedBox(height: 14),

        // Generated mix
        if (selectedMood != null)
          mixAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator(
                color: AppTheme.pink, strokeWidth: 2))),
            error: (_, __) => const SizedBox.shrink(),
            data: (songs) => songs.isEmpty
              ? const SizedBox.shrink()
              : _MixResult(
                  songs: songs,
                  mood: selectedMood),
          ),
      ],
    );
  }
}

class _MixResult extends ConsumerWidget {
  final List<Song> songs;
  final String mood;

  const _MixResult({
    required this.songs,
    required this.mood,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.pink.withOpacity(0.12),
                  AppTheme.purple.withOpacity(0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              children: [
                // Mix header
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      ShaderMask(
                        shaderCallback: (b) =>
                          AppTheme.primaryGradient.createShader(b),
                        child: const Icon(
                          Icons.queue_music_rounded,
                          color: Colors.white, size: 22)),
                      const SizedBox(width: 8),
                      Text('$mood Mix • ${songs.length} songs',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                      const Spacer(),
                      // Play all
                      GestureDetector(
                        onTap: () {
                          playQueue(ref, songs, 0);
                          ref.read(databaseServiceProvider)
                            .addToHistory(songs[0]);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.pink.withOpacity(0.4),
                                blurRadius: 10, spreadRadius: -3),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.play_arrow_rounded,
                                color: Colors.white, size: 14),
                              SizedBox(width: 4),
                              Text('Play Mix',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Song list
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 8),
                  itemCount: songs.take(6).length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: Colors.white.withOpacity(0.05),
                    indent: 66, endIndent: 16),
                  itemBuilder: (context, index) {
                    final song = songs[index];
                    return ListTile(
                      contentPadding:
                        const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 2),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: CachedNetworkImage(
                          imageUrl: song.image,
                          width: 42, height: 42,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                            width: 42, height: 42,
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius:
                                BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      title: Text(song.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                      subtitle: Text(song.artist,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                      onTap: () {
                        playQueue(ref, songs, index);
                        ref.read(databaseServiceProvider)
                          .addToHistory(song);
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate()
      .fadeIn(duration: 400.ms)
      .slideY(begin: 0.1, end: 0,
        duration: 400.ms, curve: Curves.easeOutCubic);
  }
}