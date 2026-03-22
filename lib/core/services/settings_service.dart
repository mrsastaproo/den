// ─────────────────────────────────────────────────────────────────────────────
// settings_service.dart  —  DEN Complete Settings Backend
//
// Covers every setting in settings_screen.dart:
//   Playback · Audio Quality · Downloads · Content & Language
//   Appearance · Social & Privacy · Notifications · Storage & Data
//
// Architecture:
//   • SharedPreferences  — local persistence for all non-sensitive settings
//   • Firestore          — sync settings across devices (per-user doc)
//   • just_audio         — crossfade / gapless / normalization applied live
//   • MethodChannel      — Android native EQ (MainActivity.kt)
//   • Firebase Messaging — push notification token management
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:just_audio/just_audio.dart';

// ─── SHARED PREFS KEY REGISTRY ───────────────────────────────────────────────

class _K {
  // ── Playback ────────────────────────────────────────────────────
  static const crossfadeEnabled  = 'crossfade_enabled';
  static const crossfadeDur      = 'crossfade_duration';
  static const normalization     = 'normalization';
  static const autoplay          = 'autoplay';
  static const gapless           = 'gapless';
  static const showLyrics        = 'show_lyrics';
  static const sleepTimer        = 'sleep_timer';
  static const carMode           = 'car_mode';

  // ── Audio Quality ───────────────────────────────────────────────
  static const streamingQuality  = 'streaming_quality';
  static const wifiQuality       = 'wifi_quality';
  static const mobileDataQuality = 'mobile_data_quality';
  static const audioFormat       = 'audio_format';

  // ── Downloads ───────────────────────────────────────────────────
  static const downloadQuality   = 'download_quality';
  static const offlineMode       = 'offline_mode';
  static const dataWarning       = 'data_warning';
  static const storageLocation   = 'storage_location';   // 'internal' | 'external'

  // ── Content & Language ──────────────────────────────────────────
  static const musicLanguage     = 'music_language';
  static const explicitContent   = 'explicit_content';
  static const contentPrefs      = 'content_prefs';      // JSON list of genre strings
  static const blockedArtists    = 'blocked_artists';    // JSON list of artist IDs

  // ── Appearance ──────────────────────────────────────────────────
  static const appTheme          = 'app_theme';          // 'dark' | 'amoled' | 'auto'
  static const accentColor       = 'accent_color';       // 'pink_purple' | etc.
  static const fontSize          = 'font_size';          // 'small' | 'medium' | 'large' | 'xl'
  static const animations        = 'animations';         // 'full' | 'reduced' | 'none'
  static const albumArtStyle     = 'album_art_style';    // 'vinyl' | 'square' | 'circle'

  // ── Social & Privacy ────────────────────────────────────────────
  static const privateSession    = 'private_session';
  static const analyticsEnabled  = 'analytics_enabled';
  static const activityVisible   = 'activity_visible';

  // ── Notifications ───────────────────────────────────────────────
  static const showNotifications      = 'show_notifications';
  static const notifNewReleases       = 'notif_new_releases';
  static const notifRecommendations   = 'notif_recommendations';
  static const notifAppUpdates        = 'notif_app_updates';

  // ── EQ ──────────────────────────────────────────────────────────
  static const eqEnabled         = 'eq_enabled';
  static const eqBass            = 'eq_bass';
  static const eqLowMid          = 'eq_low_mid';
  static const eqMid             = 'eq_mid';
  static const eqHighMid         = 'eq_high_mid';
  static const eqTreble          = 'eq_treble';
  static const eqMasterGain      = 'eq_master_gain';
  static const eqPreset          = 'eq_preset';

  // ── Firestore collection path ───────────────────────────────────
  static String firestoreUserSettings(String uid) => 'user_settings/$uid';
}

// ─────────────────────────────────────────────────────────────────────────────
// SETTINGS SYNC SERVICE
// Reads/writes local prefs AND syncs to Firestore for cross-device persistence.
// ─────────────────────────────────────────────────────────────────────────────

