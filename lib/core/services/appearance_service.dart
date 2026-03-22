// ─────────────────────────────────────────────────────────────────────────────
// appearance_service.dart  —  DEN Appearance Backend
//
// Provides live-switchable state for:
//   • App theme          (Dark / AMOLED / Auto)
//   • Accent color       (5 palettes, affects AppTheme gradients everywhere)
//   • Font size          (Small / Medium / Large / XL  via textScaleFactor)
//   • Animations         (Full / Reduced / None  via TickerMode)
//   • Album art style    (Vinyl / Square / Circle)
//
// Usage in main.dart:
//   final appearanceState = ref.watch(appearanceProvider);
//   MaterialApp(
//     theme: appearanceState.resolvedTheme,
//     ...
//   )
//
// Drop into lib/core/services/appearance_service.dart
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';

// ─── Keys ────────────────────────────────────────────────────────────────────

const _kAppTheme     = 'app_theme';
const _kAccentColor  = 'accent_color';
const _kFontSize     = 'font_size';
const _kAnimations   = 'animations';
const _kAlbumArt     = 'album_art_style';

// ─── Accent Palette Definition ───────────────────────────────────────────────

class AccentPalette {
  final String id;
  final String label;
  final Color color1;
  final Color color2;
  final LinearGradient gradient;

  const AccentPalette({
    required this.id,
    required this.label,
    required this.color1,
    required this.color2,
    required this.gradient,
  });
}

const _palettes = <AccentPalette>[
  AccentPalette(
    id: 'pink_purple',
    label: 'Pink + Purple',
    color1: Color(0xFFFFB3C6),
    color2: Color(0xFFD4B8FF),
    gradient: LinearGradient(
      colors: [Color(0xFFFFB3C6), Color(0xFFD4B8FF)],
      begin: Alignment.topLeft, end: Alignment.bottomRight,
    ),
  ),
  AccentPalette(
    id: 'red_orange',
    label: 'Red + Orange',
    color1: Color(0xFFFF6B6B),
    color2: Color(0xFFFFB347),
    gradient: LinearGradient(
      colors: [Color(0xFFFF6B6B), Color(0xFFFFB347)],
      begin: Alignment.topLeft, end: Alignment.bottomRight,
    ),
  ),
  AccentPalette(
    id: 'blue_cyan',
    label: 'Blue + Cyan',
    color1: Color(0xFF6BB8FF),
    color2: Color(0xFF47FFD4),
    gradient: LinearGradient(
      colors: [Color(0xFF6BB8FF), Color(0xFF47FFD4)],
      begin: Alignment.topLeft, end: Alignment.bottomRight,
    ),
  ),
  AccentPalette(
    id: 'green_teal',
    label: 'Green + Teal',
    color1: Color(0xFF6BFF8C),
    color2: Color(0xFF47FFD4),
    gradient: LinearGradient(
      colors: [Color(0xFF6BFF8C), Color(0xFF47FFD4)],
      begin: Alignment.topLeft, end: Alignment.bottomRight,
    ),
  ),
  AccentPalette(
    id: 'gold_amber',
    label: 'Gold + Amber',
    color1: Color(0xFFFFD700),
    color2: Color(0xFFFFB347),
    gradient: LinearGradient(
      colors: [Color(0xFFFFD700), Color(0xFFFFB347)],
      begin: Alignment.topLeft, end: Alignment.bottomRight,
    ),
  ),
];

AccentPalette paletteById(String id) =>
    _palettes.firstWhere((p) => p.id == id, orElse: () => _palettes.first);

const allPalettes = _palettes;

// ─── Font size → textScaleFactor mapping ─────────────────────────────────────

double fontScaleFactor(String size) {
  switch (size) {
    case 'small':  return 0.85;
    case 'large':  return 1.15;
    case 'xl':     return 1.30;
    default:       return 1.00; // medium
  }
}

// ─── AppearanceState ─────────────────────────────────────────────────────────

class AppearanceState {
  final String theme;        // 'dark' | 'amoled' | 'auto'
  final String accentColor;  // palette id
  final String fontSize;     // 'small' | 'medium' | 'large' | 'xl'
  final String animations;   // 'full' | 'reduced' | 'none'
  final String albumArtStyle;// 'vinyl' | 'square' | 'circle'

  const AppearanceState({
    this.theme         = 'dark',
    this.accentColor   = 'pink_purple',
    this.fontSize      = 'medium',
    this.animations    = 'full',
    this.albumArtStyle = 'vinyl',
  });

  AppearanceState copyWith({
    String? theme, String? accentColor, String? fontSize,
    String? animations, String? albumArtStyle,
  }) => AppearanceState(
    theme:         theme         ?? this.theme,
    accentColor:   accentColor   ?? this.accentColor,
    fontSize:      fontSize      ?? this.fontSize,
    animations:    animations    ?? this.animations,
    albumArtStyle: albumArtStyle ?? this.albumArtStyle,
  );

  AccentPalette get palette => paletteById(accentColor);

  double get textScaleFactor => fontScaleFactor(fontSize);

  bool get reduceMotion => animations != 'full';
  bool get disableAnimations => animations == 'none';

