import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DEN — ULTRA PREMIUM SPLASH SCREEN v4
// ─────────────────────────────────────────────────────────────────────────────

const _pink       = Color(0xFFFFB3C6);
const _pinkHot    = Color(0xFFFF4D8F);
const _purple     = Color(0xFF9B59E8);
const _purpleDark = Color(0xFF4A0E8F);
const _bg         = Color(0xFF04040C);

class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const SplashScreen({super.key, required this.onComplete});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {

  late final AnimationController _nebulaCtrl;

  late final AnimationController _iconCtrl;
  late final Animation<double>   _iconScale;
  late final Animation<double>   _iconOpacity;

  late final AnimationController _haloCtrl;
  late final Animation<double>   _haloScale;
  late final Animation<double>   _haloOpacity;

  late final AnimationController _glowCtrl;
  late final Animation<double>   _glowAlpha;

  late final AnimationController _shockCtrl;

  late final AnimationController _waveAnimCtrl;
  late final AnimationController _waveEnterCtrl;
  late final Animation<double>   _waveEnter;

  late final AnimationController _botAnimCtrl;
  late final AnimationController _botEnterCtrl;
  late final Animation<double>   _botEnter;

  late final AnimationController _textCtrl;
  late final Animation<double>   _textOpacity;
  late final Animation<double>   _textScale;

  late final AnimationController _tagCtrl;
  late final Animation<double>   _tagOpacity;

  late final AnimationController _starCtrl;
  late final AnimationController _rot1;
  late final AnimationController _rot2;
  late final AnimationController _progressCtrl;
  late final Animation<double>   _progressVal;
  late final AnimationController _shimCtrl;
  late final AnimationController _exitCtrl;
  late final Animation<double>   _exitOpacity;

  final _stars = <_Star>[];

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    final rng = math.Random(7);
    for (int i = 0; i < 55; i++) {
      _stars.add(_Star(
        x: rng.nextDouble(), y: rng.nextDouble(),
        r: rng.nextDouble() * 1.6 + 0.3,
        phase: rng.nextDouble() * 2 * math.pi,
        pink: i % 3 == 0,
      ));
    }

