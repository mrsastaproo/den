import 'dart:ui';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/music_providers.dart';

import '../../core/providers/queue_meta.dart';
import '../../core/services/database_service.dart';
import '../../core/services/api_service.dart';
import '../../core/services/settings_service.dart';
import '../../core/models/song.dart';

// ─────────────────────────────────────────────────────────────
// PROVIDERS — fresh on every app session, shuffled for variety
// ─────────────────────────────────────────────────────────────
// Extra section providers
final romanticSongsProvider = FutureProvider.autoDispose<List<Song>>((ref) async {
  final lang = ref.watch(musicLanguageProvider);
  final showExplicit = ref.watch(explicitContentProvider);
  final songs = await ref.read(apiServiceProvider).getMoodMix('Love');
  final filtered = showExplicit ? songs : songs.where((s) => !s.isExplicit).toList();
  filtered.shuffle();
  return filtered;
});

final partyHitsProvider = FutureProvider.autoDispose<List<Song>>((ref) async {
  final lang = ref.watch(musicLanguageProvider);
  final showExplicit = ref.watch(explicitContentProvider);
  final songs = await ref.read(apiServiceProvider).getMoodMix('Hype');
  final filtered = showExplicit ? songs : songs.where((s) => !s.isExplicit).toList();
  filtered.shuffle();
  return filtered;
});

final chillVibesProvider = FutureProvider.autoDispose<List<Song>>((ref) async {
  final lang = ref.watch(musicLanguageProvider);
  final showExplicit = ref.watch(explicitContentProvider);
  final songs = await ref.read(apiServiceProvider).getMoodMix('Chill');
  final filtered = showExplicit ? songs : songs.where((s) => !s.isExplicit).toList();
  filtered.shuffle();
  return filtered;
});

final focusMixProvider = FutureProvider.autoDispose<List<Song>>((ref) async {
  final lang = ref.watch(musicLanguageProvider);
  final showExplicit = ref.watch(explicitContentProvider);
  final songs = await ref.read(apiServiceProvider).getMoodMix('Focus');
  final filtered = showExplicit ? songs : songs.where((s) => !s.isExplicit).toList();
  filtered.shuffle();
  return filtered;
});


final sadSongsProvider = FutureProvider.autoDispose<List<Song>>((ref) async {
  final songs = await ref.read(apiServiceProvider).getMoodMix('Sad');
  songs.shuffle();
  return songs;
});

final indieHitsProvider = FutureProvider.autoDispose<List<Song>>((ref) async {
  final lang = ref.watch(musicLanguageProvider);
  final showExplicit = ref.watch(explicitContentProvider);
  
  final songs = await ref.read(apiServiceProvider).getMoodMix('Focus');
  final extra = await ref.read(apiServiceProvider)
      .searchSongs('indie pop $lang 2025', showExplicit: showExplicit);
  final seen = <String>{};
  final merged = [...songs, ...extra]
      .where((s) => seen.add(s.id))
      .where((s) => showExplicit || !s.isExplicit)
      .toList();
  merged.shuffle();
  return merged;
});


final devotionalProvider = FutureProvider.autoDispose<List<Song>>((ref) async {
  final lang = ref.watch(musicLanguageProvider);
  final showExplicit = ref.watch(explicitContentProvider);
  
  final futures = await Future.wait([
    ref.read(apiServiceProvider).searchSongs('bhajan $lang 2025', showExplicit: showExplicit),
    ref.read(apiServiceProvider).searchSongs('devotional songs $lang', showExplicit: showExplicit),
    ref.read(apiServiceProvider).searchSongs('aarti kirtan bhajan', showExplicit: showExplicit),
  ]);
  final seen = <String>{};
  final songs = futures
      .expand((l) => l)
      .where((s) => seen.add(s.id))
      .where((s) => showExplicit || !s.isExplicit)
      .toList();
  songs.shuffle();
  return songs;
});


final punjabiBangerProvider = FutureProvider.autoDispose<List<Song>>((ref) async {
  final showExplicit = ref.watch(explicitContentProvider);
  final songs = await ref.read(apiServiceProvider)
      .searchSongs('punjabi hits diljit ap dhillon 2025', showExplicit: showExplicit);
  songs.shuffle();
  return songs;
});


final workoutBangerProvider = FutureProvider.autoDispose<List<Song>>((ref) async {
  final showExplicit = ref.watch(explicitContentProvider);
  final songs = await ref.read(apiServiceProvider)
      .searchSongs('workout gym motivation energy songs', showExplicit: showExplicit);
  songs.shuffle();
  return songs;
});


