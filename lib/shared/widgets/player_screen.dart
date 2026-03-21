import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:palette_generator/palette_generator.dart';
import '../../core/providers/music_providers.dart';
import '../../core/services/player_service.dart';
import '../../core/providers/queue_meta.dart';
import '../../core/services/database_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models/song.dart';

// ─── PROVIDERS ───────────────────────────────────────────────

final _playerLikedProvider =
    StateProvider.family<bool, String>((ref, id) => false);

final _paletteProvider = StateProvider<List<Color>>((ref) =>
    [const Color(0xFF1A0A1E), const Color(0xFF0D0D1A)]);

// ─── PLAYER SCREEN ───────────────────────────────────────────

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key});
  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen>
    with TickerProviderStateMixin {

  late AnimationController _vinyl;
  late AnimationController _bgPulse;
  late PageController _pc;

  bool _dragging = false;
  double _dragVal = 0.0;
  bool _showQueue = false;
  String? _lastImg;
  bool _pcReady = false;    // ← guard so we don't jump before layout

  @override
  void initState() {
    super.initState();

    _vinyl = AnimationController(
        vsync: this, duration: const Duration(seconds: 20));

    _bgPulse = AnimationController(
        vsync: this, duration: const Duration(seconds: 5))
      ..repeat(reverse: true);

    final initIdx = ref.read(currentSongIndexProvider).clamp(0, 999999);
    _pc = PageController(initialPage: initIdx, viewportFraction: 0.80);

    // ── KEY FIX: jump to correct page after layout so
    // the PageView has real dimensions and swipe works immediately ──
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final idx = ref.read(currentSongIndexProvider).clamp(0, 999999);
      if (_pc.hasClients && (_pc.page?.round() ?? -1) != idx) {
        _pc.jumpToPage(idx);
      }
      setState(() => _pcReady = true);

      if (ref.read(isPlayingStreamProvider).value == true) {
        _vinyl.repeat();
      }
      final song = ref.read(currentSongProvider);
      if (song != null) _extractPalette(song.image);
    });
  }

  @override
  void dispose() {
    _vinyl.dispose();
    _bgPulse.dispose();
    _pc.dispose();
    super.dispose();
  }

  Future<void> _extractPalette(String url) async {
    if (url == _lastImg || url.isEmpty) return;
    _lastImg = url;
    try {
      final pg = await PaletteGenerator.fromImageProvider(
        NetworkImage(url), size: const Size(80, 80));
      final c1 = pg.dominantColor?.color ??
          pg.vibrantColor?.color ?? const Color(0xFF1A0A1E);
      final c2 = pg.darkMutedColor?.color ??
          pg.mutedColor?.color ?? const Color(0xFF0D0D1A);
      if (mounted) {
        ref.read(_paletteProvider.notifier).state = [
          Color.lerp(c1, Colors.black, 0.35)!,
          Color.lerp(c2, Colors.black, 0.55)!,
        ];
      }
    } catch (_) {}
  }

  String _fmt(Duration d) {
    if (d.inSeconds <= 0) return '0:00';
    return '${d.inMinutes.remainder(60)}:${d.inSeconds.remainder(60).toString().padLeft(2,'0')}';
  }

  void _onPageSwipe(int idx) {
    final pl = ref.read(currentPlaylistProvider);
    if (idx < 0 || idx >= pl.length) return;
    final song = pl[idx];
    ref.read(currentSongIndexProvider.notifier).state = idx;
    ref.read(currentSongProvider.notifier).state = song;
    ref.read(playerServiceProvider).playSong(song);
    _extractPalette(song.image);
    HapticFeedback.lightImpact();
  }

  // Sync page controller when external skip happens (e.g. autoplay)
  void _syncPage(int idx) {
    if (!_pcReady || !_pc.hasClients || _dragging) return;
    final curPage = _pc.page?.round() ?? idx;
    if (curPage != idx) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pc.hasClients) {
          _pc.animateToPage(idx,
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final song       = ref.watch(currentSongProvider);
    if (song == null) return const SizedBox.shrink();

    final isPlaying  = ref.watch(isPlayingStreamProvider).value ?? false;
    final position   = ref.watch(positionStreamProvider).value  ?? Duration.zero;
    final duration   = ref.watch(durationStreamProvider).value  ?? Duration.zero;
    final playlist   = ref.watch(currentPlaylistProvider);
    final curIdx     = ref.watch(currentSongIndexProvider);
    final repeat     = ref.watch(repeatModeProvider);
    final shuffle    = ref.watch(isShuffleProvider);
    final liked      = ref.watch(_playerLikedProvider(song.id));
    final palette    = ref.watch(_paletteProvider);

    // Palette + vinyl sync
    if (song.image != _lastImg) {
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => _extractPalette(song.image));
    }
    if (isPlaying  && !_vinyl.isAnimating) _vinyl.repeat();
    if (!isPlaying &&  _vinyl.isAnimating) _vinyl.stop();

    // Sync page to external skips (autoplay)
    _syncPage(curIdx);

    final double seekVal = _dragging
        ? _dragVal
        : position.inSeconds.toDouble()
            .clamp(0.0, duration.inSeconds.toDouble().clamp(1.0, double.infinity));

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(fit: StackFit.expand, children: [

          // ── Dynamic Gradient BG (palette-extracted) ──────
          AnimatedContainer(
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [palette[0], palette[1], Colors.black],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),

          // ── Blurred art ambient ───────────────────────────
          if (song.image.isNotEmpty)
            Opacity(
              opacity: 0.12,
              child: CachedNetworkImage(
                imageUrl: song.image,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
            child: Container(color: Colors.transparent)),
          Container(color: Colors.black.withOpacity(0.5)),

          // ── Pulsing glow at bottom ────────────────────────
          AnimatedBuilder(
            animation: _bgPulse,
            builder: (_, __) => Positioned(
              bottom: -60, left: 0, right: 0,
              child: Container(height: 280,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      AppTheme.pink.withOpacity(0.06 + 0.03 * _bgPulse.value),
                      Colors.transparent,
                    ],
                    radius: 1.3,
                  ),
                ),
              ),
            ),
          ),

          // ── Main Content ──────────────────────────────────
          SafeArea(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              child: _showQueue
                ? _QueuePanel(
                    key: const ValueKey('queue'),
                    playlist: playlist,
                    currentIndex: curIdx,
                    onClose: () => setState(() => _showQueue = false),
                    onSongTap: (idx) {
                      setState(() => _showQueue = false);
                      _onPageSwipe(idx);
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (_pc.hasClients) {
                          _pc.animateToPage(idx,
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeOutCubic);
                        }
                      });
                    },
                  )
                : Column(
                    key: const ValueKey('player'),
                    children: [

                      // Header
                      _PlayerHeader(
                        album: song.album.isNotEmpty ? song.album : 'DEN',
                        onClose: () => Navigator.of(context).pop(),
                        onMore: () => _showOptionsSheet(context, song),
                      ),

                      // Artwork carousel
                      Expanded(
                        flex: 5,
                        child: PageView.builder(
                          controller: _pc,
                          itemCount: playlist.length,
                          onPageChanged: _onPageSwipe,   // ← direct, no wrapper
                          physics: const BouncingScrollPhysics(),
                          itemBuilder: (_, i) {
                            final s = playlist[i];
                            final isActive = i == curIdx;
                            return AnimatedBuilder(
                              animation: _pc,
                              builder: (_, child) {
                                double scale = 0.86, op = 0.5;
                                if (_pc.position.haveDimensions) {
                                  final diff = (_pc.page! - i).abs();
                                  scale = (1.0 - diff * 0.14).clamp(0.86, 1.0);
                                  op    = (1.0 - diff * 0.5 ).clamp(0.5,  1.0);
                                } else if (isActive) { scale = 1.0; op = 1.0; }
                                return Transform.scale(
                                  scale: scale,
                                  child: Opacity(opacity: op, child: child));
                              },
                              child: _VinylDisc(
                                song: s,
                                isActive: isActive,
                                isPlaying: isPlaying && isActive,
                                vinylController: isActive ? _vinyl : null,
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Song info + like
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Row(children: [
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(song.title,
                                style: const TextStyle(
                                  color: Colors.white, fontSize: 21,
                                  fontWeight: FontWeight.w800, letterSpacing: -0.5,
                                  height: 1.1),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 4),
                              Text(song.artist,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 14, fontWeight: FontWeight.w500),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          )),
                          _LikeButton(
                            isLiked: liked,
                            onTap: () async {
                              HapticFeedback.lightImpact();
                              final nv = !liked;
                              ref.read(_playerLikedProvider(song.id).notifier).state = nv;
                              if (nv) await ref.read(databaseServiceProvider).likeSong(song);
                              else    await ref.read(databaseServiceProvider).unlikeSong(song.id);
                            },
                          ),
                        ]),
                      ).animate().fadeIn(delay: 80.ms),

                      const SizedBox(height: 20),

                      // Seeker
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: _PremiumSeeker(
                          value: seekVal,
                          max: duration.inSeconds.toDouble().clamp(1.0, double.infinity),
                          position: position,
                          duration: duration,
                          fmt: _fmt,
                          onStart: (v) => setState(() { _dragging = true;  _dragVal = v; }),
                          onChanged: (v) => setState(() => _dragVal = v),
                          onEnd: (v) {
                            ref.read(playerServiceProvider).seekTo(Duration(seconds: v.toInt()));
                            setState(() => _dragging = false);
                          },
                        ),
                      ).animate().fadeIn(delay: 100.ms),

                      const SizedBox(height: 14),

                      // Controls
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _PrimaryControls(
                          isPlaying: isPlaying,
                          repeatMode: repeat,
                          isShuffle: shuffle,
                          onPlay: () {
                            HapticFeedback.mediumImpact();
                            ref.read(playerServiceProvider).togglePlayPause();
                          },
                          onNext: () {
                            HapticFeedback.selectionClick();
                            ref.read(playerServiceProvider).skipNext();
                            final ni = ref.read(currentSongIndexProvider);
                            if (_pc.hasClients) {
                              _pc.animateToPage(ni,
                                duration: const Duration(milliseconds: 380),
                                curve: Curves.easeOutCubic);
                            }
                          },
                          onPrev: () {
                            HapticFeedback.selectionClick();
                            ref.read(playerServiceProvider).skipPrev();
                            final ni = ref.read(currentSongIndexProvider);
                            if (_pc.hasClients) {
                              _pc.animateToPage(ni,
                                duration: const Duration(milliseconds: 380),
                                curve: Curves.easeOutCubic);
                            }
                          },
                          onShuffle: () {
                            HapticFeedback.selectionClick();
                            ref.read(isShuffleProvider.notifier).state = !shuffle;
                          },
                          onRepeat: () {
                            HapticFeedback.selectionClick();
                            final next = RepeatMode.values[(repeat.index + 1) % RepeatMode.values.length];
                            ref.read(repeatModeProvider.notifier).state = next;
                          },
                        ),
                      ).animate().fadeIn(delay: 120.ms),

                      const SizedBox(height: 16),

                      // Bottom bar
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: _BottomActions(
                          onQueue: () => setState(() => _showQueue = true),
                          song: song,
                        ),
                      ).animate().fadeIn(delay: 140.ms),

                      const SizedBox(height: 10),
                    ],
                  ),
            ),
          ),
        ]),
      ),
    );
  }

  void _showOptionsSheet(BuildContext ctx, Song song) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _OptionsSheet(song: song),
    );
  }
}

