import 'dart:ui';
import 'dart:math' as math;
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

// ─────────────────────────────────────────────────────────────
// PROVIDERS
// ─────────────────────────────────────────────────────────────

final _playerLikedProvider =
    StateProvider.family<bool, String>((ref, id) => false);

final _paletteProvider = StateProvider<List<Color>>((ref) =>
    [const Color(0xFF0D0D1A), const Color(0xFF080810)]);

// ─────────────────────────────────────────────────────────────
// PLAYER SCREEN
// ─────────────────────────────────────────────────────────────

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen>
    with TickerProviderStateMixin {

  late AnimationController _bgPulse;
  late AnimationController _vinylSpin;
  late PageController _pc;

  bool _dragging     = false;
  double _dragVal    = 0.0;
  bool _showQueue    = false;
  String? _lastImg;
  bool _pcReady      = false;

  // ── Ghost-tap fix: track whether a scroll/swipe is happening ──
  bool _isScrolling  = false;

  @override
  void initState() {
    super.initState();

    _bgPulse = AnimationController(
        vsync: this, duration: const Duration(seconds: 6))
      ..repeat(reverse: true);

    _vinylSpin = AnimationController(
        vsync: this, duration: const Duration(seconds: 10))
      ..repeat();

    final initIdx =
        ref.read(currentSongIndexProvider).clamp(0, 999999);
    _pc = PageController(
        initialPage: initIdx, viewportFraction: 0.82);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final idx = ref.read(currentSongIndexProvider).clamp(0, 999999);
      if (_pc.hasClients && (_pc.page?.round() ?? -1) != idx) {
        _pc.jumpToPage(idx);
      }
      setState(() => _pcReady = true);
      final song = ref.read(currentSongProvider);
      if (song != null) _extractPalette(song.image);
    });
  }

  @override
  void dispose() {
    _bgPulse.dispose();
    _vinylSpin.dispose();
    _pc.dispose();
    super.dispose();
  }

  Future<void> _extractPalette(String url) async {
    if (url == _lastImg || url.isEmpty) return;
    _lastImg = url;
    try {
      final pg = await PaletteGenerator.fromImageProvider(
          NetworkImage(url), size: const Size(100, 100));
      final c1 = pg.dominantColor?.color ??
          pg.vibrantColor?.color ?? const Color(0xFF1A0A2E);
      final c2 = pg.darkMutedColor?.color ??
          pg.mutedColor?.color ?? const Color(0xFF080810);
      if (mounted) {
        ref.read(_paletteProvider.notifier).state = [
          Color.lerp(c1, Colors.black, 0.4)!,
          Color.lerp(c2, Colors.black, 0.6)!,
        ];
      }
    } catch (_) {}
  }

  String _fmt(Duration d) {
    if (d.inSeconds <= 0) return '0:00';
    return '${d.inMinutes.remainder(60)}:'
        '${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';
  }

  void _onPageSwipe(int idx) {
    if (idx == ref.read(currentSongIndexProvider)) return;
    final pl = ref.read(currentPlaylistProvider);
    if (idx < 0 || idx >= pl.length) return;
    final song = pl[idx];
    ref.read(currentSongIndexProvider.notifier).state = idx;
    ref.read(currentSongProvider.notifier).state = song;
    ref.read(playerServiceProvider).playSong(song);
    _extractPalette(song.image);
    HapticFeedback.lightImpact();
  }

  void _syncPage(int idx) {
    if (!_pcReady || !_pc.hasClients || _dragging || _isScrolling)
      return;
    final curPage = _pc.page?.round() ?? idx;
    if (curPage != idx) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_pc.hasClients) return;
        _pc.animateToPage(idx,
            duration: const Duration(milliseconds: 380),
            curve: Curves.easeOutCubic);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final song = ref.watch(currentSongProvider);
    if (song == null) return const SizedBox.shrink();

    final isPlaying = ref.watch(isPlayingStreamProvider).value ?? false;
    final position  = ref.watch(positionStreamProvider).value  ?? Duration.zero;
    final duration  = ref.watch(durationStreamProvider).value  ?? Duration.zero;
    final playlist  = ref.watch(currentPlaylistProvider);
    final curIdx    = ref.watch(currentSongIndexProvider);
    final repeat    = ref.watch(repeatModeProvider);
    final shuffle   = ref.watch(isShuffleProvider);
    final liked     = ref.watch(_playerLikedProvider(song.id));
    final palette   = ref.watch(_paletteProvider);

    // Sync vinyl spin to play state
    if (isPlaying && !_vinylSpin.isAnimating) {
      _vinylSpin.repeat();
    } else if (!isPlaying && _vinylSpin.isAnimating) {
      _vinylSpin.stop();
    }

    if (song.image != _lastImg) {
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => _extractPalette(song.image));
    }

    _syncPage(curIdx);

    final double seekMax =
        duration.inSeconds.toDouble().clamp(1.0, double.infinity);
    final double seekVal = _dragging
        ? _dragVal
        : position.inSeconds.toDouble().clamp(0.0, seekMax);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(fit: StackFit.expand, children: [

          // ── 1. Dynamic palette gradient BG ───────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 1000),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [palette[0], palette[1], Colors.black],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),

          // ── 2. Blurred album art wash ─────────────────────────
          if (song.image.isNotEmpty)
            Opacity(
              opacity: 0.10,
              child: CachedNetworkImage(
                imageUrl: song.image,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) =>
                    const SizedBox.shrink(),
              ),
            ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
            child: Container(color: Colors.transparent)),
          Container(color: Colors.black.withOpacity(0.45)),

          // ── 3. Animated glow orbs ─────────────────────────────
          AnimatedBuilder(
            animation: _bgPulse,
            builder: (_, __) {
              final t = _bgPulse.value;
              return Stack(children: [
                Positioned(
                  top: -100 + t * 40,
                  left: -60,
                  child: Container(
                    width: 300, height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [
                        palette[0].withOpacity(0.25 + t * 0.1),
                        Colors.transparent,
                      ]),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 80,
                  right: -40 + t * 20,
                  child: Container(
                    width: 200, height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [
                        AppTheme.pink.withOpacity(0.08 + t * 0.04),
                        Colors.transparent,
                      ]),
                    ),
                  ),
                ),
              ]);
            },
          ),

          // ── 4. Main content ──────────────────────────────────
          SafeArea(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: _showQueue
                  ? _QueuePanel(
                      key: const ValueKey('queue'),
                      playlist: playlist,
                      currentIndex: curIdx,
                      onClose: () =>
                          setState(() => _showQueue = false),
                      onSongTap: (idx) {
                        setState(() => _showQueue = false);
                        _onPageSwipe(idx);
                        WidgetsBinding.instance
                            .addPostFrameCallback((_) {
                          if (_pc.hasClients) {
                            _pc.animateToPage(idx,
                                duration: const Duration(
                                    milliseconds: 400),
                                curve: Curves.easeOutCubic);
                          }
                        });
                      },
                    )
                  : _PlayerBody(
                      key: const ValueKey('player'),
                      song: song,
                      playlist: playlist,
                      curIdx: curIdx,
                      isPlaying: isPlaying,
                      position: position,
                      duration: duration,
                      seekVal: seekVal,
                      seekMax: seekMax,
                      repeat: repeat,
                      shuffle: shuffle,
                      liked: liked,
                      pc: _pc,
                      vinylSpin: _vinylSpin,
                      fmt: _fmt,
                      onClose: () => Navigator.of(context).pop(),
                      onMore: () =>
                          _showOptionsSheet(context, song),
                      onPageSwipe: _onPageSwipe,
                      onDragStart: (v) => setState(() {
                        _dragging = true;
                        _dragVal = v;
                      }),
                      onDragUpdate: (v) =>
                          setState(() => _dragVal = v),
                      onDragEnd: (v) {
                        ref
                            .read(playerServiceProvider)
                            .seekTo(Duration(
                                seconds: v.toInt()));
                        setState(() => _dragging = false);
                      },
                      onPlay: () {
                        HapticFeedback.mediumImpact();
                        ref
                            .read(playerServiceProvider)
                            .togglePlayPause();
                      },
                      onNext: () {
                        HapticFeedback.selectionClick();
                        ref
                            .read(playerServiceProvider)
                            .skipNext();
                        final ni = ref.read(
                            currentSongIndexProvider);
                        if (_pc.hasClients) {
                          _pc.animateToPage(ni,
                              duration: const Duration(
                                  milliseconds: 380),
                              curve: Curves.easeOutCubic);
                        }
                      },
                      onPrev: () {
                        HapticFeedback.selectionClick();
                        ref
                            .read(playerServiceProvider)
                            .skipPrev();
                        final ni = ref.read(
                            currentSongIndexProvider);
                        if (_pc.hasClients) {
                          _pc.animateToPage(ni,
                              duration: const Duration(
                                  milliseconds: 380),
                              curve: Curves.easeOutCubic);
                        }
                      },
                      onShuffle: () {
                        HapticFeedback.selectionClick();
                        ref
                            .read(
                                isShuffleProvider.notifier)
                            .state = !shuffle;
                      },
                      onRepeat: () {
                        HapticFeedback.selectionClick();
                        final next = RepeatMode.values[
                            (repeat.index + 1) %
                                RepeatMode.values.length];
                        ref
                            .read(
                                repeatModeProvider.notifier)
                            .state = next;
                      },
                      onLike: () async {
                        HapticFeedback.lightImpact();
                        final nv = !liked;
                        ref
                            .read(_playerLikedProvider(
                                    song.id)
                                .notifier)
                            .state = nv;
                        if (nv) {
                          await ref
                              .read(databaseServiceProvider)
                              .likeSong(song);
                        } else {
                          await ref
                              .read(databaseServiceProvider)
                              .unlikeSong(song.id);
                        }
                      },
                      onQueue: () =>
                          setState(() => _showQueue = true),
                      // ── Ghost-tap fix ──────────────────────
                      onScrollStart: () =>
                          setState(() => _isScrolling = true),
                      onScrollEnd: () => setState(
                          () => _isScrolling = false),
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

// ─────────────────────────────────────────────────────────────
// PLAYER BODY — extracted so AnimatedSwitcher can key it
// ─────────────────────────────────────────────────────────────

class _PlayerBody extends StatelessWidget {
  final Song song;
  final List<Song> playlist;
  final int curIdx;
  final bool isPlaying, shuffle, liked;
  final Duration position, duration;
  final double seekVal, seekMax;
  final RepeatMode repeat;
  final PageController pc;
  final AnimationController vinylSpin;
  final String Function(Duration) fmt;
  final VoidCallback onClose, onMore, onPlay, onNext, onPrev,
      onShuffle, onRepeat, onLike, onQueue;
  final ValueChanged<int> onPageSwipe;
  final ValueChanged<double> onDragStart, onDragUpdate, onDragEnd;
  final VoidCallback onScrollStart, onScrollEnd;

  const _PlayerBody({
    super.key,
    required this.song,
    required this.playlist,
    required this.curIdx,
    required this.isPlaying,
    required this.shuffle,
    required this.liked,
    required this.position,
    required this.duration,
    required this.seekVal,
    required this.seekMax,
    required this.repeat,
    required this.pc,
    required this.vinylSpin,
    required this.fmt,
    required this.onClose,
    required this.onMore,
    required this.onPlay,
    required this.onNext,
    required this.onPrev,
    required this.onShuffle,
    required this.onRepeat,
    required this.onLike,
    required this.onQueue,
    required this.onPageSwipe,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onScrollStart,
    required this.onScrollEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [

      // ── Header ─────────────────────────────────────────────
      _PlayerHeader(
        album: song.album.isNotEmpty ? song.album : 'DEN',
        onClose: onClose,
        onMore: onMore,
      ).animate().fadeIn(duration: 280.ms),

      // ── Artwork carousel ───────────────────────────────────
      Expanded(
        flex: 5,
        child: NotificationListener<ScrollNotification>(
          // ── Ghost-tap fix: block taps while paging ──────
          onNotification: (n) {
            if (n is ScrollStartNotification) {
              onScrollStart();
            } else if (n is ScrollEndNotification) {
              // Small delay so the last touch up doesn't fire
              Future.delayed(
                  const Duration(milliseconds: 120),
                  onScrollEnd);
            }
            return false;
          },
          child: PageView.builder(
            controller: pc,
            itemCount: playlist.length,
            onPageChanged: onPageSwipe,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (_, i) {
              final s = playlist[i];
              final isActive = i == curIdx;
              return AnimatedBuilder(
                animation: pc,
                builder: (_, child) {
                  double scale = 0.84, op = 0.45;
                  if (pc.position.haveDimensions) {
                    final diff = (pc.page! - i).abs();
                    scale =
                        (1.0 - diff * 0.16).clamp(0.84, 1.0);
                    op =
                        (1.0 - diff * 0.55).clamp(0.45, 1.0);
                  } else if (isActive) {
                    scale = 1.0;
                    op = 1.0;
                  }
                  return Transform.scale(
                    scale: scale,
                    child: Opacity(opacity: op, child: child));
                },
                child: _ArtworkCard(
                  song: s,
                  isActive: isActive,
                  isPlaying: isPlaying && isActive,
                  vinylSpin: vinylSpin,
                ),
              );
            },
          ),
        ),
      ),

      const SizedBox(height: 20),

      // ── Song info + like ────────────────────────────────────
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.6,
                      height: 1.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    song.artist,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.48),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            _LikeButton(isLiked: liked, onTap: onLike),
          ],
        ),
      ).animate().fadeIn(delay: 60.ms, duration: 300.ms),

      const SizedBox(height: 22),

      // ── Seeker ─────────────────────────────────────────────
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: _Seeker(
          value: seekVal,
          max: seekMax,
          position: position,
          duration: duration,
          fmt: fmt,
          onStart: onDragStart,
          onChanged: onDragUpdate,
          onEnd: onDragEnd,
        ),
      ).animate().fadeIn(delay: 80.ms, duration: 300.ms),

      const SizedBox(height: 16),

      // ── Primary controls ────────────────────────────────────
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: _Controls(
          isPlaying: isPlaying,
          repeatMode: repeat,
          isShuffle: shuffle,
          onPlay: onPlay,
          onNext: onNext,
          onPrev: onPrev,
          onShuffle: onShuffle,
          onRepeat: onRepeat,
        ),
      ).animate().fadeIn(delay: 100.ms, duration: 300.ms),

      const SizedBox(height: 18),

      // ── Bottom actions ──────────────────────────────────────
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: _BottomBar(
          onQueue: onQueue,
          song: song,
          playlist: playlist,
          curIdx: curIdx,
        ),
      ).animate().fadeIn(delay: 120.ms, duration: 300.ms),

      const SizedBox(height: 12),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────