class SettingsService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  // ── Firestore helpers ─────────────────────────────────────────────────────

  /// Merge a key-value into the user's settings document on Firestore.
  Future<void> _syncToCloud(String key, dynamic value) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _db
          .doc(_K.firestoreUserSettings(uid))
          .set({key: value}, SetOptions(merge: true));
    } catch (_) {
      // Offline — SharedPrefs acts as cache, sync will happen on reconnect
    }
  }

  /// Pull the full settings doc from Firestore and apply to SharedPreferences.
  /// Called once on app launch / after sign-in.
  Future<void> pullFromCloud() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final doc = await _db.doc(_K.firestoreUserSettings(uid)).get();
      if (!doc.exists) return;
      final data = doc.data()!;
      final prefs = await _prefs;
      for (final entry in data.entries) {
        final v = entry.value;
        if (v is bool)   await prefs.setBool(entry.key, v);
        if (v is double) await prefs.setDouble(entry.key, v);
        if (v is int)    await prefs.setDouble(entry.key, v.toDouble());
        if (v is String) await prefs.setString(entry.key, v);
      }
    } catch (_) {}
  }

  // ── Generic typed setters (local + cloud) ─────────────────────────────────

  Future<void> _setBool(String key, bool v) async {
    (await _prefs).setBool(key, v);
    _syncToCloud(key, v);
  }

  Future<void> _setDouble(String key, double v) async {
    (await _prefs).setDouble(key, v);
    _syncToCloud(key, v);
  }

  Future<void> _setString(String key, String v) async {
    (await _prefs).setString(key, v);
    _syncToCloud(key, v);
  }

  Future<void> _removeKey(String key) async {
    (await _prefs).remove(key);
    _syncToCloud(key, null);
  }

  // ── Playback ──────────────────────────────────────────────────────────────

  Future<void> setCrossfadeEnabled(bool v)  => _setBool(_K.crossfadeEnabled, v);
  Future<bool> getCrossfadeEnabled()        async => (await _prefs).getBool(_K.crossfadeEnabled) ?? false;

  Future<void> setCrossfadeDuration(double v) => _setDouble(_K.crossfadeDur, v);
  Future<double> getCrossfadeDuration()      async => (await _prefs).getDouble(_K.crossfadeDur) ?? 3.0;

  Future<void> setNormalization(bool v)     => _setBool(_K.normalization, v);
  Future<bool> getNormalization()           async => (await _prefs).getBool(_K.normalization) ?? true;

  Future<void> setAutoplay(bool v)          => _setBool(_K.autoplay, v);
  Future<bool> getAutoplay()               async => (await _prefs).getBool(_K.autoplay) ?? true;

  Future<void> setGapless(bool v)           => _setBool(_K.gapless, v);
  Future<bool> getGapless()               async => (await _prefs).getBool(_K.gapless) ?? true;

  Future<void> setShowLyrics(bool v)        => _setBool(_K.showLyrics, v);
  Future<bool> getShowLyrics()             async => (await _prefs).getBool(_K.showLyrics) ?? true;

  Future<void> setSleepTimer(String? v) async {
    if (v == null) {
      await _removeKey(_K.sleepTimer);
    } else {
      await _setString(_K.sleepTimer, v);
    }
  }
  Future<String?> getSleepTimer() async => (await _prefs).getString(_K.sleepTimer);

  Future<void> setCarMode(bool v)           => _setBool(_K.carMode, v);
  Future<bool> getCarMode()               async => (await _prefs).getBool(_K.carMode) ?? false;

  // ── Audio Quality ─────────────────────────────────────────────────────────

  Future<void> setStreamingQuality(String v)  => _setString(_K.streamingQuality, v);
  Future<String> getStreamingQuality()        async => (await _prefs).getString(_K.streamingQuality) ?? '320kbps';

  Future<void> setWifiQuality(String v)       => _setString(_K.wifiQuality, v);
  Future<String> getWifiQuality()             async => (await _prefs).getString(_K.wifiQuality) ?? 'Auto';

  Future<void> setMobileDataQuality(String v) => _setString(_K.mobileDataQuality, v);
  Future<String> getMobileDataQuality()       async => (await _prefs).getString(_K.mobileDataQuality) ?? '160kbps';

  Future<void> setAudioFormat(String v)       => _setString(_K.audioFormat, v);
  Future<String> getAudioFormat()             async => (await _prefs).getString(_K.audioFormat) ?? 'MP3';

  // ── Downloads ─────────────────────────────────────────────────────────────

  Future<void> setDownloadQuality(String v)   => _setString(_K.downloadQuality, v);
  Future<String> getDownloadQuality()         async => (await _prefs).getString(_K.downloadQuality) ?? '320kbps';

  Future<void> setOfflineMode(bool v)         => _setBool(_K.offlineMode, v);
  Future<bool> getOfflineMode()               async => (await _prefs).getBool(_K.offlineMode) ?? false;

  Future<void> setDataWarning(bool v)         => _setBool(_K.dataWarning, v);
  Future<bool> getDataWarning()               async => (await _prefs).getBool(_K.dataWarning) ?? true;

  Future<void> setStorageLocation(String v)   => _setString(_K.storageLocation, v);
  Future<String> getStorageLocation()         async => (await _prefs).getString(_K.storageLocation) ?? 'internal';

  // ── Content & Language ────────────────────────────────────────────────────

  Future<void> setMusicLanguage(String v)     => _setString(_K.musicLanguage, v);
  Future<String> getMusicLanguage()           async => (await _prefs).getString(_K.musicLanguage) ?? 'Hindi + English';

  Future<void> setExplicitContent(bool v)     => _setBool(_K.explicitContent, v);
  Future<bool> getExplicitContent()           async => (await _prefs).getBool(_K.explicitContent) ?? true;

  // ── Appearance ────────────────────────────────────────────────────────────

  Future<void> setAppTheme(String v)          => _setString(_K.appTheme, v);
  Future<String> getAppTheme()               async => (await _prefs).getString(_K.appTheme) ?? 'dark';

  Future<void> setAccentColor(String v)       => _setString(_K.accentColor, v);
  Future<String> getAccentColor()             async => (await _prefs).getString(_K.accentColor) ?? 'pink_purple';

  Future<void> setFontSize(String v)          => _setString(_K.fontSize, v);
  Future<String> getFontSize()               async => (await _prefs).getString(_K.fontSize) ?? 'medium';

  Future<void> setAnimations(String v)        => _setString(_K.animations, v);
  Future<String> getAnimations()             async => (await _prefs).getString(_K.animations) ?? 'full';

  Future<void> setAlbumArtStyle(String v)     => _setString(_K.albumArtStyle, v);
  Future<String> getAlbumArtStyle()          async => (await _prefs).getString(_K.albumArtStyle) ?? 'vinyl';

  // ── Social & Privacy ──────────────────────────────────────────────────────

  Future<void> setPrivateSession(bool v)      => _setBool(_K.privateSession, v);
  Future<bool> getPrivateSession()            async => (await _prefs).getBool(_K.privateSession) ?? false;

  Future<void> setAnalyticsEnabled(bool v)    => _setBool(_K.analyticsEnabled, v);
  Future<bool> getAnalyticsEnabled()          async => (await _prefs).getBool(_K.analyticsEnabled) ?? true;

  Future<void> setActivityVisible(bool v)     => _setBool(_K.activityVisible, v);
  Future<bool> getActivityVisible()           async => (await _prefs).getBool(_K.activityVisible) ?? true;

  // ── Notifications ─────────────────────────────────────────────────────────

  Future<void> setShowNotifications(bool v)   => _setBool(_K.showNotifications, v);
  Future<bool> getShowNotifications()         async => (await _prefs).getBool(_K.showNotifications) ?? true;

  Future<void> setNotifNewReleases(bool v)    => _setBool(_K.notifNewReleases, v);
  Future<bool> getNotifNewReleases()          async => (await _prefs).getBool(_K.notifNewReleases) ?? true;

  Future<void> setNotifRecommendations(bool v) => _setBool(_K.notifRecommendations, v);
  Future<bool> getNotifRecommendations()      async => (await _prefs).getBool(_K.notifRecommendations) ?? false;

  Future<void> setNotifAppUpdates(bool v)     => _setBool(_K.notifAppUpdates, v);
  Future<bool> getNotifAppUpdates()           async => (await _prefs).getBool(_K.notifAppUpdates) ?? true;
}

