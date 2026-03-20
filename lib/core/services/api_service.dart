import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/song.dart';

class ApiService {
  static const String baseUrl =
    'https://jiosaavn-api-angv.onrender.com/api';

  final Dio _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
  ));

  // ─── HELPER ───────────────────────────────────────
  Future<List<Song>> _search(String query, {int limit = 20}) async {
    try {
      final res = await _dio.get('/search/songs',
        queryParameters: {'query': query, 'limit': limit});
      final results = res.data['data']['results'] as List? ?? [];
      return results.map((e) => Song.fromSumitApi(e)).toList();
    } catch (e) {
      print('Search error [$query]: $e');
      return [];
    }
  }

  Future<List<Song>> _multiSearch(List<String> queries,
      {int limitEach = 10}) async {
    try {
      final futures = queries.map((q) => _search(q, limit: limitEach));
      final results = await Future.wait(futures);
      final songs = results.expand((s) => s).toList();
      final seen = <String>{};
      return songs.where((s) => seen.add(s.id)).toList();
    } catch (e) {
      return [];
    }
  }

  // ─── SEARCH ───────────────────────────────────────
  Future<List<Song>> searchSongs(String query,
      {int page = 1}) async {
    try {
      final res = await _dio.get('/search/songs',
        queryParameters: {
          'query': query, 'page': page, 'limit': 20});
      final results = res.data['data']['results'] as List? ?? [];
      return results.map((e) => Song.fromSumitApi(e)).toList();
    } catch (e) {
      return [];
    }
  }

  // ─── TRENDING ─────────────────────────────────────
  Future<List<Song>> getTrending() async {
    return _multiSearch([
      'top hindi songs 2025',
      'trending bollywood march 2025',
    ], limitEach: 15);
  }

  // ─── NEW RELEASES ─────────────────────────────────
  Future<List<Song>> getNewReleases() async {
    return _multiSearch([
      'new hindi songs 2025',
      'latest bollywood 2025',
    ], limitEach: 5);
  }

  // ─── TOP CHARTS ───────────────────────────────────
  Future<List<Song>> getTopCharts() async {
    return _multiSearch([
      'top charts hindi 2025',
      'bollywood hits number one 2025',
    ], limitEach: 10);
  }

  // ─── THROWBACK ────────────────────────────────────
  Future<List<Song>> getThrowback() async {
    return _multiSearch([
      'hindi classic songs 2000s hits',
      'bollywood 90s best songs',
    ], limitEach: 8);
  }

  // ─── TIME BASED ───────────────────────────────────
  Future<List<Song>> getTimeBased() async {
    final hour = DateTime.now().hour;
    List<String> queries;

    if (hour >= 5 && hour < 12) {
      queries = ['morning fresh hindi songs',
        'happy energetic bollywood morning'];
    } else if (hour >= 12 && hour < 17) {
      queries = ['afternoon bollywood hits',
        'energetic hindi songs afternoon'];
    } else if (hour >= 17 && hour < 21) {
      queries = ['evening romantic hindi songs',
        'sunset bollywood romantic'];
    } else {
      queries = ['night chill hindi songs',
        'late night sad bollywood'];
    }
    return _multiSearch(queries, limitEach: 8);
  }

  // ─── ARTIST SPOTLIGHT ─────────────────────────────
  Future<List<Song>> getArtistSongs(String artistName) async {
    return _search('$artistName latest songs 2025', limit: 10);
  }

  // ─── MOOD MIX ─────────────────────────────────────
  Future<List<Song>> getMoodMix(String mood) async {
    final Map<String, List<String>> moodQueries = {
      'Happy': ['happy bollywood songs', 'fun upbeat hindi'],
      'Sad': ['sad hindi songs', 'heartbreak bollywood'],
      'Hype': ['party dance hindi songs', 'dj remix bollywood'],
      'Chill': ['chill lofi hindi', 'calm soft bollywood'],
      'Focus': ['instrumental hindi', 'focus study music hindi'],
      'Love': ['romantic love songs hindi', 'bollywood love 2025'],
    };
    final queries = moodQueries[mood] ??
      ['$mood hindi songs'];
    return _multiSearch(queries, limitEach: 8);
  }

  // ─── STREAM URL ───────────────────────────────────
  Future<String> getStreamUrl(String songId) async {
    try {
      final res = await _dio.get('/songs',
        queryParameters: {'ids': songId});
      final data = res.data['data'] as List?;
      if (data == null || data.isEmpty) return '';
      final song = data[0];
      final downloadUrls = song['downloadUrl'] as List?;
      if (downloadUrls == null || downloadUrls.isEmpty) return '';
      final best = downloadUrls.lastWhere(
        (u) => u['quality'] == '320kbps',
        orElse: () => downloadUrls.last);
      return best['url'] ?? '';
    } catch (e) {
      return '';
    }
  }
}

final apiServiceProvider = Provider<ApiService>((ref) => ApiService());