import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DEN — ULTRA PREMIUM SPLASH SCREEN v6
// Layout: Stack + Positioned everywhere → ZERO overflow, any screen size
// ─────────────────────────────────────────────────────────────────────────────

const _pink       = Color(0xFFFFB3C6);
const _pinkHot    = Color(0xFFFF4D8F);
const _purple     = Color(0xFF9B59E8);
const _purpleDark = Color(0xFF4A0E8F);
const _teal       = Color(0xFF00E5CC);
const _bg         = Color(0xFF04040C);

class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const SplashScreen({super.key, required this.onComplete});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {

  late final AnimationController _auroraCtrl;
  late final AnimationController _iconCtrl;
  late final Animation<double>   _iconScale;
  late final Animation<double>   _iconOpacity;
  late final AnimationController _haloCtrl;
  late final Animation<double>   _haloScale;
  late final Animation<double>   _haloOpacity;
  late final AnimationController _glowCtrl;
  late final Animation<double>   _glowAlpha;
  late final AnimationController _pulseCtrl;
  late final Animation<double>   _pulseScale;
  late final AnimationController _shockCtrl;
  late final AnimationController _waveAnimCtrl;
  late final AnimationController _waveEnterCtrl;
  late final Animation<double>   _waveEnter;
  late final AnimationController _vizCtrl;
  late final AnimationController _vizEnterCtrl;
  late final Animation<double>   _vizEnter;
  late final List<AnimationController> _letterCtrls;
  late final List<Animation<double>>   _letterOpacity;
  late final List<Animation<double>>   _letterY;
  late final AnimationController _tagCtrl;
  late final Animation<double>   _tagOpacity;
  late final AnimationController _progressCtrl;
  late final Animation<double>   _progressVal;
  late final AnimationController _shimCtrl;
  late final AnimationController _bottomCtrl;
  late final Animation<double>   _bottomOpacity;
  late final AnimationController _rot1;
  late final AnimationController _rot2;
  late final AnimationController _rot3;
  late final AnimationController _starCtrl;
  late final AnimationController _exitCtrl;
  late final Animation<double>   _exitOpacity;

  final _stars = <_Star>[];

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    final rng = math.Random(7);
    for (int i = 0; i < 65; i++) {
      _stars.add(_Star(
        x: rng.nextDouble(), y: rng.nextDouble(),
        r: rng.nextDouble() * 1.8 + 0.3,
        phase: rng.nextDouble() * 2 * math.pi,
        pink: i % 3 == 0, teal: i % 7 == 0,
      ));
    }

