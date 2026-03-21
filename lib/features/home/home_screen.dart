import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/music_providers.dart';
import '../../core/services/player_service.dart';
import '../../core/providers/queue_meta.dart';
import '../../core/services/database_service.dart';
import '../../core/services/api_service.dart';
import '../../core/models/song.dart';

// ─── EXTRA PROVIDERS ──────────────────────────────────────────

final romanticSongsProvider = FutureProvider<List<Song>>((ref) async {
  return ref.read(apiServiceProvider).getMoodMix('Love');
});

final partyHitsProvider = FutureProvider<List<Song>>((ref) async {
  return ref.read(apiServiceProvider).getMoodMix('Hype');
});

final chillVibesProvider = FutureProvider<List<Song>>((ref) async {
  return ref.read(apiServiceProvider).getMoodMix('Chill');
});

final indieHitsProvider = FutureProvider<List<Song>>((ref) async {
  return ref.read(apiServiceProvider).searchSongs('indie hindi independent artists 2024');
});

final devotionalProvider = FutureProvider<List<Song>>((ref) async {
  return ref.read(apiServiceProvider).searchSongs('best bhajan devotional hindi');
});

// ─── HOME SCREEN ──────────────────────────────────────────────

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          // ── Sticky Header ──────────────────────────────────
          SliverPersistentHeader(
            pinned: true,
            delegate: _StickyHeaderDelegate(),
          ),

          // ── Greeting + Quick Plays ──────────────────────────
          const SliverToBoxAdapter(child: _GreetingSection()),

          // ── Recently Played Row (6 tiles, 2 rows of 3) ─────
          const SliverToBoxAdapter(child: _RecentQuickGrid()),

          // ── Featured New Releases Carousel ──────────────────
          const SliverToBoxAdapter(child: _FeaturedCarousel()),

          // ── Trending Now ────────────────────────────────────
          SliverToBoxAdapter(
            child: _HorizontalSection(
              title: 'Trending Now',
              icon: Icons.local_fire_department_rounded,
              provider: ref.watch(trendingProvider),
              cardStyle: _CardStyle.standard,
              queueMeta: const QueueMeta(context: QueueContext.trending),
            ),
          ),

          // ── Made For You (time-based) ───────────────────────
          SliverToBoxAdapter(
            child: _HorizontalSection(
              title: _timeLabel(),
              icon: Icons.wb_sunny_rounded,
              provider: ref.watch(timeBasedSongsProvider),
              cardStyle: _CardStyle.wide,
              showNumberBadge: false,
              queueMeta: const QueueMeta(context: QueueContext.timeBased),
            ),
          ),

          // ── Artist Spotlight ────────────────────────────────
          const SliverToBoxAdapter(child: _ArtistSpotlightRow()),

          // ── Top Charts ──────────────────────────────────────
          SliverToBoxAdapter(
            child: _HorizontalSection(
              title: 'Top Charts',
              icon: Icons.bar_chart_rounded,
              provider: ref.watch(topChartsProvider),
              cardStyle: _CardStyle.ranked,
              queueMeta: const QueueMeta(context: QueueContext.topCharts),
            ),
          ),

          // ── Mood Pills + Mix ────────────────────────────────
          const SliverToBoxAdapter(child: _MoodSection()),

          // ── Love Songs ──────────────────────────────────────
          SliverToBoxAdapter(
            child: _HorizontalSection(
              title: 'Love Songs 💕',
              icon: Icons.favorite_rounded,
              provider: ref.watch(romanticSongsProvider),
              cardStyle: _CardStyle.standard,
              accentColor: const Color(0xFFFFB3C6),
              queueMeta: const QueueMeta(context: QueueContext.mood, mood: 'Love'),
            ),
          ),

          // ── Party Hits ──────────────────────────────────────
          SliverToBoxAdapter(
            child: _HorizontalSection(
              title: 'Party Hits 🔥',
              icon: Icons.nightlife_rounded,
              provider: ref.watch(partyHitsProvider),
              cardStyle: _CardStyle.standard,
              accentColor: const Color(0xFFFF85A1),
              queueMeta: const QueueMeta(context: QueueContext.mood, mood: 'Hype'),
            ),
          ),

          // ── Throwback ────────────────────────────────────────
          SliverToBoxAdapter(
            child: _HorizontalSection(
              title: 'Throwback 🕰️',
              icon: Icons.history_rounded,
              provider: ref.watch(throwbackProvider),
              cardStyle: _CardStyle.wide,
              showNumberBadge: false,
              queueMeta: const QueueMeta(context: QueueContext.throwback),
            ),
          ),

          // ── Chill Vibes ──────────────────────────────────────
          SliverToBoxAdapter(
            child: _HorizontalSection(
              title: 'Chill Vibes 🌊',
              icon: Icons.waves_rounded,
              provider: ref.watch(chillVibesProvider),
              cardStyle: _CardStyle.standard,
              accentColor: const Color(0xFFD4B8FF),
              queueMeta: const QueueMeta(context: QueueContext.mood, mood: 'Chill'),
            ),
          ),

          // ── Indie Corner ─────────────────────────────────────
          SliverToBoxAdapter(
            child: _HorizontalSection(
              title: 'Indie Corner 🎸',
              icon: Icons.music_note_rounded,
              provider: ref.watch(indieHitsProvider),
              cardStyle: _CardStyle.ranked,
              accentColor: const Color(0xFFB794FF),
              queueMeta: const QueueMeta(context: QueueContext.mood, mood: 'Focus'),
            ),
          ),

          // ── Devotional ───────────────────────────────────────
          SliverToBoxAdapter(
            child: _HorizontalSection(
              title: 'Devotional 🙏',
              icon: Icons.self_improvement_rounded,
              provider: ref.watch(devotionalProvider),
              cardStyle: _CardStyle.standard,
              queueMeta: const QueueMeta(context: QueueContext.general),
            ),
          ),

          // ── New Releases List (vertical compact) ─────────────
          const SliverToBoxAdapter(child: _NewReleasesCompact()),

          // ── Bottom padding for mini player ───────────────────
          const SliverToBoxAdapter(
            child: SizedBox(height: 160),
          ),
        ],
      ),
    );
  }

  static String _timeLabel() {
    final h = DateTime.now().hour;
    if (h >= 5 && h < 12) return 'Good Morning ☀️';
    if (h >= 12 && h < 17) return 'Good Afternoon 🌤️';
    if (h >= 17 && h < 21) return 'Good Evening 🌆';
    return 'Late Night 🌙';
  }
}