// ─── PLAYER HEADER ────────────────────────────────────────────

class _PlayerHeader extends StatelessWidget {
  final String album;
  final VoidCallback onClose, onMore;
  const _PlayerHeader({required this.album, required this.onClose, required this.onMore});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(children: [
        _GBtn(icon: Icons.keyboard_arrow_down_rounded, size: 28, onTap: onClose),
        const Spacer(),
        Column(children: [
          Text('NOW PLAYING',
            style: TextStyle(color: Colors.white.withOpacity(0.35),
              fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 2.5)),
          const SizedBox(height: 2),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(album,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
              maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center)),
        ]),
        const Spacer(),
        _GBtn(icon: Icons.more_horiz_rounded, size: 22, onTap: onMore),
      ]),
    ).animate().fadeIn(duration: 250.ms);
  }
}

class _GBtn extends StatelessWidget {
  final IconData icon; final double size; final VoidCallback onTap;
  const _GBtn({required this.icon, required this.size, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.07),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.1))),
            child: Icon(icon, color: Colors.white.withOpacity(0.8), size: size)),
        ),
      ),
    );
  }
}

// ─── VINYL DISC ───────────────────────────────────────────────

class _VinylDisc extends StatelessWidget {
  final Song song;
  final bool isActive, isPlaying;
  final AnimationController? vinylController;
  const _VinylDisc({required this.song, required this.isActive,
      required this.isPlaying, this.vinylController});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(width: 268, height: 268,
        child: Stack(alignment: Alignment.center, children: [

          // Glow
          if (isActive && isPlaying)
            Container(width: 284, height: 284,
              decoration: BoxDecoration(shape: BoxShape.circle,
                boxShadow: [BoxShadow(
                  color: AppTheme.pink.withOpacity(0.28),
                  blurRadius: 48, spreadRadius: 6)])),

          // Outer vinyl ring
          Container(width: 268, height: 268,
            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black,
              border: Border.all(color: Colors.white.withOpacity(0.05), width: 1))),

          // Spinning art
          ClipOval(
            child: SizedBox(width: 248, height: 248,
              child: vinylController != null
                ? RotationTransition(
                    turns: vinylController!,
                    child: _ArtImage(url: song.image))
                : _ArtImage(url: song.image),
            ),
          ),

          // Center hole
          Container(width: 22, height: 22,
            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black,
              border: Border.all(color: Colors.white.withOpacity(0.1), width: 2),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.9), blurRadius: 8)])),

          // Gloss
          Container(width: 248, height: 248,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Colors.white.withOpacity(0.1), Colors.transparent, Colors.black.withOpacity(0.05)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                stops: const [0.0, 0.45, 1.0]))),
        ]),
      ),
    );
  }
}

