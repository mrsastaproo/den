import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final double blur;
  final Color? color;
  final Color? borderColor;
  final double borderWidth;
  final Gradient? gradient;
  final List<BoxShadow>? shadows;

  const GlassContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.borderRadius = 20,
    this.blur = 20,
    this.color,
    this.borderColor,
    this.borderWidth = 1,
    this.gradient,
    this.shadows,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: shadows ?? [
          BoxShadow(
            color: AppTheme.pink.withOpacity(0.08),
            blurRadius: 30,
            spreadRadius: -5,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: AppTheme.purple.withOpacity(0.06),
            blurRadius: 20,
            spreadRadius: -5,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            decoration: BoxDecoration(
              gradient: gradient ?? LinearGradient(
                colors: [
                  (color ?? AppTheme.glassWhite),
                  AppTheme.glassShimmer,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: borderColor ?? AppTheme.glassBorder,
                width: borderWidth,
              ),
            ),
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}

// ─── Shimmer Glass Effect ──────────────────────────────────────

class GlassShimmer extends StatefulWidget {
  final Widget child;
  final double borderRadius;

  const GlassShimmer({
    super.key,
    required this.child,
    this.borderRadius = 20,
  });

  @override
  State<GlassShimmer> createState() => _GlassShimmerState();
}

class _GlassShimmerState extends State<GlassShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, __) => GlassContainer(
        borderRadius: widget.borderRadius,
        gradient: LinearGradient(
          colors: [
            Color.lerp(AppTheme.glassWhite,
              AppTheme.pink.withOpacity(0.15), _animation.value)!,
            Color.lerp(AppTheme.glassShimmer,
              AppTheme.purple.withOpacity(0.1), _animation.value)!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        child: widget.child,
      ),
    );
  }
}