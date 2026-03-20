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

// ─── FULL PLAYER SHEET ────────────────────────────────────────

class FullPlayerSheet extends ConsumerStatefulWidget {
  const FullPlayerSheet({super.key});

  @override
  ConsumerState<FullPlayerSheet> createState() => _FullPlayerSheetState();
}

class _FullPlayerSheetState extends ConsumerState<FullPlayerSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _spinController;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
        vsync: this, duration: const Duration(seconds: 20));
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  void _skipNext() {
    final playlist = ref.read(currentPlaylistProvider);
    final index = ref.read(currentSongIndexProvider);
    if (playlist.isEmpty || index < 0) return;

    final nextIndex = (index + 1) % playlist.length;
    final nextSong = playlist[nextIndex];
    ref.read(currentSongIndexProvider.notifier).state = nextIndex;
    ref.read(currentSongProvider.notifier).state = nextSong;
    ref.read(playerServiceProvider).playSong(nextSong);
  }

  void _skipPrev() {
    final playlist = ref.read(currentPlaylistProvider);
    final index = ref.read(currentSongIndexProvider);
    if (playlist.isEmpty || index < 0) return;

    final prevIndex = (index - 1 < 0) ? playlist.length - 1 : index - 1;
    final prevSong = playlist[prevIndex];
    ref.read(currentSongIndexProvider.notifier).state = prevIndex;
    ref.read(currentSongProvider.notifier).state = prevSong;
    ref.read(playerServiceProvider).playSong(prevSong);
  }

  String _fmt(Duration d) {
    if (d.inSeconds < 0) return '0:00';
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final song = ref.watch(currentSongProvider);
    if (song == null) return const SizedBox.shrink();

    final isPlaying = ref.watch(isPlayingStreamProvider).value ?? false;
    final position = ref.watch(positionStreamProvider).value ?? Duration.zero;
    final duration = ref.watch(durationStreamProvider).value ?? Duration.zero;
    final progress = duration.inSeconds > 0
        ? position.inSeconds / duration.inSeconds
        : 0.0;

    if (isPlaying && !_spinController.isAnimating) {
      _spinController.repeat();
    } else if (!isPlaying && _spinController.isAnimating) {
      _spinController.stop();
    }

    return Container(
      height: MediaQuery.of(context).size.height,
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Ambient Background (Heavily blurred artwork)
          CachedNetworkImage(
            imageUrl: song.image,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => Container(color: Colors.black),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withOpacity(0.5),
                      Colors.black.withOpacity(0.2),
                      Colors.black.withOpacity(0.8),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
          ),

          // 2. Foreground Elements
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 10),
                // Header: Down Arrow, Handle, 3-dots
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.keyboard_arrow_down_rounded,
                            color: Colors.white, size: 30),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.more_vert_rounded,
                            color: Colors.white, size: 26),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Title & Artist
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              song.title,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 34,
                                  fontWeight: FontWeight.w400,
                                  letterSpacing: -1),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              song.artist,
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w400),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Icon(Icons.favorite_border_rounded,
                            color: Colors.white.withOpacity(0.9), size: 28),
                      ),
                    ],
                  ),
                ),

                // Centerpiece: Circular Artwork + Progress Ring
                Expanded(
                  child: Center(
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width,
                      height: 380,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Previous/Next fake artwork hints for CoverFlow effect
                          Positioned(
                            left: -180,
                            child: _FadedSideArt(imageUrl: song.image),
                          ),
                          Positioned(
                            right: -180,
                            child: _FadedSideArt(imageUrl: song.image),
                          ),

                          // The Outer Glass Ring & Progress Line
                          SizedBox(
                            width: 280,
                            height: 280,
                            child: CustomPaint(
                              painter: _CircularProgressRingPainter(
                                progress: progress.clamp(0.0, 1.0),
                                gradient: AppTheme.primaryGradient,
                              ),
                            ),
                          ),

                          // The Time Text at the bottom of the ring
                          Positioned(
                            bottom: 38,
                            child: Container(
                              color: Colors.transparent, // to match background if needed, but it sits over the gap
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                _fmt(position),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),

                          // The Rotating Center Artwork
                          GestureDetector(
                            onHorizontalDragEnd: (details) {
                              if (details.primaryVelocity! < 0) {
                                // Swiped Left -> Next Song
                                _skipNext();
                              } else if (details.primaryVelocity! > 0) {
                                // Swiped Right -> Previous Song
                                _skipPrev();
                              }
                            },
                            child: RotationTransition(
                              turns: _spinController,
                              child: Container(
                                width: 220,
                                height: 220,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.4),
                                      blurRadius: 30,
                                      spreadRadius: 5,
                                    )
                                  ],
                                ),
                                child: ClipOval(
                                  child: CachedNetworkImage(
                                    imageUrl: song.image,
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) => Container(
                                      color: Colors.white10,
                                      child: const Center(
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    errorWidget: (_, __, ___) => Container(
                                      color: Colors.white10,
                                      child: const Icon(Icons.music_note,
                                          size: 60, color: Colors.white54),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Controls
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 0, 32, 40),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(Icons.shuffle_rounded,
                          color: Colors.white.withOpacity(0.7), size: 24),
                      GestureDetector(
                        onTap: () => _skipPrev(),
                        behavior: HitTestBehavior.opaque,
                        child: const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Icon(Icons.skip_previous_rounded,
                              color: Colors.white, size: 36),
                        ),
                      ),
                      
                      // Minimalist Play/Pause
                      GestureDetector(
                        onTap: () => ref
                            .read(playerServiceProvider)
                            .togglePlayPause(),
                        child: Container(
                          width: 60,
                          height: 60,
                          alignment: Alignment.center,
                          child: Icon(
                            isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                      ).animate(target: isPlaying ? 1 : 0).scale(
                            begin: const Offset(1, 1),
                            end: const Offset(1.1, 1.1),
                            duration: 200.ms,
                          ),

                      GestureDetector(
                        onTap: () => _skipNext(),
                        behavior: HitTestBehavior.opaque,
                        child: const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Icon(Icons.skip_next_rounded,
                              color: Colors.white, size: 36),
                        ),
                      ),
                      Icon(Icons.repeat_rounded,
                          color: Colors.white.withOpacity(0.7), size: 24),
                    ],
                  ),
                ),
                
                // Extra space for the floating bottom shell
                const SizedBox(height: 70),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(
        begin: 0.2, end: 0, duration: 400.ms, curve: Curves.easeOutCubic);
  }
}

