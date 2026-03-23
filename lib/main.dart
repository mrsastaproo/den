import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/services/appearance_service.dart';
import 'core/services/settings_service.dart';
import 'core/services/auth_service.dart';
import 'core/services/api_service.dart';
import 'core/services/audio_handler.dart';
void main() async {
  print('[DEN] main() started');
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor:            Colors.transparent,
      statusBarIconBrightness:   Brightness.light,
    ),
  );

  // ── Hive ──────────────────────────────────────────────────────────────────
  await Hive.initFlutter();
  print('[DEN] Hive initialized');

  // ── Firebase ──────────────────────────────────────────────────────────────
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 15));
    print('[DEN] Firebase initialized');
  } catch (e) {
    print('[DEN] Firebase error: $e');
  }

  // ── AudioService ──────────────────────────────────────────────────────────
  // Must be initialised BEFORE runApp().
  // This is what powers:
  //   - Notification bar media player (Spotify-style)
  //   - Lock screen controls with album art
  //   - Headset / Bluetooth buttons
  //   - Background playback when app is minimised
  final sharedPlayer = AudioPlayer();

  try {
    audioHandler = await AudioService.init(
      builder: () => DenAudioHandler(
        player:            sharedPlayer,
        onSkipNext:        () {}, // real callbacks wired by PlayerService
        onSkipPrev:        () {},
        onTogglePlayPause: () {},
      ),
      config: const AudioServiceConfig(
        // ── Android notification channel ──────────────────────────────────
        androidNotificationChannelId:   'com.mrsastaproo.den.audio',
        androidNotificationChannelName: 'DEN Music',
        androidNotificationIcon:        'mipmap/ic_launcher',

        // Keep notification alive while playing
        androidNotificationOngoing: true,

        // Stop foreground service when paused (saves battery, like Spotify)
        androidStopForegroundOnPause: true,

        // Show notification even before user interacts
        androidShowNotificationBadge: true,

        // Accent colour in the notification (DEN pink)
        notificationColor: Color(0xFFFFB3C6),

        // ── iOS ───────────────────────────────────────────────────────────
        // Now Playing info on lock screen / Control Center
      ),
    ).timeout(const Duration(seconds: 10));
    print('[DEN] AudioService initialized');
  } catch (e) {
    print('[DEN] AudioService error: $e');
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
      }

      // Warm up JioSaavn API
      ref.read(apiServiceProvider).warmUp();

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
          child: TickerMode(
            enabled: !appearance.disableAnimations,
            child:   child!,
          ),
        );
      },
    );
  }
}