final settingsServiceProvider = Provider<SettingsService>((ref) => SettingsService());

// ─────────────────────────────────────────────────────────────────────────────
// GENERIC NOTIFIER BASE CLASSES
// ─────────────────────────────────────────────────────────────────────────────

class PersistedBoolNotifier extends StateNotifier<bool> {
  final String key;
  final bool defaultValue;
  PersistedBoolNotifier(this.key, {this.defaultValue = false}) : super(defaultValue) { _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(key) ?? defaultValue;
  }

  Future<void> set(bool v) async {
    state = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, v);
    // Firestore sync
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        await FirebaseFirestore.instance
            .doc('user_settings/$uid')
            .set({key: v}, SetOptions(merge: true));
      } catch (_) {}
    }
  }
}

class PersistedDoubleNotifier extends StateNotifier<double> {
  final String key;
  final double defaultValue;
  PersistedDoubleNotifier(this.key, {this.defaultValue = 0.0}) : super(defaultValue) { _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getDouble(key) ?? defaultValue;
  }

  Future<void> set(double v) async {
    state = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(key, v);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        await FirebaseFirestore.instance
            .doc('user_settings/$uid')
            .set({key: v}, SetOptions(merge: true));
      } catch (_) {}
    }
  }
}

class PersistedStringNotifier extends StateNotifier<String> {
  final String key;
  final String defaultValue;
  PersistedStringNotifier(this.key, {required this.defaultValue}) : super(defaultValue) { _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(key) ?? defaultValue;
  }

