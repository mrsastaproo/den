import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/music_providers.dart';
import '../../core/services/player_service.dart';
import '../../core/services/database_service.dart';
import '../../core/models/song.dart';
import '../../core/theme/app_theme.dart';

class FeaturedBanner extends ConsumerStatefulWidget {
  const FeaturedBanner({super.key});

  @override
  ConsumerState<FeaturedBanner> createState() => _FeaturedBannerState();
}

class _FeaturedBannerState extends ConsumerState<FeaturedBanner>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late PageController _pageController;
  late AnimationController _gradientController;
  late Animation<double> _gradientAnimation;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.88);
    _gradientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    _gradientAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _gradientController,
        curve: Curves.easeInOut));
    Future.delayed(const Duration(seconds: 3), _startAutoScroll);
  }

  void _startAutoScroll() {
    if (!mounted) return;
    Future.delayed(const Duration(seconds: 4), () {
      if (!mounted) return;
      final songs = ref.read(newReleasesProvider).value;
      if (songs == null || songs.isEmpty) return;
      final next = (_currentIndex + 1) % songs.length;
      _pageController.animateToPage(next,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic);
      _startAutoScroll();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _gradientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final newReleasesAsync = ref.watch(newReleasesProvider);

    return newReleasesAsync.when(
      loading: () => _buildShimmer(context),
      error: (e, _) => const SizedBox.shrink(),
      data: (songs) {
        if (songs.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('New Releases',
                    style: TextStyle(color: Colors.white,
                      fontSize: 20, fontWeight: FontWeight.w700)),
                  GestureDetector(
                    child: ShaderMask(
                      shaderCallback: (b) =>
                        AppTheme.primaryGradient.createShader(b),
                      child: const Text('See all',
                        style: TextStyle(color: Colors.white,
                          fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                    onTap: () {
                      ref.read(searchQueryProvider.notifier).state = 'new releases hindi 2025';
                      context.push('/search');
                    },
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 500.ms).slideX(begin: -0.1),

            // PageView cards
            SizedBox(
              height: 220,
              child: PageView.builder(
                controller: _pageController,
                itemCount: songs.length,
                onPageChanged: (i) =>
                  setState(() => _currentIndex = i),
                itemBuilder: (context, index) => _BannerCard(
                  song: songs[index],
                  isActive: index == _currentIndex,
                  gradientAnimation: _gradientAnimation,
                  index: index,
                  onPlay: () {
                    ref.read(currentSongProvider.notifier)
                      .state = songs[index];
                    ref.read(playerServiceProvider)
                      .playSong(songs[index]);
                    ref.read(databaseServiceProvider)
                      .addToHistory(songs[index]);
                  },
                ),
              ),
            ),

            // Dots indicator
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                songs.length > 6 ? 6 : songs.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _currentIndex ? 20 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    gradient: i == _currentIndex
                      ? AppTheme.primaryGradient : null,
                    color: i == _currentIndex
                      ? null : Colors.white.withOpacity(0.2),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildShimmer(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
          child: Container(
            width: 140, height: 22,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8)),
          ),
        ),
        SizedBox(
          height: 220,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 3,
            itemBuilder: (_, __) => Container(
              width: MediaQuery.of(context).size.width * 0.82,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(24)),
            ).animate(onPlay: (c) => c.repeat())
              .shimmer(duration: 1200.ms,
                color: Colors.white.withOpacity(0.05)),
          ),
        ),
      ],
    );
  }
}

// ─── BANNER CARD ──────────────────────────────────────────────

class _BannerCard extends StatelessWidget {
  final Song song;
  final bool isActive;
  final Animation<double> gradientAnimation;
  final int index;
  final VoidCallback onPlay;

  const _BannerCard({
    required this.song,
    required this.isActive,
    required this.gradientAnimation,
    required this.index,
    required this.onPlay,
  });

  static const List<List<Color>> _gradients = [
    [Color(0xFFFFB3C6), Color(0xFFD4B8FF)],
    [Color(0xFFB794FF), Color(0xFFFFB3C6)],
    [Color(0xFFFF85A1), Color(0xFFB794FF)],
    [Color(0xFFD4B8FF), Color(0xFFFF85A1)],
    [Color(0xFFFFB3C6), Color(0xFFB794FF)],
  ];

  @override
  Widget build(BuildContext context) {
    final gradient = _gradients[index % _gradients.length];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      margin: EdgeInsets.only(
        right: 12,
        top: isActive ? 0 : 12,
        bottom: isActive ? 0 : 12,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Album art
            CachedNetworkImage(
              imageUrl: song.image,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => AnimatedBuilder(
                animation: gradientAnimation,
                builder: (_, __) => Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color.lerp(gradient[0],
                          gradient[1], gradientAnimation.value)!,
                        Color.lerp(gradient[1],
                          gradient[0], gradientAnimation.value)!,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
            ),

            // Animated gradient overlay
            AnimatedBuilder(
              animation: gradientAnimation,
              builder: (_, __) => Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Color.lerp(
                        gradient[0].withOpacity(0.3),
                        gradient[1].withOpacity(0.3),
                        gradientAnimation.value)!,
                      Colors.black.withOpacity(0.85),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),

            // Glass top shimmer
            Positioned(
              top: 0, left: 0, right: 0, height: 60,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24)),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 0, sigmaY: 0),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.08),
                          Colors.transparent,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // NEW badge
            Positioned(
              top: 14, left: 14,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          gradient[0].withOpacity(0.6),
                          gradient[1].withOpacity(0.6),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1),
                    ),
                    child: const Text('NEW',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5)),
                  ),
                ),
              ),
            ).animate().fadeIn(delay: 200.ms).scale(
              begin: const Offset(0.8, 0.8)),

            // Bottom glass info card
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(24)),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withOpacity(0.6),
                          Colors.black.withOpacity(0.4),
                        ],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                      border: Border(
                        top: BorderSide(
                          color: Colors.white.withOpacity(0.1),
                          width: 1)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(song.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 3),
                              Text(song.artist,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Play button
                        GestureDetector(
                          onTap: onPlay,
                          child: AnimatedBuilder(
                            animation: gradientAnimation,
                            builder: (_, __) => Container(
                              width: 44, height: 44,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Color.lerp(gradient[0],
                                      gradient[1],
                                      gradientAnimation.value)!,
                                    Color.lerp(gradient[1],
                                      gradient[0],
                                      gradientAnimation.value)!,
                                  ],
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: gradient[0].withOpacity(0.5),
                                    blurRadius: 16,
                                    spreadRadius: -4),
                                ],
                              ),
                              child: const Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white, size: 26),
                            ),
                          ),
                        ).animate(onPlay: (c) => c.repeat(reverse: true))
                          .scale(
                            begin: const Offset(1.0, 1.0),
                            end: const Offset(1.06, 1.06),
                            duration: 1500.ms,
                            curve: Curves.easeInOut),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate()
      .fadeIn(duration: 500.ms, delay: (index * 100).ms)
      .scale(begin: const Offset(0.95, 0.95),
        duration: 500.ms, curve: Curves.easeOutCubic);
  }
}