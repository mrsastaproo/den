import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/providers/music_providers.dart';
import '../../core/services/player_service.dart';
import '../../core/theme/app_theme.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentSong = ref.watch(currentSongProvider);
    if (currentSong == null) return const SizedBox.shrink();

    final isPlaying = ref.watch(isPlayingStreamProvider).value ?? false;
    final position = ref.watch(positionStreamProvider).value ?? Duration.zero;
    final duration = ref.watch(durationStreamProvider).value ?? Duration.zero;
    final progress = duration.inSeconds > 0
      ? position.inSeconds / duration.inSeconds : 0.0;

    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const FullPlayerSheet(),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.12),
                    AppTheme.pink.withOpacity(0.08),
                    AppTheme.purple.withOpacity(0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withOpacity(0.15),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.pink.withOpacity(0.2),
                    blurRadius: 30,
                    spreadRadius: -5,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Progress bar
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24)),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      backgroundColor: Colors.white.withOpacity(0.1),
                      valueColor: AlwaysStoppedAnimation(
                        AppTheme.pink),
                      minHeight: 2,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        // Album art with glow
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.pink.withOpacity(0.3),
                                blurRadius: 12,
                                spreadRadius: -2,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CachedNetworkImage(
                              imageUrl: currentSong.image,
                              width: 46, height: 46,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => Container(
                                width: 46, height: 46,
                                decoration: BoxDecoration(
                                  gradient: AppTheme.primaryGradient,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.music_note,
                                  color: Colors.white, size: 20),
                              ),
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
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 2),
                              Text(currentSong.artist,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),

                        // Controls
                        _GlassIconButton(
                          icon: Icons.skip_previous_rounded,
                          size: 22,
                          onTap: () {},
                        ),
                        const SizedBox(width: 4),
                        _PlayPauseButton(
                          isPlaying: isPlaying,
                          onTap: () => ref.read(playerServiceProvider)
                            .togglePlayPause(),
                        ),
                        const SizedBox(width: 4),
                        _GlassIconButton(
                          icon: Icons.skip_next_rounded,
                          size: 22,
                          onTap: () {},
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ).animate()
      .fadeIn(duration: 400.ms)
      .slideY(begin: 0.3, end: 0,
        duration: 400.ms, curve: Curves.easeOutCubic);
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback onTap;

  const _GlassIconButton({
    required this.icon,
    required this.size,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(icon, color: Colors.white.withOpacity(0.7),
        size: size),
    );
  }
}

class _PlayPauseButton extends StatefulWidget {
  final bool isPlaying;
  final VoidCallback onTap;

  const _PlayPauseButton({
    required this.isPlaying,
    required this.onTap,
  });

  @override
  State<_PlayPauseButton> createState() => _PlayPauseButtonState();
}

class _PlayPauseButtonState extends State<_PlayPauseButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300));
    if (widget.isPlaying) _controller.forward();
  }

  @override
  void didUpdateWidget(_PlayPauseButton old) {
    super.didUpdateWidget(old);
    if (widget.isPlaying) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppTheme.pink.withOpacity(0.4),
              blurRadius: 12,
              spreadRadius: -2,
            ),
          ],
        ),
        child: AnimatedIcon(
          icon: AnimatedIcons.play_pause,
          progress: _controller,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }
}

// ─── FULL PLAYER SHEET ────────────────────────────────────────

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
      decoration: BoxDecoration(
        color: AppTheme.bgPrimary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Stack(
        children: [
          // Ambient orbs
          Positioned(
            top: -50, left: -50,
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppTheme.pink.withOpacity(0.15),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
          Positioned(
            bottom: 100, right: -50,
            child: Container(
              width: 250, height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppTheme.purple.withOpacity(0.12),
                  Colors.transparent,
                ]),
              ),
            ),
          ),

          // Content
          Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2)),
              ),

              // Top bar
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(Icons.keyboard_arrow_down_rounded,
                        color: Colors.white.withOpacity(0.7), size: 30),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Column(
                      children: [
                        Text('Now Playing',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 12,
                            fontWeight: FontWeight.w500)),
                      ],
                    ),
                    IconButton(
                      icon: Icon(Icons.more_horiz_rounded,
                        color: Colors.white.withOpacity(0.7), size: 26),
                      onPressed: () {},
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Album art
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.pink.withOpacity(0.3),
                          blurRadius: 50,
                          spreadRadius: -5,
                          offset: const Offset(0, 20),
                        ),
                        BoxShadow(
                          color: AppTheme.purple.withOpacity(0.2),
                          blurRadius: 30,
                          spreadRadius: -5,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: CachedNetworkImage(
                        imageUrl: song.image,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                          ),
                          child: const Icon(Icons.music_note,
                            color: Colors.white54, size: 80),
                        ),
                      ),
                    ),
                  ),
                ),
              ).animate()
                .scale(begin: const Offset(0.8, 0.8),
                  duration: 500.ms, curve: Curves.easeOutBack),

              const SizedBox(height: 28),

              // Song info + like
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
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Text(song.artist,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 15),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          AppTheme.pink.withOpacity(0.2),
                          AppTheme.purple.withOpacity(0.2),
                        ]),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.15)),
                      ),
                      child: Icon(Icons.favorite_border_rounded,
                        color: AppTheme.pink, size: 20),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.1),

              const SizedBox(height: 28),

              // Seek bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: AppTheme.pink,
                        inactiveTrackColor:
                          Colors.white.withOpacity(0.1),
                        thumbColor: Colors.white,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 5),
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
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 12)),
                        Text(_fmt(duration),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Controls
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(Icons.shuffle_rounded,
                      color: Colors.white.withOpacity(0.4), size: 22),

                    Icon(Icons.skip_previous_rounded,
                      color: Colors.white, size: 44),

                    // Big play button
                    GestureDetector(
                      onTap: () => ref.read(playerServiceProvider)
                        .togglePlayPause(),
                      child: Container(
                        width: 70, height: 70,
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.pink.withOpacity(0.5),
                              blurRadius: 30,
                              spreadRadius: -5,
                            ),
                            BoxShadow(
                              color: AppTheme.purple.withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: -5,
                            ),
                          ],
                        ),
                        child: Icon(
                          isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                          color: Colors.white, size: 36),
                      ),
                    ).animate(target: isPlaying ? 1 : 0)
                      .scale(begin: const Offset(1,1),
                        end: const Offset(1.05, 1.05),
                        duration: 200.ms),

                    Icon(Icons.skip_next_rounded,
                      color: Colors.white, size: 44),

                    Icon(Icons.repeat_rounded,
                      color: Colors.white.withOpacity(0.4), size: 22),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}