import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DEN — SPLASH SCREEN v8
// Premium · Balanced · Breathing
// ─────────────────────────────────────────────────────────────────────────────

const _bg          = Color(0xFF06060F);
const _purple      = Color(0xFF7C3AED);
const _purpleMid   = Color(0xFF5B21B6);
const _purpleDark  = Color(0xFF2E1065);
const _pink        = Color(0xFFDB2777);
const _teal        = Color(0xFF0D9488);
const _white       = Color(0xFFFFFFFF);

class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const SplashScreen({super.key, required this.onComplete});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {

  // Background particle drift
  late final AnimationController _particleCtrl;

  // Icon entrance + breathe
  late final AnimationController _iconEnterCtrl;
  late final Animation<double>   _iconScale;
  late final Animation<double>   _iconFade;
  late final AnimationController _breatheCtrl;
  late final Animation<double>   _breatheScale;
  late final Animation<double>   _breatheGlow;

  // Outer ring — slow rotation
  late final AnimationController _ringCtrl;

  // Text stagger
  late final AnimationController _denCtrl;
  late final Animation<double>   _denFade;
  late final Animation<double>   _denY;
  late final AnimationController _tagCtrl;
  late final Animation<double>   _tagFade;

  // Progress
  late final AnimationController _progressCtrl;
  late final Animation<double>   _progressVal;

  // Exit
  late final AnimationController _exitCtrl;
  late final Animation<double>   _exitFade;

  // Particles
  final List<_Particle> _particles = [];

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _buildParticles();
    _initControllers();
    _runSequence();
  }

  void _buildParticles() {
    final rng = math.Random(7);
    for (int i = 0; i < 38; i++) {
      _particles.add(_Particle(
        x:      rng.nextDouble(),
        y:      rng.nextDouble(),
        radius: rng.nextDouble() * 1.2 + 0.4,
        speed:  rng.nextDouble() * 0.18 + 0.04,
        phase:  rng.nextDouble() * math.pi * 2,
        drift:  (rng.nextDouble() - 0.5) * 0.06,
        color:  i % 5 == 0 ? _teal
              : i % 3 == 0 ? _pink
              : _purple,
      ));
    }
  }

  void _initControllers() {
    _particleCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 6))
      ..repeat();

    _iconEnterCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000));
    _iconScale = Tween(begin: 0.75, end: 1.0).animate(
        CurvedAnimation(parent: _iconEnterCtrl, curve: Curves.easeOutCubic));
    _iconFade = CurvedAnimation(
        parent: _iconEnterCtrl,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOut));

    _breatheCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3200))
      ..repeat(reverse: true);
    _breatheScale = Tween(begin: 0.94, end: 1.06).animate(
        CurvedAnimation(parent: _breatheCtrl, curve: Curves.easeInOut));
    _breatheGlow = Tween(begin: 0.30, end: 0.55).animate(
        CurvedAnimation(parent: _breatheCtrl, curve: Curves.easeInOut));

    _ringCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 18))
      ..repeat();

    _denCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 750));
    _denFade = CurvedAnimation(parent: _denCtrl, curve: Curves.easeOut);
    _denY    = Tween(begin: 20.0, end: 0.0).animate(
        CurvedAnimation(parent: _denCtrl, curve: Curves.easeOutCubic));

    _tagCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _tagFade = CurvedAnimation(parent: _tagCtrl, curve: Curves.easeOut);

    _progressCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2800))
      ..forward();
    _progressVal = Tween(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _progressCtrl, curve: Curves.easeInOut));

    _exitCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 550));
    _exitFade = Tween(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(parent: _exitCtrl, curve: Curves.easeIn));
  }

  Future<void> _runSequence() async {
    await Future.delayed(const Duration(milliseconds: 160));
    _iconEnterCtrl.forward();

    await Future.delayed(const Duration(milliseconds: 580));
    _denCtrl.forward();

    await Future.delayed(const Duration(milliseconds: 320));
    _tagCtrl.forward();

    await Future.delayed(const Duration(milliseconds: 2000));
    await _exitCtrl.forward();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    widget.onComplete();
  }

  @override
  void dispose() {
    _particleCtrl.dispose();
    _iconEnterCtrl.dispose();
    _breatheCtrl.dispose();
    _ringCtrl.dispose();
    _denCtrl.dispose();
    _tagCtrl.dispose();
    _progressCtrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;
    final iconSize  = math.min(sw * 0.28, 116.0);
    // Push cluster to visual center accounting for status bar
    final clusterTop = sh * 0.34;

    return AnimatedBuilder(
      animation: _exitCtrl,
      builder: (_, child) =>
          Opacity(opacity: _exitFade.value, child: child),
      child: Scaffold(
        backgroundColor: _bg,
        body: Stack(
          clipBehavior: Clip.hardEdge,
          children: [

            // ── 1. BG GRADIENT ───────────────────────────────────────────
            Positioned.fill(
              child: CustomPaint(painter: _BgPainter(w: sw, h: sh)),
            ),

            // ── 2. PARTICLES ─────────────────────────────────────────────
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _particleCtrl,
                builder: (_, __) => CustomPaint(
                  painter: _ParticlePainter(
                    particles: _particles,
                    t: _particleCtrl.value,
                    w: sw, h: sh,
                  ),
                ),
              ),
            ),

            // ── 3. ICON CLUSTER ──────────────────────────────────────────
            Positioned(
              left: 0, right: 0,
              top: clusterTop - iconSize * 0.5 - 32,
              child: AnimatedBuilder(
                animation: Listenable.merge([
                  _iconEnterCtrl, _breatheCtrl, _ringCtrl,
                ]),
                builder: (_, __) => _IconCluster(
                  iconSize:     iconSize,
                  iconScale:    _iconScale.value,
                  iconFade:     _iconFade.value,
                  breatheScale: _breatheScale.value,
                  breatheGlow:  _breatheGlow.value,
                  ringAngle:    _ringCtrl.value * 2 * math.pi,
                ),
              ),
            ),

            // ── 4. DEN + TAGLINE ─────────────────────────────────────────
            Positioned(
              left: 0, right: 0,
              top: clusterTop + iconSize * 0.5 + 36,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [

                  // DEN
                  AnimatedBuilder(
                    animation: _denCtrl,
                    builder: (_, __) => Opacity(
                      opacity: _denFade.value,
                      child: Transform.translate(
                        offset: Offset(0, _denY.value),
                        child: _DenWordmark(sw: sw),
                      ),
                    ),
                  ),

                  SizedBox(height: sh * 0.018),

                  // Divider line
                  AnimatedBuilder(
                    animation: _tagCtrl,
                    builder: (_, __) => Opacity(
                      opacity: _tagFade.value,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _LineDivider(),
                          const SizedBox(width: 14),
                          Text(
                            'feel every beat',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w300,
                              color: _white.withOpacity(0.30),
                              letterSpacing: 4.5,
                            ),
                          ),
                          const SizedBox(width: 14),
                          _LineDivider(),
                        ],
                      ),
                    ),
                  ),

                ],
              ),
            ),

            // ── 5. PROGRESS BAR ──────────────────────────────────────────
            Positioned(
              bottom: sh * 0.09,
              left: sw * 0.34,
              right: sw * 0.34,
              child: AnimatedBuilder(
                animation: Listenable.merge([_tagCtrl, _progressCtrl]),
                builder: (_, __) => Opacity(
                  opacity: _tagFade.value,
                  child: _ProgressBar(progress: _progressVal.value),
                ),
              ),
            ),

          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ICON CLUSTER
