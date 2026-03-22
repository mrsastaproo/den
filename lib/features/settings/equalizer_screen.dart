import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/player_service.dart';

// ─── STATE ────────────────────────────────────────────────────

final equalizerProvider =
    StateNotifierProvider<EqualizerNotifier, EqualizerState>(
        (ref) => EqualizerNotifier());

class EqualizerState {
  final double bass, lowMid, mid, highMid, treble, masterGain;
  final String preset;
  final bool enabled;

  const EqualizerState({
    this.bass      = 0,
    this.lowMid    = 0,
    this.mid       = 0,
    this.highMid   = 0,
    this.treble    = 0,
    this.masterGain = 0,
    this.preset    = 'Normal',
    this.enabled   = true,
  });

  EqualizerState copyWith({
    double? bass, double? lowMid, double? mid,
    double? highMid, double? treble, double? masterGain,
    String? preset, bool? enabled,
  }) => EqualizerState(
    bass:       bass       ?? this.bass,
    lowMid:     lowMid     ?? this.lowMid,
    mid:        mid        ?? this.mid,
    highMid:    highMid    ?? this.highMid,
    treble:     treble     ?? this.treble,
    masterGain: masterGain ?? this.masterGain,
    preset:     preset     ?? this.preset,
    enabled:    enabled    ?? this.enabled,
  );

  List<double> get bands => [bass, lowMid, mid, highMid, treble];
}

class EqualizerNotifier extends StateNotifier<EqualizerState> {
  // Platform channel to Android's AudioEffect Equalizer
  static const _channel = MethodChannel('den/equalizer');
  int? _audioSessionId; // Android AudioSession ID from just_audio

  EqualizerNotifier() : super(const EqualizerState());

  // Called once from EqualizerScreen to pass the Android audio session ID.
  // just_audio 0.9.x exposes androidAudioSessionId on AudioPlayer.
  Future<void> attachSessionId(int? sessionId) async {
    _audioSessionId = sessionId;
    await _applyAll(state);
  }

  static const presets = <String, List<double>>{
    'Normal':     [0.0,  0.0,  0.0,  0.0,  0.0],
    'Bass Boost': [8.0,  5.0,  0.0, -2.0, -3.0],
    'Pop':        [-2.0, 2.0,  4.0,  2.0, -1.0],
    'Rock':       [5.0,  3.0, -1.0,  3.0,  5.0],
    'Jazz':       [3.0,  1.0,  2.0,  3.0,  2.0],
    'Classical':  [4.0,  2.0, -1.0,  2.0,  4.0],
    'Hip Hop':    [6.0,  4.0,  1.0,  3.0,  2.0],
    'Electronic': [4.0,  2.0,  0.0,  4.0,  5.0],
    'Acoustic':   [3.0,  2.0,  3.0,  2.0,  1.0],
    'Dance':      [5.0,  3.0,  1.0,  4.0,  3.0],
  };

  // ── Apply EQ to Android AudioEffect via platform channel ───────
  Future<void> _applyAll(EqualizerState s) async {
    final sessionId = _audioSessionId;
    if (sessionId == null || sessionId == 0) return;
    try {
      await _channel.invokeMethod('setEqualizer', {
        'sessionId': sessionId,
        'enabled': s.enabled,
        'bands': s.bands, // List<double> in dB, -10 to +10
        'masterGain': s.masterGain,
      });
    } catch (e) {
      // Graceful degradation — EQ unavailable on this device/OS
      print('[EQ] Platform channel error: $e');
    }
  }

  void setBand(int index, double v) {
    final bands = state.bands.toList();
    bands[index] = v;
    final next = state.copyWith(
      bass: bands[0], lowMid: bands[1], mid: bands[2],
      highMid: bands[3], treble: bands[4], preset: 'Custom');
    state = next;
    _applyAll(next);
  }

  void setMasterGain(double v) {
    final next = state.copyWith(masterGain: v);
    state = next;
    _applyAll(next);
  }

  void setEnabled(bool v) {
    final next = state.copyWith(enabled: v);
    state = next;
    _applyAll(next);
  }

  void applyPreset(String name) {
    final v = presets[name];
    if (v == null) return;
    final next = EqualizerState(
      bass: v[0], lowMid: v[1], mid: v[2],
      highMid: v[3], treble: v[4],
      preset: name, enabled: state.enabled,
      masterGain: state.masterGain,
    );
    state = next;
    _applyAll(next);
    HapticFeedback.selectionClick();
  }

