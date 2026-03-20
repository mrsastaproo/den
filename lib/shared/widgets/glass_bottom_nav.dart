import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_theme.dart';

class GlassBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const GlassBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(36),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: Container(
            height: 72,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.12),
                  AppTheme.pink.withOpacity(0.05),
                  AppTheme.purple.withOpacity(0.08),
                  Colors.white.withOpacity(0.06),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(36),
              border: Border.all(
                color: Colors.white.withOpacity(0.18),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.pink.withOpacity(0.2),
                  blurRadius: 40,
                  spreadRadius: -8,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: AppTheme.purple.withOpacity(0.15),
                  blurRadius: 30,
                  spreadRadius: -8,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 20,
                  spreadRadius: 0,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(icon: Icons.home_rounded,
                  label: 'Home', index: 0,
                  currentIndex: currentIndex, onTap: onTap),
                _NavItem(icon: Icons.search_rounded,
                  label: 'Search', index: 1,
                  currentIndex: currentIndex, onTap: onTap),
                _NavItem(icon: Icons.library_music_rounded,
                  label: 'Library', index: 2,
                  currentIndex: currentIndex, onTap: onTap),
                _NavItem(icon: Icons.person_rounded,
                  label: 'Profile', index: 3,
                  currentIndex: currentIndex, onTap: onTap),
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

class _NavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final int index;
  final int currentIndex;
  final Function(int) onTap;

  const _NavItem({
    required this.icon,
    required this.label,
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
  late Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _glowAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut));
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
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, __) => Transform.scale(
          scale: _scaleAnim.value,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(
              horizontal: 18, vertical: 10),
            decoration: isSelected ? BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.pink.withOpacity(0.25),
                  AppTheme.purple.withOpacity(0.2),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppTheme.pink.withOpacity(0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.pink.withOpacity(
                    0.3 * _glowAnim.value),
                  blurRadius: 16,
                  spreadRadius: -2,
                ),
              ],
            ) : null,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon with glow
                ShaderMask(
                  shaderCallback: (bounds) => isSelected
                    ? AppTheme.primaryGradient.createShader(bounds)
                    : LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.35),
                          Colors.white.withOpacity(0.35),
                        ],
                      ).createShader(bounds),
                  child: Icon(widget.icon, size: 22,
                    color: Colors.white),
                ),
                const SizedBox(height: 3),
                // Label
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isSelected
                      ? FontWeight.w700
                      : FontWeight.w400,
                    color: isSelected
                      ? AppTheme.pink
                      : Colors.white.withOpacity(0.35),
                  ),
                  child: Text(widget.label),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}