import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsService {
  static const _streamKey = 'streaming_quality';
  static const _downloadKey = 'download_quality';
  static const _languageKey = 'music_language';
  static const _themeKey = 'accent_color';

  Future<void> setStreamingQuality(String quality) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_streamKey, quality);
  }

  Future<String> getStreamingQuality() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_streamKey) ?? '320kbps';
  }

  Future<void> setDownloadQuality(String quality) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_downloadKey, quality);
  }

  Future<String> getDownloadQuality() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_downloadKey) ?? '320kbps';
  }

  Future<void> setMusicLanguage(String language) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, language);
  }

  Future<String> getMusicLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_languageKey) ?? 'Hindi + English';
  }

  Future<void> setAccentColor(String color) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, color);
  }

  Future<String> getAccentColor() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_themeKey) ?? 'Pink + Purple';
  }
}

final settingsServiceProvider = Provider<SettingsService>(
  (ref) => SettingsService());

// Persisted providers
final streamingQualityProvider =
  StateNotifierProvider<QualityNotifier, String>(
    (ref) => QualityNotifier('streaming'));

final downloadQualityProvider =
  StateNotifierProvider<QualityNotifier, String>(
    (ref) => QualityNotifier('download'));

final musicLanguageProvider =
  StateNotifierProvider<LanguageNotifier, String>(
    (ref) => LanguageNotifier());

class QualityNotifier extends StateNotifier<String> {
  final String type;

  QualityNotifier(this.type) : super('320kbps') {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final key = type == 'streaming'
      ? 'streaming_quality' : 'download_quality';
    state = prefs.getString(key) ?? '320kbps';
  }

  Future<void> set(String quality) async {
    state = quality;
    final prefs = await SharedPreferences.getInstance();
    final key = type == 'streaming'
      ? 'streaming_quality' : 'download_quality';
    await prefs.setString(key, quality);
  }
}

class LanguageNotifier extends StateNotifier<String> {
  LanguageNotifier() : super('Hindi + English') {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString('music_language') ?? 'Hindi + English';
  }

  Future<void> set(String language) async {
    state = language;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('music_language', language);
  }
}