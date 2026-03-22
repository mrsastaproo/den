import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/providers/music_providers.dart';
import '../../core/services/player_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models/song.dart';

class DynamicIsland extends ConsumerStatefulWidget {
  const DynamicIsland({super.key});

  @override
  ConsumerState<DynamicIsland> createState() => _DynamicIslandState();
}

class _DynamicIslandState extends ConsumerState<DynamicIsland>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _waveCtrl;

  @override
  void initState() {
    super.initState();
    _waveCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000))
      ..repeat();
  }

  @override
  void dispose() {
    _waveCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentSong = ref.watch(currentSongProvider);
    final isPlaying = ref.watch(isPlayingProvider);

    if (currentSong == null) return const SizedBox.shrink();

    // Trigger wave animation based on play state
    if (isPlaying && !_waveCtrl.isAnimating) {
      _waveCtrl.repeat();
    } else if (!isPlaying && _waveCtrl.isAnimating) {
      _waveCtrl.stop();
    }

    final topPadding = MediaQuery.of(context).padding.top;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutBack,
      top: topPadding + 6,
      left: _isExpanded ? 16 : (MediaQuery.of(context).size.width / 2) - 85,
      right: _isExpanded ? 16 : (MediaQuery.of(context).size.width / 2) - 85,
      child: GestureDetector(
        onTap: () {
          setState(() => _isExpanded = !_isExpanded);
          HapticFeedback.lightImpact();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutBack,
          height: _isExpanded ? 80 : 38,
          padding: EdgeInsets.symmetric(
              horizontal: _isExpanded ? 16 : 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.85),
            borderRadius: BorderRadius.circular(_isExpanded ? 24 : 100),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 15,
                spreadRadius: 2,
                offset: const Offset(0, 8),
              )
            ],
          ),
          child: _isExpanded
              ? _buildExpanded(currentSong, isPlaying)
              : _buildCollapsed(currentSong, isPlaying),
        ),
      ),
    );
  }

  // ─── COLLAPSED PILL ─────────────────────────────────────────

  Widget _buildCollapsed(Song currentSong, bool isPlaying) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Pulsing bars
        SizedBox(
          width: 20,
          child: AnimatedBuilder(
            animation: _waveCtrl,
            builder: (_, __) => Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(3, (i) {
                final h = isPlaying
                    ? 4.0 + (14.0 * (0.3 + 0.7 * (0.5 + 0.5 * (30 - i * 10).abs() % 10 / 10)))
                    : 4.0;
                return Container(
                  width: 2,
                  height: isPlaying ? (4.0 + (10.0 * (1.0 + 0.3 * i) * (0.2 + 0.8 * _waveCtrl.value)).clamp(4.0, 16.0)) : 4.0,
                  decoration: BoxDecoration(
                    color: AppTheme.pink,
                    borderRadius: BorderRadius.circular(1),
                  ),
                );
              }),
            ),
          ),
        ),
        // Mini Title
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              currentSong.title,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        // Compact Art
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppTheme.purple.withOpacity(0.4),
                blurRadius: 4,
              )
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: currentSong.image,
              fit: BoxFit.cover,
            ),
          ),
        ),
      ],
    );
  }

  // ─── EXPANDED BANNER ────────────────────────────────────────

  Widget _buildExpanded(Song currentSong, bool isPlaying) {
    final player = ref.read(playerServiceProvider);

    return Row(
      children: [
        // Art
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppTheme.pink.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: CachedNetworkImage(
              imageUrl: currentSong.image,
              fit: BoxFit.cover,
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
              Text(
                currentSong.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                currentSong.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        // Controls
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                isPlaying
                    ? Icons.pause_circle_filled_rounded
                    : Icons.play_circle_filled_rounded,
                color: Colors.white,
                size: 34,
              ),
              onPressed: () {
                if (isPlaying) {
                  player.player.pause();
                } else {
                  player.player.play();
                }
                HapticFeedback.mediumImpact();
              },
            ),
          ],
        ),
      ],
    );
  }
}