// ─── CARD STYLE ENUM ──────────────────────────────────────────

enum _CardStyle { standard, wide, ranked }

// ─── STICKY HEADER ────────────────────────────────────────────

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  @override
  double get minExtent => 80;
  @override
  double get maxExtent => 80;

  @override
  Widget build(BuildContext context, double shrinkOffset,
      bool overlapsContent) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.black.withOpacity(0.7),
                Colors.black.withOpacity(0.3),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withOpacity(0.06)),
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
              ShaderMask(
                shaderCallback: (b) =>
                    AppTheme.primaryGradient.createShader(b),
                child: const Text(
                  'DEN',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
                ),
              ),
              Row(
                children: [
                  _HeaderBtn(
                    icon: Icons.search_rounded,
                    onTap: () => context.go('/search'),
                  ),
                  const SizedBox(width: 8),
                  _HeaderBtn(
                    icon: Icons.notifications_rounded,
                    showDot: true,
                    onTap: () {},
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 36,
                    height: 36,
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
                    child: const Icon(Icons.person_rounded,
                        color: Colors.white, size: 18),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate _) =>
      false;
}

class _HeaderBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool showDot;

  const _HeaderBtn({
    required this.icon,
    required this.onTap,
    this.showDot = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: Colors.white.withOpacity(0.12)),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(icon,
                    color: Colors.white.withOpacity(0.8),
                    size: 18),
                if (showDot)
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
    );
  }
}

// ─── GREETING SECTION ─────────────────────────────────────────