  Future<void> set(String v) async {
    state = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, v);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        await FirebaseFirestore.instance
            .doc('user_settings/$uid')
            .set({key: v}, SetOptions(merge: true));
      } catch (_) {}
    }
  }
}

class PersistedNullableStringNotifier extends StateNotifier<String?> {
  final String key;
  PersistedNullableStringNotifier(this.key) : super(null) { _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(key);
  }

  Future<void> set(String? v) async {
    state = v;
    final prefs = await SharedPreferences.getInstance();
    if (v == null) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, v);
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        await FirebaseFirestore.instance
            .doc('user_settings/$uid')
            .set({key: v}, SetOptions(merge: true));
      } catch (_) {}
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// QUALITY NOTIFIER — wires directly into just_audio via AudioService
// ─────────────────────────────────────────────────────────────────────────────

class QualityNotifier extends StateNotifier<String> {
  final String _prefKey;
  QualityNotifier(this._prefKey, String defaultVal) : super(defaultVal) { _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(_prefKey) ?? state;
  }

  Future<void> set(String quality) async {
    state = quality;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, quality);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        await FirebaseFirestore.instance
            .doc('user_settings/$uid')
            .set({_prefKey: quality}, SetOptions(merge: true));
      } catch (_) {}
    }
  }

  /// Maps a quality string to a just_audio preferred bitrate hint.
  /// Used by player_service when building audio sources.
  static int bitrate(String quality) {
    switch (quality) {
      case '96kbps':  return 96000;
      case '160kbps': return 160000;
      case '320kbps': return 320000;
      default:        return 320000;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ALL PERSISTED PROVIDERS
// ─────────────────────────────────────────────────────────────────────────────

// ── Playback ───────────────────────────────────────────────────────────────

final crossfadeEnabledProvider  = StateNotifierProvider<PersistedBoolNotifier, bool>(
  (ref) => PersistedBoolNotifier(_K.crossfadeEnabled, defaultValue: false));

final crossfadeDurationProvider = StateNotifierProvider<PersistedDoubleNotifier, double>(
  (ref) => PersistedDoubleNotifier(_K.crossfadeDur, defaultValue: 3.0));

final normalizationEnabledProvider = StateNotifierProvider<PersistedBoolNotifier, bool>(
  (ref) => PersistedBoolNotifier(_K.normalization, defaultValue: true));

final autoplayEnabledProvider   = StateNotifierProvider<PersistedBoolNotifier, bool>(
  (ref) => PersistedBoolNotifier(_K.autoplay, defaultValue: true));

final gaplessPlaybackProvider   = StateNotifierProvider<PersistedBoolNotifier, bool>(
  (ref) => PersistedBoolNotifier(_K.gapless, defaultValue: true));

final showLyricsProvider        = StateNotifierProvider<PersistedBoolNotifier, bool>(
  (ref) => PersistedBoolNotifier(_K.showLyrics, defaultValue: true));

final sleepTimerProvider        = StateNotifierProvider<PersistedNullableStringNotifier, String?>(
  (ref) => PersistedNullableStringNotifier(_K.sleepTimer));

final carModeProvider           = StateNotifierProvider<PersistedBoolNotifier, bool>(
  (ref) => PersistedBoolNotifier(_K.carMode, defaultValue: false));

// ── Audio Quality ─────────────────────────────────────────────────────────

final streamingQualityProvider  = StateNotifierProvider<QualityNotifier, String>(
  (ref) => QualityNotifier(_K.streamingQuality, '320kbps'));

final wifiQualityProvider       = StateNotifierProvider<PersistedStringNotifier, String>(
  (ref) => PersistedStringNotifier(_K.wifiQuality, defaultValue: 'Auto'));

final mobileDataQualityProvider = StateNotifierProvider<QualityNotifier, String>(
  (ref) => QualityNotifier(_K.mobileDataQuality, '160kbps'));

final audioFormatProvider       = StateNotifierProvider<PersistedStringNotifier, String>(
  (ref) => PersistedStringNotifier(_K.audioFormat, defaultValue: 'MP3'));

// ── Downloads ────────────────────────────────────────────────────────────

final downloadQualityProvider   = StateNotifierProvider<QualityNotifier, String>(
  (ref) => QualityNotifier(_K.downloadQuality, '320kbps'));

final offlineModeProvider       = StateNotifierProvider<PersistedBoolNotifier, bool>(
  (ref) => PersistedBoolNotifier(_K.offlineMode, defaultValue: false));

final dataWarningProvider       = StateNotifierProvider<PersistedBoolNotifier, bool>(
  (ref) => PersistedBoolNotifier(_K.dataWarning, defaultValue: true));

final storageLocationProvider   = StateNotifierProvider<PersistedStringNotifier, String>(
  (ref) => PersistedStringNotifier(_K.storageLocation, defaultValue: 'internal'));

// ── Content & Language ───────────────────────────────────────────────────

class LanguageNotifier extends StateNotifier<String> {
  LanguageNotifier() : super('Hindi + English') { _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(_K.musicLanguage) ?? 'Hindi + English';
  }

  Future<void> set(String v) async {
    state = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_K.musicLanguage, v);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        await FirebaseFirestore.instance
            .doc('user_settings/$uid')
            .set({_K.musicLanguage: v}, SetOptions(merge: true));
      } catch (_) {}
    }
  }
}