  void reset() {
    state = const EqualizerState();
    _applyAll(state);
    HapticFeedback.mediumImpact();
  }
}


// ─── EQUALIZER SCREEN ─────────────────────────────────────────

class EqualizerScreen extends ConsumerStatefulWidget {
  const EqualizerScreen({super.key});
  @override
  ConsumerState<EqualizerScreen> createState() => _EqualizerScreenState();
}

class _EqualizerScreenState extends ConsumerState<EqualizerScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _vizCtrl;

  @override
  void initState() {
    super.initState();
    _vizCtrl = AnimationController(
      vsync: this, duration: const Duration(seconds: 2))
      ..repeat();
    // Pass Android audio session ID to the EQ notifier
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final player = ref.read(playerServiceProvider).player;
      // androidAudioSessionId is available on just_audio 0.9.x
      final sessionId = player.androidAudioSessionId;
      ref.read(equalizerProvider.notifier).attachSessionId(sessionId);
    });
  }

  @override
  void dispose() {
    _vizCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final eq = ref.watch(equalizerProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [

            // ── Header ──────────────────────────────────────
            SliverToBoxAdapter(child: _Header(eq: eq)),

            // ── Animated Visualizer ──────────────────────────
            SliverToBoxAdapter(
              child: _Visualizer(
                eq: eq, controller: _vizCtrl).animate()
                  .fadeIn(duration: 500.ms)),

            // ── Preset pills ─────────────────────────────────
            SliverToBoxAdapter(
              child: _PresetRow(eq: eq).animate()
                  .fadeIn(delay: 100.ms, duration: 400.ms)),

            // ── Master Gain ──────────────────────────────────
            SliverToBoxAdapter(
              child: _MasterGainCard(eq: eq).animate()
                  .fadeIn(delay: 150.ms, duration: 400.ms)
                  .slideY(begin: 0.05, end: 0, delay: 150.ms)),

            // ── Band Sliders ─────────────────────────────────
            SliverToBoxAdapter(
              child: _BandSliders(eq: eq).animate()
                  .fadeIn(delay: 200.ms, duration: 400.ms)
                  .slideY(begin: 0.05, end: 0, delay: 200.ms)),

            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
  }
}

// ─── HEADER ───────────────────────────────────────────────────

class _Header extends ConsumerWidget {
  final EqualizerState eq;
  const _Header({required this.eq});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(children: [
        IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded,
            color: Colors.white.withOpacity(0.7)),
          onPressed: () => Navigator.pop(context)),
        ShaderMask(
          shaderCallback: (b) =>
              AppTheme.primaryGradient.createShader(b),
          child: const Icon(Icons.equalizer_rounded,
              color: Colors.white, size: 24)),
        const SizedBox(width: 8),
        const Text('Equalizer',
          style: TextStyle(color: Colors.white,
            fontSize: 22, fontWeight: FontWeight.w800)),
        const Spacer(),
        // Enable/disable toggle
        GestureDetector(
          onTap: () => ref.read(equalizerProvider.notifier)
              .setEnabled(!eq.enabled),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: eq.enabled ? AppTheme.primaryGradient : null,
              color: eq.enabled ? null : Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: eq.enabled
                    ? Colors.transparent
                    : Colors.white.withOpacity(0.1))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(eq.enabled
                  ? Icons.graphic_eq_rounded
                  : Icons.do_not_disturb_rounded,
                color: Colors.white, size: 14),
              const SizedBox(width: 5),
              Text(eq.enabled ? 'ON' : 'OFF',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
        const SizedBox(width: 8),
        // Reset
        GestureDetector(
          onTap: () => ref.read(equalizerProvider.notifier).reset(),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.07),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: Colors.white.withOpacity(0.1))),
            child: Text('Reset',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
    ).animate().fadeIn(duration: 300.ms);
  }
}

// ─── ANIMATED VISUALIZER ──────────────────────────────────────

