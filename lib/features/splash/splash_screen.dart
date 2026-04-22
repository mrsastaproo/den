import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DEN — SPLASH SCREEN  (premium · glass · minimal · iOS-feel)
// ─────────────────────────────────────────────────────────────────────────────

class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const SplashScreen({super.key, required this.onComplete});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {

  // ── Icon entrance
  late final AnimationController _iconCtrl;
  late final Animation<double>   _iconScale;
  late final Animation<double>   _iconFade;
  late final Animation<double>   _iconBlur;

  // ── Orbs / background lights drift
  late final AnimationController _orbCtrl;

  // ── Glass ring pulse
  late final AnimationController _ringCtrl;
  late final Animation<double>   _ringScale;
  late final Animation<double>   _ringOpacity;

  // ── Text reveal
  late final AnimationController _textCtrl;
  late final Animation<double>   _textFade;
  late final Animation<double>   _textSpacing;

  // ── Tagline
  late final AnimationController _tagCtrl;
  late final Animation<double>   _tagFade;
  late final Animation<double>   _tagY;

  // ── Loading dots
  late final AnimationController _dotCtrl;

  // ── Exit
  late final AnimationController _exitCtrl;
  late final Animation<double>   _exitFade;
  late final Animation<double>   _exitScale;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _init();
    _run();
  }

  void _init() {
    // Icon
    _iconCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100));
    _iconScale = Tween(begin: 0.72, end: 1.0).animate(
        CurvedAnimation(parent: _iconCtrl, curve: Curves.easeOutQuint));
    _iconFade = Tween(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _iconCtrl,
            curve: const Interval(0.0, 0.65, curve: Curves.easeOut)));
    _iconBlur = Tween(begin: 12.0, end: 0.0).animate(
        CurvedAnimation(parent: _iconCtrl, curve: Curves.easeOutQuint));

    // Orbs drift
    _orbCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 8))
      ..repeat();

    // Ring pulse
    _ringCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2400))
      ..repeat();
    _ringScale = Tween(begin: 0.88, end: 1.12).animate(
        CurvedAnimation(parent: _ringCtrl, curve: Curves.easeInOut));
    _ringOpacity = Tween(begin: 0.18, end: 0.04).animate(
        CurvedAnimation(parent: _ringCtrl, curve: Curves.easeInOut));

    // Text
    _textCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _textFade = Tween(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut));
    _textSpacing = Tween(begin: 20.0, end: 12.0).animate(
        CurvedAnimation(parent: _textCtrl, curve: Curves.easeOutCubic));

    // Tagline
    _tagCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _tagFade = Tween(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _tagCtrl, curve: Curves.easeOut));
    _tagY = Tween(begin: 10.0, end: 0.0).animate(
        CurvedAnimation(parent: _tagCtrl, curve: Curves.easeOutCubic));

    // Dots
    _dotCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();

    // Exit
    _exitCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _exitFade = Tween(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(parent: _exitCtrl, curve: Curves.easeInCubic));
    _exitScale = Tween(begin: 1.0, end: 1.06).animate(
        CurvedAnimation(parent: _exitCtrl, curve: Curves.easeIn));
  }

  Future<void> _run() async {
    await Future.delayed(const Duration(milliseconds: 150));
    _iconCtrl.forward();

    await Future.delayed(const Duration(milliseconds: 650));
    _textCtrl.forward();

    await Future.delayed(const Duration(milliseconds: 320));
    _tagCtrl.forward();

    await Future.delayed(const Duration(milliseconds: 1800));
    _dotCtrl.stop();
    await _exitCtrl.forward();

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    widget.onComplete();
  }

  @override
  void dispose() {
    _iconCtrl.dispose();
    _orbCtrl.dispose();
    _ringCtrl.dispose();
    _textCtrl.dispose();
    _tagCtrl.dispose();
    _dotCtrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size     = MediaQuery.of(context).size;
    final w        = size.width;
    final h        = size.height;
    final iconSize = math.min(w * 0.22, 96.0);

    return AnimatedBuilder(
      animation: _exitCtrl,
      builder: (_, child) => Opacity(
        opacity: _exitFade.value,
        child: Transform.scale(scale: _exitScale.value, child: child),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF080810),
        body: Stack(
          children: [

            // ── 1. DEEP BG ────────────────────────────────────────────────
            Positioned.fill(
              child: CustomPaint(
                painter: _BgPainter(w: w, h: h),
              ),
            ),

            // ── 2. ANIMATED ORBS ─────────────────────────────────────────
            AnimatedBuilder(
              animation: _orbCtrl,
              builder: (_, __) {
                final t = _orbCtrl.value;
                return Stack(
                  children: [
                    // Top left orb
                    Positioned(
                      left: w * 0.08 + math.sin(t * math.pi * 2) * 18,
                      top:  h * 0.12 + math.cos(t * math.pi * 2) * 14,
                      child: _Orb(
                        size: w * 0.52,
                        color: const Color(0xFF6D28D9),
                        opacity: 0.13,
                      ),
                    ),
                    // Bottom right orb
                    Positioned(
                      right: w * 0.04 + math.cos(t * math.pi * 2) * 16,
                      bottom: h * 0.18 + math.sin(t * math.pi * 2) * 12,
                      child: _Orb(
                        size: w * 0.44,
                        color: const Color(0xFF0EA5E9),
                        opacity: 0.09,
                      ),
                    ),
                    // Center soft pink
                    Positioned(
                      left: w * 0.28,
                      top:  h * 0.34 + math.sin(t * math.pi * 2 + 1) * 10,
                      child: _Orb(
                        size: w * 0.48,
                        color: const Color(0xFFDB2777),
                        opacity: 0.06,
                      ),
                    ),
                  ],
                );
              },
            ),

            // ── 3. CENTER CONTENT ─────────────────────────────────────────
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [

                  // Icon block with glass ring
                  AnimatedBuilder(
                    animation: Listenable.merge(
                        [_iconCtrl, _ringCtrl]),
                    builder: (_, __) => _IconBlock(
                      size:         iconSize,
                      scale:        _iconScale.value,
                      fade:         _iconFade.value,
                      blur:         _iconBlur.value,
                      ringScale:    _ringScale.value,
                      ringOpacity:  _ringOpacity.value,
                    ),
                  ),

                  SizedBox(height: h * 0.048),

                  // DEN wordmark
                  AnimatedBuilder(
                    animation: _textCtrl,
                    builder: (_, __) => Opacity(
                      opacity: _textFade.value,
                      child: Text(
                        'DEN',
                        style: TextStyle(
                          fontSize:     math.min(w * 0.155, 68.0),
                          fontWeight:   FontWeight.w200,
                          letterSpacing: _textSpacing.value,
                          color:        Colors.white,
                          height:       1,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: h * 0.014),

                  // Tagline
                  AnimatedBuilder(
                    animation: _tagCtrl,
                    builder: (_, __) => Opacity(
                      opacity: _tagFade.value,
                      child: Transform.translate(
                        offset: Offset(0, _tagY.value),
                        child: Text(
                          'FEEL EVERY BEAT',
                          style: TextStyle(
                            fontSize:     9.5,
                            fontWeight:   FontWeight.w300,
                            letterSpacing: 5.5,
                            color:        Colors.white.withOpacity(0.22),
                          ),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: h * 0.072),

                  // Loading dots
                  AnimatedBuilder(
                    animation: _tagCtrl,
                    builder: (_, child) => Opacity(
                      opacity: _tagFade.value,
                      child: child,
                    ),
                    child: AnimatedBuilder(
                      animation: _dotCtrl,
                      builder: (_, __) => _LoadingDots(t: _dotCtrl.value),
                    ),
                  ),
                ],
              ),
            ),

          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ICON BLOCK — glassmorphism card + breathing ring
// ─────────────────────────────────────────────────────────────────────────────
class _IconBlock extends StatelessWidget {
  final double size, scale, fade, blur, ringScale, ringOpacity;
  const _IconBlock({
    required this.size, required this.scale, required this.fade,
    required this.blur, required this.ringScale, required this.ringOpacity,
  });

  @override
  Widget build(BuildContext context) {
    final pad = size * 0.18;

    return Opacity(
      opacity: fade,
      child: Transform.scale(
        scale: scale,
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(
            sigmaX: blur, sigmaY: blur, tileMode: TileMode.decal),
          child: SizedBox(
            width:  size + 100,
            height: size + 100,
            child: Stack(
              alignment: Alignment.center,
              children: [

                // Outer breathing ring
                Transform.scale(
                  scale: ringScale,
                  child: Container(
                    width:  size + 80,
                    height: size + 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(ringOpacity),
                        width: 1.0,
                      ),
                    ),
                  ),
                ),

                // Second inner ring (static, subtle)
                Container(
                  width:  size + 32,
                  height: size + 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.06),
                      width: 0.8,
                    ),
                  ),
                ),

                // Glass card behind icon
                ClipRRect(
                  borderRadius: BorderRadius.circular((size + pad * 2) * 0.28),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      width:  size + pad * 2,
                      height: size + pad * 2,
                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.circular((size + pad * 2) * 0.28),
                        color: Colors.white.withOpacity(0.06),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.10),
                          width: 0.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6D28D9).withOpacity(0.35),
                            blurRadius: 48,
                            spreadRadius: -4,
                          ),
                          BoxShadow(
                            color: Colors.black.withOpacity(0.40),
                            blurRadius: 32,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      padding: EdgeInsets.all(pad),
                      child: ClipRRect(
                        borderRadius:
                            BorderRadius.circular(size * 0.22),
                        child: Image.asset(
                          'assets/icons/app_icon.png',
                          width:  size,
                          height: size,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _FallbackIcon(size: size),
                        ),
                      ),
                    ),
                  ),
                ),

                // Top-left shine on glass card
                Positioned(
                  top:  size * 0.04 + pad * 0.4,
                  left: size * 0.04 + pad * 0.4,
                  child: Container(
                    width:  size * 0.38,
                    height: size * 0.14,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(40),
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.18),
                          Colors.white.withOpacity(0.0),
                        ],
                      ),
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

// ─────────────────────────────────────────────────────────────────────────────
// LOADING DOTS
// ─────────────────────────────────────────────────────────────────────────────
class _LoadingDots extends StatelessWidget {
  final double t;
  const _LoadingDots({required this.t});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        // Each dot pulses with a phase offset
        final phase = (t - i * 0.28).clamp(0.0, 1.0);
        final pulse = math.sin(phase * math.pi);
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 3.5),
          width:  3.5,
          height: 3.5,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.15 + pulse * 0.45),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ORB
// ─────────────────────────────────────────────────────────────────────────────
class _Orb extends StatelessWidget {
  final double size, opacity;
  final Color color;
  const _Orb({required this.size, required this.color, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width:  size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withOpacity(opacity),
            color.withOpacity(opacity * 0.3),
            Colors.transparent,
          ],
          stops: const [0.0, 0.4, 1.0],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BG PAINTER
// ─────────────────────────────────────────────────────────────────────────────
class _BgPainter extends CustomPainter {
  final double w, h;
  const _BgPainter({required this.w, required this.h});

  @override
  void paint(Canvas canvas, Size size) {
    // Deep dark base
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..color = const Color(0xFF080810),
    );

    // Subtle center vignette lift
    final cx = w / 2;
    final cy = h * 0.44;
    canvas.drawCircle(
      Offset(cx, cy),
      w * 0.68,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF1A0A2E).withOpacity(0.55),
            Colors.transparent,
          ],
          stops: const [0.0, 1.0],
        ).createShader(
            Rect.fromCircle(center: Offset(cx, cy), radius: w * 0.68)),
    );

    // Very subtle grid lines (iOS-feel)
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.018)
      ..strokeWidth = 0.5;
    const step = 36.0;
    for (double x = 0; x < w; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, h), gridPaint);
    }
    for (double y = 0; y < h; y += step) {
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(_BgPainter _) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// FALLBACK ICON
// ─────────────────────────────────────────────────────────────────────────────
class _FallbackIcon extends StatelessWidget {
  final double size;
  const _FallbackIcon({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.22),
        gradient: const LinearGradient(
          colors: [Color(0xFF3B0764), Color(0xFF6D28D9), Color(0xFFDB2777)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Icon(
        Icons.music_note_rounded,
        color: Colors.white.withOpacity(0.9),
        size: size * 0.46,
      ),
    );
  }
}