class _ArtImage extends StatelessWidget {
  final String url;
  const _ArtImage({required this.url});
  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: url, fit: BoxFit.cover,
      placeholder: (_, __) => Container(color: AppTheme.bgTertiary,
        child: const Icon(Icons.music_note, color: AppTheme.pink, size: 48)),
      errorWidget: (_, __, ___) => Container(
        decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
        child: const Icon(Icons.music_note, color: Colors.white, size: 48)));
  }
}

// ─── LIKE BUTTON ──────────────────────────────────────────────

class _LikeButton extends StatelessWidget {
  final bool isLiked;
  final VoidCallback onTap;
  const _LikeButton({required this.isLiked, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutBack,
        width: 44, height: 44,
        decoration: BoxDecoration(shape: BoxShape.circle,
          color: isLiked ? AppTheme.pink.withOpacity(0.18) : Colors.white.withOpacity(0.06),
          border: Border.all(
            color: isLiked ? AppTheme.pink.withOpacity(0.5) : Colors.white.withOpacity(0.1))),
        child: Icon(
          isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          color: isLiked ? AppTheme.pink : Colors.white.withOpacity(0.5), size: 20)),
    );
  }
}

// ─── SEEKER ───────────────────────────────────────────────────

class _PremiumSeeker extends StatefulWidget {
  final double value, max;
  final Duration position, duration;
  final String Function(Duration) fmt;
  final ValueChanged<double> onStart, onChanged, onEnd;
  const _PremiumSeeker({required this.value, required this.max,
      required this.position, required this.duration, required this.fmt,
      required this.onStart, required this.onChanged, required this.onEnd});

