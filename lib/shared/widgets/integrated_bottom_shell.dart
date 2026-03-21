import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/music_providers.dart';
import 'mini_player.dart'; // For FullPlayerSheet
import '../../core/services/player_service.dart';
import 'player_screen.dart';

class IntegratedBottomShell extends ConsumerWidget {
  final int currentIndex;
  final Function(int) onTap;

  const IntegratedBottomShell({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Current track info for the center orb
    final currentSong = ref.watch(currentSongProvider);
    final isPlaying = ref.watch(isPlayingStreamProvider).value ?? false;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(40),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
          child: Container(
            height: 76,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.08),
                  AppTheme.pink.withOpacity(0.03),
                  AppTheme.purple.withOpacity(0.05),
                  Colors.white.withOpacity(0.04),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(40),
              border: Border.all(
                color: Colors.white.withOpacity(0.12),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 30,
                  spreadRadius: 0,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _NavItem(
                  icon: Icons.home_rounded,
                  index: 0,
                  currentIndex: currentIndex,
                  onTap: onTap,
                ),
                _NavItem(
                  icon: Icons.queue_music_rounded,
                  index: 1,
                  currentIndex: currentIndex,
                  onTap: onTap,
                ),

                // Center Orb (Mini Player)
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    if (currentSong != null) {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => const PlayerScreen(),
                      );
                    }
                  },
                  child: _CenterOrbPlayer(
                    imageUrl: currentSong?.image,
                    isPlaying: isPlaying,
                  ),
                ),

                _NavItem(
                  icon: Icons.bar_chart_rounded, // or equalizer
                  index: 2,
                  currentIndex: currentIndex,
                  onTap: onTap,
                ),
                _NavItem(
                  icon: Icons.notifications_rounded,
                  index: 3,
                  currentIndex: currentIndex,
                  onTap: onTap,
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate()
      .fadeIn(duration: 600.ms, delay: 200.ms)
      .slideY(begin: 1, end: 0, duration: 600.ms,
        delay: 200.ms, curve: Curves.easeOutCubic);
  }
}

class _CenterOrbPlayer extends StatefulWidget {
  final String? imageUrl;
  final bool isPlaying;

  const _CenterOrbPlayer({
    this.imageUrl,
    this.isPlaying = false,
  });

  @override
  State<_CenterOrbPlayer> createState() => _CenterOrbPlayerState();
}

class _CenterOrbPlayerState extends State<_CenterOrbPlayer>
    with SingleTickerProviderStateMixin {
  late AnimationController _spinController;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );
    if (widget.isPlaying) {
      _spinController.repeat();
    }
  }

  @override
  void didUpdateWidget(_CenterOrbPlayer old) {
    super.didUpdateWidget(old);
    if (widget.isPlaying && !_spinController.isAnimating) {
      _spinController.repeat();
    } else if (!widget.isPlaying && _spinController.isAnimating) {
      _spinController.stop();
    }
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: widget.imageUrl == null
            ? AppTheme.primaryGradient
            : null,
        boxShadow: [
          BoxShadow(
            color: AppTheme.purple.withOpacity(0.4),
            blurRadius: 20,
            spreadRadius: -2,
          ),
          BoxShadow(
            color: AppTheme.pink.withOpacity(0.4),
            blurRadius: 20,
            spreadRadius: -2,
          ),
        ],
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 2,
        ),
      ),
      child: widget.imageUrl != null
          ? ClipOval(
              child: RotationTransition(
                turns: _spinController,
                child: CachedNetworkImage(
                  imageUrl: widget.imageUrl!,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: Colors.black26),
                  errorWidget: (_, __, ___) => const Icon(Icons.music_note, color: Colors.white),
                ),
              ),
            )
          : const Icon(Icons.music_note_rounded, color: Colors.white, size: 24),
    );
  }
}

class _NavItem extends StatefulWidget {
  final IconData icon;
  final int index;
  final int currentIndex;
  final Function(int) onTap;

  const _NavItem({
    required this.icon,
    required this.index,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
  }

  @override
  void didUpdateWidget(_NavItem old) {
    super.didUpdateWidget(old);
    if (widget.currentIndex == widget.index) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.index == widget.currentIndex;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap(widget.index);
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (_, __) => Transform.scale(
            scale: _scaleAnim.value,
            child: Icon(
              widget.icon,
              size: 26,
              color: isSelected
                  ? Colors.white
                  : Colors.white.withOpacity(0.4),
            ),
          ),
        ),
      ),
    );
  }
}