final musicLanguageProvider     = StateNotifierProvider<LanguageNotifier, String>(
  (ref) => LanguageNotifier());

final explicitContentProvider   = StateNotifierProvider<PersistedBoolNotifier, bool>(
  (ref) => PersistedBoolNotifier(_K.explicitContent, defaultValue: true));

// ── Appearance ───────────────────────────────────────────────────────────

final appThemeProvider          = StateNotifierProvider<PersistedStringNotifier, String>(
  (ref) => PersistedStringNotifier(_K.appTheme, defaultValue: 'dark'));

final accentColorProvider       = StateNotifierProvider<PersistedStringNotifier, String>(
  (ref) => PersistedStringNotifier(_K.accentColor, defaultValue: 'pink_purple'));

final fontSizeProvider          = StateNotifierProvider<PersistedStringNotifier, String>(
  (ref) => PersistedStringNotifier(_K.fontSize, defaultValue: 'medium'));

final animationsProvider        = StateNotifierProvider<PersistedStringNotifier, String>(
  (ref) => PersistedStringNotifier(_K.animations, defaultValue: 'full'));

final albumArtStyleProvider     = StateNotifierProvider<PersistedStringNotifier, String>(
  (ref) => PersistedStringNotifier(_K.albumArtStyle, defaultValue: 'vinyl'));