// ─────────────────────────────────────────────────────────────────────────────
class _IconCluster extends StatelessWidget {
  final double iconSize, iconScale, iconFade;
  final double breatheScale, breatheGlow, ringAngle;

  const _IconCluster({
    required this.iconSize,
    required this.iconScale, required this.iconFade,
    required this.breatheScale, required this.breatheGlow,
    required this.ringAngle,
  });

  @override
  Widget build(BuildContext context) {
    final clusterSize = iconSize + 90.0;

    return SizedBox(
      height: clusterSize,
      child: Stack(
        alignment: Alignment.center,
        children: [

          // Outer breathing aura
          Transform.scale(
            scale: breatheScale,
            child: Container(
              width: clusterSize,
              height: clusterSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _purple.withOpacity(breatheGlow * 0.45),
                    _purpleDark.withOpacity(breatheGlow * 0.15),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),

          // Rotating thin ring
          Transform.rotate(
            angle: ringAngle,
            child: SizedBox(
              width: iconSize + 52,
              height: iconSize + 52,
              child: CustomPaint(
                painter: _RingPainter(
                  color: _purple.withOpacity(0.22),
                  dashCount: 40,
                  strokeWidth: 0.6,
                ),
              ),
            ),
          ),

          // Counter-rotating inner ring
          Transform.rotate(
            angle: -ringAngle * 1.5,
            child: SizedBox(
              width: iconSize + 28,
              height: iconSize + 28,
              child: CustomPaint(
                painter: _RingPainter(
                  color: _pink.withOpacity(0.14),
                  dashCount: 24,
                  strokeWidth: 0.5,
                ),
              ),
            ),
          ),

          // Icon
          Opacity(
            opacity: iconFade,
            child: Transform.scale(
              scale: iconScale * breatheScale * 0.5 + iconScale * 0.5,
              child: Stack(
                alignment: Alignment.center,
                children: [

                  // Glow behind icon
                  Container(
                    width: iconSize + 12,
                    height: iconSize + 12,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular((iconSize + 12) * 0.25),
                      boxShadow: [
                        BoxShadow(
                          color: _purple.withOpacity(0.60),
                          blurRadius: 40,
                          spreadRadius: 4,
                        ),
                        BoxShadow(
                          color: _pink.withOpacity(0.22),
                          blurRadius: 56,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                  ),

                  // App icon image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(iconSize * 0.24),
                    child: Image.asset(
                      'assets/icons/app_icon.png',
                      width: iconSize,
                      height: iconSize,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _FallbackIcon(size: iconSize),
                    ),
                  ),

                ],
              ),
            ),
          ),

        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DEN WORDMARK
// ─────────────────────────────────────────────────────────────────────────────
class _DenWordmark extends StatelessWidget {
  final double sw;
  const _DenWordmark({required this.sw});

  @override
  Widget build(BuildContext context) {
    final fs = math.min(sw * 0.17, 72.0);
    return Stack(
      alignment: Alignment.center,
      children: [
        // Glow
        Text('DEN', style: TextStyle(
          fontSize: fs,
          fontWeight: FontWeight.w200,
          letterSpacing: 18,
          height: 1,
          foreground: Paint()
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22)
            ..color = _purple.withOpacity(0.50),
        )),
        // Pink accent glow
        Text('DEN', style: TextStyle(
          fontSize: fs,
          fontWeight: FontWeight.w200,
          letterSpacing: 18,
          height: 1,
          foreground: Paint()
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
            ..color = _pink.withOpacity(0.20),
        )),
        // Crisp white
        Text('DEN', style: TextStyle(
          fontSize: fs,
          fontWeight: FontWeight.w200,
          color: _white.withOpacity(0.95),
          letterSpacing: 18,
          height: 1,
        )),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROGRESS BAR
// ─────────────────────────────────────────────────────────────────────────────
class _ProgressBar extends StatelessWidget {
  final double progress;
  const _ProgressBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1.5,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(1),
        color: _white.withOpacity(0.06),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(1),
            gradient: const LinearGradient(
              colors: [_purple, _pink],
            ),
            boxShadow: [
              BoxShadow(
                color: _purple.withOpacity(0.60),
                blurRadius: 8,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────

class _LineDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 0.5,
      color: _white.withOpacity(0.18),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PAINTERS
// ─────────────────────────────────────────────────────────────────────────────

class _BgPainter extends CustomPainter {
  final double w, h;
  const _BgPainter({required this.w, required this.h});

  @override
  void paint(Canvas canvas, Size size) {
    // Base fill
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h),
        Paint()..color = _bg);

    // Subtle deep purple mass — top center, tight
    final cx = w / 2;
    final cy = h * 0.38;
    final r  = w * 0.68;
    canvas.drawCircle(
      Offset(cx, cy), r,
      Paint()..shader = RadialGradient(
        colors: [
          _purpleDark.withOpacity(0.55),
          _purpleDark.withOpacity(0.10),
          Colors.transparent,
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r)),
    );

    // Tiny pink hint — bottom right
    canvas.drawCircle(
      Offset(w * 0.85, h * 0.78), w * 0.28,
      Paint()..shader = RadialGradient(
        colors: [_pink.withOpacity(0.06), Colors.transparent],
      ).createShader(Rect.fromCircle(
          center: Offset(w * 0.85, h * 0.78), radius: w * 0.28)),
    );

    // Tiny teal hint — top left
    canvas.drawCircle(
      Offset(w * 0.10, h * 0.18), w * 0.22,
      Paint()..shader = RadialGradient(
        colors: [_teal.withOpacity(0.06), Colors.transparent],
      ).createShader(Rect.fromCircle(
          center: Offset(w * 0.10, h * 0.18), radius: w * 0.22)),
    );
  }

  @override
  bool shouldRepaint(_BgPainter _) => false;
}

class _Particle {
  final double x, y, radius, speed, phase, drift;
  final Color color;
  const _Particle({
    required this.x, required this.y,
    required this.radius, required this.speed,
    required this.phase, required this.drift,
    required this.color,
  });
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double t, w, h;
  const _ParticlePainter(
      {required this.particles, required this.t,
       required this.w, required this.h});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      // Slow upward drift + horizontal sine
      final dy    = (t * p.speed) % 1.0;
      final yPos  = ((p.y - dy + 1.0) % 1.0) * h;
      final xPos  = p.x * w + math.sin(t * 2 * math.pi + p.phase) * w * p.drift;
      final twink = math.sin(t * 2 * math.pi * 1.3 + p.phase);
      final op    = (0.06 + 0.18 * ((twink + 1) / 2)).clamp(0.0, 1.0);

      canvas.drawCircle(
        Offset(xPos, yPos),
        p.radius,
        Paint()..color = p.color.withOpacity(op),
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter o) => o.t != t;
}

class _RingPainter extends CustomPainter {
  final Color color;
  final int dashCount;
  final double strokeWidth;
  const _RingPainter(
      {required this.color,
       required this.dashCount,
       required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final cx   = size.width / 2;
    final cy   = size.height / 2;
    final r    = math.min(cx, cy);
    final step = (2 * math.pi) / dashCount;
    const gap  = 0.07;
    for (int i = 0; i < dashCount; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        i * step + gap,
        step - gap * 2,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter _) => false;
}

class _FallbackIcon extends StatelessWidget {
  final double size;
  const _FallbackIcon({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.24),
        gradient: const LinearGradient(
          colors: [_purpleDark, _purple, _pink],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Icon(
        Icons.music_note_rounded,
        color: _white.withOpacity(0.90),
        size: size * 0.44,
      ),
    );
  }
}