class _Visualizer extends StatelessWidget {
  final EqualizerState eq;
  final AnimationController controller;
  const _Visualizer({required this.eq, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.pink.withOpacity(0.08),
                  AppTheme.purple.withOpacity(0.06),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                  color: Colors.white.withOpacity(0.08))),
            child: AnimatedBuilder(
              animation: controller,
              builder: (_, __) => CustomPaint(
                painter: _VisualizerPainter(
                  bands: eq.bands,
                  progress: controller.value,
                  enabled: eq.enabled,
                ),
                child: Container(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VisualizerPainter extends CustomPainter {
  final List<double> bands;
  final double progress;
  final bool enabled;

  _VisualizerPainter({
    required this.bands,
    required this.progress,
    required this.enabled,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!enabled) {
      // Draw flat line when disabled
      final paint = Paint()
        ..color = Colors.white.withOpacity(0.15)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(16, size.height / 2),
        Offset(size.width - 16, size.height / 2),
        paint);
      return;
    }

    final barCount = 32;
    final barWidth = (size.width - 32) / (barCount * 1.6);
    final spacing  = (size.width - 32) / barCount;

    final grad = LinearGradient(
      colors: [AppTheme.pink, AppTheme.purple],
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
    );

    for (int i = 0; i < barCount; i++) {
      final t = i / barCount;
      // Interpolate band influence
      final bandIdx = (t * (bands.length - 1)).floor()
          .clamp(0, bands.length - 1);
      final bandVal = bands[bandIdx] / 10.0; // normalize -1 to 1

      // Animate height with noise
      final noise = math.sin(progress * math.pi * 2 + i * 0.8) * 0.3;
      final base  = 0.15 + (bandVal + 1) * 0.25;
      final height = ((base + noise).clamp(0.05, 0.9)) * size.height * 0.75;

      final x   = 16 + i * spacing;
      final top = size.height / 2 - height / 2;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, top, barWidth, height),
        const Radius.circular(3));

      final paint = Paint()
        ..shader = grad.createShader(
            Rect.fromLTWH(x, top, barWidth, height))
        ..style = PaintingStyle.fill;

      canvas.drawRRect(rect, paint);
    }

    // Center line
    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.06)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(16, size.height / 2),
      Offset(size.width - 16, size.height / 2),
      linePaint);
  }

  @override
  bool shouldRepaint(_VisualizerPainter old) =>
      old.progress != progress ||
      old.enabled != enabled ||
      old.bands.toString() != bands.toString();
}

// ─── PRESET ROW ───────────────────────────────────────────────

class _PresetRow extends ConsumerWidget {
  final EqualizerState eq;
  const _PresetRow({required this.eq});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presets = EqualizerNotifier.presets.keys.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
          child: Row(children: [
            ShaderMask(
              shaderCallback: (b) =>
                  AppTheme.primaryGradient.createShader(b),
              child: const Icon(Icons.tune_rounded,
                  color: Colors.white, size: 16)),
            const SizedBox(width: 8),
            const Text('Presets',
              style: TextStyle(color: Colors.white,
                fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                gradient: eq.preset != 'Custom'
                    ? AppTheme.primaryGradient : null,
                color: eq.preset == 'Custom'
                    ? Colors.white.withOpacity(0.1) : null,
                borderRadius: BorderRadius.circular(10)),
              child: Text(eq.preset,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
        SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: presets.length,
            itemBuilder: (_, i) {
              final p   = presets[i];
              final sel = p == eq.preset;
              return GestureDetector(
                onTap: () => ref.read(equalizerProvider.notifier)
                    .applyPreset(p),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: sel ? AppTheme.primaryGradient : null,
                    color: sel ? null : Colors.white.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: sel
                          ? Colors.transparent
                          : Colors.white.withOpacity(0.1)),
                    boxShadow: sel ? [
                      BoxShadow(
                        color: AppTheme.pink.withOpacity(0.25),
                        blurRadius: 10, spreadRadius: -3),
                    ] : null,
                  ),
                  child: Text(p,
                    style: TextStyle(
                      color: sel
                          ? Colors.white
                          : Colors.white.withOpacity(0.6),
                      fontSize: 13,
                      fontWeight: sel
                          ? FontWeight.w700
                          : FontWeight.w500)),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── MASTER GAIN ──────────────────────────────────────────────

class _MasterGainCard extends ConsumerWidget {
  final EqualizerState eq;
  const _MasterGainCard({required this.eq});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                Colors.white.withOpacity(0.07),
                Colors.white.withOpacity(0.03),
              ]),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: Colors.white.withOpacity(0.1))),
            child: Column(children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    ShaderMask(
                      shaderCallback: (b) =>
                          AppTheme.primaryGradient.createShader(b),
                      child: const Icon(Icons.volume_up_rounded,
                          color: Colors.white, size: 18)),
                    const SizedBox(width: 8),
                    const Text('Master Volume',
                      style: TextStyle(color: Colors.white,
                        fontSize: 14, fontWeight: FontWeight.w700)),
                  ]),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.pink.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppTheme.pink.withOpacity(0.3))),
                    child: Text(
                      '${eq.masterGain >= 0 ? '+' : ''}'
                      '${eq.masterGain.toStringAsFixed(1)} dB',
                      style: const TextStyle(
                        color: AppTheme.pink,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4,
                  thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 8),
                  activeTrackColor: AppTheme.pink,
                  inactiveTrackColor: Colors.white.withOpacity(0.1),
                  thumbColor: Colors.white,
                  overlayColor: AppTheme.pink.withOpacity(0.12),
                  overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 16),
                ),
                child: Slider(
                  value: eq.masterGain,
                  min: -10, max: 10,
                  onChanged: (v) => ref
                      .read(equalizerProvider.notifier)
                      .setMasterGain(v),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('-10 dB',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 10)),
                  Text('0 dB',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 10)),
                  Text('+10 dB',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 10)),
                ],
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─── BAND SLIDERS ─────────────────────────────────────────────