  @override
  State<_PremiumSeeker> createState() => _PremiumSeekerState();
}

class _PremiumSeekerState extends State<_PremiumSeeker> {
  bool _active = false;
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: _active ? 5 : 3,
          thumbShape: _active
            ? const RoundSliderThumbShape(enabledThumbRadius: 8)
            : const RoundSliderThumbShape(enabledThumbRadius: 0),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
          activeTrackColor: Colors.white,
          inactiveTrackColor: Colors.white.withOpacity(0.14),
          thumbColor: Colors.white,
          overlayColor: Colors.white.withOpacity(0.1),
        ),
        child: Slider(
          value: widget.value.clamp(0.0, widget.max),
          max: widget.max,
          onChangeStart: (v) { setState(() => _active = true);  widget.onStart(v); },
          onChanged: widget.onChanged,
          onChangeEnd: (v)  { setState(() => _active = false); widget.onEnd(v); },
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(widget.fmt(widget.position),
            style: TextStyle(color: Colors.white.withOpacity(0.38), fontSize: 11,
              fontWeight: FontWeight.w600, fontFeatures: const [FontFeature.tabularFigures()])),
          Text(widget.fmt(widget.duration),
            style: TextStyle(color: Colors.white.withOpacity(0.38), fontSize: 11,
              fontWeight: FontWeight.w600, fontFeatures: const [FontFeature.tabularFigures()])),
        ]),
      ),
    ]);
  }
}