// ─────────────────────────────────────────────────────────────
// HOME SCREEN
// ─────────────────────────────────────────────────────────────

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin {
  final _scrollController = ScrollController();
  late AnimationController _orbController;
  late AnimationController _headerController;
  final ValueNotifier<double> _scrollOffset = ValueNotifier<double>(0);
  final ValueNotifier<bool> _isHeaderScrolled = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    _scrollController.addListener(() {
      _scrollOffset.value = _scrollController.offset;
      final sc = _scrollController.offset > 20;
      if (_isHeaderScrolled.value != sc) {
        _isHeaderScrolled.value = sc;
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _orbController.dispose();
    _headerController.dispose();
    _scrollOffset.dispose();
    _isHeaderScrolled.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    HapticFeedback.mediumImpact();
    final List<ProviderBase> providers = [
      sessionSeedProvider,
      trendingProvider, newReleasesProvider, topChartsProvider, throwbackProvider,
      timeBasedSongsProvider, romanticSongsProvider, partyHitsProvider,
      chillVibesProvider, focusMixProvider, sadSongsProvider, indieHitsProvider,
      devotionalProvider, punjabiBangerProvider, workoutBangerProvider
    ];
    for (final p in providers) {
      ref.invalidate(p);
    }
    // Artificial delay to let the UI shimmer beautifully before rendering
    await Future.delayed(const Duration(milliseconds: 1500));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Ambient background orbs
          _AmbientBackground(
            orbController: _orbController,
            scrollOffset: _scrollOffset,
          ),

          // Main scroll content
          RefreshIndicator(
            onRefresh: _onRefresh,
            color: AppTheme.pink,
            backgroundColor: Colors.black87,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                // Sticky glass header
                SliverPersistentHeader(
                pinned: true,
                delegate: _GlassHeaderDelegate(
                  isScrolledNotifier: _isHeaderScrolled,
                  onSearch: () => context.go('/search'),
                  onNotification: () => context.push('/notifications'),
                  onSettings: () => context.go('/settings'),
                ),
              ),

              // Greeting
              SliverToBoxAdapter(
                child: _GreetingHero(
                  orbController: _orbController,
                ).animate().fadeIn(duration: 600.ms).slideY(
                      begin: -0.08,
                      end: 0,
                      duration: 600.ms,
                      curve: Curves.easeOutCubic,
                    ),
              ),

              // Quick access grid
              const SliverToBoxAdapter(child: _QuickAccessGrid()),

              // Hero carousel (New Releases)
              const SliverToBoxAdapter(child: _HeroCarousel()),

              // Trending Now
              SliverToBoxAdapter(
                child: _LiquidSection(
                  title: 'Trending Now',
                  subtitle: "what everyone's playing",
                  icon: Icons.local_fire_department_rounded,
                  accentColor: const Color(0xFFFF6B6B),
                  provider: ref.watch(trendingProvider),
                  cardStyle: _CardStyle.standard,
                  queueMeta: const QueueMeta(context: QueueContext.trending),
                ),
              ),

              // Time-based
              SliverToBoxAdapter(
                child: _LiquidSection(
                  title: _timeGreeting(),
                  subtitle: 'curated for this moment',
                  icon: Icons.auto_awesome_rounded,
                  accentColor: AppTheme.pink,
                  provider: ref.watch(timeBasedSongsProvider),
                  cardStyle: _CardStyle.wide,
                  queueMeta: const QueueMeta(context: QueueContext.timeBased),
                ),
              ),

              // Artist Spotlight
              const SliverToBoxAdapter(child: _ArtistSpotlight()),

              // Top Charts (ranked)
              SliverToBoxAdapter(
                child: _LiquidSection(
                  title: 'Top Charts',
                  subtitle: '#1 to #∞',
                  icon: Icons.leaderboard_rounded,
                  accentColor: const Color(0xFFFFD700),
                  provider: ref.watch(topChartsProvider),
                  cardStyle: _CardStyle.ranked,
                  queueMeta: const QueueMeta(context: QueueContext.topCharts),
                ),
              ),

              // Mood Section
              const SliverToBoxAdapter(child: _MoodSection()),

              // Love Songs
              SliverToBoxAdapter(
                child: _LiquidSection(
                  title: 'Love Songs',
                  subtitle: 'straight to the heart',
                  icon: Icons.favorite_rounded,
                  accentColor: const Color(0xFFFFB3C6),
                  provider: ref.watch(romanticSongsProvider),
                  cardStyle: _CardStyle.standard,
                  queueMeta: const QueueMeta(
                      context: QueueContext.mood, mood: 'Love'),
                ),
              ),

              // Party Hits
              SliverToBoxAdapter(
                child: _LiquidSection(
                  title: 'Party Hits',
                  subtitle: 'turn it up',
                  icon: Icons.nightlife_rounded,
                  accentColor: const Color(0xFFFF85A1),
                  provider: ref.watch(partyHitsProvider),
                  cardStyle: _CardStyle.wide,
                  queueMeta: const QueueMeta(
                      context: QueueContext.mood, mood: 'Hype'),
                ),
              ),

              // Punjabi Bangers
              SliverToBoxAdapter(
                child: _LiquidSection(
                  title: 'Punjabi Bangers',
                  subtitle: 'desi flavour',
                  icon: Icons.graphic_eq_rounded,
                  accentColor: const Color(0xFFB794FF),
                  provider: ref.watch(punjabiBangerProvider),
                  cardStyle: _CardStyle.standard,
                  queueMeta:
                      const QueueMeta(context: QueueContext.general),
                ),
              ),

              // Throwback
              SliverToBoxAdapter(
                child: _LiquidSection(
                  title: 'Throwback',
                  subtitle: 'golden era hits',
                  icon: Icons.history_rounded,
                  accentColor: const Color(0xFFD4B8FF),
                  provider: ref.watch(throwbackProvider),
                  cardStyle: _CardStyle.wide,
                  queueMeta:
                      const QueueMeta(context: QueueContext.throwback),
                ),
              ),

              // Chill Vibes
              SliverToBoxAdapter(
                child: _LiquidSection(
                  title: 'Chill Vibes',
                  subtitle: 'slow it down',
                  icon: Icons.waves_rounded,
                  accentColor: const Color(0xFF89CFF0),
                  provider: ref.watch(chillVibesProvider),
                  cardStyle: _CardStyle.standard,
                  queueMeta: const QueueMeta(
                      context: QueueContext.mood, mood: 'Chill'),
                ),
              ),

              // Workout Bangers
              SliverToBoxAdapter(
                child: _LiquidSection(
                  title: 'Workout Mode',
                  subtitle: 'beast mode activated',
                  icon: Icons.fitness_center_rounded,
                  accentColor: const Color(0xFFFF6B35),
                  provider: ref.watch(workoutBangerProvider),
                  cardStyle: _CardStyle.ranked,
                  queueMeta:
                      const QueueMeta(context: QueueContext.general),
                ),
              ),

              // Sad Hours
              SliverToBoxAdapter(
                child: _LiquidSection(
                  title: 'Sad Hours',
                  subtitle: 'feel it all',
                  icon: Icons.water_drop_rounded,
                  accentColor: const Color(0xFF89CFF0),
                  provider: ref.watch(sadSongsProvider),
                  cardStyle: _CardStyle.standard,
                  queueMeta: const QueueMeta(
                      context: QueueContext.mood, mood: 'Sad'),
                ),
              ),

              // Focus Mix
              SliverToBoxAdapter(
                child: _LiquidSection(
                  title: 'Focus Mix',
                  subtitle: 'deep work playlist',
                  icon: Icons.center_focus_strong_rounded,
                  accentColor: const Color(0xFFB794FF),
                  provider: ref.watch(focusMixProvider),
                  cardStyle: _CardStyle.wide,
                  queueMeta: const QueueMeta(
                      context: QueueContext.mood, mood: 'Focus'),
                ),
              ),

              // Indie Corner
              SliverToBoxAdapter(
                child: _LiquidSection(
                  title: 'Indie Corner',
                  subtitle: 'underground gems',
                  icon: Icons.music_note_rounded,
                  accentColor: const Color(0xFF89CFF0),
                  provider: ref.watch(indieHitsProvider),
                  cardStyle: _CardStyle.ranked,
                  queueMeta:
                      const QueueMeta(context: QueueContext.general),
                ),
              ),

              // Devotional
              SliverToBoxAdapter(
                child: _LiquidSection(
                  title: 'Devotional',
                  subtitle: 'peace for the soul',
                  icon: Icons.self_improvement_rounded,
                  accentColor: const Color(0xFFFFD700),
                  provider: ref.watch(devotionalProvider),
                  cardStyle: _CardStyle.standard,
                  queueMeta:
                      const QueueMeta(context: QueueContext.general),
                ),
              ),

              // Fresh Drops compact list
              const SliverToBoxAdapter(child: _FreshDropsList()),

              // Bottom space
              SliverToBoxAdapter(child: SizedBox(height: kDenBottomPadding + 40)),
            ],
          ),
          ),
        ],
      ),
    );
  }

  static String _timeGreeting() {
    final h = DateTime.now().hour;
    if (h >= 5 && h < 12) return 'Morning Vibes ☀️';
    if (h >= 12 && h < 17) return 'Afternoon Mix 🌤️';
    if (h >= 17 && h < 21) return 'Evening Feels 🌆';
    return 'Late Night 🌙';
  }
}

