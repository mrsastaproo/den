import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'firebase_options.dart';
import 'core/router/app_router.dart';
import 'core/services/appearance_service.dart';
import 'core/services/settings_service.dart';
import 'core/services/auth_service.dart';
import 'core/services/api_service.dart';
import 'core/services/audio_handler.dart';
import 'core/services/notification_service.dart';
import 'core/services/update_service.dart';

void main() async {
  print('[DEN] main() started');
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // ── 120Hz / High Refresh Rate support ──────────────────────────────────
  // Tell the gesture system to resample touch events at the display
  // refresh rate instead of the default 60Hz. This makes scrolling
  // on 90Hz/120Hz/144Hz panels buttery smooth.
  GestureBinding.instance.resamplingEnabled = true;

  // Request highest available refresh rate on Android
  if (Platform.isAndroid) {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor:            Colors.transparent,
      statusBarIconBrightness:   Brightness.light,
    ),
  );

  // ── Hive ──────────────────────────────────────────────────────────────────
  await Hive.initFlutter();
  print('[DEN] Hive initialized');

  // ── Parallel Boot ─────────────────────────────────────────────────────────
  // Run Firebase and AudioService initializing natively parallel to halve boot delay.
  final sharedPlayer = AudioPlayer();

  try {
    await Future.wait([
      Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ).then((_) => print('[DEN] Firebase initialized')),
      
      AudioService.init(
        builder: () => DenAudioHandler(
          player:            sharedPlayer,
          onSkipNext:        () {}, // real callbacks wired by PlayerService
          onSkipPrev:        () {},
          onTogglePlayPause: () {},
        ),
        config: const AudioServiceConfig(
          androidNotificationChannelId:   'com.mrsastaproo.den.audio',
          androidNotificationChannelName: 'DEN Music',
          androidNotificationIcon:        'mipmap/ic_launcher',
          androidNotificationOngoing: true,
          androidStopForegroundOnPause: true,
          androidShowNotificationBadge: true,
          notificationColor: Color(0xFFFFB3C6),
        ),
      ).then((handler) {
        audioHandler = handler;
        print('[DEN] AudioService initialized');
      }),
    ]).timeout(const Duration(seconds: 25));
  } catch (e) {
    print('[DEN] Heavy Init Error via timeout or crash: $e');
  }

  runApp(const ProviderScope(child: DenApp()));
}




// ─────────────────────────────────────────────────────────────────────────────
class DenApp extends ConsumerStatefulWidget {
  const DenApp({super.key});

  @override
  ConsumerState<DenApp> createState() => _DenAppState();
}

class _DenAppState extends ConsumerState<DenApp> {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Reset stuck offline mode
      final prefs = await SharedPreferences.getInstance();
      final offlineStuck = prefs.getBool('offline_mode') ?? false;
      if (offlineStuck) {
        await prefs.setBool('offline_mode', false);
        ref.read(offlineModeProvider.notifier).set(false);
      }

      // Pull cloud settings on startup
      final authState = ref.read(authStateProvider).value;
      if (authState != null) {
        await ref.read(settingsServiceProvider).pullFromCloud();
        // Update last active heartbeat
        ref.read(authServiceProvider).updateLastActive();
      }

      // Initialize Push Notifications
      ref.read(notificationServiceProvider).initialize();

      // Warm up JioSaavn API
      ref.read(apiServiceProvider).warmUp();

      // Check for updates
      UpdateService.checkUpdate(context);

      // Re-pull settings on sign-in
      ref.listenManual(authStateProvider, (prev, next) async {
        if (next.value != null && prev?.value == null) {
          await ref.read(settingsServiceProvider).pullFromCloud();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final router     = ref.watch(appRouterProvider);
    final appearance = ref.watch(appearanceProvider);

    return MaterialApp.router(
      title:                    'DEN',
      debugShowCheckedModeBanner: false,
      // ── Global scroll fix: prevents overscroll glow from eating
      //    reverse-direction gestures on ALL screens ──
      scrollBehavior: const _DenScrollBehavior(),
      theme:     appearance.resolvedTheme,
      darkTheme: appearance.resolvedTheme,
      themeMode: appearance.theme == 'auto'
          ? ThemeMode.system
          : ThemeMode.dark,
      routerConfig: router,
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: TextScaler.linear(appearance.textScaleFactor),
          ),
          child: child!,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Global scroll behavior — fixes scroll-stuck on fast direction changes.
//
// The Android overscroll glow indicator can absorb scroll gestures when
// the user quickly reverses direction, causing the page to appear "stuck".
// By forcing ClampingScrollPhysics and stripping the glow indicator,
// we eliminate the gesture ambiguity entirely.
// ─────────────────────────────────────────────────────────────────────────────
class _DenScrollBehavior extends ScrollBehavior {
  const _DenScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const ClampingScrollPhysics();

  // Remove the overscroll glow that can eat reverse-direction gestures
  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) =>
      child;
}