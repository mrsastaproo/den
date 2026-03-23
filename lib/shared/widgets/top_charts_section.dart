import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/music_providers.dart';
import '../../core/services/database_service.dart';
import '../../core/models/song.dart';
import '../../core/theme/app_theme.dart';

class TopChartsSection extends ConsumerWidget {
  const TopChartsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chartsAsync = ref.watch(topChartsProvider);

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
                    child: const Icon(Icons.bar_chart_rounded,
                      color: Colors.white, size: 22)),
                  const SizedBox(width: 8),
                  const Text('Top Charts',
                    style: TextStyle(color: Colors.white,
                      fontSize: 20, fontWeight: FontWeight.w700)),
                ],
              ),
              GestureDetector(
                child: ShaderMask(
                  shaderCallback: (b) =>
                    AppTheme.primaryGradient.createShader(b),
                  child: const Text('See all',
                    style: TextStyle(color: Colors.white,
                      fontSize: 13, fontWeight: FontWeight.w600)),
                ),
                onTap: () {
                  ref.read(searchQueryProvider.notifier).state = 'top charts 2025';
                  context.push('/search');
                },
              ),
            ],
          ),
        ).animate().fadeIn(duration: 500.ms).slideX(begin: -0.1),

        // Charts list
        chartsAsync.when(
          loading: () => _buildShimmer(),
          error: (e, _) => const SizedBox.shrink(),
          data: (songs) => ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.07),
                      AppTheme.pink.withOpacity(0.03),
                      AppTheme.purple.withOpacity(0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                    width: 1),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: songs.take(10).length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: Colors.white.withOpacity(0.05),
                    indent: 80, endIndent: 16),
                  itemBuilder: (context, index) => _ChartTile(
                    song: songs[index],
                    rank: index + 1,
                    onTap: () {
                        playQueue(ref, songs, index);
                      ref.read(databaseServiceProvider)
                        .addToHistory(songs[index]);
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildShimmer() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(24)),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 5,
        itemBuilder: (_, i) => Container(
          height: 72,
          margin: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12)),
        ).animate(onPlay: (c) => c.repeat())
          .shimmer(duration: 1200.ms,
            color: Colors.white.withOpacity(0.05)),
      ),
    );
  }
}

class _ChartTile extends StatefulWidget {
  final Song song;
  final int rank;
  final VoidCallback onTap;

  const _ChartTile({
    required this.song,
    required this.rank,
    required this.onTap,
  });

  @override
  State<_ChartTile> createState() => _ChartTileState();
}

class _ChartTileState extends State<_ChartTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150));
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Top 3 get special colors
  Color get _rankColor {
    switch (widget.rank) {
      case 1: return const Color(0xFFFFD700); // Gold
      case 2: return const Color(0xFFC0C0C0); // Silver
      case 3: return const Color(0xFFCD7F32); // Bronze
      default: return AppTheme.pink;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTop3 = widget.rank <= 3;

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (_, child) => Transform.scale(
          scale: _scaleAnim.value, child: child),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 10),
          child: Row(
            children: [
              // Rank number
              SizedBox(
                width: 36,
                child: isTop3
                  ? ShaderMask(
                      shaderCallback: (b) => LinearGradient(
                        colors: [_rankColor,
                          _rankColor.withOpacity(0.7)],
                      ).createShader(b),
                      child: Text('#${widget.rank}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w900)),
                    )
                  : Text('#${widget.rank}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.3),
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ),

              const SizedBox(width: 10),

              // Album art
              Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: isTop3 ? [
                        BoxShadow(
                          color: _rankColor.withOpacity(0.3),
                          blurRadius: 12, spreadRadius: -2),
                      ] : null,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(memCacheWidth: 400, 
                        imageUrl: widget.song.image,
                        width: 50, height: 50,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          width: 50, height: 50,
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.music_note,
                            color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                  ),
                  // Crown for #1
                  if (widget.rank == 1)
                    Positioned(
                      top: -4, right: -4,
                      child: Container(
                        width: 18, height: 18,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD700),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.black, width: 1.5)),
                        child: const Icon(Icons.star_rounded,
                          color: Colors.black, size: 10),
                      ),
                    ),
                ],
              ),

              const SizedBox(width: 12),

              // Song info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.song.title,
                      style: TextStyle(
                        color: isTop3
                          ? Colors.white
                          : Colors.white.withOpacity(0.9),
                        fontWeight: isTop3
                          ? FontWeight.w700
                          : FontWeight.w500,
                        fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Text(widget.song.artist,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),

              // Trending indicator
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Play button
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      gradient: isTop3
                        ? LinearGradient(colors: [
                            _rankColor.withOpacity(0.3),
                            _rankColor.withOpacity(0.1)])
                        : LinearGradient(colors: [
                            AppTheme.pink.withOpacity(0.2),
                            AppTheme.purple.withOpacity(0.2)]),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isTop3
                          ? _rankColor.withOpacity(0.4)
                          : Colors.white.withOpacity(0.1)),
                    ),
                    child: Icon(Icons.play_arrow_rounded,
                      color: isTop3 ? _rankColor : AppTheme.pink,
                      size: 18),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).animate()
      .fadeIn(duration: 400.ms,
        delay: (widget.rank * 60).ms)
      .slideX(begin: 0.1, end: 0,
        duration: 400.ms,
        delay: (widget.rank * 60).ms,
        curve: Curves.easeOutCubic);
  }
}