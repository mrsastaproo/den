import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/services/appearance_service.dart';
import 'core/services/settings_service.dart';
import 'core/services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  await Hive.initFlutter();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    print('Firebase already initialized: $e');
  }

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
      final authState = ref.read(authStateProvider).value;
      if (authState != null) {
        await ref.read(settingsServiceProvider).pullFromCloud();
      }

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

    return MediaQuery(
      // Live font scaling from appearance settings
      data: MediaQueryData.fromView(View.of(context)).copyWith(
        textScaler: TextScaler.linear(appearance.textScaleFactor),
      ),
      child: MaterialApp.router(
        title: 'DEN',
        debugShowCheckedModeBanner: false,

        // Live theme switching (Dark / AMOLED / Auto)
        theme:     appearance.resolvedTheme,
        darkTheme: appearance.resolvedTheme,
        themeMode: appearance.theme == 'auto' ? ThemeMode.system : ThemeMode.dark,

        routerConfig: router,

        // Live animation toggling (Full / Reduced / None)
        builder: (context, child) {
          return TickerMode(
            enabled: !appearance.disableAnimations,
            child: child!,
          );
        },
      ),
    );
  }
}