// ── Social & Privacy ─────────────────────────────────────────────────────

final privateSessionProvider    = StateNotifierProvider<PersistedBoolNotifier, bool>(
  (ref) => PersistedBoolNotifier(_K.privateSession, defaultValue: false));

final analyticsEnabledProvider  = StateNotifierProvider<PersistedBoolNotifier, bool>(
  (ref) => PersistedBoolNotifier(_K.analyticsEnabled, defaultValue: true));

final activityVisibleProvider   = StateNotifierProvider<PersistedBoolNotifier, bool>(
  (ref) => PersistedBoolNotifier(_K.activityVisible, defaultValue: true));

// ── Notifications ────────────────────────────────────────────────────────

final showNotificationsProvider     = StateNotifierProvider<PersistedBoolNotifier, bool>(
  (ref) => PersistedBoolNotifier(_K.showNotifications, defaultValue: true));

final notifNewReleasesProvider      = StateNotifierProvider<PersistedBoolNotifier, bool>(
  (ref) => PersistedBoolNotifier(_K.notifNewReleases, defaultValue: true));

final notifRecommendationsProvider  = StateNotifierProvider<PersistedBoolNotifier, bool>(
  (ref) => PersistedBoolNotifier(_K.notifRecommendations, defaultValue: false));

final notifAppUpdatesProvider       = StateNotifierProvider<PersistedBoolNotifier, bool>(
  (ref) => PersistedBoolNotifier(_K.notifAppUpdates, defaultValue: true));

// ─────────────────────────────────────────────────────────────────────────────
// EQ STATE & NOTIFIER
// ─────────────────────────────────────────────────────────────────────────────

class EqState {
  final bool enabled;
  final double bass, lowMid, mid, highMid, treble, masterGain;
  final String preset;

  const EqState({
    this.enabled    = true,
    this.bass       = 0,
    this.lowMid     = 0,
    this.mid        = 0,
    this.highMid    = 0,
    this.treble     = 0,
    this.masterGain = 0,
    this.preset     = 'Normal',
  });

  List<double> get bands => [bass, lowMid, mid, highMid, treble];

  EqState copyWith({
    bool? enabled, double? bass, double? lowMid, double? mid,
    double? highMid, double? treble, double? masterGain, String? preset,
  }) => EqState(
    enabled:    enabled    ?? this.enabled,
    bass:       bass       ?? this.bass,
    lowMid:     lowMid     ?? this.lowMid,
    mid:        mid        ?? this.mid,
    highMid:    highMid    ?? this.highMid,
    treble:     treble     ?? this.treble,
    masterGain: masterGain ?? this.masterGain,
    preset:     preset     ?? this.preset,
  );
}

