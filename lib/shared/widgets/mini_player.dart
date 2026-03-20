import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/providers/music_providers.dart';
import '../../core/services/player_service.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentSong = ref.watch(currentSongProvider);
    if (currentSong == null) return const SizedBox.shrink();

    final isPlayingAsync = ref.watch(isPlayingStreamProvider);
    final positionAsync = ref.watch(positionStreamProvider);
    final durationAsync = ref.watch(durationStreamProvider);

    final isPlaying = isPlayingAsync.value ?? false;
    final position = positionAsync.value ?? Duration.zero;
    final duration = durationAsync.value ?? Duration.zero;
    final progress = duration.inSeconds > 0
        ? position.inSeconds / duration.inSeconds
        : 0.0;

    return GestureDetector(
      onTap: () => _showFullPlayer(context, ref),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Progress bar
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                backgroundColor: const Color(0xFF2A2A2A),
                valueColor: const AlwaysStoppedAnimation(Color(0xFFE8383D)),
                minHeight: 2,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  // Album art
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: currentSong.image,
                      width: 44, height: 44, fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        width: 44, height: 44,
                        color: const Color(0xFF2A2A2A),
                        child: const Icon(Icons.music_note,
                          color: Color(0xFF6B6B6B), size: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Song info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(currentSong.title,
                          style: const TextStyle(color: Colors.white,
                            fontWeight: FontWeight.w600, fontSize: 14),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(currentSong.artist,
                          style: const TextStyle(color: Color(0xFFB3B3B3),
                            fontSize: 12),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  // Play/Pause
                  IconButton(
                    icon: Icon(
                      isPlaying
                        ? Icons.pause_circle_filled_rounded
                        : Icons.play_circle_filled_rounded,
                      color: const Color(0xFFE8383D), size: 40,
                    ),
                    onPressed: () {
                      ref.read(playerServiceProvider).togglePlayPause();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFullPlayer(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const FullPlayerSheet(),
    );
  }
}

class FullPlayerSheet extends ConsumerWidget {
  const FullPlayerSheet({super.key});

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final song = ref.watch(currentSongProvider);
    if (song == null) return const SizedBox.shrink();

    final isPlaying = ref.watch(isPlayingStreamProvider).value ?? false;
    final position = ref.watch(positionStreamProvider).value ?? Duration.zero;
    final duration = ref.watch(durationStreamProvider).value ?? Duration.zero;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Color(0xFF0A0A0A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF3A3A3A),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 32),
          // Album art
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: CachedNetworkImage(
                  imageUrl: song.image,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(
                    color: const Color(0xFF1E1E1E),
                    child: const Icon(Icons.music_note,
                      color: Color(0xFF6B6B6B), size: 80),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          // Song info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(song.title,
                        style: const TextStyle(color: Colors.white,
                          fontSize: 22, fontWeight: FontWeight.w700),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(song.artist,
                        style: const TextStyle(color: Color(0xFFB3B3B3),
                          fontSize: 16),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                const Icon(Icons.favorite_border_rounded,
                  color: Color(0xFFB3B3B3), size: 28),
              ],
            ),
          ),
          const SizedBox(height: 32),
          // Seek bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: const Color(0xFFE8383D),
                    inactiveTrackColor: const Color(0xFF2A2A2A),
                    thumbColor: const Color(0xFFE8383D),
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: SliderComponentShape.noOverlay,
                    trackHeight: 3,
                  ),
                  child: Slider(
                    value: position.inSeconds.toDouble()
                      .clamp(0, duration.inSeconds.toDouble()),
                    max: duration.inSeconds.toDouble() > 0
                      ? duration.inSeconds.toDouble() : 1,
                    onChanged: (v) {
                      ref.read(playerServiceProvider)
                        .seekTo(Duration(seconds: v.toInt()));
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_formatDuration(position),
                      style: const TextStyle(color: Color(0xFF6B6B6B),
                        fontSize: 12)),
                    Text(_formatDuration(duration),
                      style: const TextStyle(color: Color(0xFF6B6B6B),
                        fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.shuffle_rounded,
                  color: Color(0xFFB3B3B3), size: 26),
                onPressed: () {},
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.skip_previous_rounded,
                  color: Colors.white, size: 42),
                onPressed: () {},
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () =>
                  ref.read(playerServiceProvider).togglePlayPause(),
                child: Container(
                  width: 70, height: 70,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE8383D),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                    color: Colors.white, size: 40,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.skip_next_rounded,
                  color: Colors.white, size: 42),
                onPressed: () {},
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.repeat_rounded,
                  color: Color(0xFFB3B3B3), size: 26),
                onPressed: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }
}