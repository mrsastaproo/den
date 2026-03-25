import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/appearance_service.dart';

class AmbientBackground extends ConsumerStatefulWidget {
  final Widget child;
  const AmbientBackground({super.key, required this.child});

  @override
  ConsumerState<AmbientBackground> createState() => _AmbientBackgroundState();
}

class _AmbientBackgroundState extends ConsumerState<AmbientBackground>
    with TickerProviderStateMixin {
  late AnimationController _orb1Controller;
  late AnimationController _orb2Controller;
  late AnimationController _orb3Controller;

  late Animation<Offset> _orb1Position;
  late Animation<Offset> _orb2Position;
  late Animation<Offset> _orb3Position;

  @override
  void initState() {
    super.initState();

    _orb1Controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

    _orb2Controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 11),
    )..repeat(reverse: true);

    _orb3Controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    )..repeat(reverse: true);

    _orb1Position = Tween<Offset>(
      begin: const Offset(-0.1, -0.05),
      end: const Offset(0.1, 0.08),
    ).animate(CurvedAnimation(
      parent: _orb1Controller, curve: Curves.easeInOut));

    _orb2Position = Tween<Offset>(
      begin: const Offset(0.05, 0.0),
      end: const Offset(-0.08, 0.1),
    ).animate(CurvedAnimation(
      parent: _orb2Controller, curve: Curves.easeInOut));

    _orb3Position = Tween<Offset>(
      begin: const Offset(0.0, 0.05),
      end: const Offset(0.06, -0.05),
    ).animate(CurvedAnimation(
      parent: _orb3Controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _orb1Controller.dispose();
    _orb2Controller.dispose();
    _orb3Controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final disableOrbs = ref.watch(appearanceProvider).disableAnimations;

    final orb1 = _Orb(
      size: size.width * 0.7,
      color: AppTheme.pink.withOpacity(0.12),
    );
    final orb2 = _Orb(
      size: size.width * 0.6,
      color: AppTheme.purple.withOpacity(0.10),
    );
    final orb3 = _Orb(
      size: size.width * 0.5,
      color: AppTheme.purpleDeep.withOpacity(0.07),
    );

    return Stack(
      children: [
        // Pure black base
        Container(color: AppTheme.bgPrimary),

        if (!disableOrbs) ...[
          // Orb 1 — Pink top left
          AnimatedBuilder(
            animation: _orb1Position,
            child: orb1,
            builder: (_, child) => Positioned(
              left: size.width * (0.15 + _orb1Position.value.dx),
              top: size.height * (0.08 + _orb1Position.value.dy),
              child: child!,
            ),
          ),

          // Orb 2 — Purple top right
          AnimatedBuilder(
            animation: _orb2Position,
            child: orb2,
            builder: (_, child) => Positioned(
              right: size.width * (0.05 + _orb2Position.value.dx),
              top: size.height * (0.15 + _orb2Position.value.dy),
              child: child!,
            ),
          ),

          // Orb 3 — Pink/Purple mid
          AnimatedBuilder(
            animation: _orb3Position,
            child: orb3,
            builder: (_, child) => Positioned(
              left: size.width * (0.2 + _orb3Position.value.dx),
              top: size.height * (0.4 + _orb3Position.value.dy),
              child: child!,
            ),
          ),
        ],

        // Main content
        widget.child,
      ],
    );
  }
}

class _Orb extends StatelessWidget {
  final double size;
  final Color color;

  const _Orb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, Colors.transparent],
          stops: const [0.0, 1.0],
        ),
      ),
    );
  }
}