// HEADER
// ─────────────────────────────────────────────────────────────

class _PlayerHeader extends StatelessWidget {
  final String album;
  final VoidCallback onClose, onMore;
  const _PlayerHeader(
      {required this.album,
      required this.onClose,
      required this.onMore});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(16, 6, 16, 4),
      child: Row(children: [
        _HdrBtn(
            icon: Icons.keyboard_arrow_down_rounded,
            size: 26,
            onTap: onClose),
        const Spacer(),
        Column(children: [
          Text(
            'NOW PLAYING',
            style: TextStyle(
              color: Colors.white.withOpacity(0.32),
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.8,
            ),
          ),
          const SizedBox(height: 2),
          ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: 160),
            child: Text(
              album,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ]),
        const Spacer(),
        _HdrBtn(
            icon: Icons.more_horiz_rounded,
            size: 22,
            onTap: onMore),
      ]),
    );
  }
}

class _HdrBtn extends StatefulWidget {
  final IconData icon;
  final double size;
  final VoidCallback onTap;
  const _HdrBtn(
      {required this.icon,
      required this.size,
      required this.onTap});

  @override
  State<_HdrBtn> createState() => _HdrBtnState();
}

class _HdrBtnState extends State<_HdrBtn> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? 0.88 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: BackdropFilter(
            filter:
                ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white
                    .withOpacity(_pressed ? 0.12 : 0.07),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                    color: Colors.white.withOpacity(0.1)),
              ),
              child: Icon(widget.icon,
                  color: Colors.white.withOpacity(0.85),
                  size: widget.size),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// ARTWORK CARD
