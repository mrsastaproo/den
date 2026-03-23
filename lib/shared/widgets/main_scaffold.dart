import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/social_service.dart';
import '../../core/services/settings_service.dart';
import 'integrated_bottom_shell.dart';
import 'ambient_background.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import '../../core/providers/music_providers.dart';
import '../../core/services/player_service.dart';
import '../../core/theme/app_theme.dart';



class MainScaffold extends ConsumerStatefulWidget {
  final Widget child;
  const MainScaffold({super.key, required this.child});

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold>
    with WidgetsBindingObserver {

  @override
  void initState() {
    super.initState();
    _checkOverlayPermission();
    WidgetsBinding.instance.addObserver(this);

    Future.microtask(
        () => ref.read(socialServiceProvider).updateOnlineStatus(true));
  }

  void _checkOverlayPermission() async {
    final granted = await FlutterOverlayWindow.isPermissionGranted();
    if (!granted) {
      await FlutterOverlayWindow.requestPermission();
    }
  }


  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(socialServiceProvider).updateOnlineStatus(true);
      // App came back to foreground — dismiss the overlay
      _hideOverlay();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // App truly went to background (home button / recent apps)
      // NOTE: 'inactive' is intentionally excluded — it fires during
      // in-app interactions (notification shade, dialogs, system UI)
      // which would cause the overlay to flash while the app is open.
      ref.read(socialServiceProvider).updateOnlineStatus(false);
      _showOverlayIfPlaying();
    }
  }


  void _hideOverlay() async {
    if (await FlutterOverlayWindow.isActive()) {
      await FlutterOverlayWindow.closeOverlay();
    }
  }

  void _showOverlayIfPlaying() async {
    final isPlaying = ref.read(isPlayingProvider);
    final song = ref.read(currentSongProvider);
    if (!isPlaying || song == null) return;

    if (await FlutterOverlayWindow.isActive()) return;

    // Show the overlay pinned to the top (notch area)
    await FlutterOverlayWindow.showOverlay(
      enableDrag: false,
      overlayTitle: 'DEN – Now Playing',
      overlayContent: song.title,
      // topCenter so the pill appears behind the punch-hole / notch
      alignment: OverlayAlignment.topCenter,
      visibility: NotificationVisibility.visibilityPublic,
      flag: OverlayFlag.defaultFlag,
      // Collapsed pill: 400×60 logical pixels
      width: 400,
      height: 60,
      positionGravity: PositionGravity.auto,
    );

    // Give the overlay isolate ~300 ms to boot, then push playback data
    Future.delayed(const Duration(milliseconds: 300), () {
      ref.read(playerServiceProvider).updateOverlay();
    });
  }



  int _locationToIndex(String location) {
    if (location.startsWith('/home'))     return 0;
    if (location.startsWith('/search'))   return 1;
    if (location.startsWith('/ai'))       return 2;
    if (location.startsWith('/library'))  return 3;
    if (location.startsWith('/friends'))  return 4;
    if (location.startsWith('/settings')) return 5;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location     = GoRouterState.of(context).uri.toString();
    final currentIndex = _locationToIndex(location);
    final carMode      = ref.watch(carModeProvider);

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor:                    Colors.transparent,
        statusBarIconBrightness:           Brightness.light,
        systemNavigationBarColor:          Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    // ── Car Mode: show simplified driving UI ─────────────────────
    if (carMode) {
      return _CarModeScreen(
        onExit: () =>
            ref.read(carModeProvider.notifier).set(false),
      );
    }

    return AmbientBackground(
      child: Scaffold(
        backgroundColor:          Colors.transparent,
        extendBody:               true,
        extendBodyBehindAppBar:   true,
        body: Stack(
          children: [
            widget.child,
          ],
        ),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IntegratedBottomShell(
              currentIndex: currentIndex,
              onTap: (i) {
                switch (i) {
                  case 0: context.go('/home');     break;
                  case 1: context.go('/search');   break;
                  case 2: context.go('/ai');       break;
                  case 3: context.go('/library');  break;
                  case 4: context.go('/friends');  break;
                  case 5: context.go('/settings'); break;
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// CAR MODE SCREEN
// Large tap targets, minimal UI, stays locked to this screen.
// ─────────────────────────────────────────────────────────────

class _CarModeScreen extends ConsumerWidget {
  final VoidCallback onExit;
  const _CarModeScreen({required this.onExit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final song      = ref.watch(currentSongProvider);
    final isPlaying = ref.watch(isPlayingStreamProvider).value ?? false;
    final position  = ref.watch(positionStreamProvider).value  ?? Duration.zero;
    final duration  = ref.watch(durationStreamProvider).value  ?? Duration.zero;
    final player    = ref.read(playerServiceProvider);

    String fmt(Duration d) {
      return '${d.inMinutes.remainder(60)}:'
          '${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';
    }

    final double seekMax = (duration.inSeconds.toDouble()).clamp(1.0, double.infinity);
    final double seekVal = position.inSeconds.toDouble().clamp(0.0, seekMax);

    return Scaffold(
      backgroundColor: const Color(0xFF080810),
      body: Stack(
        children: [
          // Background glow
          Center(
            child: Container(
              width: 500, height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppTheme.purple.withOpacity(0.12),
                  Colors.transparent,
                ]),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Top bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Row(
                    children: [
                      ShaderMask(
                        shaderCallback: (b) =>
                            AppTheme.primaryGradient.createShader(b),
                        child: const Icon(Icons.directions_car_rounded,
                            color: Colors.white, size: 22)),
                      const SizedBox(width: 8),
                      const Text(
                        'CAR MODE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 4,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          onExit();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.07),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.12)),
                          ),
                          child: const Text('Exit',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              )),
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Song info
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    children: [
                      Text(
                        song?.title ?? 'Not Playing',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                          height: 1.1,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        song?.artist ?? '',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.45),
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Progress bar (read-only in car mode for safety)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 36),
                  child: Column(
                    children: [
                      LinearProgressIndicator(
                        value: seekMax > 0 ? (seekVal / seekMax) : 0,
                        backgroundColor: Colors.white.withOpacity(0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(
                            AppTheme.pink.withOpacity(0.9)),
                        minHeight: 3,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(fmt(position),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.3),
                                fontSize: 11,
                              )),
                          Text(fmt(duration),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.3),
                                fontSize: 11,
                              )),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // Big controls — huge tap targets for driving safety
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Prev
                      _CarBtn(
                        icon: Icons.skip_previous_rounded,
                        size: 52,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          player.skipPrev();
                        },
                      ),
                      // Play/Pause — much larger
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          player.togglePlayPauseSync();
                        },
                        child: Container(
                          width: 96, height: 96,
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.pink.withOpacity(0.5),
                                blurRadius: 30,
                                spreadRadius: -4,
                              ),
                            ],
                          ),
                          child: Icon(
                            isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 52,
                          ),
                        ),
                      ),
                      // Next
                      _CarBtn(
                        icon: Icons.skip_next_rounded,
                        size: 52,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          player.skipNext();
                        },
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Reminder text
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Text(
                    'Keep your eyes on the road',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.2),
                      fontSize: 12,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CarBtn extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback onTap;
  const _CarBtn({required this.icon, required this.size, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72, height: 72,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.07),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Icon(icon, color: Colors.white.withOpacity(0.85), size: size),
      ),
    );
  }
}