class _GreetingSection extends ConsumerWidget {
  const _GreetingSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final h = DateTime.now().hour;
    final greeting = h < 12
        ? 'Good Morning'
        : h < 17
            ? 'Good Afternoon'
            : h < 21
                ? 'Good Evening'
                : 'Late Night';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            greeting,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 13,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'What do you feel\nlike today?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
              height: 1.2,
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 500.ms)
        .slideY(begin: -0.1, end: 0, duration: 500.ms);
  }
}

// ─── RECENT QUICK GRID ────────────────────────────────────────
// 2×3 grid of recently played / quick access tiles

class _RecentQuickGrid extends ConsumerWidget {
  const _RecentQuickGrid();

  static const _quickItems = [
    _QuickItem('Trending', Icons.local_fire_department_rounded,
        [Color(0xFFFFB3C6), Color(0xFFFF85A1)], 'trending hindi songs 2025',
        queueContext: QueueContext.trending),
    _QuickItem('Party Mix', Icons.nightlife_rounded,
        [Color(0xFFB794FF), Color(0xFFD4B8FF)], 'party dance hindi songs',
        queueContext: QueueContext.mood, mood: 'Hype'),
    _QuickItem('Chill Out', Icons.waves_rounded,
        [Color(0xFF89CFF0), Color(0xFFB794FF)], 'chill lofi hindi',
        queueContext: QueueContext.mood, mood: 'Chill'),
    _QuickItem('Love Songs', Icons.favorite_rounded,
        [Color(0xFFFFB3C6), Color(0xFFD4B8FF)], 'romantic love songs hindi',
        queueContext: QueueContext.mood, mood: 'Love'),
    _QuickItem('Top Charts', Icons.bar_chart_rounded,
        [Color(0xFFFF85A1), Color(0xFFB794FF)], 'top charts bollywood 2025',
        queueContext: QueueContext.topCharts),
    _QuickItem('Throwback', Icons.history_rounded,
        [Color(0xFFD4B8FF), Color(0xFF89CFF0)], 'hindi classic 90s 2000s',
        queueContext: QueueContext.throwback),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 3.0,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: _quickItems.length,
        itemBuilder: (context, index) {
          final item = _quickItems[index];
          return GestureDetector(
            onTap: () async {
              HapticFeedback.lightImpact();
              final songs = await ref
                  .read(apiServiceProvider)
                  .searchSongs(item.query);
              if (songs.isNotEmpty) {
                playQueue(ref, songs, 0,
                  meta: QueueMeta(
                    context: item.queueContext,
                    mood: item.mood,
                  ));
              }
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: BackdropFilter(
                filter:
                    ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        item.colors[0].withOpacity(0.25),
                        item.colors[1].withOpacity(0.12),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: item.colors[0].withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                              colors: item.colors),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(10),
                            bottomLeft: Radius.circular(10),
                          ),
                        ),
                        child: Icon(item.icon,
                            color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
                  delay: Duration(milliseconds: 50 * index),
                  duration: 400.ms)
              .slideX(
                begin: -0.1,
                end: 0,
                delay: Duration(milliseconds: 50 * index),
                duration: 400.ms,
              );
        },
      ),
    );
  }
}

class _QuickItem {
  final String label;
  final IconData icon;
  final List<Color> colors;
  final String query;
  final QueueContext queueContext;
  final String? mood;
  const _QuickItem(this.label, this.icon, this.colors, this.query,
      {this.queueContext = QueueContext.general, this.mood});
}

// ─── FEATURED CAROUSEL ────────────────────────────────────────

class _FeaturedCarousel extends ConsumerStatefulWidget {
  const _FeaturedCarousel();

  @override
  ConsumerState<_FeaturedCarousel> createState() =>
      _FeaturedCarouselState();
}

class _FeaturedCarouselState extends ConsumerState<_FeaturedCarousel> {
  late PageController _pc;
  int _current = 0;

  @override
  void initState() {
    super.initState();
    _pc = PageController(viewportFraction: 0.88);
    Future.delayed(const Duration(seconds: 3), _autoScroll);
  }

