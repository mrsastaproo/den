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

    final isPlaying = ref.watch(isPlayingStreamProvider).value ?? false;

    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const FullPlayerSheet(),
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          // Purple gradient like in the image
          gradient: const LinearGradient(
            colors: [Color(0xFF6B35B8), Color(0xFF9B59D4)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6B35B8).withOpacity(0.5),
              blurRadius: 20, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            // Album art
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(
                imageUrl: currentSong.image,
                width: 44, height: 44, fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  width: 44, height: 44,
                  color: Colors.white24,
                  child: const Icon(Icons.music_note,
                    color: Colors.white, size: 20)),
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
                      fontWeight: FontWeight.w700, fontSize: 14),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(currentSong.artist,
                    style: const TextStyle(color: Colors.white70,
                      fontSize: 12),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            // Controls
            IconButton(
              icon: const Icon(Icons.skip_previous_rounded,
                color: Colors.white, size: 26),
              onPressed: () {},
            ),
            IconButton(
              icon: Icon(
                isPlaying
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
                color: Colors.white, size: 30),
              onPressed: () =>
                ref.read(playerServiceProvider).togglePlayPause(),
            ),
            IconButton(
              icon: const Icon(Icons.skip_next_rounded,
                color: Colors.white, size: 26),
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
  }
}

class FullPlayerSheet extends ConsumerWidget {
  const FullPlayerSheet({super.key});

  String _fmt(Duration d) {
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
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1A0533), Color(0xFF6B35B8), Color(0xFF9B59D4)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.white38,
              borderRadius: BorderRadius.circular(2)),
          ),

          // Top bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.keyboard_arrow_down_rounded,
                    color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
                const Text('Now Playing',
                  style: TextStyle(color: Colors.white,
                    fontSize: 16, fontWeight: FontWeight.w600)),
                IconButton(
                  icon: const Icon(Icons.more_vert_rounded,
                    color: Colors.white, size: 26),
                  onPressed: () {},
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Album art — large and centered like the image
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: CachedNetworkImage(
                  imageUrl: song.image,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF7B3FD4), Color(0xFFAB5FE8)])),
                    child: const Icon(Icons.music_note,
                      color: Colors.white54, size: 80)),
                ),
              ),
            ),
          ),

          const SizedBox(height: 28),

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
                          fontSize: 22, fontWeight: FontWeight.w800),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(song.artist,
                        style: const TextStyle(color: Colors.white70,
                          fontSize: 15),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.favorite_border_rounded,
                    color: Colors.white, size: 20),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Seek bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: Colors.white,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: Colors.white,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6),
                    overlayShape: SliderComponentShape.noOverlay,
                    trackHeight: 3,
                  ),
                  child: Slider(
                    value: position.inSeconds.toDouble()
                      .clamp(0, duration.inSeconds.toDouble()),
                    max: duration.inSeconds.toDouble() > 0
                      ? duration.inSeconds.toDouble() : 1,
                    onChanged: (v) => ref.read(playerServiceProvider)
                      .seekTo(Duration(seconds: v.toInt())),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_fmt(position),
                      style: const TextStyle(
                        color: Colors.white60, fontSize: 12)),
                    Text(_fmt(duration),
                      style: const TextStyle(
                        color: Colors.white60, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Controls — exactly like image
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.shuffle_rounded,
                  color: Colors.white60, size: 24),
                onPressed: () {},
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.skip_previous_rounded,
                  color: Colors.white, size: 44),
                onPressed: () {},
              ),
              const SizedBox(width: 8),
              // Big play button like in image
              GestureDetector(
                onTap: () =>
                  ref.read(playerServiceProvider).togglePlayPause(),
                child: Container(
                  width: 68, height: 68,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                    color: const Color(0xFF6B35B8), size: 38),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.skip_next_rounded,
                  color: Colors.white, size: 44),
                onPressed: () {},
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.repeat_rounded,
                  color: Colors.white60, size: 24),
                onPressed: () {},
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Bottom icons like image
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.share_rounded,
                  color: Colors.white60, size: 22),
                onPressed: () {},
              ),
              const SizedBox(width: 32),
              IconButton(
                icon: const Icon(Icons.favorite_rounded,
                  color: Colors.white60, size: 22),
                onPressed: () {},
              ),
              const SizedBox(width: 32),
              IconButton(
                icon: const Icon(Icons.shuffle_outlined,
                  color: Colors.white60, size: 22),
                onPressed: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }
}