  ThemeData get resolvedTheme {
    final isAmoled  = theme == 'amoled';
    final isDark    = theme == 'dark' || isAmoled;
    final sysDark   = SchedulerBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
    final effectiveDark = theme == 'auto' ? sysDark : isDark;

    final bg        = isAmoled ? Colors.black : AppTheme.bgPrimary;
    final accent1   = palette.color1;
    final accent2   = palette.color2;

    return ThemeData(
      useMaterial3:            true,
      brightness:              effectiveDark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: effectiveDark ? bg : Colors.white,
      primaryColor:            accent1,
      colorScheme: ColorScheme(
        brightness: effectiveDark ? Brightness.dark : Brightness.light,
        primary:    accent1,
        onPrimary:  Colors.white,
        secondary:  accent2,
        onSecondary: Colors.white,
        surface:    effectiveDark ? AppTheme.bgSecondary : Colors.grey[100]!,
        onSurface:  effectiveDark ? Colors.white : Colors.black,
        background: effectiveDark ? bg : Colors.white,
        onBackground: effectiveDark ? Colors.white : Colors.black,
        error:      Colors.redAccent,
        onError:    Colors.white,
      ),
      textTheme: const TextTheme(
        displayLarge:  TextStyle(fontWeight: FontWeight.w800),
        displayMedium: TextStyle(fontWeight: FontWeight.w700),
        titleLarge:    TextStyle(fontWeight: FontWeight.w700),
        bodyLarge:     TextStyle(),
        bodyMedium:    TextStyle(color: AppTheme.textSecondary),
        bodySmall:     TextStyle(color: AppTheme.textMuted),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: effectiveDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 8,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xFF121212),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        clipBehavior: Clip.antiAlias,
      ),
    );
  }

  String get themeLabel {
    switch (theme) {
      case 'amoled': return 'Pure Black (AMOLED)';
      case 'auto':   return 'Auto (System)';
      default:       return 'Dark';
    }
  }

  String get fontSizeLabel {
    switch (fontSize) {
      case 'small': return 'Small';
      case 'large': return 'Large';
      case 'xl':    return 'Extra Large';
      default:      return 'Medium';
    }
  }

  String get animationsLabel {
    switch (animations) {
      case 'reduced': return 'Reduced';
      case 'none':    return 'None';
      default:        return 'Full';
    }
  }

  String get albumArtLabel {
    switch (albumArtStyle) {
      case 'square': return 'Square Card';
      case 'circle': return 'Circle';
      default:       return 'Vinyl Disc';
    }
  }
}

// ─── AppearanceNotifier ───────────────────────────────────────────────────────

class AppearanceNotifier extends StateNotifier<AppearanceState> {
  AppearanceNotifier() : super(const AppearanceState()) { _load(); }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    state = AppearanceState(
      theme:         p.getString(_kAppTheme)    ?? 'dark',
      accentColor:   p.getString(_kAccentColor) ?? 'pink_purple',
      fontSize:      p.getString(_kFontSize)    ?? 'medium',
      animations:    p.getString(_kAnimations)  ?? 'full',
      albumArtStyle: p.getString(_kAlbumArt)    ?? 'vinyl',
    );
  }

  Future<void> _persist(AppearanceState s) async {
    final p = await SharedPreferences.getInstance();
    await Future.wait([
      p.setString(_kAppTheme,    s.theme),
      p.setString(_kAccentColor, s.accentColor),
      p.setString(_kFontSize,    s.fontSize),
      p.setString(_kAnimations,  s.animations),
      p.setString(_kAlbumArt,    s.albumArtStyle),
    ]);
    // Sync to Firestore
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        await FirebaseFirestore.instance
            .doc('user_settings/$uid')
            .set({
          _kAppTheme:    s.theme,
          _kAccentColor: s.accentColor,
          _kFontSize:    s.fontSize,
          _kAnimations:  s.animations,
          _kAlbumArt:    s.albumArtStyle,
        }, SetOptions(merge: true));
      } catch (_) {}
    }
  }

  Future<void> setTheme(String v) async {
    state = state.copyWith(theme: v);
    await _persist(state);
  }

  Future<void> setAccentColor(String paletteId) async {
    state = state.copyWith(accentColor: paletteId);
    await _persist(state);
  }

  Future<void> setFontSize(String v) async {
    state = state.copyWith(fontSize: v);
    await _persist(state);
  }

  Future<void> setAnimations(String v) async {
    state = state.copyWith(animations: v);
    await _persist(state);
  }

  Future<void> setAlbumArtStyle(String v) async {
    state = state.copyWith(albumArtStyle: v);
    await _persist(state);
  }
}

final appearanceProvider = StateNotifierProvider<AppearanceNotifier, AppearanceState>(
  (ref) => AppearanceNotifier());

// ─────────────────────────────────────────────────────────────────────────────
// HOW TO WIRE INTO main.dart
// ─────────────────────────────────────────────────────────────────────────────
//
// class MyApp extends ConsumerWidget {
//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     final appearance = ref.watch(appearanceProvider);
//     return MediaQuery(
//       // Live font scaling
//       data: MediaQuery.of(context).copyWith(
//         textScaleFactor: appearance.textScaleFactor,
//       ),
//       child: MaterialApp.router(
//         theme:       appearance.resolvedTheme,
//         // Live animation reduction
//         builder: (context, child) => TickerMode(
//           enabled: !appearance.disableAnimations,
//           child: child!,
//         ),
//         routerConfig: ref.watch(appRouterProvider),
//       ),
//     );
//   }
// }
// ─────────────────────────────────────────────────────────────────────────────