// ─── CONTROLS ─────────────────────────────────────────────────

class _PrimaryControls extends StatelessWidget {
  final bool isPlaying, isShuffle;
  final RepeatMode repeatMode;
  final VoidCallback onPlay, onNext, onPrev, onShuffle, onRepeat;

  const _PrimaryControls({required this.isPlaying, required this.isShuffle,
      required this.repeatMode, required this.onPlay, required this.onNext,
      required this.onPrev, required this.onShuffle, required this.onRepeat});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _Ctrl(icon: Icons.shuffle_rounded, size: 22,
          color: isShuffle ? AppTheme.pink : Colors.white.withOpacity(0.35),
          onTap: onShuffle, dot: isShuffle),
        _Ctrl(icon: Icons.skip_previous_rounded, size: 42, color: Colors.white, onTap: onPrev),
        _BigPlayBtn(isPlaying: isPlaying, onTap: onPlay),
        _Ctrl(icon: Icons.skip_next_rounded, size: 42, color: Colors.white, onTap: onNext),
        _Ctrl(
          icon: repeatMode == RepeatMode.one ? Icons.repeat_one_rounded : Icons.repeat_rounded,
          size: 22,
          color: repeatMode == RepeatMode.off ? Colors.white.withOpacity(0.35) : AppTheme.pink,
          onTap: onRepeat, dot: repeatMode == RepeatMode.one),
      ],
    );
  }
}

class _Ctrl extends StatelessWidget {
  final IconData icon; final double size; final Color color;
  final VoidCallback onTap; final bool dot;
  const _Ctrl({required this.icon, required this.size, required this.color,
      required this.onTap, this.dot = false});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Stack(clipBehavior: Clip.none, children: [
          Icon(icon, color: color, size: size),
          if (dot) Positioned(bottom: -5, left: 0, right: 0,
            child: Center(child: Container(width: 4, height: 4,
              decoration: const BoxDecoration(color: AppTheme.pink, shape: BoxShape.circle)))),
        ]),
      ),
    );
  }
}

class _BigPlayBtn extends StatefulWidget {
  final bool isPlaying; final VoidCallback onTap;
  const _BigPlayBtn({required this.isPlaying, required this.onTap});
  @override
  State<_BigPlayBtn> createState() => _BigPlayBtnState();
}

class _BigPlayBtnState extends State<_BigPlayBtn> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 280));
    if (widget.isPlaying) _ctrl.forward();
  }
  @override
  void didUpdateWidget(_BigPlayBtn old) {
    super.didUpdateWidget(old);
    widget.isPlaying ? _ctrl.forward() : _ctrl.reverse();
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: 68, height: 68,
        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.white.withOpacity(0.2), blurRadius: 24),
            BoxShadow(color: AppTheme.pink.withOpacity(0.25), blurRadius: 32, spreadRadius: -4)]),
        child: Center(child: AnimatedIcon(
          icon: AnimatedIcons.play_pause, progress: _ctrl,
          color: Colors.black, size: 32))),
    );
  }
}

// ─── BOTTOM ACTIONS ───────────────────────────────────────────

class _BottomActions extends StatelessWidget {
  final VoidCallback onQueue; final Song song;
  const _BottomActions({required this.onQueue, required this.song});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
      _Chip(icon: Icons.queue_music_rounded, label: 'QUEUE', onTap: onQueue),
      _Chip(icon: Icons.ios_share_rounded, label: 'SHARE', onTap: () {
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Sharing "${song.title}"', style: const TextStyle(color: Colors.white)),
          backgroundColor: Colors.black.withOpacity(0.85), behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(milliseconds: 1400)));
      }),
      _Chip(icon: Icons.download_rounded, label: 'SAVE', onTap: () {
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Coming soon!', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.black.withOpacity(0.85), behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(milliseconds: 1200)));
      }),
    ]);
  }
}