// ─────────────────────────────────────────────────────────────

class _ArtworkCard extends StatelessWidget {
  final Song song;
  final bool isActive, isPlaying;
  final AnimationController vinylSpin;

  const _ArtworkCard({
    required this.song,
    required this.isActive,
    required this.isPlaying,
    required this.vinylSpin,
  });

  @override
  Widget build(BuildContext context) {
    // Spotify-style: shrinks slightly when paused
    final double playScale =
        (isActive && isPlaying) ? 1.0 : 0.92;

    return AnimatedScale(
      scale: playScale,
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutExpo,
      child: Center(
        child: AspectRatio(
          aspectRatio: 1.0,
          child: Container(
            margin:
                const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.55),
                  blurRadius: 50,
                  offset: const Offset(0, 24),
                  spreadRadius: -6,
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: CachedNetworkImage(
                imageUrl: song.image,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: AppTheme.bgTertiary,
                  child: const Center(
                    child: Icon(Icons.music_note_rounded,
                        color: AppTheme.pink, size: 72),
                  ),
                ),
                errorWidget: (_, __, ___) => Container(
                  decoration: const BoxDecoration(
                      gradient: AppTheme.primaryGradient),
                  child: const Center(
                    child: Icon(Icons.music_note_rounded,
                        color: Colors.white, size: 72),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// LIKE BUTTON
// ─────────────────────────────────────────────────────────────

class _LikeButton extends StatefulWidget {
  final bool isLiked;
  final VoidCallback onTap;
  const _LikeButton(
      {required this.isLiked, required this.onTap});

  @override
  State<_LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<_LikeButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 200));
    _scale = Tween<double>(begin: 1.0, end: 1.3).animate(
        CurvedAnimation(
            parent: _ctrl, curve: Curves.easeOutBack));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _ctrl.forward().then((_) => _ctrl.reverse());
        widget.onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutBack,
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.isLiked
                ? AppTheme.pink.withOpacity(0.18)
                : Colors.white.withOpacity(0.07),
            border: Border.all(
              color: widget.isLiked
                  ? AppTheme.pink.withOpacity(0.55)
                  : Colors.white.withOpacity(0.12),
              width: 1.2,
            ),
          ),
          child: Icon(
            widget.isLiked
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            color: widget.isLiked
                ? AppTheme.pink
                : Colors.white.withOpacity(0.45),
            size: 20,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SEEKER
// ─────────────────────────────────────────────────────────────

class _Seeker extends StatefulWidget {
  final double value, max;
  final Duration position, duration;
  final String Function(Duration) fmt;
  final ValueChanged<double> onStart, onChanged, onEnd;

  const _Seeker({
    required this.value,
    required this.max,
    required this.position,
    required this.duration,
    required this.fmt,
    required this.onStart,
    required this.onChanged,
    required this.onEnd,
  });

  @override
  State<_Seeker> createState() => _SeekerState();
}

class _SeekerState extends State<_Seeker> {
  bool _active = false;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: _active ? 5.0 : 3.0,
          thumbShape: _active
              ? const RoundSliderThumbShape(
                  enabledThumbRadius: 8)
              : const RoundSliderThumbShape(
                  enabledThumbRadius: 0),
          overlayShape: const RoundSliderOverlayShape(
              overlayRadius: 18),
          activeTrackColor: Colors.white,
          inactiveTrackColor:
              Colors.white.withOpacity(0.15),
          thumbColor: Colors.white,
          overlayColor: Colors.white.withOpacity(0.08),
          trackShape:
              const _RoundedTrackShape(),
        ),
        child: Slider(
          value: widget.value.clamp(0.0, widget.max),
          max: widget.max,
          onChangeStart: (v) {
            setState(() => _active = true);
            widget.onStart(v);
          },
          onChanged: widget.onChanged,
          onChangeEnd: (v) {
            setState(() => _active = false);
            widget.onEnd(v);
          },
        ),
      ),
      Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          mainAxisAlignment:
              MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.fmt(widget.position),
              style: TextStyle(
                color: Colors.white.withOpacity(0.38),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                fontFeatures: const [
                  FontFeature.tabularFigures()
                ],
              ),
            ),
            Text(
              widget.fmt(widget.duration),
              style: TextStyle(
                color: Colors.white.withOpacity(0.38),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                fontFeatures: const [
                  FontFeature.tabularFigures()
                ],
              ),
            ),
          ],
        ),
      ),
    ]);
  }
}