// ─────────────────────────────────────────────────────────────
// AMBIENT BACKGROUND
// ─────────────────────────────────────────────────────────────

class _AmbientBackground extends StatelessWidget {
  final AnimationController orbController;
  final ValueNotifier<double> scrollOffset;

  const _AmbientBackground({
    required this.orbController,
    required this.scrollOffset,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([orbController, scrollOffset]),
      builder: (_, __) {
        final t = orbController.value;
        final parallax = (scrollOffset.value * 0.15).clamp(0.0, 120.0);
        return Stack(
          children: [
            // Top-left orb
            Positioned(
              top: -100,
              left: -80,
              child: Transform.translate(
                offset: Offset(
                  math.cos(t * math.pi) * 20,
                  math.sin(t * math.pi) * 30 - parallax * 0.5,
                ),
                child: _Orb(
                  size: 340,
                  color: AppTheme.pink,
                  opacity: 0.12 + t * 0.04,
                ),
              ),
            ),
            // Top-right orb
            Positioned(
              top: 80,
              right: -60,
              child: Transform.translate(
                offset: Offset(
                  math.sin(t * math.pi * 0.7) * 15,
                  math.cos(t * math.pi * 1.3) * 25 - parallax * 0.3,
                ),
                child: _Orb(
                  size: 260,
                  color: AppTheme.purple,
                  opacity: 0.10 + t * 0.03,
                ),
              ),
            ),
            // Mid orb
            Positioned(
              top: 500,
              left: 60,
              child: Transform.translate(
                offset: Offset(
                  math.sin(t * math.pi * 1.5) * 20,
                  -parallax * 0.2,
                ),
                child: _Orb(
                  size: 200,
                  color: AppTheme.pinkDeep,
                  opacity: 0.06 + t * 0.02,
                ),
              ),
            ),
            // Bottom orb
            Positioned(
              bottom: 300,
              right: -30,
              child: Transform.translate(
                offset: Offset(
                  math.cos(t * math.pi) * 15,
                  0,
                ),
                child: _Orb(
                  size: 240,
                  color: AppTheme.purpleDeep,
                  opacity: 0.08 + t * 0.025,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Orb extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;

  const _Orb({required this.size, required this.color, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withOpacity(opacity), color.withOpacity(0)],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// GLASS HEADER
// ─────────────────────────────────────────────────────────────

class _GlassHeaderDelegate extends SliverPersistentHeaderDelegate {
  final ValueNotifier<bool> isScrolledNotifier;
  final VoidCallback onSearch;
  final VoidCallback onNotification;
  final VoidCallback onSettings;

  _GlassHeaderDelegate({
    required this.isScrolledNotifier,
    required this.onSearch,
    required this.onNotification,
    required this.onSettings,
  });

  @override
  double get minExtent => 80;
  @override
  double get maxExtent => 80;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return ValueListenableBuilder<bool>(
      valueListenable: isScrolledNotifier,
      builder: (context, isScrolled, child) {
        return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.black.withOpacity(isScrolled ? 0.72 : 0.45),
                Colors.transparent,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            border: Border(
              bottom: BorderSide(
                color: Colors.white
                    .withOpacity(isScrolled ? 0.07 : 0.0),
                width: 0.5,
              ),
            ),
          ),
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top,
            left: 20,
            right: 20,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Logo
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.pink.withOpacity(0.35),
                          blurRadius: 14,
                          spreadRadius: -3,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.music_note_rounded,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  ShaderMask(
                    shaderCallback: (b) =>
                        AppTheme.primaryGradient.createShader(b),
                    child: const Text(
                      'DEN',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                      ),
                    ),
                  ),
                ],
              ),
              // Actions
              Row(
                children: [
                  _GlassIconBtn(
                    icon: Icons.search_rounded,
                    onTap: onSearch,
                  ),
                  const SizedBox(width: 8),
                  _GlassIconBtn(
                    icon: Icons.notifications_rounded,
                    showDot: true,
                    onTap: onNotification,
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: onSettings,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.pink.withOpacity(0.4),
                            blurRadius: 12,
                            spreadRadius: -3,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.person_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  },
);
}

  @override
  bool shouldRebuild(_GlassHeaderDelegate old) =>
      old.isScrolledNotifier != isScrolledNotifier;
}

class _GlassIconBtn extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool showDot;

  const _GlassIconBtn({
    required this.icon,
    required this.onTap,
    this.showDot = false,
  });

  @override
  State<_GlassIconBtn> createState() => _GlassIconBtnState();
}

class _GlassIconBtnState extends State<_GlassIconBtn> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? 0.88 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white
                    .withOpacity(_pressed ? 0.14 : 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: Colors.white.withOpacity(0.12)),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(widget.icon,
                      color: Colors.white.withOpacity(0.85),
                      size: 18),
                  if (widget.showDot)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.black, width: 1),
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
// GREETING HERO
// ─────────────────────────────────────────────────────────────

class _GreetingHero extends StatelessWidget {
  final AnimationController orbController;

  const _GreetingHero({required this.orbController});

  static String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    if (h < 21) return 'Good Evening';
    return 'Good Night';
  }

  static String _emoji() {
    final h = DateTime.now().hour;
    if (h < 12) return '☀️';
    if (h < 17) return '🌤️';
    if (h < 21) return '🌆';
    return '🌙';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _emoji(),
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(width: 6),
              Text(
                _greeting(),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          RichText(
            text: TextSpan(
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.0,
                height: 1.15,
              ),
              children: [
                const TextSpan(
                  text: 'What\'s your\n',
                  style: TextStyle(color: Colors.white),
                ),
                WidgetSpan(
                  child: ShaderMask(
                    shaderCallback: (b) =>
                        AppTheme.primaryGradient.createShader(b),
                    child: const Text(
                      'vibe today?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// QUICK ACCESS GRID
// ─────────────────────────────────────────────────────────────

class _QuickAccessGrid extends ConsumerWidget {
  const _QuickAccessGrid();

  // Each tile has a real Unsplash photo + dominant color wash
  static const _items = [
    _QItem(
      label: 'Trending',
      icon: Icons.local_fire_department_rounded,
      colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
      query: 'trending hindi songs 2025',
      queueContext: QueueContext.trending,
      imageUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=400&q=80',
    ),
    _QItem(
      label: 'Party Mix',
      icon: Icons.nightlife_rounded,
      colors: [Color(0xFF9B59B6), Color(0xFF6C3483)],
      query: 'party dance hindi songs',
      queueContext: QueueContext.mood,
      mood: 'Hype',
      imageUrl: 'https://images.unsplash.com/photo-1540575467063-178a50c2df87?w=400&q=80',
    ),
    _QItem(
      label: 'Chill Out',
      icon: Icons.waves_rounded,
      colors: [Color(0xFF2193B0), Color(0xFF6DD5FA)],
      query: 'chill lofi hindi',
      queueContext: QueueContext.mood,
      mood: 'Chill',
      imageUrl: 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=400&q=80',
    ),
    _QItem(
      label: 'Love Songs',
      icon: Icons.favorite_rounded,
      colors: [Color(0xFFE91E8C), Color(0xFFFF6B9D)],
      query: 'romantic love songs hindi',
      queueContext: QueueContext.mood,
      mood: 'Love',
      imageUrl: 'https://images.unsplash.com/photo-1518199266791-5375a83190b7?w=400&q=80',
    ),
    _QItem(
      label: 'Top Charts',
      icon: Icons.leaderboard_rounded,
      colors: [Color(0xFFF7971E), Color(0xFFFFD200)],
      query: 'top charts bollywood 2025',
      queueContext: QueueContext.topCharts,
      imageUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=400&q=80',
    ),
    _QItem(
      label: 'Throwback',
      icon: Icons.history_rounded,
      colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
      query: 'hindi classic 90s 2000s',
      queueContext: QueueContext.throwback,
      imageUrl: 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=400&q=80',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: GridView.builder(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 3.0,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: _items.length,
        itemBuilder: (_, i) => _QuickTile(
          key: ValueKey(_items[i].label),
          item: _items[i],
          delay: i * 50,
        ),
      ),
    );
  }
}

class _QItem {
  final String label;
  final IconData icon;
  final List<Color> colors;
  final String query;
  final String imageUrl;
  final QueueContext queueContext;
  final String? mood;

  const _QItem({
    required this.label,
    required this.icon,
    required this.colors,
    required this.query,
    required this.imageUrl,
    required this.queueContext,
    this.mood,
  });
}

class _QuickTile extends ConsumerStatefulWidget {
  final _QItem item;
  final int delay;

  const _QuickTile({super.key, required this.item, required this.delay});

  @override
  ConsumerState<_QuickTile> createState() => _QuickTileState();
}

class _QuickTileState extends ConsumerState<_QuickTile> {
  bool _pressed = false;
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: _loading ? null : _play,
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── Real background photo ──────────────────
              CachedNetworkImage(memCacheWidth: 400, 
                imageUrl: item.imageUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: item.colors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
                errorWidget: (_, __, ___) => Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: item.colors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),

              // ── Color wash overlay ─────────────────────
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      item.colors[0].withOpacity(0.72),
                      item.colors[1].withOpacity(0.55),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
              ),

              // ── Dark scrim for text legibility ─────────
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withOpacity(0.25),
                      Colors.black.withOpacity(0.05),
                    ],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
              ),

              // ── Press highlight ────────────────────────
              if (_pressed)
                Container(color: Colors.white.withOpacity(0.08)),

              // ── Content row ───────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 0),
                child: Row(
                  children: [
                    // Icon badge
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 0.8,
                        ),
                      ),
                      child: _loading
                          ? const Center(
                              child: SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          : Icon(item.icon,
                              color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                          shadows: [
                            Shadow(
                              color: Colors.black54,
                              blurRadius: 8,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(
            delay: Duration(milliseconds: widget.delay),
            duration: 400.ms)
        .slideX(
          begin: -0.08,
          end: 0,
          delay: Duration(milliseconds: widget.delay),
          duration: 400.ms,
          curve: Curves.easeOutCubic,
        );
  }

  Future<void> _play() async {
    HapticFeedback.lightImpact();
    setState(() => _loading = true);
    try {
      final songs = await ref
          .read(apiServiceProvider)
          .searchSongs(widget.item.query);
      if (songs.isNotEmpty && mounted) {
        playQueue(ref, songs, 0,
            meta: QueueMeta(
              context: widget.item.queueContext,
              mood: widget.item.mood,
            ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

// ─────────────────────────────────────────────────────────────
// HERO CAROUSEL
// ─────────────────────────────────────────────────────────────

class _HeroCarousel extends ConsumerStatefulWidget {
  const _HeroCarousel();

  @override
  ConsumerState<_HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends ConsumerState<_HeroCarousel> {
  late final PageController _pc = PageController(viewportFraction: 0.88);
  int _current = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startAutoScroll();
  }

  void _startAutoScroll() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted) return;
      final songs = ref.read(newReleasesProvider).value;
      if (songs == null || songs.isEmpty) return;

      final next = (_current + 1) % songs.length;
      if (_pc.hasClients) {
        _pc.animateToPage(
          next,
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(newReleasesProvider);

    return async.when(
      loading: () => _shimmer(context),
      error: (_, __) => const SizedBox.shrink(),
      data: (songs) {
        if (songs.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              title: 'New Releases',
              subtitle: 'fresh out now',
              icon: Icons.new_releases_rounded,
              accentColor: AppTheme.pinkDeep,
              topPadding: 12,
              onSeeAll: () {
                ref.read(searchQueryProvider.notifier).state =
                    'new releases hindi 2025';
                context.push('/search');
              },
            ),
            SizedBox(
              height: 230,
              child: PageView.builder(
                controller: _pc,
                itemCount: songs.length,
                onPageChanged: (i) => setState(() => _current = i),
                itemBuilder: (_, i) => _HeroCard(
                  key: ValueKey(songs[i].id),
                  song: songs[i],
                  isActive: i == _current,
                  gradIndex: i,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    playQueue(ref, songs, i,
                        meta: const QueueMeta(
                            context: QueueContext.newReleases));
                    ref
                        .read(databaseServiceProvider)
                        .addToHistory(songs[i]);
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Pill dots indicator
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  songs.length.clamp(0, 8),
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutCubic,
                    margin: const EdgeInsets.symmetric(horizontal: 2.5),
                    width: i == _current ? 22 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      gradient: i == _current
                          ? AppTheme.primaryGradient
                          : null,
                      color: i == _current
                          ? null
                          : Colors.white.withOpacity(0.18),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
          ],
        );
      },
    );
  }

  Widget _shimmer(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'New Releases',
          subtitle: 'fresh out now',
          icon: Icons.new_releases_rounded,
          accentColor: AppTheme.pinkDeep,
          onSeeAll: () {},
        ),
        SizedBox(
          height: 230,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 3,
            itemBuilder: (_, __) => Container(
              width: MediaQuery.of(context).size.width * 0.85,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(28),
              ),
            )
                .animate(onPlay: (c) => c.repeat())
                .shimmer(
                  duration: 1400.ms,
                  color: Colors.white.withOpacity(0.045),
                ),
          ),
        ),
      ],
    );
  }
}

class _HeroCard extends StatefulWidget {
  final Song song;
  final bool isActive;
  final int gradIndex;
  final VoidCallback onTap;

  static const _grads = [
    [Color(0xFFFF6B6B), Color(0xFFFFD93D)],
    [Color(0xFF6C63FF), Color(0xFFFF6584)],
    [Color(0xFF11998E), Color(0xFF38EF7D)],
    [Color(0xFFE91E8C), Color(0xFFFF6B9D)],
    [Color(0xFFF7971E), Color(0xFFFFD200)],
    [Color(0xFF2193B0), Color(0xFF6DD5FA)],
  ];

  const _HeroCard({
    super.key,
    required this.song,
    required this.isActive,
    required this.gradIndex,
    required this.onTap,
  });

  @override
  State<_HeroCard> createState() => _HeroCardState();
}

class _HeroCardState extends State<_HeroCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final grad = _HeroCard._grads[widget.gradIndex % _HeroCard._grads.length];

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        margin: EdgeInsets.only(
          right: 12,
          left: widget.gradIndex == 0 ? 16 : 0,
          top: widget.isActive ? 0 : 10,
          bottom: widget.isActive ? 0 : 10,
        ),
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Album art
                CachedNetworkImage(memCacheWidth: 400, 
                  imageUrl: widget.song.image,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                          colors: grad,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight),
                    ),
                  ),
                ),
                // Gradient overlay
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.88),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.3, 1.0],
                    ),
                  ),
                ),
                // Side gradient for depth
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        grad[0].withOpacity(0.2),
                        Colors.transparent,
                        grad[1].withOpacity(0.15),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
                // NEW badge
                Positioned(
                  top: 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        grad[0].withOpacity(0.95),
                        grad[1].withOpacity(0.95),
                      ]),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.35)),
                    ),
                    child: const Text(
                      'NEW',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
                // Bottom info
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.song.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                  height: 1.1,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.song.artist,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Play button
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: grad),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: grad[0].withOpacity(0.5),
                                blurRadius: 20,
                                spreadRadius: -4,
                              ),
                            ],
                          ),
                          child: const Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 28),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// LIQUID SECTION (generic horizontal scroll)