class _FadedSideArt extends StatelessWidget {
  final String imageUrl;
  const _FadedSideArt({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      height: 200,
      decoration: const BoxDecoration(shape: BoxShape.circle),
      child: ClipOval(
        child: ColorFiltered(
          colorFilter:
              ColorFilter.mode(Colors.black.withOpacity(0.6), BlendMode.darken),
          child: BackdropFilter(
  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
  child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }
}

class _CircularProgressRingPainter extends CustomPainter {
  final double progress;
  final Gradient gradient;

  _CircularProgressRingPainter({
    required this.progress,
    required this.gradient,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    
    // We leave a gap at the bottom for the text. Wait, a 15% angular gap at bottom.
    // Bottom is at pi/2 rads (90 deg). Start angle = pi/2 + gapAngle, sweep = 2*pi - 2*gapAngle.
    const gapAngle = 0.3; // radians roughly 17 degrees
    const startAngle = (3 * 3.14159 / 2) + gapAngle; // start from bottom right and go clockwise?
    // In Flutter, 0 is right, pi/2 is bottom, pi is left, 3*pi/2 is top.
    // Start drawing from bottom-gap, sweep clockwise
    const realStart = (3.14159 / 2) + gapAngle;
    const maxSweep = (2 * 3.14159) - (gapAngle * 2);

    final rect = Rect.fromCircle(center: center, radius: radius);

    // 1. Draw the glassy background track
    final trackPaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
      
    canvas.drawArc(rect, realStart, maxSweep, false, trackPaint);

    // 2. Draw the inner gradient progress track
    // If progress is 0, draw nothing for progress
    if (progress > 0) {
      final sweepAngle = maxSweep * progress;
      final progressPaint = Paint()
        ..shader = gradient.createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round;
        
      canvas.drawArc(rect, realStart, sweepAngle, false, progressPaint);
    }
    
    // 3. Draw a thicker glass outer casing (optional) to make it look like a lens
    final lensRimPaint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 15.0;
      
    // The lens rim doesn't have a gap
    canvas.drawCircle(center, radius + 10, lensRimPaint);
  }

  @override
  bool shouldRepaint(_CircularProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.gradient != gradient;
  }
}