/// Rounded track so the slider looks premium
class _RoundedTrackShape extends RoundedRectSliderTrackShape {
  const _RoundedTrackShape();

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final double trackHeight =
        sliderTheme.trackHeight ?? 3.0;
    final double trackLeft =
        offset.dx + 0; // full width
    final double trackTop = offset.dy +
        (parentBox.size.height - trackHeight) / 2;
    final double trackWidth = parentBox.size.width;
    return Rect.fromLTWH(
        trackLeft, trackTop, trackWidth, trackHeight);
  }
}

// ─────────────────────────────────────────────────────────────
// CONTROLS
// ─────────────────────────────────────────────────────────────

class _Controls extends StatelessWidget {
  final bool isPlaying, isShuffle;
  final RepeatMode repeatMode;
  final VoidCallback onPlay, onNext, onPrev,
      onShuffle, onRepeat;

  const _Controls({
    required this.isPlaying,
    required this.isShuffle,
    required this.repeatMode,
    required this.onPlay,
    required this.onNext,
    required this.onPrev,
    required this.onShuffle,
    required this.onRepeat,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Shuffle
        _CtrlBtn(
          icon: Icons.shuffle_rounded,
          size: 22,
          color: isShuffle
              ? AppTheme.pink
              : Colors.white.withOpacity(0.35),
          onTap: onShuffle,
          dot: isShuffle,
        ),

        // Skip prev
        _CtrlBtn(
          icon: Icons.skip_previous_rounded,
          size: 40,
          color: Colors.white,
          onTap: onPrev,
        ),

        // Big play/pause
        _PlayPauseBtn(
            isPlaying: isPlaying, onTap: onPlay),

        // Skip next
        _CtrlBtn(
          icon: Icons.skip_next_rounded,
          size: 40,
          color: Colors.white,
          onTap: onNext,
        ),

        // Repeat
        _CtrlBtn(
          icon: repeatMode == RepeatMode.one
              ? Icons.repeat_one_rounded
              : Icons.repeat_rounded,
          size: 22,
          color: repeatMode == RepeatMode.off
              ? Colors.white.withOpacity(0.35)
              : AppTheme.pink,
          onTap: onRepeat,
          dot: repeatMode == RepeatMode.one,
        ),
      ],
    );
  }
}

