import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/providers/music_providers.dart';
import '../../core/services/player_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models/song.dart';

// ─────────────────────────────────────────────────────────────
// DEN DYNAMIC ISLAND
// Works on every Android phone — notch, punch-hole, flat top
// Uses SafeArea padding so it never overlaps the camera
// ─────────────────────────────────────────────────────────────

class DynamicIsland extends ConsumerStatefulWidget {
  const DynamicIsland({super.key});
  @override
  ConsumerState<DynamicIsland> createState() => _DynamicIslandState();
}

class _DynamicIslandState extends ConsumerState<DynamicIsland>
    with TickerProviderStateMixin {

  bool _expanded = false;

  late AnimationController _waveCtrl;
  late AnimationController _spinCtrl;

  @override
  void initState() {
    super.initState();
    _waveCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
    _spinCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 8))
      ..repeat();
  }

  @override
  void dispose() {
    _waveCtrl.dispose();
    _spinCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final song         = ref.watch(currentSongProvider);
    final isPlaying    = ref.watch(isPlayingProvider);
    final isPlayerOpen = ref.watch(playerScreenOpenProvider);
    final position     = ref.watch(positionStreamProvider).value
        ?? Duration.zero;
    final duration     = ref.watch(durationStreamProvider).value
        ?? Duration.zero;

    // Hide when no song or player screen is open
    if (song == null || isPlayerOpen) {
      if (_expanded) setState(() => _expanded = false);
      return const SizedBox.shrink();
    }

    // Sync spin/wave to play state
    if (isPlaying) {
      if (!_waveCtrl.isAnimating) _waveCtrl.repeat();
      if (!_spinCtrl.isAnimating) _spinCtrl.repeat();
    } else {
      if (_waveCtrl.isAnimating) _waveCtrl.stop();
      if (_spinCtrl.isAnimating) _spinCtrl.stop();
    }

    final progress = duration.inMilliseconds > 0
        ? (position.inMilliseconds / duration.inMilliseconds)
            .clamp(0.0, 1.0)
        : 0.0;

    final topPad = MediaQuery.of(context).padding.top;
    final screenW = MediaQuery.of(context).size.width;
    const hMargin = 14.0;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Center(
        child: GestureDetector(
          onTap: () {
            setState(() => _expanded = !_expanded);
            HapticFeedback.lightImpact();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            curve: _expanded ? Curves.easeOutBack : Curves.easeOutCubic,
            margin: EdgeInsets.only(
              top: 6,
              left: _expanded ? hMargin : (screenW / 2) - 105,
              right: _expanded ? hMargin : (screenW / 2) - 105,
            ),
            padding: EdgeInsets.only(top: topPad > 0 ? topPad - 4 : 0),
            height: _expanded ? 110 : 40 + (topPad > 0 ? topPad - 4 : 0),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.95),
              borderRadius: BorderRadius.circular(_expanded ? 28 : 100),
              border: Border.all(
                color: isPlaying
                    ? AppTheme.pink.withOpacity(0.4)
                    : Colors.white.withOpacity(0.1),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.6),
                  blurRadius: 24,
                  spreadRadius: -2,
                  offset: const Offset(0, 10),
                ),
                if (isPlaying)
                  BoxShadow(
                    color: AppTheme.pink.withOpacity(0.25),
                    blurRadius: 30,
                    spreadRadius: -6,
                  ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_expanded ? 28 : 100),
              child: Stack(
                children: [
                  // Glassmorphism reflection
                  Positioned(
                    top: -20, left: -20,
                    child: Container(
                      width: 100, height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.white.withOpacity(0.08),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Main content
                  Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: _expanded ? 16 : 12),
                    child: _expanded
                        ? _ExpandedView(
                            song: song,
                            isPlaying: isPlaying,
                            progress: progress,
                            position: position,
                            duration: duration,
                          )
                        : _CollapsedView(
                            song: song,
                            isPlaying: isPlaying,
                            waveCtrl: _waveCtrl,
                            spinCtrl: _spinCtrl,
                          ),
                  ),

                  // Progress line at bottom of collapsed pill
                  if (!_expanded && progress > 0)
                    Positioned(
                      bottom: 1, left: 20, right: 20,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(100),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 2.2,
                          backgroundColor: Colors.white.withOpacity(0.08),
                          valueColor: AlwaysStoppedAnimation(
                              AppTheme.pink.withOpacity(0.85)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// COLLAPSED
// ─────────────────────────────────────────────────────────────

class _CollapsedView extends StatelessWidget {
  final Song song;
  final bool isPlaying;
  final AnimationController waveCtrl;
  final AnimationController spinCtrl;

  const _CollapsedView({
    required this.song,
    required this.isPlaying,
    required this.waveCtrl,
    required this.spinCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Art (Left)
        AnimatedBuilder(
          animation: spinCtrl,
          builder: (_, child) => Transform.rotate(
            angle: isPlaying ? spinCtrl.value * 2 * math.pi : 0,
            child: child,
          ),
          child: Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.pink.withOpacity(0.4),
                  blurRadius: 10,
                  spreadRadius: -2,
                ),
              ],
            ),
            child: ClipOval(
              child: CachedNetworkImage(memCacheWidth: 400, 
                imageUrl: song.image,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  decoration: const BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.music_note,
                      color: Colors.white, size: 14),
                ),
              ),
            ),
          ),
        ),

        // Title (Center)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              song.title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
              ),
            ),
          ),
        ),

        // Waveform (Right)
        SizedBox(
          width: 26,
          child: AnimatedBuilder(
            animation: waveCtrl,
            builder: (_, __) => Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: List.generate(4, (i) {
                final wave = math.sin(
                    (waveCtrl.value * 2 * math.pi) + i * 1.5);
                final h = isPlaying
                    ? (4.0 + (10.0 * ((wave + 1) / 2)))
                        .clamp(3.0, 14.0)
                    : 4.0;
                return Container(
                  width: 3.0,
                  height: h,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.pink, AppTheme.purple],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// EXPANDED
// ─────────────────────────────────────────────────────────────

class _ExpandedView extends ConsumerWidget {
  final Song song;
  final bool isPlaying;
  final double progress;
  final Duration position;
  final Duration duration;

  const _ExpandedView({
    required this.song,
    required this.isPlaying,
    required this.progress,
    required this.position,
    required this.duration,
  });

  String _fmt(Duration d) {
    if (d.inSeconds <= 0) return '0:00';
    return '${d.inMinutes.remainder(60)}:'
        '${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.read(playerServiceProvider);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 10),
        Expanded(
          child: Row(
            children: [
              // Art
              Container(
                width: 58, height: 58,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.pink.withOpacity(0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CachedNetworkImage(memCacheWidth: 400, 
                    imageUrl: song.image,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                      decoration: const BoxDecoration(
                          gradient: AppTheme.primaryGradient),
                      child: const Icon(Icons.music_note,
                          color: Colors.white, size: 28),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 14),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(song.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.55),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 6),

              // Controls
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Btn(icon: Icons.skip_previous_rounded,
                      onTap: player.skipPrev),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () {
                      player.togglePlayPause();
                      HapticFeedback.mediumImpact();
                    },
                    child: Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppTheme.primaryGradient,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.pink.withOpacity(0.4),
                            blurRadius: 16,
                            spreadRadius: -4,
                          ),
                        ],
                      ),
                      child: Icon(
                        isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  _Btn(icon: Icons.skip_next_rounded,
                      onTap: player.skipNext),
                ],
              ),
            ],
          ),
        ),

        // Progress
        Padding(
          padding: const EdgeInsets.only(bottom: 12, top: 4),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(100),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  backgroundColor: Colors.white.withOpacity(0.12),
                  valueColor:
                      const AlwaysStoppedAnimation(AppTheme.pink),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  Text(_fmt(position),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 10, fontWeight: FontWeight.w700)),
                  Text(_fmt(duration),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 10, fontWeight: FontWeight.w700)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SMALL BUTTON
// ─────────────────────────────────────────────────────────────

class _Btn extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _Btn({required this.icon, required this.onTap});
  @override
  State<_Btn> createState() => _BtnState();
}

class _BtnState extends State<_Btn> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   (_) => setState(() => _pressed = true),
      onTapUp:     (_) {
        setState(() => _pressed = false);
        widget.onTap();
        HapticFeedback.selectionClick();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.78 : 1.0,
        duration: const Duration(milliseconds: 80),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(widget.icon,
              color: Colors.white.withOpacity(0.75), size: 22),
        ),
      ),
    );
  }
}