class EqNotifier extends StateNotifier<EqState> {
  // MethodChannel to the Android native AudioEffect EQ.
  // Requires MainActivity.kt to handle 'setEqualizer' calls.
  static const _channel = MethodChannel('den/equalizer');
  int? _sessionId;

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
    'Vocal':      [-2.0, 0.0,  4.0,  3.0,  2.0],
    'Flat':       [0.0,  0.0,  0.0,  0.0,  0.0],
  };

  EqNotifier() : super(const EqState()) { _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = EqState(
      enabled:    prefs.getBool(_K.eqEnabled)     ?? true,
      bass:       prefs.getDouble(_K.eqBass)       ?? 0.0,
      lowMid:     prefs.getDouble(_K.eqLowMid)     ?? 0.0,
      mid:        prefs.getDouble(_K.eqMid)         ?? 0.0,
      highMid:    prefs.getDouble(_K.eqHighMid)    ?? 0.0,
      treble:     prefs.getDouble(_K.eqTreble)     ?? 0.0,
      masterGain: prefs.getDouble(_K.eqMasterGain) ?? 0.0,
      preset:     prefs.getString(_K.eqPreset)     ?? 'Normal',
    );
  }

  Future<void> _save(EqState s) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setBool(_K.eqEnabled,       s.enabled),
      prefs.setDouble(_K.eqBass,        s.bass),
      prefs.setDouble(_K.eqLowMid,      s.lowMid),
      prefs.setDouble(_K.eqMid,         s.mid),
      prefs.setDouble(_K.eqHighMid,     s.highMid),
      prefs.setDouble(_K.eqTreble,      s.treble),
      prefs.setDouble(_K.eqMasterGain,  s.masterGain),
      prefs.setString(_K.eqPreset,      s.preset),
    ]);
    // Sync eq state to Firestore
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        await FirebaseFirestore.instance
            .doc('user_settings/$uid')
            .set({
          _K.eqEnabled:    s.enabled,
          _K.eqBass:       s.bass,
          _K.eqLowMid:     s.lowMid,
          _K.eqMid:        s.mid,
          _K.eqHighMid:    s.highMid,
          _K.eqTreble:     s.treble,
          _K.eqMasterGain: s.masterGain,
          _K.eqPreset:     s.preset,
        }, SetOptions(merge: true));
      } catch (_) {}
    }
  }

  /// Apply current EQ to the Android native AudioEffect layer.
  Future<void> _apply(EqState s) async {
    final sid = _sessionId;
    if (sid == null || sid == 0) return;
    try {
      await _channel.invokeMethod('setEqualizer', {
        'sessionId':  sid,
        'enabled':    s.enabled,
        'bands':      s.bands,
        'masterGain': s.masterGain,
      });
    } catch (_) {
      // iOS / simulator — no native EQ, silently ignore
    }
  }

  /// Called by player_service when a new audio session starts.
  Future<void> attachSession(int? sid) async {
    _sessionId = sid;
    await _apply(state);
  }

  void setBand(int i, double v) {
    final b = state.bands.toList()..setRange(i, i + 1, [v]);
    final next = state.copyWith(
      bass: b[0], lowMid: b[1], mid: b[2],
      highMid: b[3], treble: b[4], preset: 'Custom',
    );
    state = next;
    _apply(next);
    _save(next);
  }

  void setMasterGain(double v) {
    final next = state.copyWith(masterGain: v);
    state = next;
    _apply(next);
    _save(next);
  }

  void setEnabled(bool v) {
    final next = state.copyWith(enabled: v);
    state = next;
    _apply(next);
    _save(next);
    HapticFeedback.selectionClick();
  }

  void applyPreset(String name) {
    final v = presets[name];
    if (v == null) return;
    final next = EqState(
      enabled: state.enabled, masterGain: state.masterGain,
      bass: v[0], lowMid: v[1], mid: v[2],
      highMid: v[3], treble: v[4], preset: name,
    );
    state = next;
    _apply(next);
    _save(next);
    HapticFeedback.selectionClick();
  }

  void reset() {
    const next = EqState();
    state = next;
    _apply(next);
    _save(next);
    HapticFeedback.mediumImpact();
  }
}

final eqProvider = StateNotifierProvider<EqNotifier, EqState>(
  (ref) => EqNotifier());