class _CtrlBtn extends StatefulWidget {
  final IconData icon;
  final double size;
  final Color color;
  final VoidCallback onTap;
  final bool dot;

  const _CtrlBtn({
    required this.icon,
    required this.size,
    required this.color,
    required this.onTap,
    this.dot = false,
  });

  @override
  State<_CtrlBtn> createState() => _CtrlBtnState();
}

class _CtrlBtnState extends State<_CtrlBtn> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) =>
          Future.delayed(const Duration(milliseconds: 80),
              () { if (mounted) setState(() => _pressed = false); }),
      onTapCancel: () =>
          setState(() => _pressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? 0.82 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(widget.icon,
                  color: widget.color, size: widget.size),
              if (widget.dot)
                Positioned(
                  bottom: -4,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      width: 4, height: 4,
                      decoration: const BoxDecoration(
                          color: AppTheme.pink,
                          shape: BoxShape.circle),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayPauseBtn extends StatefulWidget {
  final bool isPlaying;
  final VoidCallback onTap;
  const _PlayPauseBtn(
      {required this.isPlaying, required this.onTap});

  @override
  State<_PlayPauseBtn> createState() =>
      _PlayPauseBtnState();
}

class _PlayPauseBtnState extends State<_PlayPauseBtn>
    with SingleTickerProviderStateMixin {
  late AnimationController _iconCtrl;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _iconCtrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 250));
    if (widget.isPlaying) _iconCtrl.forward();
  }

  @override
  void didUpdateWidget(_PlayPauseBtn old) {
    super.didUpdateWidget(old);
    widget.isPlaying
        ? _iconCtrl.forward()
        : _iconCtrl.reverse();
  }

  @override
  void dispose() {
    _iconCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) =>
          setState(() => _pressed = true),
      onTapUp: (_) =>
          Future.delayed(const Duration(milliseconds: 100),
              () { if (mounted) setState(() => _pressed = false); }),
      onTapCancel: () =>
          setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.9 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.white.withOpacity(0.18),
                blurRadius: 28,
                spreadRadius: -4,
              ),
              BoxShadow(
                color: AppTheme.pink.withOpacity(0.22),
                blurRadius: 36,
                spreadRadius: -8,
              ),
            ],
          ),
          child: Center(
            child: AnimatedIcon(
              icon: AnimatedIcons.play_pause,
              progress: _iconCtrl,
              color: Colors.black,
              size: 34,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// BOTTOM BAR
// ─────────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  final VoidCallback onQueue;
  final Song song;
  final List<Song> playlist;
  final int curIdx;

  const _BottomBar({
    required this.onQueue,
    required this.song,
    required this.playlist,
    required this.curIdx,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _BarChip(
          icon: Icons.queue_music_rounded,
          label: 'QUEUE',
          badge: '${playlist.length}',
          onTap: onQueue,
        ),
        _BarChip(
          icon: Icons.ios_share_rounded,
          label: 'SHARE',
          onTap: () {
            HapticFeedback.lightImpact();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Sharing "${song.title}"',
                    style: const TextStyle(
                        color: Colors.white)),
                backgroundColor:
                    Colors.black.withOpacity(0.85),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(12)),
                duration:
                    const Duration(milliseconds: 1400),
              ),
            );
          },
        ),
        _BarChip(
          icon: Icons.download_rounded,
          label: 'SAVE',
          onTap: () {
            HapticFeedback.lightImpact();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Coming soon!',
                    style: TextStyle(
                        color: Colors.white)),
                backgroundColor:
                    Colors.black.withOpacity(0.85),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(12)),
                duration:
                    const Duration(milliseconds: 1200),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _BarChip extends StatefulWidget {
  final IconData icon;
  final String label;
  final String? badge;
  final VoidCallback onTap;

  const _BarChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge,
  });

  @override
  State<_BarChip> createState() => _BarChipState();
}