class _BandSliders extends ConsumerWidget {
  final EqualizerState eq;
  const _BandSliders({required this.eq});

  static const _bands = [
    {'label': 'Bass',     'freq': '60 Hz',  'c1': AppTheme.pink,      'c2': AppTheme.pinkDeep},
    {'label': 'Low Mid',  'freq': '230 Hz', 'c1': Color(0xFFFF9999),  'c2': AppTheme.pink},
    {'label': 'Mid',      'freq': '910 Hz', 'c1': AppTheme.purple,    'c2': AppTheme.purpleDeep},
    {'label': 'High Mid', 'freq': '4 kHz',  'c1': AppTheme.purpleDeep,'c2': AppTheme.pink},
    {'label': 'Treble',   'freq': '14 kHz', 'c1': AppTheme.pinkDeep,  'c2': AppTheme.purple},
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final values = eq.bands;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                Colors.white.withOpacity(0.07),
                Colors.white.withOpacity(0.03),
              ]),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                  color: Colors.white.withOpacity(0.1))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                  child: Row(children: [
                    ShaderMask(
                      shaderCallback: (b) =>
                          AppTheme.primaryGradient.createShader(b),
                      child: const Icon(Icons.equalizer_rounded,
                          color: Colors.white, size: 16)),
                    const SizedBox(width: 8),
                    const Text('Frequency Bands',
                      style: TextStyle(color: Colors.white,
                        fontSize: 14, fontWeight: FontWeight.w700)),
                  ]),
                ),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _bands.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: Colors.white.withOpacity(0.05)),
                  itemBuilder: (_, i) {
                    final band = _bands[i];
                    final c1   = band['c1'] as Color;
                    final val  = values[i];
                    final isUp = val > 0;
                    final isDown = val < 0;

                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
                      child: Row(children: [
                        // Label
                        SizedBox(
                          width: 68,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(band['label'] as String,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                              Text(band['freq'] as String,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.3),
                                  fontSize: 10)),
                            ],
                          ),
                        ),

                        // Slider
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 3,
                              thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 7),
                              activeTrackColor: c1,
                              inactiveTrackColor:
                                  Colors.white.withOpacity(0.1),
                              thumbColor: Colors.white,
                              overlayColor: c1.withOpacity(0.15),
                              overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 14),
                            ),
                            child: Slider(
                              value: val,
                              min: -10, max: 10,
                              onChanged: (v) {
                                ref.read(equalizerProvider.notifier)
                                    .setBand(i, v);
                              },
                            ),
                          ),
                        ),

                        // Value chip
                        SizedBox(
                          width: 52,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: val == 0
                                  ? Colors.transparent
                                  : c1.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: val == 0
                                    ? Colors.transparent
                                    : c1.withOpacity(0.3)),
                            ),
                            child: Text(
                              '${val >= 0 ? '+' : ''}${val.toStringAsFixed(1)}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: val == 0
                                    ? Colors.white.withOpacity(0.25)
                                    : c1,
                                fontSize: 11,
                                fontWeight: FontWeight.w800)),
                          ),
                        ),
                      ]),
                    ).animate()
                        .fadeIn(delay: Duration(milliseconds: i * 50),
                            duration: 300.ms)
                        .slideX(begin: 0.05, end: 0,
                            delay: Duration(milliseconds: i * 50),
                            duration: 300.ms);
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}