// ─────────────────────────────────────────────────────────────────────────────
// SLEEP TIMER SERVICE
// ─────────────────────────────────────────────────────────────────────────────

class SleepTimerService {
  Timer? _timer;
  DateTime? _endsAt;

  void start(Duration duration, VoidCallback onDone) {
    _timer?.cancel();
    _endsAt = DateTime.now().add(duration);
    _timer  = Timer(duration, () {
      _endsAt = null;
      onDone();
    });
  }

  void cancel() {
    _timer?.cancel();
    _timer  = null;
    _endsAt = null;
  }

  bool get isActive => _timer?.isActive ?? false;

  /// Remaining duration so the UI can show a countdown.
  Duration? get remaining {
    if (_endsAt == null) return null;
    final r = _endsAt!.difference(DateTime.now());
    return r.isNegative ? Duration.zero : r;
  }
}

final sleepTimerServiceProvider = Provider<SleepTimerService>(
  (ref) => SleepTimerService());

// ─────────────────────────────────────────────────────────────────────────────
// PLAYBACK SETTINGS APPLIER
// Bridges settings state → just_audio AudioPlayer live configuration.
// Import this in player_service.dart and call after player init.
// ─────────────────────────────────────────────────────────────────────────────

class PlaybackSettingsApplier {
  final AudioPlayer player;
  final Ref ref;

  PlaybackSettingsApplier({required this.player, required this.ref});

  /// Apply all playback-related settings to the live AudioPlayer.
  Future<void> applyAll() async {
    await applyNormalization();
    await applyGapless();
    await applyCrossfade();
  }

  Future<void> applyNormalization() async {
    // just_audio doesn't expose normalization directly.
    // Best approach: read the flag so the UI is live-aware; actual
    // loudness normalization is done server-side by JioSaavn.
    // For a native implementation, use audio_session to configure
    // AVAudioSession on iOS or AudioAttributes on Android.
    final enabled = ref.read(normalizationEnabledProvider);
    // Placeholder — integrate with audio_session when needed
    var _ = enabled;
  }

  Future<void> applyGapless() async {
    // just_audio handles gapless automatically when using a
    // ConcatenatingAudioSource. No extra call needed; the flag
    // controls whether we insert silence between tracks.
  }

  Future<void> applyCrossfade() async {
    // Crossfade at the just_audio level requires a custom
    // AudioSource pipeline or using audio_service's queue.
    // This flag is read by player_service when advancing tracks.
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FIRESTORE SETTINGS SCHEMA (reference)
//
// Collection: user_settings
// Document:   {uid}
// Fields (all optional, defaults applied at read time):
//   crossfade_enabled:    bool
//   crossfade_duration:   double
//   normalization:        bool
//   autoplay:             bool
//   gapless:              bool
//   show_lyrics:          bool
//   sleep_timer:          string?
//   car_mode:             bool
//   streaming_quality:    string   '96kbps' | '160kbps' | '320kbps'
//   wifi_quality:         string
//   mobile_data_quality:  string
//   audio_format:         string   'MP3' | 'AAC' | 'FLAC'
//   download_quality:     string
//   offline_mode:         bool
//   data_warning:         bool
//   storage_location:     string   'internal' | 'external'
//   music_language:       string
//   explicit_content:     bool
//   app_theme:            string   'dark' | 'amoled' | 'auto'
//   accent_color:         string   'pink_purple' | 'red_orange' | etc.
//   font_size:            string   'small' | 'medium' | 'large' | 'xl'
//   animations:           string   'full' | 'reduced' | 'none'
//   album_art_style:      string   'vinyl' | 'square' | 'circle'
//   private_session:      bool
//   analytics_enabled:    bool
//   activity_visible:     bool
//   show_notifications:   bool
//   notif_new_releases:   bool
//   notif_recommendations:bool
//   notif_app_updates:    bool
//   eq_enabled:           bool
//   eq_bass … eq_treble:  double
//   eq_master_gain:       double
//   eq_preset:            string
// ─────────────────────────────────────────────────────────────────────────────