class _BarChipState extends State<_BarChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) =>
          setState(() => _pressed = true),
      onTapUp: (_) =>
          setState(() => _pressed = false),
      onTapCancel: () =>
          setState(() => _pressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 110),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter:
                ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: AnimatedContainer(
              duration:
                  const Duration(milliseconds: 120),
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 11),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(
                    _pressed ? 0.12 : 0.07),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                    color:
                        Colors.white.withOpacity(0.1)),
              ),
              child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(widget.icon,
                        color: Colors.white
                            .withOpacity(0.65),
                        size: 14),
                    const SizedBox(width: 6),
                    Text(
                      widget.label,
                      style: TextStyle(
                        color: Colors.white
                            .withOpacity(0.55),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    if (widget.badge != null) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets
                            .symmetric(
                            horizontal: 5,
                            vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.pink
                              .withOpacity(0.25),
                          borderRadius:
                              BorderRadius.circular(
                                  6),
                        ),
                        child: Text(
                          widget.badge!,
                          style: const TextStyle(
                            color: AppTheme.pink,
                            fontSize: 9,
                            fontWeight:
                                FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// QUEUE PANEL
// ─────────────────────────────────────────────────────────────

class _QueuePanel extends StatelessWidget {
  final List<Song> playlist;
  final int currentIndex;
  final VoidCallback onClose;
  final ValueChanged<int> onSongTap;

  const _QueuePanel({
    super.key,
    required this.playlist,
    required this.currentIndex,
    required this.onClose,
    required this.onSongTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Header
      Padding(
        padding: const EdgeInsets.fromLTRB(
            20, 8, 20, 12),
        child: Row(children: [
          GestureDetector(
            onTap: onClose,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.07),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                    color: Colors.white
                        .withOpacity(0.1)),
              ),
              child: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Colors.white, size: 22),
            ),
          ),
          const Spacer(),
          Column(children: [
            Text(
              'QUEUE',
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.2,
              ),
            ),
            Text(
              '${playlist.length} songs',
              style: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 11,
              ),
            ),
          ]),
          const Spacer(),
          const SizedBox(width: 40),
        ]),
      ),

      // List — uses ListView.builder so no janky
      // flutter_animate stagger on big queues
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(
              16, 0, 16, 20),
          physics: const BouncingScrollPhysics(),
          itemCount: playlist.length,
          itemBuilder: (_, i) {
            final s = playlist[i];
            final active = i == currentIndex;
            return _QueueTile(
              song: s,
              isActive: active,
              index: i,
              onTap: () => onSongTap(i),
            );
          },
        ),
      ),
    ]);
  }
}