// ─────────────────────────────────────────────────────────────

enum _CardStyle { standard, wide, ranked }

class _LiquidSection extends ConsumerWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final AsyncValue<List<Song>> provider;
  final _CardStyle cardStyle;
  final QueueMeta queueMeta;

  const _LiquidSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.provider,
    required this.cardStyle,
    required this.queueMeta,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: title,
          subtitle: subtitle,
          icon: icon,
          accentColor: accentColor,
          onSeeAll: () => context.push('/search'),
        ),
        SizedBox(
          height: cardStyle == _CardStyle.wide ? 178 : 194,
          child: provider.when(
            loading: () => _LiquidShimmer(wide: cardStyle == _CardStyle.wide),
            error: (_, __) => const SizedBox.shrink(),
            data: (songs) {
              if (songs.isEmpty) return const SizedBox.shrink();
              return ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                cacheExtent: 500,
                // No physics override — inherits parent BouncingScrollPhysics
                itemCount: songs.length,
                itemBuilder: (_, i) {
                  switch (cardStyle) {
                    case _CardStyle.wide:
                      return _WideCard(
                        song: songs[i],
                        index: i,
                        accentColor: accentColor,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          playQueue(ref, songs, i, meta: queueMeta);
                        },
                      );
                    case _CardStyle.ranked:
                      return _RankedCard(
                        song: songs[i],
                        rank: i + 1,
                        accentColor: accentColor,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          playQueue(ref, songs, i, meta: queueMeta);
                        },
                      );
                    default:
                      return _StandardCard(
                        song: songs[i],
                        index: i,
                        accentColor: accentColor,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          playQueue(ref, songs, i, meta: queueMeta);
                        },
                      );
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// STANDARD CARD
// ─────────────────────────────────────────────────────────────

class _StandardCard extends StatefulWidget {
  final Song song;
  final int index;
  final Color accentColor;
  final VoidCallback onTap;

  const _StandardCard({
    required this.song,
    required this.index,
    required this.onTap,
    this.accentColor = AppTheme.pink,
  });

  @override
  State<_StandardCard> createState() => _StandardCardState();
}

class _StandardCardState extends State<_StandardCard> {
  bool _pressed = false;

  static const _fallbackGrads = [
    [Color(0xFFFFB3C6), Color(0xFFD4B8FF)],
    [Color(0xFFB794FF), Color(0xFFFFB3C6)],
    [Color(0xFFFF85A1), Color(0xFFB794FF)],
    [Color(0xFF89CFF0), Color(0xFFFFB3C6)],
    [Color(0xFFFFD700), Color(0xFFFF85A1)],
  ];

  @override
  Widget build(BuildContext context) {
    final grad = _fallbackGrads[widget.index % _fallbackGrads.length];
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      // Absorb vertical scroll to prevent phantom taps during list scrolling
      onVerticalDragStart: (_) => setState(() => _pressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? 0.93 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          width: 148,
          margin: const EdgeInsets.only(right: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Art
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    CachedNetworkImage(memCacheWidth: 400, 
                      imageUrl: widget.song.image,
                      width: 148,
                      height: 148,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        width: 148,
                        height: 148,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                              colors: grad,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight),
                        ),
                        child: const Icon(Icons.music_note,
                            color: Colors.white38, size: 44),
                      ),
                    ),
                    // Press overlay
                    if (_pressed)
                      Container(
                        width: 148,
                        height: 148,
                        color: Colors.black.withOpacity(0.2),
                      ),
                    // Play btn
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: AnimatedScale(
                        scale: _pressed ? 1.15 : 1.0,
                        duration: const Duration(milliseconds: 120),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                                colors: [
                                  widget.accentColor,
                                  widget.accentColor.withOpacity(0.7),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: widget.accentColor
                                    .withOpacity(0.45),
                                blurRadius: 12,
                                spreadRadius: -3,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.play_arrow_rounded,
                              color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.song.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                widget.song.artist,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.42),
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(
            delay: Duration(milliseconds: widget.index * 55),
            duration: 350.ms)
        .slideX(
          begin: 0.12,
          end: 0,
          delay: Duration(milliseconds: widget.index * 55),
          duration: 350.ms,
          curve: Curves.easeOutCubic,
        );
  }
}

// ─────────────────────────────────────────────────────────────
// WIDE CARD
// ─────────────────────────────────────────────────────────────

class _WideCard extends StatefulWidget {
  final Song song;
  final int index;
  final Color accentColor;
  final VoidCallback onTap;

  const _WideCard({
    required this.song,
    required this.index,
    required this.onTap,
    this.accentColor = AppTheme.pink,
  });

  @override
  State<_WideCard> createState() => _WideCardState();
}

class _WideCardState extends State<_WideCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onVerticalDragStart: (_) => setState(() => _pressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          width: 210,
          margin: const EdgeInsets.only(right: 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(memCacheWidth: 400, 
                  imageUrl: widget.song.image,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(
                    color: AppTheme.bgTertiary,
                    child: Icon(Icons.music_note,
                        color: widget.accentColor, size: 42),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.85),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.35, 1.0],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.song.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.song.artist,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.55),
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.white.withOpacity(0.3)),
                          ),
                          child: const Icon(Icons.play_arrow_rounded,
                              color: Colors.white, size: 18),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(
            delay: Duration(milliseconds: widget.index * 65),
            duration: 350.ms)
        .slideX(
          begin: 0.12,
          end: 0,
          delay: Duration(milliseconds: widget.index * 65),
          duration: 350.ms,
          curve: Curves.easeOutCubic,
        );
  }
}

