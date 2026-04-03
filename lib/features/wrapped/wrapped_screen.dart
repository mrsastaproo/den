import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../core/theme/app_theme.dart';
import '../../core/services/wrapped_service.dart';

class WrappedScreen extends ConsumerStatefulWidget {
  const WrappedScreen({super.key});

  @override
  ConsumerState<WrappedScreen> createState() => _WrappedScreenState();
}

class _WrappedScreenState extends ConsumerState<WrappedScreen>
    with TickerProviderStateMixin {
  WrappedPeriod _period = WrappedPeriod.week;
  final GlobalKey _cardKey = GlobalKey();
  late AnimationController _bgCtrl;
  bool _isSharing = false;

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    super.dispose();
  }

  Future<void> _shareCard() async {
    setState(() => _isSharing = true);
    HapticFeedback.mediumImpact();
    try {
      // Capture the card as image
      final boundary = _cardKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ImageByteFormat.png);
      if (byteData == null) return;

      final bytes = byteData.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/den_wrapped.png');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: '🎵 My DEN Wrapped — Check out my music stats! #DENApp #Wrapped',
      );
    } catch (e) {
      print('[Wrapped] Share error: $e');
    } finally {
      setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(wrappedStatsProvider(_period));

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back_ios_rounded,
                          color: Colors.white, size: 16),
                    ),
                  ),
                  const Spacer(),
                  ShaderMask(
                    shaderCallback: (b) =>
                        AppTheme.primaryGradient.createShader(b),
                    child: const Text(
                      'DEN WRAPPED',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _isSharing ? null : _shareCard,
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        shape: BoxShape.circle,
                      ),
                      child: _isSharing
                          ? const Padding(
                              padding: EdgeInsets.all(8),
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white),
                            )
                          : const Icon(Icons.ios_share_rounded,
                              color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms),

            // ── Period Selector ──────────────────────────────
            const SizedBox(height: 16),
            _PeriodSelector(
              selected: _period,
              onSelect: (p) => setState(() => _period = p),
            ).animate().fadeIn(delay: 100.ms, duration: 400.ms),

            const SizedBox(height: 20),

            // ── Card ────────────────────────────────────────
            Expanded(
              child: statsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.pink, strokeWidth: 2),
                ),
                error: (_, __) => _EmptyState(period: _period),
                data: (stats) => stats == null
                    ? _EmptyState(period: _period)
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        child: RepaintBoundary(
                          key: _cardKey,
                          child: _WrappedCard(
                            stats: stats,
                            bgCtrl: _bgCtrl,
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Period Selector ──────────────────────────────────────────────────────────

class _PeriodSelector extends StatelessWidget {
  final WrappedPeriod selected;
  final ValueChanged<WrappedPeriod> onSelect;

  const _PeriodSelector(
      {required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final options = [
      (WrappedPeriod.week, 'This Week'),
      (WrappedPeriod.month, 'This Month'),
      (WrappedPeriod.allTime, 'All Time'),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: options.map((o) {
        final isSel = o.$1 == selected;
        return GestureDetector(
          onTap: () => onSelect(o.$1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: isSel ? AppTheme.primaryGradient : null,
              color: isSel ? null : Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSel
                    ? Colors.transparent
                    : Colors.white.withOpacity(0.12),
              ),
            ),
            child: Text(
              o.$2,
              style: TextStyle(
                color: isSel
                    ? Colors.white
                    : Colors.white.withOpacity(0.5),
                fontSize: 13,
                fontWeight: isSel
                    ? FontWeight.w700
                    : FontWeight.w500,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Main Wrapped Card ───────────────────────────────────────────────────────

class _WrappedCard extends StatelessWidget {
  final WrappedStats stats;
  final AnimationController bgCtrl;

  const _WrappedCard({required this.stats, required this.bgCtrl});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Stack(
        children: [
          // Animated gradient background
          AnimatedBuilder(
            animation: bgCtrl,
            builder: (_, __) => CustomPaint(
              painter: _BgPainter(progress: bgCtrl.value),
              child: const SizedBox(width: double.infinity, height: 800),
            ),
          ),

          // Glass overlay
          Container(child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.55),
                    Colors.black.withOpacity(0.3),
                    Colors.black.withOpacity(0.6),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // DEN branding
                  Row(
                    children: [
                      ShaderMask(
                        shaderCallback: (b) =>
                            AppTheme.primaryGradient.createShader(b),
                        child: const Text(
                          'DEN',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _periodLabel(stats.period),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Personality badge
                  _PersonalityBadge(stats: stats)
                      .animate()
                      .fadeIn(duration: 500.ms)
                      .scale(
                          begin: const Offset(0.9, 0.9),
                          duration: 500.ms,
                          curve: Curves.easeOutBack),

                  const SizedBox(height: 20),

                  // Big stats row
                  _BigStatsRow(stats: stats)
                      .animate()
                      .fadeIn(delay: 100.ms, duration: 400.ms)
                      .slideY(begin: 0.1, end: 0, delay: 100.ms),

                  const SizedBox(height: 20),

                  // Top Artist
                  _TopArtistCard(stats: stats)
                      .animate()
                      .fadeIn(delay: 200.ms, duration: 400.ms)
                      .slideY(begin: 0.1, end: 0, delay: 200.ms),

                  const SizedBox(height: 14),

                  // Top Song
                  _TopSongCard(stats: stats)
                      .animate()
                      .fadeIn(delay: 300.ms, duration: 400.ms)
                      .slideY(begin: 0.1, end: 0, delay: 300.ms),

                  const SizedBox(height: 14),

                  // Top Songs List
                  _TopSongsList(stats: stats)
                      .animate()
                      .fadeIn(delay: 400.ms, duration: 400.ms),

                  const SizedBox(height: 14),

                  // Language + Peak Hour row
                  Row(
                    children: [
                      Expanded(
                        child: _StatChip(
                          label: 'Top Language',
                          value: stats.topLanguage,
                          emoji: stats.topLanguageEmoji,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatChip(
                          label: 'Peak Hour',
                          value: stats.peakHour,
                          emoji: '🕐',
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 500.ms, duration: 400.ms),

                  const SizedBox(height: 20),

                  // Footer
                  Center(
                    child: Text(
                      'generated by DEN • den.app',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.25),
                        fontSize: 10,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _periodLabel(WrappedPeriod p) {
    switch (p) {
      case WrappedPeriod.week: return 'THIS WEEK';
      case WrappedPeriod.month: return 'THIS MONTH';
      case WrappedPeriod.allTime: return 'ALL TIME';
    }
  }
}

// ─── Sub-widgets ─────────────────────────────────────────────────────────────

class _PersonalityBadge extends StatelessWidget {
  final WrappedStats stats;
  const _PersonalityBadge({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          AppTheme.pink.withOpacity(0.2),
          AppTheme.purple.withOpacity(0.15),
        ]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.pink.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'YOUR MUSIC PERSONALITY',
            style: TextStyle(
              color: AppTheme.pink.withOpacity(0.8),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                stats.personalityEmoji,
                style: const TextStyle(fontSize: 28),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stats.musicPersonality,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      stats.personalityDesc,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
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

class _BigStatsRow extends StatelessWidget {
  final WrappedStats stats;
  const _BigStatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _BigStat(
            value: stats.totalSongs.toString(),
            label: 'Songs Played',
            gradient: AppTheme.primaryGradient,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _BigStat(
            value: stats.totalMinutes >= 60
                ? '${(stats.totalMinutes / 60).toStringAsFixed(1)}h'
                : '${stats.totalMinutes}m',
            label: 'Time Listened',
            gradient: AppTheme.purpleGradient,
          ),
        ),
      ],
    );
  }
}

class _BigStat extends StatelessWidget {
  final String value;
  final String label;
  final LinearGradient gradient;
  const _BigStat(
      {required this.value,
      required this.label,
      required this.gradient});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          gradient.colors.first.withOpacity(0.15),
          gradient.colors.last.withOpacity(0.08),
        ]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: gradient.colors.first.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShaderMask(
            shaderCallback: (b) => gradient.createShader(b),
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopArtistCard extends StatelessWidget {
  final WrappedStats stats;
  const _TopArtistCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          // Artist image
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: stats.topArtistImage.isNotEmpty
                ? CachedNetworkImage(memCacheWidth: 400, 
                    imageUrl: stats.topArtistImage,
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) =>
                        _defaultArt(52),
                  )
                : _defaultArt(52),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TOP ARTIST',
                  style: TextStyle(
                    color: AppTheme.pink.withOpacity(0.8),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  stats.topArtist,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          ShaderMask(
            shaderCallback: (b) =>
                AppTheme.primaryGradient.createShader(b),
            child: const Icon(Icons.star_rounded,
                color: Colors.white, size: 22),
          ),
        ],
      ),
    );
  }

  Widget _defaultArt(double size) => Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
            gradient: AppTheme.primaryGradient),
        child: const Icon(Icons.person_rounded,
            color: Colors.white, size: 24),
      );
}

class _TopSongCard extends StatelessWidget {
  final WrappedStats stats;
  const _TopSongCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: stats.topSongImage.isNotEmpty
                ? CachedNetworkImage(memCacheWidth: 400, 
                    imageUrl: stats.topSongImage,
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) =>
                        _defaultArt(52),
                  )
                : _defaultArt(52),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TOP SONG',
                  style: TextStyle(
                    color: AppTheme.purple.withOpacity(0.9),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  stats.topSong,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  stats.topSongArtist,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          ShaderMask(
            shaderCallback: (b) =>
                AppTheme.purpleGradient.createShader(b),
            child: const Icon(Icons.music_note_rounded,
                color: Colors.white, size: 22),
          ),
        ],
      ),
    );
  }

  Widget _defaultArt(double size) => Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
            gradient: AppTheme.purpleGradient),
        child: const Icon(Icons.music_note_rounded,
            color: Colors.white, size: 24),
      );
}

class _TopSongsList extends StatelessWidget {
  final WrappedStats stats;
  const _TopSongsList({required this.stats});

  @override
  Widget build(BuildContext context) {
    if (stats.topSongs.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TOP 5 SONGS',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          ...stats.topSongs.asMap().entries.map((e) {
            final i = e.key;
            final s = e.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        color: i == 0
                            ? AppTheme.pink
                            : Colors.white.withOpacity(0.3),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: CachedNetworkImage(memCacheWidth: 400, 
                      imageUrl: s.image,
                      width: 32,
                      height: 32,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        width: 32,
                        height: 32,
                        color: Colors.white12,
                        child: const Icon(Icons.music_note,
                            color: Colors.white54, size: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.title,
                          style: TextStyle(
                            color: i == 0
                                ? Colors.white
                                : Colors.white
                                    .withOpacity(0.75),
                            fontSize: 12,
                            fontWeight: i == 0
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          s.artist,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.35),
                            fontSize: 10,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final String emoji;

  const _StatChip(
      {required this.label,
      required this.value,
      required this.emoji});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(emoji,
                  style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Animated Background Painter ─────────────────────────────────────────────

class _BgPainter extends CustomPainter {
  final double progress;
  _BgPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    // Dark base
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF0A0A0F),
    );

    // Animated gradient orbs
    final orbs = [
      _Orb(cx: 0.2, cy: 0.15, r: 0.4, color: AppTheme.pink, phase: 0),
      _Orb(cx: 0.8, cy: 0.7, r: 0.45, color: AppTheme.purple, phase: 0.33),
      _Orb(cx: 0.5, cy: 0.9, r: 0.3, color: AppTheme.pinkDeep, phase: 0.66),
    ];

    for (final orb in orbs) {
      final animProgress =
          (progress + orb.phase) % 1.0;
      final pulse =
          0.85 + 0.15 * math.sin(animProgress * math.pi * 2);
      final cx = orb.cx * size.width +
          math.sin(animProgress * math.pi * 2) * 20;
      final cy = orb.cy * size.height +
          math.cos(animProgress * math.pi * 2) * 15;

      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            orb.color.withOpacity(0.35),
            orb.color.withOpacity(0),
          ],
        ).createShader(Rect.fromCircle(
          center: Offset(cx, cy),
          radius: orb.r * size.width * pulse,
        ));

      canvas.drawCircle(
        Offset(cx, cy),
        orb.r * size.width * pulse,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_BgPainter old) => old.progress != progress;
}

class _Orb {
  final double cx, cy, r, phase;
  final Color color;
  const _Orb(
      {required this.cx,
      required this.cy,
      required this.r,
      required this.color,
      required this.phase});
}

// ─── Empty State ─────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final WrappedPeriod period;
  const _EmptyState({required this.period});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ShaderMask(
              shaderCallback: (b) =>
                  AppTheme.primaryGradient.createShader(b),
              child: const Icon(Icons.bar_chart_rounded,
                  color: Colors.white, size: 72),
            ),
            const SizedBox(height: 20),
            const Text(
              'Not Enough Data Yet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Listen to more songs and come back!\nYour stats will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 500.ms).scale(
        begin: const Offset(0.95, 0.95),
        duration: 500.ms,
        curve: Curves.easeOutBack);
  }
}