    _nebulaCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))..forward();

    _iconCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 950));
    _iconScale = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _iconCtrl, curve: Curves.elasticOut));
    _iconOpacity = CurvedAnimation(parent: _iconCtrl,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut));

    _haloCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100));
    _haloScale = Tween<double>(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(parent: _haloCtrl, curve: Curves.easeOutCubic));
    _haloOpacity = CurvedAnimation(parent: _haloCtrl, curve: Curves.easeOut);

    _glowCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600));
    _glowAlpha = Tween<double>(begin: 0.35, end: 0.85).animate(
        CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));

    _shockCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1700));

    _waveAnimCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 750))..repeat();
    _waveEnterCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _waveEnter = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _waveEnterCtrl, curve: Curves.easeOutCubic));

    _botAnimCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 780))..repeat();
    _botEnterCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 750));
    _botEnter = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _botEnterCtrl, curve: Curves.easeOutCubic));

    _textCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _textOpacity = CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut);
    _textScale = Tween<double>(begin: 0.82, end: 1.0).animate(
        CurvedAnimation(parent: _textCtrl, curve: Curves.easeOutBack));

    _tagCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _tagOpacity = CurvedAnimation(parent: _tagCtrl, curve: Curves.easeOut);

    _starCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 4))..repeat();

    _rot1 = AnimationController(
        vsync: this, duration: const Duration(seconds: 7))..repeat();
    _rot2 = AnimationController(
        vsync: this, duration: const Duration(seconds: 11))..repeat();

    _progressCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3000))..forward();
    _progressVal = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _progressCtrl, curve: Curves.easeInOut));

    _shimCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600))..repeat();

    _exitCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _exitOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(parent: _exitCtrl, curve: Curves.easeIn));

    _runSequence();
  }

  Future<void> _runSequence() async {
    await Future.delayed(const Duration(milliseconds: 200));
    _shockCtrl.forward();
    _iconCtrl.forward();
    _haloCtrl.forward();
    _glowCtrl.repeat(reverse: true);

    await Future.delayed(const Duration(milliseconds: 520));
    _waveEnterCtrl.forward();

    await Future.delayed(const Duration(milliseconds: 180));
    _botEnterCtrl.forward();

    await Future.delayed(const Duration(milliseconds: 260));
    _textCtrl.forward();

    await Future.delayed(const Duration(milliseconds: 340));
    _tagCtrl.forward();

    await Future.delayed(const Duration(milliseconds: 1100));
    _glowCtrl.stop();
    await _exitCtrl.forward();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    widget.onComplete();
  }

  @override
  void dispose() {
    _nebulaCtrl.dispose();
    _iconCtrl.dispose();
    _haloCtrl.dispose();
    _glowCtrl.dispose();
    _shockCtrl.dispose();
    _waveAnimCtrl.dispose();
    _waveEnterCtrl.dispose();
    _botAnimCtrl.dispose();
    _botEnterCtrl.dispose();
    _textCtrl.dispose();
    _tagCtrl.dispose();
    _starCtrl.dispose();
    _rot1.dispose();
    _rot2.dispose();
    _progressCtrl.dispose();
    _shimCtrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;

    return AnimatedBuilder(
      animation: _exitCtrl,
      builder: (_, child) =>
          Opacity(opacity: _exitOpacity.value, child: child),
      child: Scaffold(
        backgroundColor: _bg,
        body: Stack(
          fit: StackFit.expand,
          children: [

            // 1. NEBULA
            AnimatedBuilder(
              animation: _nebulaCtrl,
              builder: (_, __) => CustomPaint(
                size: Size(sw, sh),
                painter: _NebulaPainter(p: _nebulaCtrl.value,
                    w: sw, h: sh),
              ),
            ),

            // 2. STARS
            AnimatedBuilder(
              animation: _starCtrl,
              builder: (_, __) => CustomPaint(
                size: Size(sw, sh),
                painter: _StarPainter(stars: _stars, t: _starCtrl.value),
              ),
            ),

            // 3. SHOCKWAVES
            Center(
              child: AnimatedBuilder(
                animation: _shockCtrl,
                builder: (_, __) => Stack(
                  alignment: Alignment.center,
                  children: [
                    _SWave(t: _shockCtrl.value, d: 0.00,
                        max: sw * 1.3, c: _purple),
                    _SWave(t: _shockCtrl.value, d: 0.10,
                        max: sw * 1.7, c: _pink),
                    _SWave(t: _shockCtrl.value, d: 0.20,
                        max: sw * 2.1, c: _purpleDark),
                  ],
                ),
              ),
            ),

            // 4. MAIN COLUMN
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [

                // ICON BLOCK
                AnimatedBuilder(
                  animation: Listenable.merge([
                    _iconCtrl, _haloCtrl, _glowCtrl,
                    _rot1, _rot2, _shimCtrl,
                  ]),
                  builder: (_, __) {
                    final iconSize = sw * 0.34;
                    final areaSize = sw * 0.78;
                    return SizedBox(
                      width: areaSize, height: areaSize,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [

                          // Ambient glow
                          Container(
                            width:  areaSize * 0.88,
                            height: areaSize * 0.88,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  _purple.withOpacity(
                                      0.3 * _glowAlpha.value),
                                  _pink.withOpacity(
                                      0.1 * _glowAlpha.value),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),

                          // Outer static ring
                          Opacity(
                            opacity: _haloOpacity.value * 0.2,
                            child: Transform.scale(
                              scale: _haloScale.value,
                              child: Container(
                                width: areaSize * 0.82,
                                height: areaSize * 0.82,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: _purple, width: 0.5),
                                ),
                              ),
                            ),
                          ),

                          // Mid ring
                          Opacity(
                            opacity: _haloOpacity.value * 0.32,
                            child: Transform.scale(
                              scale: _haloScale.value,
                              child: Container(
                                width: areaSize * 0.65,
                                height: areaSize * 0.65,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: _pink.withOpacity(0.6),
                                      width: 0.5),
                                ),
                              ),
                            ),
                          ),

                          // Rotating dashed ring 1
                          Transform.rotate(
                            angle: _rot1.value * 2 * math.pi,
                            child: Opacity(
                              opacity: _haloOpacity.value * 0.55,
                              child: CustomPaint(
                                size: Size(areaSize * 0.54,
                                    areaSize * 0.54),
                                painter: _DashRing(
                                    c: _purple.withOpacity(0.65),
                                    n: 28, sw: 1.2),
                              ),
                            ),
                          ),

                          // Rotating dashed ring 2 counter
                          Transform.rotate(
                            angle: -_rot2.value * 2 * math.pi,
                            child: Opacity(
                              opacity: _haloOpacity.value * 0.4,
                              child: CustomPaint(
                                size: Size(areaSize * 0.43,
                                    areaSize * 0.43),
                                painter: _DashRing(
                                    c: _pink.withOpacity(0.55),
                                    n: 18, sw: 0.9),
                              ),
                            ),
                          ),

                          // Icon with deep glow — NO white bg
                          Opacity(
                            opacity: _iconOpacity.value,
                            child: Transform.scale(
                              scale: _iconScale.value,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Deep glow behind
                                  Container(
                                    width:  iconSize + 24,
                                    height: iconSize + 24,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: RadialGradient(
                                        colors: [
                                          _purple.withOpacity(0.85),
                                          _purpleDark.withOpacity(0.4),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  ),
                                  // Outer shadow box
                                  Container(
                                    width:  iconSize + 4,
                                    height: iconSize + 4,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(
                                          iconSize * 0.235),
                                      boxShadow: [
                                        BoxShadow(
                                          color: _purple.withOpacity(0.85),
                                          blurRadius: 60,
                                          spreadRadius: 12,
                                        ),
                                        BoxShadow(
                                          color: _pink.withOpacity(0.4),
                                          blurRadius: 90,
                                          spreadRadius: 0,
                                        ),
                                      ],
                                    ),
                                  ),
                                  // The icon — clipped tightly
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(
                                        iconSize * 0.22),
                                    child: Image.asset(
                                      'assets/icons/app_icon.png',
                                      width:  iconSize,
                                      height: iconSize,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          _Fallback(s: iconSize),
                                    ),
                                  ),
                                  // Shimmer sweep
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(
                                        iconSize * 0.22),
                                    child: SizedBox(
                                      width:  iconSize,
                                      height: iconSize,
                                      child: CustomPaint(
                                        painter: _ShimmerPainter(
                                            p: _shimCtrl.value),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        ],
                      ),
                    );
                  },
                ),

                // WAVEFORM — wide, right below icon
                AnimatedBuilder(
                  animation: Listenable.merge(
                      [_waveAnimCtrl, _waveEnter]),
                  builder: (_, __) => _Wave(
                    anim:  _waveAnimCtrl.value,
                    enter: _waveEnter.value,
                    w:     sw * 0.88,
                    maxH:  42,
                    bars:  52,
                  ),
                ),

                const SizedBox(height: 26),

                // DEN TEXT — huge, glowing
                AnimatedBuilder(
                  animation: _textCtrl,
                  builder: (_, __) => Opacity(
                    opacity: _textOpacity.value,
                    child: Transform.scale(
                      scale: _textScale.value,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Text('DEN', style: TextStyle(
                            fontSize: 96, fontWeight: FontWeight.w100,
                            foreground: Paint()
                              ..maskFilter = const MaskFilter.blur(
                                  BlurStyle.normal, 32)
                              ..color = _purple.withOpacity(0.7),
                            height: 1, letterSpacing: 24,
                          )),
                          Text('DEN', style: TextStyle(
                            fontSize: 96, fontWeight: FontWeight.w100,
                            foreground: Paint()
                              ..maskFilter = const MaskFilter.blur(
                                  BlurStyle.normal, 12)
                              ..color = _pink.withOpacity(0.45),
                            height: 1, letterSpacing: 24,
                          )),
                          const Text('DEN', style: TextStyle(
                            fontSize: 96, fontWeight: FontWeight.w100,
                            color: Colors.white,
                            height: 1, letterSpacing: 24,
                          )),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // TAGLINE
                AnimatedBuilder(
                  animation: _tagCtrl,
                  builder: (_, __) => Opacity(
                    opacity: _tagOpacity.value,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 38, height: 0.5,
                            color: _pink.withOpacity(0.4)),
                        const SizedBox(width: 14),
                        Text('feel every beat',
                          style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w300,
                            color: Colors.white.withOpacity(0.4),
                            letterSpacing: 4.5,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Container(width: 38, height: 0.5,
                            color: _pink.withOpacity(0.4)),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 48),

                // PROGRESS BAR
                AnimatedBuilder(
                  animation: Listenable.merge(
                      [_progressCtrl, _tagOpacity]),
                  builder: (_, __) => Opacity(
                    opacity: _tagOpacity.value,
                    child: SizedBox(
                      width: sw * 0.3, height: 2,
                      child: Stack(children: [
                        Container(
                            color: Colors.white.withOpacity(0.07)),
                        FractionallySizedBox(
                          widthFactor: _progressVal.value,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                  colors: [_pink, _purple]),
                              boxShadow: [BoxShadow(
                                color: _pink.withOpacity(0.7),
                                blurRadius: 10,
                              )],
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),

              ],
            ),

          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WAVEFORM
// ─────────────────────────────────────────────────────────────────────────────
class _Wave extends StatelessWidget {
  final double anim, enter, w, maxH;
  final int bars;
  const _Wave({
    required this.anim, required this.enter,
    required this.w, required this.maxH, required this.bars,
  });

  @override
  Widget build(BuildContext context) {
    const barW = 2.2;
    const minH = 2.0;
    final gap  = (w - bars * barW) / bars;

    return SizedBox(
      height: maxH, width: w,
      child: Row(
        mainAxisAlignment:  MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(bars, (i) {
          final p1 = (i / bars) * 2 * math.pi;
          final p2 = (i / bars) * 3.3 * math.pi + 1.1;
          final w1 = math.sin(anim * 2 * math.pi + p1);
          final w2 = math.sin(anim * 1.7 * math.pi + p2);
          final c  = ((w1 + w2) / 2 + 1) / 2;
          final raw = minH + (maxH - minH) * c;
          final h   = minH + (raw - minH) * enter;

          final edge = i < 7 ? i / 7.0
              : i > bars - 8 ? (bars - 1 - i) / 7.0 : 1.0;

          final t = i / (bars - 1).toDouble();
          final col = t < 0.5
              ? Color.lerp(_pink, _purple, t * 2)!
              : Color.lerp(_purple, _pink, (t - 0.5) * 2)!;

          return Container(
            width: barW, height: h.clamp(minH, maxH),
            margin: EdgeInsets.symmetric(horizontal: gap / 2),
            decoration: BoxDecoration(
              color: col.withOpacity(0.9 * edge),
              borderRadius: BorderRadius.circular(barW),
              boxShadow: h > 18 ? [BoxShadow(
                color: col.withOpacity(0.38 * edge),
                blurRadius: 8,
              )] : null,
            ),
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHOCKWAVE
// ─────────────────────────────────────────────────────────────────────────────
class _SWave extends StatelessWidget {
  final double t, d, max;
  final Color c;
  const _SWave({required this.t, required this.d,
      required this.max, required this.c});

  @override
  Widget build(BuildContext context) {
    final p = ((t - d) / (1.0 - d)).clamp(0.0, 1.0);
    if (p <= 0) return const SizedBox.shrink();
    final r  = p * max;
    final op = (1.0 - p).clamp(0.0, 0.55);
    return Container(
      width: r, height: r,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: c.withOpacity(op),
          width: 1.5 * (1 - p * 0.7),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NEBULA
// ─────────────────────────────────────────────────────────────────────────────
class _NebulaPainter extends CustomPainter {
  final double p, w, h;
  const _NebulaPainter({required this.p, required this.w, required this.h});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h),
        Paint()..color = _bg);

    void blob(Offset c, double r, Color col, double op) {
      canvas.drawCircle(c, r, Paint()
        ..shader = RadialGradient(colors: [
          col.withOpacity(op * p),
          Colors.transparent,
        ]).createShader(Rect.fromCircle(center: c, radius: r)));
    }

    blob(Offset(w / 2, h * 0.27), w * 0.75,
        const Color(0xFF1A0845), 0.95);
    blob(Offset(w / 2, h * 0.82), w * 0.55,
        const Color(0xFF2D0A5C), 0.4);
    blob(Offset(w * 0.12, h * 0.45), w * 0.38,
        _pinkHot, 0.07);
    blob(Offset(w * 0.88, h * 0.35), w * 0.32,
        _purple, 0.06);
  }

  @override
  bool shouldRepaint(_NebulaPainter o) => o.p != p;
}

// ─────────────────────────────────────────────────────────────────────────────
// STARS
// ─────────────────────────────────────────────────────────────────────────────
class _Star {
  final double x, y, r, phase;
  final bool   pink;
  const _Star({required this.x, required this.y,
      required this.r, required this.phase, required this.pink});
}

class _StarPainter extends CustomPainter {
  final List<_Star> stars;
  final double t;
  const _StarPainter({required this.stars, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in stars) {
      final tw = math.sin(t * 2 * math.pi + s.phase);
      final op = 0.12 + 0.55 * ((tw + 1) / 2);
      final col = (s.pink ? _pink : _purple).withOpacity(op);
      final x = s.x * size.width;
      final y = s.y * size.height;
      canvas.drawCircle(Offset(x, y), s.r, Paint()..color = col);
      if (s.r > 1.0) {
        final lp = Paint()
          ..color = col.withOpacity(op * 0.45)
          ..strokeWidth = 0.4;
        final sp = s.r * 3.5;
        canvas.drawLine(Offset(x-sp, y), Offset(x+sp, y), lp);
        canvas.drawLine(Offset(x, y-sp), Offset(x, y+sp), lp);
      }
    }
  }

  @override
  bool shouldRepaint(_StarPainter o) => o.t != t;
}

// ─────────────────────────────────────────────────────────────────────────────
// DASHED RING
// ─────────────────────────────────────────────────────────────────────────────
class _DashRing extends CustomPainter {
  final Color c;
  final int   n;
  final double sw;
  const _DashRing({required this.c, required this.n, required this.sw});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = c ..style = PaintingStyle.stroke
      ..strokeWidth = sw ..strokeCap = StrokeCap.round;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = math.min(cx, cy);
    final step = 2 * math.pi / n;
    const gap = 0.06;
    for (int i = 0; i < n; i++) {
      canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r),
          i * step + gap, step - gap * 2, false, paint);
    }
  }

  @override
  bool shouldRepaint(_DashRing _) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// SHIMMER
// ─────────────────────────────────────────────────────────────────────────────
class _ShimmerPainter extends CustomPainter {
  final double p;
  const _ShimmerPainter({required this.p});

  @override
  void paint(Canvas canvas, Size size) {
    final x = p * (size.width + 80) - 40;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..shader = LinearGradient(colors: [
        Colors.transparent,
        Colors.white.withOpacity(0.14),
        Colors.transparent,
      ], stops: const [0, 0.5, 1]).createShader(
          Rect.fromLTWH(x - 40, 0, 80, size.height)),
    );
  }

  @override
  bool shouldRepaint(_ShimmerPainter o) => o.p != p;
}

// ─────────────────────────────────────────────────────────────────────────────
// FALLBACK
// ─────────────────────────────────────────────────────────────────────────────
class _Fallback extends StatelessWidget {
  final double s;
  const _Fallback({required this.s});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: s, height: s,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(s * 0.22),
        gradient: const LinearGradient(
          colors: [_purpleDark, _purple, _pinkHot],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
      ),
      child: Icon(Icons.music_note_rounded,
          color: Colors.white, size: s * 0.5),
    );
  }
}