// ─────────────────────────────────────────────────────────────
// RANKED CARD
// ─────────────────────────────────────────────────────────────

class _RankedCard extends StatefulWidget {
  final Song song;
  final int rank;
  final Color accentColor;
  final VoidCallback onTap;

  const _RankedCard({
    required this.song,
    required this.rank,
    required this.onTap,
    this.accentColor = AppTheme.pink,
  });

  @override
  State<_RankedCard> createState() => _RankedCardState();
}

class _RankedCardState extends State<_RankedCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onVerticalDragStart: (_) => setState(() => _pressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? 0.93 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          width: 138,
          margin: const EdgeInsets.only(right: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CachedNetworkImage(memCacheWidth: 400, 
                      imageUrl: widget.song.image,
                      width: 138,
                      height: 138,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        width: 138,
                        height: 138,
                        color: AppTheme.bgTertiary,
                        child: Icon(Icons.music_note,
                            color: widget.accentColor, size: 42),
                      ),
                    ),
                  ),
                  // Rank badge
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.75),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: widget.rank <= 3
                              ? widget.accentColor.withOpacity(0.5)
                              : Colors.white.withOpacity(0.15),
                        ),
                      ),
                      child: Text(
                        '#${widget.rank}',
                        style: TextStyle(
                          color: widget.rank <= 3
                              ? widget.accentColor
                              : Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                widget.song.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                widget.song.artist,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.42),
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(
            delay: Duration(milliseconds: widget.rank * 55),
            duration: 350.ms)
        .slideX(
          begin: 0.12,
          end: 0,
          delay: Duration(milliseconds: widget.rank * 55),
          duration: 350.ms,
          curve: Curves.easeOutCubic,
        );
  }
}