class _Chip extends StatelessWidget {
  final IconData icon; final String label; final VoidCallback onTap;
  const _Chip({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.07),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.1))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, color: Colors.white.withOpacity(0.6), size: 14),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: Colors.white.withOpacity(0.55),
                fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
            ])),
        ),
      ),
    );
  }
}

// ─── QUEUE PANEL ──────────────────────────────────────────────

class _QueuePanel extends StatelessWidget {
  final List<Song> playlist;
  final int currentIndex;
  final VoidCallback onClose;
  final ValueChanged<int> onSongTap;
  const _QueuePanel({super.key, required this.playlist, required this.currentIndex,
      required this.onClose, required this.onSongTap});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(children: [
          GestureDetector(onTap: onClose,
            child: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 28)),
          const Spacer(),
          Column(children: [
            Text('QUEUE', style: TextStyle(color: Colors.white.withOpacity(0.85),
              fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 2)),
            Text('${playlist.length} songs', style: TextStyle(
              color: Colors.white.withOpacity(0.3), fontSize: 11)),
          ]),
          const Spacer(),
          const SizedBox(width: 28),
        ]),
      ),
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: playlist.length,
          itemBuilder: (_, i) {
            final s = playlist[i];
            final active = i == currentIndex;
            return GestureDetector(
              onTap: () => onSongTap(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: active ? AppTheme.pink.withOpacity(0.12) : Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: active ? AppTheme.pink.withOpacity(0.3) : Colors.transparent)),
                child: Row(children: [
                  ClipRRect(borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(imageUrl: s.image, width: 42, height: 42,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(width: 42, height: 42,
                        color: AppTheme.bgTertiary,
                        child: const Icon(Icons.music_note, color: AppTheme.pink, size: 18)))),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s.title,
                      style: TextStyle(color: active ? AppTheme.pink : Colors.white,
                        fontSize: 13, fontWeight: active ? FontWeight.w700 : FontWeight.w500),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(s.artist,
                      style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  ])),
                  if (active)
                    Container(width: 6, height: 6,
                      decoration: const BoxDecoration(color: AppTheme.pink, shape: BoxShape.circle))
                  else
                    Text(_dur(int.tryParse(s.duration) ?? 0),
                      style: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 11)),
                ]),
              ),
            ).animate().fadeIn(delay: Duration(milliseconds: i * 14));
          },
        ),
      ),
    ]);
  }

  String _dur(int s) {
    if (s <= 0) return '--:--';
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2,'0')}';
  }
}

// ─── OPTIONS SHEET ────────────────────────────────────────────

class _OptionsSheet extends StatelessWidget {
  final Song song;
  const _OptionsSheet({required this.song});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.75),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: Colors.white.withOpacity(0.08))),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 36, height: 4,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Row(children: [
              ClipRRect(borderRadius: BorderRadius.circular(10),
                child: CachedNetworkImage(imageUrl: song.image, width: 50, height: 50,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(width: 50, height: 50,
                    color: AppTheme.bgTertiary,
                    child: const Icon(Icons.music_note, color: AppTheme.pink)))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(song.title,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(song.artist,
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              ])),
            ]),
            const SizedBox(height: 16),
            Divider(color: Colors.white.withOpacity(0.08)),
            const SizedBox(height: 8),
            ...[
              (Icons.playlist_add_rounded, 'Add to Playlist'),
              (Icons.person_rounded, 'Go to Artist'),
              (Icons.album_rounded, 'Go to Album'),
              (Icons.radio_rounded, 'Start Radio'),
              (Icons.share_rounded, 'Share'),
            ].map((item) => ListTile(
              leading: Icon(item.$1, color: Colors.white.withOpacity(0.7), size: 22),
              title: Text(item.$2, style: const TextStyle(color: Colors.white,
                fontSize: 14, fontWeight: FontWeight.w500)),
              onTap: () { Navigator.pop(context); HapticFeedback.selectionClick(); },
              contentPadding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            )),
          ]),
        ),
      ),
    );
  }
}