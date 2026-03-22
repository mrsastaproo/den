import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/song.dart';

class LyricLine {
  final Duration time;
  final String text;
  LyricLine(this.time, this.text);
}

class LyricsService {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  Future<List<LyricLine>> fetchLyrics(Song song) async {
    try {
      // 1. Try exact match first
      final url = 'https://lrclib.net/api/get?artist=${Uri.encodeComponent(song.artist)}&track=${Uri.encodeComponent(song.title)}';
      print('[LyricsService] Fetching exact: $url');

      try {
        final response = await _dio.get(url);
        if (response.statusCode == 200) {
          final data = response.data;
          final synced = data['syncedLyrics'] as String?;
          if (synced != null && synced.isNotEmpty) {
            final parsed = _parseLrc(synced);
            if (parsed.isNotEmpty) return parsed;
          }
          final plain = data['plainLyrics'] as String?;
          if (plain != null && plain.isNotEmpty) {
            return plain
                .split('\n')
                .where((l) => l.trim().isNotEmpty)
                .map((l) => LyricLine(Duration.zero, l.trim()))
                .toList();
          }
        }
      } catch (_) {
        print('[LyricsService] Exact match failed, trying search...');
      }

      // 2. Fallback to fuzzy search query
      final query = '${song.artist} ${song.title}';
      final searchUrl = 'https://lrclib.net/api/search?q=${Uri.encodeComponent(query)}';
      print('[LyricsService] Searching: $searchUrl');

      final searchResponse = await _dio.get(searchUrl);
      if (searchResponse.statusCode == 200) {
        final List<dynamic> results = searchResponse.data;
        if (results.isNotEmpty) {
          for (final item in results) {
            final synced = item['syncedLyrics'] as String?;
            if (synced != null && synced.isNotEmpty) {
              final parsed = _parseLrc(synced);
              if (parsed.isNotEmpty) return parsed;
            }
            final plain = item['plainLyrics'] as String?;
            if (plain != null && plain.isNotEmpty) {
              return plain
                  .split('\n')
                  .where((l) => l.trim().isNotEmpty)
                  .map((l) => LyricLine(Duration.zero, l.trim()))
                  .toList();
            }
          }
        }
      }
    } catch (e) {
      print('[LyricsService] Error fetching lyrics: $e');
    }
    return [];
  }

  List<LyricLine> _parseLrc(String lrc) {
    final lines = lrc.split('\n');
    final parsed = <LyricLine>[];
    final regExp = RegExp(r'^\[(\d+):(\d+(?:\.\d+)?)\]\s*(.*)$');

    for (final line in lines) {
      final match = regExp.firstMatch(line.trim());
      if (match != null) {
        final minutes = int.parse(match.group(1)!);
        final seconds = double.parse(match.group(2)!);
        final text = match.group(3)!;
        
        final duration = Duration(
          minutes: minutes,
          seconds: seconds.truncate(),
          milliseconds: ((seconds - seconds.truncate()) * 1000).round(),
        );
        parsed.add(LyricLine(duration, text));
      }
    }
    return parsed;
  }
}

final lyricsServiceProvider = Provider<LyricsService>((ref) {
  return LyricsService();
});

final lyricsProvider = FutureProvider.family<List<LyricLine>, Song>((ref, song) {
  return ref.watch(lyricsServiceProvider).fetchLyrics(song);
});