// ─────────────────────────────────────────────────────────────
// ARTIST SPOTLIGHT
// ─────────────────────────────────────────────────────────────

class _ArtistSpotlight extends ConsumerWidget {
  const _ArtistSpotlight();

  static const _artists = [
    {'name': 'Arijit Singh', 'emoji': '🎤', 'color': 0xFFFFB3C6},
    {'name': 'AP Dhillon', 'emoji': '🎵', 'color': 0xFFB794FF},
    {'name': 'Shreya Ghoshal', 'emoji': '🌟', 'color': 0xFFFFD700},
    {'name': 'Atif Aslam', 'emoji': '🎶', 'color': 0xFF89CFF0},
    {'name': 'Diljit Dosanjh', 'emoji': '🔥', 'color': 0xFFFF85A1},
    {'name': 'Neha Kakkar', 'emoji': '💫', 'color': 0xFFFF6B9D},
    {'name': 'Jubin Nautiyal', 'emoji': '🎼', 'color': 0xFFD4B8FF},
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Artist Spotlight',
          subtitle: 'your favourites',
          icon: Icons.star_rounded,
          accentColor: const Color(0xFFFFD700),
          onSeeAll: () => context.push('/search'),
        ),
        SizedBox(
          height: 108,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _artists.length,
            itemBuilder: (_, i) {
              final artist = _artists[i];
              final color = Color(artist['color'] as int);
              return _ArtistBubble(
                name: artist['name'] as String,
                emoji: artist['emoji'] as String,
                color: color,
                index: i,
                onTap: () async {
                  HapticFeedback.lightImpact();
                  final songs = await ref
                      .read(apiServiceProvider)
                      .getArtistSongs(artist['name'] as String);
                  if (songs.isNotEmpty && context.mounted) {
                    playQueue(ref, songs, 0,
                        meta: QueueMeta(
                          context: QueueContext.artist,
                          artistName: artist['name'] as String,
                        ));
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ArtistBubble extends StatefulWidget {
  final String name;
  final String emoji;
  final Color color;
  final int index;
  final VoidCallback onTap;

  const _ArtistBubble({
    required this.name,
    required this.emoji,
    required this.color,
    required this.index,
    required this.onTap,
  });

  @override
  State<_ArtistBubble> createState() => _ArtistBubbleState();
}

class _ArtistBubbleState extends State<_ArtistBubble> {
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
        child: Container(
          width: 80,
          margin: const EdgeInsets.only(right: 14),
          child: Column(
            children: [
              Container(
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      widget.color.withOpacity(0.4),
                      widget.color.withOpacity(0.15),
                    ],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.color.withOpacity(0.45),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withOpacity(0.25),
                      blurRadius: 16,
                      spreadRadius: -4,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(widget.emoji,
                      style: const TextStyle(fontSize: 28)),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.name.split(' ').first,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.1,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(
            delay: Duration(milliseconds: 80 * widget.index),
            duration: 400.ms)
        .scale(
          begin: const Offset(0.82, 0.82),
          delay: Duration(milliseconds: 80 * widget.index),
          duration: 400.ms,
          curve: Curves.easeOutBack,
        );
  }
}

// ─────────────────────────────────────────────────────────────
// MOOD SECTION
// ─────────────────────────────────────────────────────────────

class _MoodSection extends ConsumerWidget {
  const _MoodSection();

  static const _moods = [
    _Mood('Happy 😊', 'Happy', Color(0xFFFFD700), Color(0xFFFFB3C6)),
    _Mood('Sad 💔', 'Sad', Color(0xFF89CFF0), Color(0xFFB794FF)),
    _Mood('Hype 🔥', 'Hype', Color(0xFFFF85A1), Color(0xFFFF6B6B)),
    _Mood('Chill 🌊', 'Chill', Color(0xFF89CFF0), Color(0xFFD4B8FF)),
    _Mood('Focus 🎯', 'Focus', Color(0xFFB794FF), Color(0xFF89CFF0)),
    _Mood('Love 💕', 'Love', Color(0xFFFFB3C6), Color(0xFFD4B8FF)),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMood = ref.watch(selectedMoodProvider);
    final moodSongs = ref.watch(moodMixProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Mood Mix',
          subtitle: 'how are you feeling?',
          icon: Icons.mood_rounded,
          accentColor: AppTheme.purple,
          onSeeAll: () {},
          showSeeAll: false,
        ),
        // Mood pills
        SizedBox(
          height: 46,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _moods.length,
            itemBuilder: (_, i) {
              final mood = _moods[i];
              final isSelected = selectedMood == mood.key;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref.read(selectedMoodProvider.notifier).state =
                      isSelected ? null : mood.key;
                },
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 11),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? LinearGradient(
                            colors: [mood.c1, mood.c2])
                        : null,
                    color: isSelected
                        ? null
                        : Colors.white.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isSelected
                          ? Colors.transparent
                          : Colors.white.withOpacity(0.1),
                      width: 0.8,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: mood.c1.withOpacity(0.3),
                              blurRadius: 14,
                              spreadRadius: -4,
                            ),
                          ]
                        : [],
                  ),
                  child: Text(
                    mood.label,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : Colors.white.withOpacity(0.55),
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        // Mood results
        if (selectedMood != null)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: SizedBox(
              height: 194,
              child: moodSongs.when(
                loading: () => const _LiquidShimmer(wide: false),
                error: (_, __) => const SizedBox.shrink(),
                data: (songs) {
                  if (songs.isEmpty) return const SizedBox.shrink();
                  return ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: songs.length,
                    itemBuilder: (_, i) => _StandardCard(
                      song: songs[i],
                      index: i,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        playQueue(ref, songs, i,
                            meta: QueueMeta(
                              context: QueueContext.mood,
                              mood: selectedMood,
                            ));
                      },
                    ),
                  );
                },
              ),
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _Mood {
  final String label;
  final String key;
  final Color c1;
  final Color c2;

  const _Mood(this.label, this.key, this.c1, this.c2);
}

// ─────────────────────────────────────────────────────────────
// FRESH DROPS (compact vertical list)
// ─────────────────────────────────────────────────────────────

class _FreshDropsList extends ConsumerWidget {
  const _FreshDropsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(newReleasesProvider);

    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (songs) {
        if (songs.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              title: 'Fresh Drops',
              subtitle: 'just landed',
              icon: Icons.fiber_new_rounded,
              accentColor: AppTheme.pinkDeep,
              onSeeAll: () {
                ref.read(searchQueryProvider.notifier).state =
                    'new hindi fresh songs 2025';
                context.push('/search');
              },
            ),
            ...songs.take(8).toList().asMap().entries.map((e) {
              final i = e.key;
              final song = e.value;
              return _FreshDropTile(
                song: song,
                index: i,
                onTap: () {
                  HapticFeedback.lightImpact();
                  playQueue(ref, songs, i,
                      meta: const QueueMeta(
                          context: QueueContext.newReleases));
                },
              );
            }),
          ],
        );
      },
    );
  }
}

class _FreshDropTile extends StatefulWidget {
  final Song song;
  final int index;
  final VoidCallback onTap;

  const _FreshDropTile({
    required this.song,
    required this.index,
    required this.onTap,
  });

  @override
  State<_FreshDropTile> createState() => _FreshDropTileState();
}

class _FreshDropTileState extends State<_FreshDropTile> {
  bool _pressed = false;

  String _fmt(int s) {
    if (s <= 0) return '';
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _pressed
              ? Colors.white.withOpacity(0.07)
              : Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(_pressed ? 0.1 : 0.04),
          ),
        ),
        child: Row(
          children: [
            // Number
            SizedBox(
              width: 28,
              child: Text(
                '${widget.index + 1}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.25),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 8),
            // Art
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(memCacheWidth: 400, 
                imageUrl: widget.song.image,
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  width: 50,
                  height: 50,
                  color: AppTheme.bgTertiary,
                  child: const Icon(Icons.music_note,
                      color: AppTheme.pink, size: 22),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.song.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.song.artist,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.42),
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Text(
              _fmt(int.tryParse(widget.song.duration) ?? 0),
              style: TextStyle(
                color: Colors.white.withOpacity(0.28),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(
            delay: Duration(milliseconds: 60 * widget.index),
            duration: 350.ms)
        .slideX(
          begin: -0.04,
          end: 0,
          delay: Duration(milliseconds: 60 * widget.index),
          duration: 350.ms,
          curve: Curves.easeOutCubic,
        );
  }
}

// ─────────────────────────────────────────────────────────────
// SECTION HEADER
// ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onSeeAll;
  final bool showSeeAll;
  final double? topPadding;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.onSeeAll,
    this.showSeeAll = true,
    this.topPadding,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, topPadding ?? 30, 20, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: accentColor.withOpacity(0.22),
                    width: 0.8,
                  ),
                ),
                child: Icon(icon, color: accentColor, size: 18),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.35),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (showSeeAll)
            GestureDetector(
              onTap: onSeeAll,
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.1)),
                ),
                child: Text(
                  'See all',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.55),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideX(
        begin: -0.04,
        end: 0,
        duration: 400.ms,
        curve: Curves.easeOutCubic);
  }
}

// ─────────────────────────────────────────────────────────────
// SHIMMER
// ─────────────────────────────────────────────────────────────

class _LiquidShimmer extends StatelessWidget {
  final bool wide;
  const _LiquidShimmer({this.wide = false});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 5,
      itemBuilder: (_, __) => Container(
        width: wide ? 210 : 148,
        height: wide ? 178 : 148,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(wide ? 18 : 16),
        ),
      )
          .animate(onPlay: (c) => c.repeat())
          .shimmer(
            duration: 1400.ms,
            color: Colors.white.withOpacity(0.045),
          ),
    );
  }
}