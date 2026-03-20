import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/music_providers.dart';
import '../../core/services/player_service.dart';
import '../../core/services/database_service.dart';
import '../../shared/widgets/glass_container.dart';
import '../../shared/widgets/featured_banner.dart';
import '../../shared/widgets/trending_section.dart';
import '../../shared/widgets/top_charts_section.dart';
import '../../shared/widgets/mood_section.dart';
import '../../shared/widgets/time_based_section.dart';
import '../../shared/widgets/recently_played_section.dart';
import '../../shared/widgets/throwback_section.dart';
import '../../shared/widgets/artist_spotlight_section.dart';
import '../../shared/widgets/mood_mix_section.dart';
import '../../core/services/api_service.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Premium Sticky Header
          SliverPersistentHeader(
            pinned: true,
            delegate: _PremiumHeaderDelegate(),
          ),

          // Welcome Hero Section
          const SliverToBoxAdapter(
            child: _WelcomeHero(),
          ),

          // Quick Stats Row
          const SliverToBoxAdapter(
            child: _QuickStatsRow(),
          ),

          // Featured Banner
          const SliverToBoxAdapter(child: FeaturedBanner()),

          // Trending
          const SliverToBoxAdapter(child: TrendingSection()),

          // Top Charts
          const SliverToBoxAdapter(child: TopChartsSection()),

          // Mood Section
          const SliverToBoxAdapter(child: MoodSection()),

          // Recently Played
const SliverToBoxAdapter(child: RecentlyPlayedSection()),

// Time Based
const SliverToBoxAdapter(child: TimeBasedSection()),

// Artist Spotlight
const SliverToBoxAdapter(child: ArtistSpotlightSection()),

// Throwback
const SliverToBoxAdapter(child: ThrowbackSection()),

// Mood Mix Generator
const SliverToBoxAdapter(child: MoodMixSection()),
        ],
      ),
    );
  }
}

// ─── PREMIUM STICKY HEADER ────────────────────────────────────

class _PremiumHeaderDelegate extends SliverPersistentHeaderDelegate {
  @override
  double get minExtent => 80;
  @override
  double get maxExtent => 80;

  @override
  Widget build(BuildContext context, double shrinkOffset,
      bool overlapsContent) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.black.withOpacity(0.6),
                Colors.black.withOpacity(0.3),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withOpacity(0.06),
                width: 1)),
          ),
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top,
            left: 20, right: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Logo
              ShaderMask(
                shaderCallback: (b) =>
                  AppTheme.primaryGradient.createShader(b),
                child: const Text('DEN',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1)),
              ),

              Row(
                children: [
                  // Search icon
                  _HeaderIconBtn(
                    icon: Icons.search_rounded,
                    onTap: () => context.go('/search'),
                  ),
                  const SizedBox(width: 8),
                  // Notification
                  _HeaderIconBtn(
                    icon: Icons.notifications_rounded,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('No new notifications'),
                          backgroundColor: Colors.black.withOpacity(0.8),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    showDot: true,
                  ),
                  const SizedBox(width: 8),
                  // Avatar
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.pink.withOpacity(0.4),
                          blurRadius: 12, spreadRadius: -2),
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
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate old) =>
    false;
}

class _HeaderIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool showDot;

  const _HeaderIconBtn({
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
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.12))),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(icon, color: Colors.white.withOpacity(0.8),
                  size: 18),
                if (showDot)
                  Positioned(
                    top: 6, right: 6,
                    child: Container(
                      width: 7, height: 7,
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.black, width: 1)),
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

// ─── WELCOME HERO ─────────────────────────────────────────────

class _WelcomeHero extends ConsumerStatefulWidget {
  const _WelcomeHero();
  @override
  ConsumerState<_WelcomeHero> createState() => _WelcomeHeroState();
}