    _auroraCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 8))..repeat(reverse: true);

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
    _glowAlpha = Tween<double>(begin: 0.35, end: 0.95).animate(
        CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));

    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2200));
    _pulseScale = Tween<double>(begin: 1.0, end: 1.045).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _shockCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1700));

    _waveAnimCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 750))..repeat();
    _waveEnterCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _waveEnter = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _waveEnterCtrl, curve: Curves.easeOutCubic));

    _vizCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))..repeat();
    _vizEnterCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _vizEnter = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _vizEnterCtrl, curve: Curves.easeOutBack));

    _letterCtrls = List.generate(3, (_) => AnimationController(
        vsync: this, duration: const Duration(milliseconds: 550)));
    _letterOpacity = _letterCtrls.map((c) =>
        CurvedAnimation(parent: c, curve: Curves.easeOut)).toList();
    _letterY = _letterCtrls.map((c) =>
        Tween<double>(begin: 22.0, end: 0.0).animate(
            CurvedAnimation(parent: c, curve: Curves.easeOutBack))).toList();

    _tagCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _tagOpacity = CurvedAnimation(parent: _tagCtrl, curve: Curves.easeOut);

    _progressCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3000))..forward();
    _progressVal = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _progressCtrl, curve: Curves.easeInOut));
    _shimCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600))..repeat();

    _bottomCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _bottomOpacity = CurvedAnimation(parent: _bottomCtrl, curve: Curves.easeOut);

    _rot1 = AnimationController(
        vsync: this, duration: const Duration(seconds: 7))..repeat();
    _rot2 = AnimationController(
        vsync: this, duration: const Duration(seconds: 11))..repeat();
    _rot3 = AnimationController(
        vsync: this, duration: const Duration(seconds: 16))..repeat();

    _starCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 4))..repeat();

    _exitCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 650));
    _exitOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(parent: _exitCtrl, curve: Curves.easeIn));

    _runSequence();
  }

  Future<void> _runSequence() async {
    await Future.delayed(const Duration(milliseconds: 180));
    _shockCtrl.forward();
    _iconCtrl.forward();
    _haloCtrl.forward();
    _glowCtrl.repeat(reverse: true);

    await Future.delayed(const Duration(milliseconds: 480));
    _vizEnterCtrl.forward();
    _waveEnterCtrl.forward();

    await Future.delayed(const Duration(milliseconds: 260));
    for (int i = 0; i < 3; i++) {
      await Future.delayed(const Duration(milliseconds: 110));
      _letterCtrls[i].forward();
    }

    await Future.delayed(const Duration(milliseconds: 200));
    _tagCtrl.forward();

    await Future.delayed(const Duration(milliseconds: 150));
    _bottomCtrl.forward();
    _pulseCtrl.repeat(reverse: true);

    await Future.delayed(const Duration(milliseconds: 1200));
    _glowCtrl.stop();
    await _exitCtrl.forward();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    widget.onComplete();
  }

  @override
  void dispose() {
    _auroraCtrl.dispose();   _iconCtrl.dispose();     _haloCtrl.dispose();
    _glowCtrl.dispose();     _pulseCtrl.dispose();    _shockCtrl.dispose();
    _waveAnimCtrl.dispose(); _waveEnterCtrl.dispose();
    _vizCtrl.dispose();      _vizEnterCtrl.dispose();
    for (final c in _letterCtrls) c.dispose();
    _tagCtrl.dispose();      _progressCtrl.dispose(); _shimCtrl.dispose();
    _bottomCtrl.dispose();   _rot1.dispose();          _rot2.dispose();
    _rot3.dispose();          _starCtrl.dispose();     _exitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;

    // ── All sizes derived from screen dimensions — nothing can overflow ──────
    //
    // Layout budget (top → bottom):
    //   iconTop  = sh*0.08  (safe top padding)
    //   iconArea = min(sw*0.70, sh*0.40)
    //   waveform = 42px  (gap 6px below icon)
    //   DEN text = denFontSz + 8  (gap 20px below wave)
    //   tagline  = 20px  (gap 12px below DEN)
    //   pill     = 6px   (gap 28px below tagline)
    //   bottom text positioned absolutely at bottom
    //
    final iconArea   = math.min(sw * 0.70, sh * 0.40);
    final iconSize   = iconArea * 0.415;
    const waveH      = 42.0;
    final denFontSz  = math.min(sw * 0.22, 96.0);

    final iconTop  = sh * 0.08;
    final waveTop  = iconTop  + iconArea + 6;
    final denTop   = waveTop  + waveH    + 20;
    final tagTop   = denTop   + denFontSz + 8 + 12;
    final pillTop  = tagTop   + 20       + 28;

    return AnimatedBuilder(
      animation: _exitCtrl,
      builder: (_, child) => Opacity(opacity: _exitOpacity.value, child: child),
      child: Scaffold(
        backgroundColor: _bg,
        body: Stack(
          clipBehavior: Clip.hardEdge,
          children: [

            // ── 1. AURORA ──────────────────────────────────────────────────
            AnimatedBuilder(
              animation: _auroraCtrl,
              builder: (_, __) => CustomPaint(
                size: Size(sw, sh),
                painter: _AuroraPainter(t: _auroraCtrl.value, w: sw, h: sh),
              ),
            ),

            // ── 2. STARS ───────────────────────────────────────────────────
            AnimatedBuilder(
              animation: _starCtrl,
              builder: (_, __) => CustomPaint(
                size: Size(sw, sh),
                painter: _StarPainter(stars: _stars, t: _starCtrl.value),
              ),
            ),

            // ── 3. SHOCKWAVES ──────────────────────────────────────────────
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _shockCtrl,
                builder: (_, __) => Stack(
                  alignment: Alignment.center,
                  children: [
                    _SWave(t: _shockCtrl.value, d: 0.00, max: sw * 1.3, c: _purple),
                    _SWave(t: _shockCtrl.value, d: 0.10, max: sw * 1.7, c: _pink),
                    _SWave(t: _shockCtrl.value, d: 0.20, max: sw * 2.1, c: _purpleDark),
                    _SWave(t: _shockCtrl.value, d: 0.30, max: sw * 2.5, c: _teal),
                  ],
                ),
              ),
            ),

            // ── 4. ICON CLUSTER ────────────────────────────────────────────
            Positioned(
              left: (sw - iconArea) / 2,
              top: iconTop,
              width: iconArea,
              height: iconArea,
              child: AnimatedBuilder(
                animation: Listenable.merge([
                  _iconCtrl, _haloCtrl, _glowCtrl,
                  _rot1, _rot2, _rot3,
                  _shimCtrl, _vizCtrl, _vizEnterCtrl, _pulseCtrl,
                ]),
                builder: (_, __) => Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [

                    // Ambient glow
                    Container(
                      width: iconArea * 0.92, height: iconArea * 0.92,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(colors: [
                          _purple.withOpacity(0.32 * _glowAlpha.value),
                          _teal.withOpacity(0.06 * _glowAlpha.value),
                          Colors.transparent,
                        ]),
                      ),
                    ),

                    // Outer static ring
                    Opacity(
                      opacity: _haloOpacity.value * 0.18,
                      child: Transform.scale(
                        scale: _haloScale.value,
                        child: Container(
                          width: iconArea * 0.86, height: iconArea * 0.86,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: _purple, width: 0.5),
                          ),
                        ),
                      ),
                    ),

                    // Mid ring
                    Opacity(
                      opacity: _haloOpacity.value * 0.28,
                      child: Transform.scale(
                        scale: _haloScale.value,
                        child: Container(
                          width: iconArea * 0.67, height: iconArea * 0.67,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: _pink.withOpacity(0.6), width: 0.5),
                          ),
                        ),
                      ),
                    ),

                    // Rotating dashed ring 1
                    Transform.rotate(
                      angle: _rot1.value * 2 * math.pi,
                      child: Opacity(
                        opacity: _haloOpacity.value * 0.5,
                        child: CustomPaint(
                          size: Size(iconArea * 0.56, iconArea * 0.56),
                          painter: _DashRing(
                              c: _purple.withOpacity(0.65), n: 28, sw: 1.2),
                        ),
                      ),
                    ),

                    // Rotating dashed ring 2 (counter)
                    Transform.rotate(
                      angle: -_rot2.value * 2 * math.pi,
                      child: Opacity(
                        opacity: _haloOpacity.value * 0.38,
                        child: CustomPaint(
                          size: Size(iconArea * 0.45, iconArea * 0.45),
                          painter: _DashRing(
                              c: _pink.withOpacity(0.55), n: 18, sw: 0.9),
                        ),
                      ),
                    ),

                    // Third ring (teal, slow)
                    Transform.rotate(
                      angle: _rot3.value * 2 * math.pi,
                      child: Opacity(
                        opacity: _haloOpacity.value * 0.25,
                        child: CustomPaint(
                          size: Size(iconArea * 0.72, iconArea * 0.72),
                          painter: _DashRing(
                              c: _teal.withOpacity(0.45), n: 14, sw: 0.8),
                        ),
                      ),
                    ),

                    // Circular frequency visualizer
                    Opacity(
                      opacity: _vizEnter.value.clamp(0.0, 1.0),
                      child: CustomPaint(
                        size: Size(iconArea * 0.80, iconArea * 0.80),
                        painter: _CircVizPainter(
                          t: _vizCtrl.value,
                          radius: iconArea * 0.40,
                        ),
                      ),
                    ),

                    // Icon with glow + micro-pulse
                    Opacity(
                      opacity: _iconOpacity.value,
                      child: Transform.scale(
                        scale: _iconScale.value * _pulseScale.value,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: iconSize + 28, height: iconSize + 28,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(colors: [
                                  _purple.withOpacity(0.88),
                                  _purpleDark.withOpacity(0.4),
                                  Colors.transparent,
                                ]),
                              ),
                            ),
                            Container(
                              width: iconSize + 4, height: iconSize + 4,
                              decoration: BoxDecoration(
                                borderRadius:
                                    BorderRadius.circular(iconSize * 0.235),
                                boxShadow: [
                                  BoxShadow(color: _purple.withOpacity(0.9),
                                      blurRadius: 64, spreadRadius: 14),
                                  BoxShadow(color: _pink.withOpacity(0.45),
                                      blurRadius: 96),
                                  BoxShadow(color: _teal.withOpacity(0.2),
                                      blurRadius: 40, spreadRadius: -4),
                                ],
                              ),
                            ),
                            ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(iconSize * 0.22),
                              child: Image.asset(
                                'assets/icons/app_icon.png',
                                width: iconSize, height: iconSize,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _Fallback(s: iconSize),
                              ),
                            ),
                            ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(iconSize * 0.22),
                              child: SizedBox(
                                width: iconSize, height: iconSize,
                                child: CustomPaint(
                                  painter: _ShimmerPainter(p: _shimCtrl.value),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  ],
                ),
              ),
            ),

            // ── 5. WAVEFORM ────────────────────────────────────────────────
            Positioned(
              left: 0, right: 0,
              top: waveTop,
              height: waveH,
              child: AnimatedBuilder(
                animation: Listenable.merge([_waveAnimCtrl, _waveEnter]),
                builder: (_, __) => Center(
                  child: _Wave(
                    anim: _waveAnimCtrl.value,
                    enter: _waveEnter.value,
                    w: sw * 0.88,
                    maxH: waveH,
                    bars: 52,
                  ),
                ),
              ),
            ),

            // ── 6. DEN TEXT ────────────────────────────────────────────────
            Positioned(
              left: 0, right: 0,
              top: denTop,
              height: denFontSz + 8,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (i) {
                  const letters = ['D', 'E', 'N'];
                  return AnimatedBuilder(
                    animation: _letterCtrls[i],
                    builder: (_, __) => Opacity(
                      opacity: _letterOpacity[i].value,
                      child: Transform.translate(
                        offset: Offset(0, _letterY[i].value),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Text(letters[i], style: TextStyle(
                              fontSize: denFontSz, fontWeight: FontWeight.w100,
                              foreground: Paint()
                                ..maskFilter = const MaskFilter.blur(
                                    BlurStyle.normal, 28)
                                ..color = _purple.withOpacity(0.75),
                              height: 1, letterSpacing: 4,
                            )),
                            Text(letters[i], style: TextStyle(
                              fontSize: denFontSz, fontWeight: FontWeight.w100,
                              foreground: Paint()
                                ..maskFilter = const MaskFilter.blur(
                                    BlurStyle.normal, 10)
                                ..color = _pink.withOpacity(0.4),
                              height: 1, letterSpacing: 4,
                            )),
                            Text(letters[i], style: TextStyle(
                              fontSize: denFontSz, fontWeight: FontWeight.w100,
                              color: Colors.white,
                              height: 1, letterSpacing: 4,
                            )),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),

            // ── 7. TAGLINE ─────────────────────────────────────────────────
            Positioned(
              left: 0, right: 0,
              top: tagTop,
              height: 20,
              child: AnimatedBuilder(
                animation: _tagCtrl,
                builder: (_, __) => Opacity(
                  opacity: _tagOpacity.value,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(width: 38, height: 0.5,
                          color: _pink.withOpacity(0.4)),
                      const SizedBox(width: 14),
                      Text('feel every beat', style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w300,
                        color: Colors.white.withOpacity(0.4),
                        letterSpacing: 4.5,
                      )),
                      const SizedBox(width: 14),
                      Container(width: 38, height: 0.5,
                          color: _pink.withOpacity(0.4)),
                    ],
                  ),
                ),
              ),
            ),

            // ── 8. PROGRESS PILL ───────────────────────────────────────────
            Positioned(
              left: 0, right: 0,
              top: pillTop,
              height: 6,
              child: AnimatedBuilder(
                animation: Listenable.merge(
                    [_progressCtrl, _tagOpacity, _shimCtrl]),
                builder: (_, __) => Opacity(
                  opacity: _tagOpacity.value,
                  child: Center(
                    child: Container(
                      width: sw * 0.52,
                      height: 6,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        color: Colors.white.withOpacity(0.06),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.10),
                          width: 0.5,
                        ),
                        boxShadow: [BoxShadow(
                          color: _purple.withOpacity(0.15),
                          blurRadius: 12, spreadRadius: 1,
                        )],
                      ),
                      child: Stack(children: [
                        FractionallySizedBox(
                          widthFactor: _progressVal.value,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(3),
                              gradient: const LinearGradient(
                                  colors: [_teal, _purple, _pinkHot]),
                              boxShadow: [
                                BoxShadow(color: _pink.withOpacity(0.75),
                                    blurRadius: 12),
                                BoxShadow(color: _teal.withOpacity(0.5),
                                    blurRadius: 8, spreadRadius: -2),
                              ],
                            ),
                          ),
                        ),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: CustomPaint(
                            painter: _ShimmerPainter(p: _shimCtrl.value),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
              ),
            ),

            // ── 9. CINEMATIC BOTTOM LINE ────────────────────────────────────
            Positioned(
              left: 0, right: 0,
              bottom: sh * 0.055,
              child: AnimatedBuilder(
                animation: _bottomCtrl,
                builder: (_, __) => Opacity(
                  opacity: _bottomOpacity.value,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(width: 20, height: 0.4,
                              color: Colors.white.withOpacity(0.18)),
                          const SizedBox(width: 10),
                          Text('NOW ENTERING', style: TextStyle(
                            fontSize: 8.5, fontWeight: FontWeight.w400,
                            color: Colors.white.withOpacity(0.25),
                            letterSpacing: 5.5,
                          )),
                          const SizedBox(width: 10),
                          Container(width: 20, height: 0.4,
                              color: Colors.white.withOpacity(0.18)),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text('YOUR SONIC UNIVERSE', style: TextStyle(
                        fontSize: 7, fontWeight: FontWeight.w300,
                        color: Colors.white.withOpacity(0.14),
                        letterSpacing: 4.0,
                      )),
                    ],
                  ),
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
// AURORA PAINTER
// ─────────────────────────────────────────────────────────────────────────────
class _AuroraPainter extends CustomPainter {
  final double t, w, h;
  const _AuroraPainter({required this.t, required this.w, required this.h});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = _bg);

    void blob(Offset c, double r, Color col, double op) {
      canvas.drawCircle(c, r, Paint()
        ..shader = RadialGradient(
          colors: [col.withOpacity(op), Colors.transparent],
        ).createShader(Rect.fromCircle(center: c, radius: r)));
    }

    final s = math.sin(t * math.pi);
    final c = math.cos(t * math.pi);
    blob(Offset(w * (0.4 + 0.15 * s), h * (0.2 + 0.07 * c)),
        w * 0.7, const Color(0xFF1A0845), 0.98);
    blob(Offset(w * (0.6 - 0.12 * c), h * (0.75 + 0.06 * s)),
        w * 0.55, const Color(0xFF2D0A5C), 0.5);
    blob(Offset(w * (0.1 + 0.08 * s), h * (0.42 + 0.08 * c)),
        w * 0.40, _pinkHot, 0.065 + 0.04 * s);
    blob(Offset(w * (0.88 - 0.06 * c), h * (0.32 + 0.05 * s)),
        w * 0.32, _purple,  0.07 + 0.03 * c);
    blob(Offset(w * (0.5 + 0.2 * c),  h * (0.55 - 0.12 * s)),
        w * 0.42, _teal,    0.05 + 0.03 * s);
    blob(Offset(w * (0.2 - 0.06 * s), h * (0.85 + 0.04 * c)),
        w * 0.28, _teal, 0.04);
  }

  @override
  bool shouldRepaint(_AuroraPainter o) => o.t != t;
}

// ─────────────────────────────────────────────────────────────────────────────
// CIRCULAR FREQUENCY VISUALIZER
// ─────────────────────────────────────────────────────────────────────────────
class _CircVizPainter extends CustomPainter {
  final double t, radius;
  const _CircVizPainter({required this.t, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    const bars = 72;
    const step = 2 * math.pi / bars;
    final inner = radius * 0.84;

    for (int i = 0; i < bars; i++) {
      final angle = i * step - math.pi / 2;
      final p1  = (i / bars) * 2.5 * math.pi;
      final p2  = (i / bars) * 1.7 * math.pi + 0.9;
      final w1  = math.sin(t * 2 * math.pi + p1);
      final w2  = math.sin(t * 1.4 * math.pi + p2);
      final mag = ((w1 + w2) / 2 + 1) / 2;
      final outer = inner + 4 + 16 * mag;

      final startX = cx + inner * math.cos(angle);
      final startY = cy + inner * math.sin(angle);
      final endX   = cx + outer * math.cos(angle);
      final endY   = cy + outer * math.sin(angle);

      final frac = i / bars.toDouble();
      final Color col;
      if (frac < 0.33) {
        col = Color.lerp(_pink, _teal, frac / 0.33)!;
      } else if (frac < 0.66) {
        col = Color.lerp(_teal, _purple, (frac - 0.33) / 0.33)!;
      } else {
        col = Color.lerp(_purple, _pink, (frac - 0.66) / 0.34)!;
      }

      canvas.drawLine(Offset(startX, startY), Offset(endX, endY),
        Paint()
          ..color = col.withOpacity(0.55 + 0.45 * mag)
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round,
      );

      if (mag > 0.6) {
        canvas.drawLine(Offset(startX, startY), Offset(endX, endY),
          Paint()
            ..color = col.withOpacity(0.22 * mag)
            ..strokeWidth = 5
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_CircVizPainter o) => o.t != t;
}

// ─────────────────────────────────────────────────────────────────────────────
// WAVEFORM
// ─────────────────────────────────────────────────────────────────────────────
class _Wave extends StatelessWidget {
  final double anim, enter, w, maxH;
  final int bars;
  const _Wave({required this.anim, required this.enter,
      required this.w, required this.maxH, required this.bars});

  @override
  Widget build(BuildContext context) {
    const barW = 2.2;
    const minH = 2.0;
    final gap  = (w - bars * barW) / bars;

    return SizedBox(
      height: maxH, width: w,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(bars, (i) {
          final p1  = (i / bars) * 2 * math.pi;
          final p2  = (i / bars) * 3.3 * math.pi + 1.1;
          final w1  = math.sin(anim * 2 * math.pi + p1);
          final w2  = math.sin(anim * 1.7 * math.pi + p2);
          final c   = ((w1 + w2) / 2 + 1) / 2;
          final raw = minH + (maxH - minH) * c;
          final h   = minH + (raw - minH) * enter;
          final edge = i < 7 ? i / 7.0
              : i > bars - 8 ? (bars - 1 - i) / 7.0 : 1.0;
          final frac = i / (bars - 1).toDouble();
          final Color col = frac < 0.5
              ? Color.lerp(_pink, _purple, frac * 2)!
              : Color.lerp(_purple, _teal, (frac - 0.5) * 2)!;

          return Container(
            width: barW, height: h.clamp(minH, maxH),
            margin: EdgeInsets.symmetric(horizontal: gap / 2),
            decoration: BoxDecoration(
              color: col.withOpacity(0.9 * edge),
              borderRadius: BorderRadius.circular(barW),
              boxShadow: h > 18 ? [BoxShadow(
                color: col.withOpacity(0.38 * edge), blurRadius: 8,
              )] : null,
            ),
          );
        }),
      ),
    ),
  );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHOCKWAVE RING
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
// STARS
// ─────────────────────────────────────────────────────────────────────────────
class _Star {
  final double x, y, r, phase;
  final bool   pink, teal;
  const _Star({required this.x, required this.y,
      required this.r, required this.phase,
      required this.pink, required this.teal});
}

class _StarPainter extends CustomPainter {
  final List<_Star> stars;
  final double t;
  const _StarPainter({required this.stars, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in stars) {
      final tw  = math.sin(t * 2 * math.pi + s.phase);
      final op  = 0.12 + 0.55 * ((tw + 1) / 2);
      final Color base = s.teal ? _teal : (s.pink ? _pink : _purple);
      final col = base.withOpacity(op);
      final x   = s.x * size.width;
      final y   = s.y * size.height;
      canvas.drawCircle(Offset(x, y), s.r, Paint()..color = col);
      if (s.r > 1.0) {
        final lp = Paint()
          ..color = col.withOpacity(op * 0.45)
          ..strokeWidth = 0.4;
        final sp = s.r * 3.5;
        canvas.drawLine(Offset(x - sp, y), Offset(x + sp, y), lp);
        canvas.drawLine(Offset(x, y - sp), Offset(x, y + sp), lp);
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
    final cx   = size.width  / 2;
    final cy   = size.height / 2;
    final r    = math.min(cx, cy);
    final step = 2 * math.pi / n;
    const gap  = 0.06;
    for (int i = 0; i < n; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        i * step + gap, step - gap * 2, false, paint,
      );
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
        Colors.white.withOpacity(0.13),
        Colors.transparent,
      ], stops: const [0, 0.5, 1]).createShader(
          Rect.fromLTWH(x - 40, 0, 80, size.height)),
    );
  }

  @override
  bool shouldRepaint(_ShimmerPainter o) => o.p != p;
}

// ─────────────────────────────────────────────────────────────────────────────
// FALLBACK ICON
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