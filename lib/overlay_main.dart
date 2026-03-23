import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

// ─────────────────────────────────────────────────────────────
// OVERLAY ENTRY POINT
// Called by flutter_overlay_window in a separate isolate when the
// app is minimised and music is playing. This is the system-level
// "Dynamic Island" that appears in the notch/status-bar area.
// ─────────────────────────────────────────────────────────────

@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: DynamicIslandOverlay(),
  ));
}

// ─────────────────────────────────────────────────────────────
// ROOT OVERLAY WIDGET
// ─────────────────────────────────────────────────────────────

class DynamicIslandOverlay extends StatefulWidget {
  const DynamicIslandOverlay({super.key});

  @override
  State<DynamicIslandOverlay> createState() => _DynamicIslandOverlayState();
}

class _DynamicIslandOverlayState extends State<DynamicIslandOverlay>
    with TickerProviderStateMixin {
  bool _expanded = false;
  Map<String, dynamic>? _data;

  // Animation controllers
  late AnimationController _waveCtrl;
  late AnimationController _spinCtrl;

  @override
  void initState() {
    super.initState();

    _waveCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();

    _spinCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 8))
      ..repeat();

    // Listen for data updates from the main app
    if (!kIsWeb && Platform.isAndroid) {
      FlutterOverlayWindow.overlayListener.listen((event) {
        if (event is Map<String, dynamic>) {
          setState(() => _data = event);
        }
      });
    }
  }

  @override
  void dispose() {
    _waveCtrl.dispose();
    _spinCtrl.dispose();
    super.dispose();
  }

  bool get _isPlaying => (_data?['isPlaying'] as bool?) ?? false;

  void _toggleExpand() async {
    if (kIsWeb || !Platform.isAndroid) return;
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      // Resize overlay to expanded height
      await FlutterOverlayWindow.resizeOverlay(400, 130, false);
    } else {
      await FlutterOverlayWindow.resizeOverlay(400, 60, false);
    }
  }

  void _sendCommand(String cmd) {
    if (!kIsWeb && Platform.isAndroid) {
      FlutterOverlayWindow.shareData(cmd);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Sync animations to play state
    if (_isPlaying) {
      if (!_waveCtrl.isAnimating) _waveCtrl.repeat();
      if (!_spinCtrl.isAnimating) _spinCtrl.repeat();
    } else {
      if (_waveCtrl.isAnimating) _waveCtrl.stop();
      if (_spinCtrl.isAnimating) _spinCtrl.stop();
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: GestureDetector(
            onTap: _toggleExpand,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 420),
              curve: _expanded ? Curves.easeOutBack : Curves.easeOutCubic,
              width: double.infinity,
              height: _expanded ? 124 : 52,
              margin: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.96),
                borderRadius: BorderRadius.circular(_expanded ? 26 : 100),
                border: Border.all(
                  color: _isPlaying
                      ? const Color(0xFFFFB3C6).withOpacity(0.45)
                      : Colors.white.withOpacity(0.12),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.7),
                    blurRadius: 20,
                    spreadRadius: -4,
                    offset: const Offset(0, 8),
                  ),
                  if (_isPlaying)
                    BoxShadow(
                      color: const Color(0xFFFFB3C6).withOpacity(0.18),
                      blurRadius: 28,
                      spreadRadius: -6,
                    ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(_expanded ? 26 : 100),
                child: _expanded ? _buildExpanded() : _buildCollapsed(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── COLLAPSED VIEW ────────────────────────────────────────────
  // Pill: [SpinningArt] [Song title…] [WaveForm] [▶/⏸]
  Widget _buildCollapsed() {
    final title = (_data?['title'] as String?) ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          // Spinning album art
          AnimatedBuilder(
            animation: _spinCtrl,
            builder: (_, child) => Transform.rotate(
              angle: _isPlaying ? _spinCtrl.value * 2 * math.pi : 0,
              child: child,
            ),
            child: _buildArtCircle(size: 30),
          ),

          const SizedBox(width: 10),

          // Song title
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Waveform indicator
          SizedBox(
            width: 22,
            child: AnimatedBuilder(
              animation: _waveCtrl,
              builder: (_, __) => Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: List.generate(3, (i) {
                  final wave = math.sin(
                      (_waveCtrl.value * 2 * math.pi) + i * 1.8);
                  final h = _isPlaying
                      ? (4.0 + (8.0 * ((wave + 1) / 2))).clamp(3.0, 12.0)
                      : 3.0;
                  return Container(
                    width: 3,
                    height: h,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFB3C6),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Play / Pause button
          GestureDetector(
            onTap: () {
              _sendCommand('toggle');
            },
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFB3C6), Color(0xFF9B7EDC)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Icon(
                _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── EXPANDED VIEW ─────────────────────────────────────────────
  // Full card: art + title/artist + progress + [⏮ ▶/⏸ ⏭]
  Widget _buildExpanded() {
    final title = (_data?['title'] as String?) ?? 'Unknown';
    final artist = (_data?['artist'] as String?) ?? '';
    final progress = ((_data?['progress'] as num?)?.toDouble()) ?? 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        children: [
          // Top row: art + info + controls
          Expanded(
            child: Row(
              children: [
                // Album art
                _buildArtRect(size: 52),

                const SizedBox(width: 12),

                // Title & artist
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                      if (artist.isNotEmpty)
                        Text(
                          artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.55),
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Playback controls
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _CtrlBtn(
                      icon: Icons.skip_previous_rounded,
                      onTap: () => _sendCommand('skipPrev'),
                    ),
                    const SizedBox(width: 2),
                    _PlayPauseBtn(
                      isPlaying: _isPlaying,
                      onTap: () => _sendCommand('toggle'),
                    ),
                    const SizedBox(width: 2),
                    _CtrlBtn(
                      icon: Icons.skip_next_rounded,
                      onTap: () => _sendCommand('skipNext'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 3,
              backgroundColor: Colors.white.withOpacity(0.12),
              valueColor:
                  const AlwaysStoppedAnimation(Color(0xFFFFB3C6)),
            ),
          ),
        ],
      ),
    );
  }

  // ── HELPERS ──────────────────────────────────────────────────

  Widget _buildArtCircle({required double size}) {
    final image = (_data?['image'] as String?) ?? '';
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(shape: BoxShape.circle),
      child: ClipOval(
        child: image.isNotEmpty
            ? CachedNetworkImage(memCacheWidth: 400, 
                imageUrl: image,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) =>
                    _fallbackIcon(size: size, circular: true),
              )
            : _fallbackIcon(size: size, circular: true),
      ),
    );
  }

  Widget _buildArtRect({required double size}) {
    final image = (_data?['image'] as String?) ?? '';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: image.isNotEmpty
            ? CachedNetworkImage(memCacheWidth: 400, 
                imageUrl: image,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) =>
                    _fallbackIcon(size: size, circular: false),
              )
            : _fallbackIcon(size: size, circular: false),
      ),
    );
  }

  Widget _fallbackIcon({required double size, required bool circular}) {
    return Container(
      decoration: BoxDecoration(
        shape: circular ? BoxShape.circle : BoxShape.rectangle,
        gradient: const LinearGradient(
          colors: [Color(0xFFFFB3C6), Color(0xFF9B7EDC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Icon(Icons.music_note_rounded,
          color: Colors.white, size: size * 0.45),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// CONTROL BUTTON
// ─────────────────────────────────────────────────────────────

class _CtrlBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CtrlBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Icon(icon,
            color: Colors.white.withOpacity(0.8), size: 22),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// PLAY / PAUSE BUTTON
// ─────────────────────────────────────────────────────────────

class _PlayPauseBtn extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onTap;
  const _PlayPauseBtn({required this.isPlaying, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFFFFB3C6), Color(0xFF9B7EDC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFB3C6).withOpacity(0.4),
              blurRadius: 14,
              spreadRadius: -4,
            ),
          ],
        ),
        child: Icon(
          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }
}