class _WelcomeHeroState extends ConsumerState<_WelcomeHero>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3))..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good Morning'
        : hour < 17 ? 'Good Afternoon' : 'Good Evening';
    final greetingEmoji = hour < 12 ? '☀️'
        : hour < 17 ? '🌤️' : '🌙';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.pink.withOpacity(0.15),
                  AppTheme.purple.withOpacity(0.1),
                  Colors.white.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Colors.white.withOpacity(0.12)),
            ),
            padding: const EdgeInsets.all(24),
            child: Stack(
              children: [
                // Decorative orb
                Positioned(
                  right: -20, top: -20,
                  child: AnimatedBuilder(
                    animation: _pulseAnim,
                    builder: (_, __) => Transform.scale(
                      scale: _pulseAnim.value,
                      child: Container(
                        width: 120, height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AppTheme.pink.withOpacity(0.3),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 40, bottom: -10,
                  child: AnimatedBuilder(
                    animation: _pulseAnim,
                    builder: (_, __) => Transform.scale(
                      scale: 1.1 - (_pulseAnim.value - 0.95) * 2,
                      child: Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AppTheme.purple.withOpacity(0.25),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Content
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(greetingEmoji,
                          style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 8),
                        Text(greeting,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 14,
                            fontWeight: FontWeight.w500)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text('What would you like\nto listen today?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                        letterSpacing: -0.5)),
                    const SizedBox(height: 16),

                    // Quick play buttons
                    Row(
                      children: [
                        _QuickPlayBtn(
                          label: 'For You',
                          icon: Icons.favorite_rounded,
                          colors: const [AppTheme.pink, AppTheme.pinkDeep],
                          onTap: () async {
                            final songs = await ref.read(apiServiceProvider).searchSongs('bollywood hits 2025', page: 1);
                            if (songs.isNotEmpty) {
                              ref.read(currentSongProvider.notifier).state = songs[0];
                              ref.read(playerServiceProvider).playSong(songs[0]);
                              ref.read(databaseServiceProvider).addToHistory(songs[0]);
                            }
                          },
                        ),
                        const SizedBox(width: 10),
                        _QuickPlayBtn(
                          label: 'Discover',
                          icon: Icons.explore_rounded,
                          colors: const [AppTheme.purple, AppTheme.purpleDeep],
                          onTap: () async {
                            final songs = await ref.read(apiServiceProvider).searchSongs('latest new songs hindi 2025', page: 1);
                            if (songs.isNotEmpty) {
                              ref.read(currentSongProvider.notifier).state = songs[0];
                              ref.read(playerServiceProvider).playSong(songs[0]);
                              ref.read(databaseServiceProvider).addToHistory(songs[0]);
                            }
                          },
                        ),
                        const SizedBox(width: 10),
                        _QuickPlayBtn(
                          label: 'Charts',
                          icon: Icons.bar_chart_rounded,
                          colors: const [AppTheme.pinkDeep, AppTheme.purple],
                          onTap: () async {
                            final songs = await ref.read(apiServiceProvider).searchSongs('top charts 2025', page: 1);
                            if (songs.isNotEmpty) {
                              ref.read(currentSongProvider.notifier).state = songs[0];
                              ref.read(playerServiceProvider).playSong(songs[0]);
                              ref.read(databaseServiceProvider).addToHistory(songs[0]);
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    )
    .animate()
    .fadeIn(duration: 600.ms)
    .slideY(begin: -0.1, end: 0,
      duration: 600.ms, curve: Curves.easeOutCubic);
  }
}

class _QuickPlayBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onTap;

  const _QuickPlayBtn({
    required this.label,
    required this.icon,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colors[0].withOpacity(0.25),
                  colors[1].withOpacity(0.15),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: colors[0].withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: colors[0], size: 14),
                const SizedBox(width: 6),
                Text(label,
                  style: TextStyle(
                    color: colors[0],
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── QUICK STATS ROW ──────────────────────────────────────────

class _QuickStatsRow extends ConsumerWidget {
  const _QuickStatsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          Expanded(child: GestureDetector(
            onTap: () async {
              final songs = await ref.read(apiServiceProvider).searchSongs('trending hindi 2025', page: 1);
              if (songs.isNotEmpty) {
                ref.read(currentSongProvider.notifier).state = songs[0];
                ref.read(playerServiceProvider).playSong(songs[0]);
                ref.read(databaseServiceProvider).addToHistory(songs[0]);
              }
            },
            child: const _StatCard(
              label: 'Trending',
              value: '🔥 Hot',
              icon: Icons.local_fire_department_rounded,
              colors: [AppTheme.pink, AppTheme.pinkDeep],
            ),
          )),
          const SizedBox(width: 10),
          Expanded(child: GestureDetector(
            onTap: () async {
              final songs = await ref.read(apiServiceProvider).searchSongs('new hindi fresh 2025', page: 1);
              if (songs.isNotEmpty) {
                ref.read(currentSongProvider.notifier).state = songs[0];
                ref.read(playerServiceProvider).playSong(songs[0]);
                ref.read(databaseServiceProvider).addToHistory(songs[0]);
              }
            },
            child: const _StatCard(
              label: 'New Today',
              value: '✨ Fresh',
              icon: Icons.new_releases_rounded,
              colors: [AppTheme.purple, AppTheme.purpleDeep],
            ),
          )),
          const SizedBox(width: 10),
          Expanded(child: GestureDetector(
            onTap: () async {
              final songs = await ref.read(apiServiceProvider).searchSongs('legendary hindi classic hits', page: 1);
              if (songs.isNotEmpty) {
                ref.read(currentSongProvider.notifier).state = songs[0];
                ref.read(playerServiceProvider).playSong(songs[0]);
                ref.read(databaseServiceProvider).addToHistory(songs[0]);
              }
            },
            child: const _StatCard(
              label: 'Top Pick',
              value: '🎵 Play',
              icon: Icons.star_rounded,
              colors: [AppTheme.pinkDeep, AppTheme.purple],
            ),
          )),
        ],
      ),
    ).animate()
      .fadeIn(duration: 500.ms, delay: 200.ms)
      .slideY(begin: 0.2, end: 0,
        duration: 500.ms, delay: 200.ms,
        curve: Curves.easeOutCubic);
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final List<Color> colors;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colors[0].withOpacity(0.15),
                colors[1].withOpacity(0.08),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: colors[0].withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShaderMask(
                shaderCallback: (b) => LinearGradient(
                  colors: colors).createShader(b),
                child: Icon(icon, color: Colors.white, size: 20)),
              const SizedBox(height: 8),
              Text(value,
                style: TextStyle(
                  color: colors[0],
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}