import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/providers/music_providers.dart';
import '../../core/services/player_service.dart';
import '../../core/services/database_service.dart';
import '../../core/models/song.dart';
import '../../core/theme/app_theme.dart';

class TrendingSection extends ConsumerWidget {
  const TrendingSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendingAsync = ref.watch(trendingProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  ShaderMask(
                    shaderCallback: (b) =>
                      AppTheme.primaryGradient.createShader(b),
                    child: const Icon(Icons.local_fire_department_rounded,
                      color: Colors.white, size: 22)),
                  const SizedBox(width: 8),
                  const Text('Trending',
                    style: TextStyle(color: Colors.white,
                      fontSize: 20, fontWeight: FontWeight.w700)),
                ],
              ),
              ShaderMask(
                shaderCallback: (b) =>
                  AppTheme.primaryGradient.createShader(b),
                child: const Text('See all',
                  style: TextStyle(color: Colors.white,
                    fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 500.ms).slideX(begin: -0.1),

        // Horizontal scroll
        SizedBox(
          height: 200,
          child: trendingAsync.when(
            loading: () => _buildShimmer(),
            error: (e, _) => const SizedBox.shrink(),
            data: (songs) => ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: songs.take(12).length,
              itemBuilder: (context, index) => _TrendingCard(
                song: songs[index],
                index: index,
                onTap: () {
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
        ),
      ],
    );
  }

  Widget _buildShimmer() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 5,
      itemBuilder: (_, __) => Container(
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20)),
      ).animate(onPlay: (c) => c.repeat())
        .shimmer(duration: 1200.ms,
          color: Colors.white.withOpacity(0.05)),
    );
  }
}

class _TrendingCard extends StatefulWidget {
  final Song song;
  final int index;
  final VoidCallback onTap;

  const _TrendingCard({
    required this.song,
    required this.index,
    required this.onTap,
  });

  @override
  State<_TrendingCard> createState() => _TrendingCardState();
}

class _TrendingCardState extends State<_TrendingCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150));
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static const List<List<Color>> _gradients = [
    [Color(0xFFFFB3C6), Color(0xFFD4B8FF)],
    [Color(0xFFB794FF), Color(0xFFFFB3C6)],
    [Color(0xFFFF85A1), Color(0xFFB794FF)],
    [Color(0xFFD4B8FF), Color(0xFFFF85A1)],
    [Color(0xFFFFB3C6), Color(0xFFB794FF)],
  ];

  @override
  Widget build(BuildContext context) {
    final gradient = _gradients[widget.index % _gradients.length];

    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        _controller.forward();
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
        _controller.reverse();
      },
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (_, child) => Transform.scale(
          scale: _scaleAnim.value,
          child: child,
        ),
        child: Container(
          width: 145,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: gradient[0].withOpacity(0.25),
                blurRadius: 20,
                spreadRadius: -5,
                offset: const Offset(0, 8)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Album art
                CachedNetworkImage(
                  imageUrl: widget.song.image,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: gradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight)),
                    child: const Icon(Icons.music_note_rounded,
                      color: Colors.white38, size: 40),
                  ),
                ),

                // Dark gradient overlay
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.75),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),

                // Rank number
                Positioned(
                  top: 10, left: 12,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.15)),
                        ),
                        child: Text('#${widget.index + 1}',
                          style: TextStyle(
                            color: gradient[0],
                            fontSize: 11,
                            fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ),
                ),

                // Play indicator
                Positioned(
                  top: 10, right: 10,
                  child: Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: gradient),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: gradient[0].withOpacity(0.4),
                          blurRadius: 8, spreadRadius: -2),
                      ],
                    ),
                    child: const Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 16),
                  ),
                ),

                // Song info at bottom
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(20)),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.black.withOpacity(0.7),
                              Colors.black.withOpacity(0.5),
                            ],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                          border: Border(
                            top: BorderSide(
                              color: Colors.white.withOpacity(0.08))),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(widget.song.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 2),
                            Text(widget.song.artist,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.55),
                                fontSize: 10),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          ],
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
    ).animate()
      .fadeIn(duration: 400.ms,
        delay: (widget.index * 80).ms)
      .slideX(begin: 0.2, end: 0,
        duration: 400.ms,
        delay: (widget.index * 80).ms,
        curve: Curves.easeOutCubic);
  }
}