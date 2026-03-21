import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/providers/music_providers.dart';
import '../../core/services/player_service.dart';
import '../../core/providers/queue_meta.dart';
import '../../core/theme/app_theme.dart';
import 'player_screen.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentSong = ref.watch(currentSongProvider);
    if (currentSong == null) return const SizedBox.shrink();

    final isPlaying =
        ref.watch(isPlayingStreamProvider).value ?? false;
    final position =
        ref.watch(positionStreamProvider).value ?? Duration.zero;
    final duration =
        ref.watch(durationStreamProvider).value ?? Duration.zero;
    final double progress = duration.inSeconds > 0
        ? (position.inSeconds / duration.inSeconds)
            .clamp(0.0, 1.0)
        : 0.0;

    // Skip helpers
    void skipNext() {
      final playlist = ref.read(currentPlaylistProvider);
      final index = ref.read(currentSongIndexProvider);
      if (playlist.isEmpty || index < 0) return;
      final nextIndex = (index + 1) % playlist.length;
      final nextSong = playlist[nextIndex];
      ref.read(currentSongIndexProvider.notifier).state =
          nextIndex;
      ref.read(currentSongProvider.notifier).state = nextSong;
      ref.read(playerServiceProvider).playSong(nextSong);
      HapticFeedback.selectionClick();
    }

    void skipPrev() {
      final pos =
          ref.read(positionStreamProvider).value ?? Duration.zero;
      if (pos.inSeconds > 3) {
        ref
            .read(playerServiceProvider)
            .seekTo(Duration.zero);
        return;
      }
      final playlist = ref.read(currentPlaylistProvider);
      final index = ref.read(currentSongIndexProvider);
      if (playlist.isEmpty || index < 0) return;
      final prevIndex =
          index - 1 < 0 ? playlist.length - 1 : index - 1;
      final prevSong = playlist[prevIndex];
      ref.read(currentSongIndexProvider.notifier).state =
          prevIndex;
      ref.read(currentSongProvider.notifier).state = prevSong;
      ref.read(playerServiceProvider).playSong(prevSong);
      HapticFeedback.selectionClick();
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (_, animation, __) =>
                const PlayerScreen(),
            transitionsBuilder:
                (_, animation, __, child) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 1),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                )),
                child: child,
              );
            },
            transitionDuration:
                const Duration(milliseconds: 400),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter:
                ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.12),
                    AppTheme.pink.withOpacity(0.08),
                    AppTheme.purple.withOpacity(0.10),
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
                      value: progress,
                      backgroundColor:
                          Colors.white.withOpacity(0.1),
                      valueColor: const AlwaysStoppedAnimation(
                          AppTheme.pink),
                      minHeight: 2,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        // Album art
                        Container(
                          decoration: BoxDecoration(
                            borderRadius:
                                BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.pink
                                    .withOpacity(0.3),
                                blurRadius: 12,
                                spreadRadius: -2,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius:
                                BorderRadius.circular(12),
                            child: CachedNetworkImage(
                              imageUrl: currentSong.image,
                              width: 46,
                              height: 46,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) =>
                                  Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  gradient:
                                      AppTheme.primaryGradient,
                                  borderRadius:
                                      BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                    Icons.music_note,
                                    color: Colors.white,
                                    size: 20),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 12),

                        // Song info
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                currentSong.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow:
                                    TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                currentSong.artist,
                                style: TextStyle(
                                  color: Colors.white
                                      .withOpacity(0.5),
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow:
                                    TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),

                        // Skip Prev (now working!)
                        _MiniIconBtn(
                          icon:
                              Icons.skip_previous_rounded,
                          size: 22,
                          onTap: skipPrev,
                        ),
                        const SizedBox(width: 4),

                        // Play/Pause
                        _MiniPlayPauseBtn(
                          isPlaying: isPlaying,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            ref
                                .read(playerServiceProvider)
                                .togglePlayPause();
                          },
                        ),
                        const SizedBox(width: 4),

                        // Skip Next (now working!)
                        _MiniIconBtn(
                          icon: Icons.skip_next_rounded,
                          size: 22,
                          onTap: skipNext,
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
    )
        .animate()
        .fadeIn(duration: 400.ms)
        .slideY(
          begin: 0.3,
          end: 0,
          duration: 400.ms,
          curve: Curves.easeOutCubic,
        );
  }
}

// ─── MINI ICON BUTTON ─────────────────────────────────────────

class _MiniIconBtn extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback onTap;

  const _MiniIconBtn({
    required this.icon,
    required this.size,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(
          icon,
          color: Colors.white.withOpacity(0.7),
          size: size,
        ),
      ),
    );
  }
}

// ─── MINI PLAY/PAUSE BUTTON ───────────────────────────────────

class _MiniPlayPauseBtn extends StatefulWidget {
  final bool isPlaying;
  final VoidCallback onTap;

  const _MiniPlayPauseBtn({
    required this.isPlaying,
    required this.onTap,
  });

  @override
  State<_MiniPlayPauseBtn> createState() =>
      _MiniPlayPauseBtnState();
}

class _MiniPlayPauseBtnState extends State<_MiniPlayPauseBtn>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    if (widget.isPlaying) _ctrl.forward();
  }

  @override
  void didUpdateWidget(_MiniPlayPauseBtn old) {
    super.didUpdateWidget(old);
    widget.isPlaying ? _ctrl.forward() : _ctrl.reverse();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: 38,
        height: 38,
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
        child: Center(
          child: AnimatedIcon(
            icon: AnimatedIcons.play_pause,
            progress: _ctrl,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }
}