class _QueueTile extends StatefulWidget {
  final Song song;
  final bool isActive;
  final int index;
  final VoidCallback onTap;

  const _QueueTile({
    required this.song,
    required this.isActive,
    required this.index,
    required this.onTap,
  });

  @override
  State<_QueueTile> createState() => _QueueTileState();
}

class _QueueTileState extends State<_QueueTile> {
  bool _pressed = false;

  String _dur(int s) {
    if (s <= 0) return '--:--';
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) =>
          setState(() => _pressed = true),
      onTapUp: (_) =>
          setState(() => _pressed = false),
      onTapCancel: () =>
          setState(() => _pressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 5),
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: widget.isActive
              ? AppTheme.pink.withOpacity(0.12)
              : _pressed
                  ? Colors.white.withOpacity(0.07)
                  : Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: widget.isActive
                ? AppTheme.pink.withOpacity(0.28)
                : Colors.transparent,
            width: 0.8,
          ),
        ),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: CachedNetworkImage(
              imageUrl: widget.song.image,
              width: 44, height: 44,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Container(
                width: 44, height: 44,
                color: AppTheme.bgTertiary,
                child: const Icon(Icons.music_note,
                    color: AppTheme.pink, size: 18)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  widget.song.title,
                  style: TextStyle(
                    color: widget.isActive
                        ? AppTheme.pink
                        : Colors.white,
                    fontSize: 13,
                    fontWeight: widget.isActive
                        ? FontWeight.w700
                        : FontWeight.w500,
                    letterSpacing: -0.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  widget.song.artist,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.38),
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (widget.isActive)
            Container(
              width: 6, height: 6,
              decoration: const BoxDecoration(
                  color: AppTheme.pink,
                  shape: BoxShape.circle),
            )
          else
            Text(
              _dur(int.tryParse(
                      widget.song.duration) ??
                  0),
              style: TextStyle(
                color: Colors.white.withOpacity(0.22),
                fontSize: 11,
              ),
            ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// OPTIONS SHEET
// ─────────────────────────────────────────────────────────────

class _OptionsSheet extends StatelessWidget {
  final Song song;
  const _OptionsSheet({required this.song});

  @override
  Widget build(BuildContext context) {
    final options = [
      (Icons.playlist_add_rounded, 'Add to Playlist',
          AppTheme.purple),
      (Icons.person_rounded, 'Go to Artist',
          Colors.white70),
      (Icons.album_rounded, 'Go to Album',
          Colors.white70),
      (Icons.radio_rounded, 'Start Radio',
          AppTheme.pinkDeep),
      (Icons.share_rounded, 'Share', Colors.white70),
    ];

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
          top: Radius.circular(28)),
      child: BackdropFilter(
        filter:
            ImageFilter.blur(sigmaX: 32, sigmaY: 32),
        child: Container(
          padding:
              const EdgeInsets.fromLTRB(24, 12, 24, 32),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.82),
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28)),
            border: Border.all(
                color: Colors.white.withOpacity(0.08)),
          ),
          child:
              Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),
            Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CachedNetworkImage(
                  imageUrl: song.image,
                  width: 52, height: 52,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(
                    width: 52, height: 52,
                    color: AppTheme.bgTertiary,
                    child: const Icon(Icons.music_note,
                        color: AppTheme.pink)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      song.artist,
                      style: TextStyle(
                        color:
                            Colors.white.withOpacity(0.45),
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 18),
            Divider(
                color: Colors.white.withOpacity(0.07)),
            const SizedBox(height: 6),
            ...options.map((o) => ListTile(
                  leading: Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: (o.$3 as Color)
                          .withOpacity(0.1),
                      borderRadius:
                          BorderRadius.circular(10),
                    ),
                    child: Icon(o.$1 as IconData,
                        color: o.$3 as Color, size: 18),
                  ),
                  title: Text(
                    o.$2 as String,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    HapticFeedback.selectionClick();
                  },
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                )),
          ]),
        ),
      ),
    );
  }
}