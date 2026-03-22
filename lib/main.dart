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
  print('[DEN] WidgetsFlutterBinding initialized');

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  print('[DEN] Orientations set');

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  print('[DEN] Initializing Hive...');
  await Hive.initFlutter();
  print('[DEN] Hive initialized');

  print('[DEN] Initializing Firebase...');
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 15));
    print('[DEN] Firebase initialized successfully');
  } catch (e) {
    print('[DEN] Firebase initialization error (might be already initialized or timed out): $e');
  }

  // ── Init audio_service BEFORE runApp ─────────────────────────────────────
  // Powers lock screen controls, notification bar media player,
  // homescreen notification, headset buttons, Android Auto.
  print('[DEN] Initializing AudioService...');
  final sharedPlayer = AudioPlayer();

  try {
    audioHandler = await AudioService.init(
      builder: () => DenAudioHandler(
        player:            sharedPlayer,
        onSkipNext:        () {},  // wired after PlayerService init via callbacks
        onSkipPrev:        () {},
        onTogglePlayPause: () {},
      ),
      config: const AudioServiceConfig(
        androidNotificationChannelId:   'com.mrsastaproo.den.audio',
        androidNotificationChannelName: 'DEN Music',
        androidNotificationOngoing:     true,
        androidStopForegroundOnPause:   true,
        notificationColor:              Color(0xFFFFB3C6),
      ),
    ).timeout(const Duration(seconds: 10));
    print('[DEN] AudioService initialized');
  } catch (e) {
    print('[DEN] AudioService initialization error: $e');
  }

  print('[DEN] Calling runApp()...');
  runApp(const ProviderScope(child: DenApp()));
}

class DenApp extends ConsumerStatefulWidget {
  const DenApp({super.key});

  @override
  ConsumerState<DenApp> createState() => _DenAppState();
}

class _DenAppState extends ConsumerState<DenApp> {

  @override
  void initState() {
    super.initState();
    // Pull cross-device settings from Firestore once on startup.
    // Runs after the first frame so providers are ready.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // ── One-time fix: reset offline_mode if it got stuck true ──
      // This clears a corrupted SharedPreferences value without
      // wiping all app data. Safe to keep permanently — it only
      // resets if offline mode is somehow true on cold launch while
      // no downloaded songs exist (impossible in normal usage).
      final prefs = await SharedPreferences.getInstance();
      final offlineStuck = prefs.getBool('offline_mode') ?? false;
      if (offlineStuck) {
        await prefs.setBool('offline_mode', false);
        ref.read(offlineModeProvider.notifier).set(false);
      }

      final authState = ref.read(authStateProvider).value;
      if (authState != null) {
        await ref.read(settingsServiceProvider).pullFromCloud();
      }

      // Warm up the JioSaavn API server
      ref.read(apiServiceProvider).warmUp();

      // Re-pull whenever the user signs in
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
      title: 'DEN',
      debugShowCheckedModeBanner: false,

      // Live theme switching (Dark / AMOLED / Auto)
      theme:     appearance.resolvedTheme,
      darkTheme: appearance.resolvedTheme,
      themeMode: appearance.theme == 'auto' ? ThemeMode.system : ThemeMode.dark,

      routerConfig: router,

      // Live animation toggling (Full / Reduced / None)
      builder: (context, child) {
        // Apply font scaling here where View is guaranteed to exist
        final mediaQueryData = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQueryData.copyWith(
            textScaler: TextScaler.linear(appearance.textScaleFactor),
          ),
          child: TickerMode(
            enabled: !appearance.disableAnimations,
            child: child!,
          ),
        );
      },
    );
  }
}