  void _autoScroll() {
    if (!mounted) return;
    Future.delayed(const Duration(seconds: 4), () {
      if (!mounted) return;
      final songs = ref.read(newReleasesProvider).value;
      if (songs == null || songs.isEmpty) return;
      final next = (_current + 1) % songs.length;
      _pc.animateToPage(next,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic);
      _autoScroll();
    });
  }

  @override
  void dispose() {
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
              icon: Icons.new_releases_rounded,
              onSeeAll: () {
                ref.read(searchQueryProvider.notifier).state =
                    'new releases hindi 2025';
                context.push('/search');
              },
            ),
            SizedBox(
              height: 215,
              child: PageView.builder(
                controller: _pc,
                itemCount: songs.length,
                onPageChanged: (i) =>
                    setState(() => _current = i),
                itemBuilder: (_, i) => _FeaturedCard(
                  song: songs[i],
                  isActive: i == _current,
                  index: i,
                  onTap: () {
                    playQueue(ref, songs, i,
                        meta: const QueueMeta(context: QueueContext.newReleases));
                    ref
                        .read(databaseServiceProvider)
                        .addToHistory(songs[i]);
                  },
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                songs.length > 6 ? 6 : songs.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _current ? 20 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    gradient: i == _current
                        ? AppTheme.primaryGradient
                        : null,
                    color: i == _current
                        ? null
                        : Colors.white.withOpacity(0.2),
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
        _SectionHeader(title: 'New Releases',
            icon: Icons.new_releases_rounded, onSeeAll: () {}),
        SizedBox(
          height: 215,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 3,
            itemBuilder: (_, __) => Container(
              width: MediaQuery.of(context).size.width * 0.84,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(24),
              ),
            ).animate(onPlay: (c) => c.repeat()).shimmer(
                duration: 1200.ms,
                color: Colors.white.withOpacity(0.05)),
          ),
        ),
      ],
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  final Song song;
  final bool isActive;
  final int index;
  final VoidCallback onTap;

  static const _grads = [
    [Color(0xFFFFB3C6), Color(0xFFD4B8FF)],
    [Color(0xFFB794FF), Color(0xFFFFB3C6)],
    [Color(0xFFFF85A1), Color(0xFFB794FF)],
    [Color(0xFFD4B8FF), Color(0xFFFF85A1)],
  ];

  const _FeaturedCard({
    required this.song,
    required this.isActive,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final grad = _grads[index % _grads.length];
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: EdgeInsets.only(
        right: 12,
        left: index == 0 ? 16 : 0,
        top: isActive ? 0 : 8,
        bottom: isActive ? 0 : 8,
      ),
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: song.image,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: grad),
                  ),
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
              // NEW badge
              Positioned(
                top: 14,
                left: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      grad[0].withOpacity(0.8),
                      grad[1].withOpacity(0.8),
                    ]),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.3)),
                  ),
                  child: const Text('NEW',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      )),
                ),
              ),
              // Song info + play
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(song.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 3),
                            Text(song.artist,
                                style: TextStyle(
                                  color: Colors.white
                                      .withOpacity(0.65),
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient:
                              LinearGradient(colors: grad),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: grad[0].withOpacity(0.5),
                              blurRadius: 16,
                              spreadRadius: -4,
                            ),
                          ],
                        ),
                        child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 26),
                      ),
                    ],
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

// ─── GENERIC HORIZONTAL SECTION ───────────────────────────────

class _HorizontalSection extends ConsumerWidget {
  final String title;
  final IconData icon;
  final AsyncValue<List<Song>> provider;
  final _CardStyle cardStyle;
  final bool showNumberBadge;
  final Color? accentColor;
  final QueueMeta queueMeta;

  const _HorizontalSection({
    required this.title,
    required this.icon,
    required this.provider,
    required this.cardStyle,
    this.showNumberBadge = true,
    this.accentColor,
    this.queueMeta = const QueueMeta(),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: title,
          icon: icon,
          accentColor: accentColor,
          onSeeAll: () => context.push('/search'),
        ),
        SizedBox(
          height: cardStyle == _CardStyle.wide ? 170 : 185,
          child: provider.when(
            loading: () => _Shimmer(
                wide: cardStyle == _CardStyle.wide),
            error: (_, __) => const SizedBox.shrink(),
            data: (songs) {
              if (songs.isEmpty) return const SizedBox.shrink();
              return ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16),
                // Use songs.length — no cap, let it scroll
                itemCount: songs.length,
                itemBuilder: (context, index) {
                  switch (cardStyle) {
                    case _CardStyle.wide:
                      return _WideCard(
                        song: songs[index],
                        index: index,
                        onTap: () => playQueue(ref, songs, index, meta: queueMeta),
                      );
                    case _CardStyle.ranked:
                      return _RankedCard(
                        song: songs[index],
                        rank: index + 1,
                        onTap: () => playQueue(ref, songs, index, meta: queueMeta),
                      );
                    case _CardStyle.standard:
                    default:
                      return _StandardCard(
                        song: songs[index],
                        index: index,
                        accentColor: accentColor,
                        onTap: () => playQueue(ref, songs, index, meta: queueMeta),
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

// ─── STANDARD CARD (145×175) ──────────────────────────────────

class _StandardCard extends StatelessWidget {
  final Song song;
  final int index;
  final Color? accentColor;
  final VoidCallback onTap;

  static const _grads = [
    [Color(0xFFFFB3C6), Color(0xFFD4B8FF)],
    [Color(0xFFB794FF), Color(0xFFFFB3C6)],
    [Color(0xFFFF85A1), Color(0xFFB794FF)],
    [Color(0xFFD4B8FF), Color(0xFFFF85A1)],
    [Color(0xFFFFB3C6), Color(0xFFB794FF)],
  ];

  const _StandardCard({
    required this.song,
    required this.index,
    required this.onTap,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final grad = _grads[index % _grads.length];
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Art
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: song.image,
                    width: 140,
                    height: 140,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                          gradient: LinearGradient(
                              colors: grad,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight)),
                      child: const Icon(Icons.music_note,
                          color: Colors.white38, size: 40),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color:
                                Colors.white.withOpacity(0.2)),
                      ),
                      child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 18),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(song.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(song.artist,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.45),
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(
            delay: Duration(milliseconds: index * 60),
            duration: 350.ms)
        .slideX(
          begin: 0.15,
          end: 0,
          delay: Duration(milliseconds: index * 60),
          duration: 350.ms,
          curve: Curves.easeOutCubic,
        );
  }
}

// ─── WIDE CARD (200×150) ──────────────────────────────────────

class _WideCard extends StatelessWidget {
  final Song song;
  final int index;
  final VoidCallback onTap;

  const _WideCard({
    required this.song,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: 200,
        margin: const EdgeInsets.only(right: 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: song.image,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  color: AppTheme.bgTertiary,
                  child: const Icon(Icons.music_note,
                      color: AppTheme.pink, size: 36),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.8),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.4, 1.0],
                  ),
                ),
              ),
              Positioned(
                bottom: 10,
                left: 12,
                right: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(song.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text(song.artist,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.55),
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
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
            delay: Duration(milliseconds: index * 70),
            duration: 350.ms)
        .slideX(
          begin: 0.15,
          end: 0,
          delay: Duration(milliseconds: index * 70),
          duration: 350.ms,
          curve: Curves.easeOutCubic,
        );
  }
}

// ─── RANKED CARD (130×175) ────────────────────────────────────

class _RankedCard extends StatelessWidget {
  final Song song;
  final int rank;
  final VoidCallback onTap;

  const _RankedCard({
    required this.song,
    required this.rank,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: 130,
        margin: const EdgeInsets.only(right: 12),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: CachedNetworkImage(
                    imageUrl: song.image,
                    width: 130,
                    height: 130,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                      width: 130,
                      height: 130,
                      color: AppTheme.bgTertiary,
                      child: const Icon(Icons.music_note,
                          color: AppTheme.pink, size: 36),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(song.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(song.artist,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.45),
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
            // Rank badge
            Positioned(
              top: 8,
              left: 8,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: BackdropFilter(
                  filter:
                      ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color:
                              Colors.white.withOpacity(0.15)),
                    ),
                    child: Text(
                      '#$rank',
                      style: const TextStyle(
                        color: AppTheme.pink,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(
            delay: Duration(milliseconds: rank * 60),
            duration: 350.ms)
        .slideX(
          begin: 0.15,
          end: 0,
          delay: Duration(milliseconds: rank * 60),
          duration: 350.ms,
          curve: Curves.easeOutCubic,
        );
  }
}

// ─── ARTIST SPOTLIGHT ROW ─────────────────────────────────────

class _ArtistSpotlightRow extends ConsumerWidget {
  const _ArtistSpotlightRow();

  static const _artists = [
    {'name': 'Arijit Singh', 'emoji': '🎤'},
    {'name': 'AP Dhillon', 'emoji': '🎵'},
    {'name': 'Shreya Ghoshal', 'emoji': '🌟'},
    {'name': 'Atif Aslam', 'emoji': '🎶'},
    {'name': 'Diljit Dosanjh', 'emoji': '🔥'},
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Artist Spotlight',
          icon: Icons.star_rounded,
          onSeeAll: () => context.push('/search'),
        ),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding:
                const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _artists.length,
            itemBuilder: (context, index) {
              final artist = _artists[index];
              return GestureDetector(
                onTap: () async {
                  HapticFeedback.lightImpact();
                  final songs = await ref
                      .read(apiServiceProvider)
                      .getArtistSongs(artist['name']!);
                  if (songs.isNotEmpty) {
                    playQueue(ref, songs, 0,
                      meta: QueueMeta(
                        context: QueueContext.artist,
                        artistName: artist['name'],
                      ));
                  }
                },
                child: Container(
                  width: 80,
                  margin: const EdgeInsets.only(right: 14),
                  child: Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color:
                                  AppTheme.pink.withOpacity(0.3),
                              blurRadius: 12,
                              spreadRadius: -3,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            artist['emoji']!,
                            style: const TextStyle(fontSize: 28),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        artist['name']!.split(' ').first,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              )
                  .animate()
                  .fadeIn(
                    delay: Duration(
                        milliseconds: 80 * index),
                    duration: 400.ms,
                  )
                  .scale(
                    begin: const Offset(0.85, 0.85),
                    delay: Duration(
                        milliseconds: 80 * index),
                    duration: 400.ms,
                    curve: Curves.easeOutBack,
                  );
            },
          ),
        ),
      ],
    );
  }
}

// ─── MOOD SECTION ─────────────────────────────────────────────

class _MoodSection extends ConsumerWidget {
  const _MoodSection();

  static const _moods = [
    ('Happy 😊', 'Happy', [Color(0xFFFFD700), Color(0xFFFFB3C6)]),
    ('Sad 💔', 'Sad', [Color(0xFF89CFF0), Color(0xFFB794FF)]),
    ('Hype 🔥', 'Hype', [Color(0xFFFF85A1), Color(0xFFFF6B6B)]),
    ('Chill 🌊', 'Chill', [Color(0xFF89CFF0), Color(0xFFD4B8FF)]),
    ('Focus 🎯', 'Focus', [Color(0xFFB794FF), Color(0xFF89CFF0)]),
    ('Love 💕', 'Love', [Color(0xFFFFB3C6), Color(0xFFD4B8FF)]),
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
          icon: Icons.mood_rounded,
          onSeeAll: () {},
          showSeeAll: false,
        ),
        // Mood pills
        SizedBox(
          height: 44,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding:
                const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _moods.length,
            itemBuilder: (_, i) {
              final (label, key, colors) = _moods[i];
              final isSelected = selectedMood == key;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref
                      .read(selectedMoodProvider.notifier)
                      .state = isSelected ? null : key;
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? LinearGradient(colors: colors)
                        : null,
                    color: isSelected
                        ? null
                        : Colors.white.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: isSelected
                          ? Colors.transparent
                          : Colors.white.withOpacity(0.12),
                    ),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : Colors.white.withOpacity(0.6),
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
        // Results
        if (selectedMood != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: SizedBox(
              height: 185,
              child: moodSongs.when(
                loading: () =>
                    const _Shimmer(wide: false),
                error: (_, __) =>
                    const SizedBox.shrink(),
                data: (songs) {
                  if (songs.isEmpty)
                    return const SizedBox.shrink();
                  return ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16),
                    itemCount: songs.length,
                    itemBuilder: (_, i) => _StandardCard(
                      song: songs[i],
                      index: i,
                      onTap: () => playQueue(ref, songs, i,
                        meta: QueueMeta(
                          context: QueueContext.mood,
                          mood: selectedMood,
                        )),
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

// ─── NEW RELEASES COMPACT LIST ────────────────────────────────

class _NewReleasesCompact extends ConsumerWidget {
  const _NewReleasesCompact();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(newReleasesProvider);

    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (songs) {
        if (songs.isEmpty) return const SizedBox.shrink();
        final display = songs.take(6).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              title: 'Fresh Drops',
              icon: Icons.fiber_new_rounded,
              onSeeAll: () {
                ref.read(searchQueryProvider.notifier).state =
                    'new hindi fresh songs 2025';
                context.push('/search');
              },
            ),
            ...display.asMap().entries.map((e) {
              final i = e.key;
              final song = e.value;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  // ✅ FIX: play full list so next song is correct
                  playQueue(ref, display, i,
                    meta: const QueueMeta(context: QueueContext.newReleases));
                },
                child: Container(
                  margin: const EdgeInsets.fromLTRB(
                      16, 0, 16, 2),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius:
                            BorderRadius.circular(10),
                        child: CachedNetworkImage(
                          imageUrl: song.image,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              Container(
                            width: 48,
                            height: 48,
                            color: AppTheme.bgTertiary,
                            child: const Icon(
                                Icons.music_note,
                                color: AppTheme.pink,
                                size: 22),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(song.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight:
                                      FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow:
                                    TextOverflow.ellipsis),
                            const SizedBox(height: 2),
                            Text(song.artist,
                                style: TextStyle(
                                  color: Colors.white
                                      .withOpacity(0.45),
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow:
                                    TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      Text(
                        _fmt(
                            int.tryParse(song.duration) ??
                                0),
                        style: TextStyle(
                          color:
                              Colors.white.withOpacity(0.3),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              )
                  .animate()
                  .fadeIn(
                    delay:
                        Duration(milliseconds: 60 * i),
                    duration: 350.ms,
                  )
                  .slideX(
                    begin: -0.05,
                    end: 0,
                    delay:
                        Duration(milliseconds: 60 * i),
                    duration: 350.ms,
                  );
            }),
          ],
        );
      },
    );
  }

  String _fmt(int seconds) {
    if (seconds <= 0) return '';
    final m = seconds ~/ 60;
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// ─── SECTION HEADER ───────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onSeeAll;
  final Color? accentColor;
  final bool showSeeAll;

  const _SectionHeader({
    required this.title,
    required this.icon,
    required this.onSeeAll,
    this.accentColor,
    this.showSeeAll = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              ShaderMask(
                shaderCallback: (b) =>
                    (accentColor != null
                            ? LinearGradient(colors: [
                                accentColor!,
                                accentColor!
                              ])
                            : AppTheme.primaryGradient)
                        .createShader(b),
                child: Icon(icon,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          if (showSeeAll)
            GestureDetector(
              onTap: onSeeAll,
              child: ShaderMask(
                shaderCallback: (b) =>
                    AppTheme.primaryGradient.createShader(b),
                child: const Text(
                  'See all',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideX(
        begin: -0.05, end: 0, duration: 400.ms);
  }
}

// ─── SHIMMER PLACEHOLDER ──────────────────────────────────────

class _Shimmer extends StatelessWidget {
  final bool wide;
  const _Shimmer({this.wide = false});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 5,
      itemBuilder: (_, __) => Container(
        width: wide ? 200 : 140,
        height: wide ? 160 : 140,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
        ),
      )
          .animate(onPlay: (c) => c.repeat())
          .shimmer(
            duration: 1200.ms,
            color: Colors.white.withOpacity(0.04),
          ),
    );
  }
}