import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/song.dart';

class ApiService {
  static const String baseUrl =
    'https://jiosaavn-api-angv.onrender.com/api';

  // ── Primary client — generous timeouts for Render.com cold start ──
  // Render free tier can take 30-60s on cold start. We give it 45s.
  final Dio _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 45),
    receiveTimeout: const Duration(seconds: 45),
  ));

  // ── Stream URL cache ──────────────────────────────────────────────
  // Caches resolved URLs so re-playing the same song is instant.
  // Key: songId  Value: url
  final Map<String, String> _urlCache = {};

  // ─── HELPER ───────────────────────────────────────────────────────

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

  // ─── SEARCH ───────────────────────────────────────────────────────

  Future<List<Song>> searchSongs(String query,
      {int page = 1, int limit = 20}) async {
    try {
      final res = await _dio.get('/search/songs',
        queryParameters: {
          'query': query,
          'page':  page,
          'limit': limit,
        });
      final results = res.data['data']?['results'] as List? ?? [];
      return results.map((e) => Song.fromSumitApi(e)).toList();
    } catch (e) {
      print('searchSongs error [$query]: $e');
      return [];
    }
  }

  Future<List<Song>> searchBroad(String query) async {
    try {
      final res = await _dio.get('/search',
        queryParameters: {'query': query});
      final songsData =
          res.data['data']?['songs']?['results'] as List? ?? [];
      return songsData.map((e) => Song.fromSumitApi(e)).toList();
    } catch (e) {
      return [];
    }
  }

  // ─── CONTENT FEEDS ────────────────────────────────────────────────

  Future<List<Song>> getTrending() async => _multiSearch([
    'top hindi songs 2025', 'trending bollywood march 2025',
  ], limitEach: 15);

  Future<List<Song>> getNewReleases() async => _multiSearch([
    'new hindi songs 2025', 'latest bollywood 2025',
  ], limitEach: 5);

  Future<List<Song>> getTopCharts() async => _multiSearch([
    'top charts hindi 2025', 'bollywood hits number one 2025',
  ], limitEach: 10);

  Future<List<Song>> getThrowback() async => _multiSearch([
    'hindi classic songs 2000s hits', 'bollywood 90s best songs',
  ], limitEach: 8);

  Future<List<Song>> getTimeBased() async {
    final hour = DateTime.now().hour;
    List<String> queries;
    if (hour >= 5 && hour < 12) {
      queries = ['happy bollywood songs', 'upbeat hindi songs 2025',
        'good morning hindi songs', 'energetic bollywood hits'];
    } else if (hour >= 12 && hour < 17) {
      queries = ['top hindi songs 2025', 'bollywood hits playlist',
        'popular hindi songs', 'best bollywood 2024'];
    } else if (hour >= 17 && hour < 21) {
      queries = ['romantic hindi songs', 'bollywood love songs',
        'evening hindi hits', 'soft hindi songs 2025'];
    } else {
      queries = ['sad hindi songs', 'chill hindi songs night',
        'late night bollywood', 'slow hindi songs 2025'];
    }
    return _multiSearch(queries, limitEach: 12);
  }

  Future<List<Song>> getArtistSongs(String artistName) async =>
      _search('$artistName latest songs 2025', limit: 10);

  Future<List<Song>> getMoodMix(String mood) async {
    final moodQueries = <String, List<String>>{
      'Happy':  ['happy bollywood songs', 'fun upbeat hindi'],
      'Sad':    ['sad hindi songs', 'heartbreak bollywood'],
      'Hype':   ['party dance hindi songs', 'dj remix bollywood'],
      'Chill':  ['chill lofi hindi', 'calm soft bollywood'],
      'Focus':  ['instrumental hindi', 'focus study music hindi'],
      'Love':   ['romantic love songs hindi', 'bollywood love 2025'],
    };
    return _multiSearch(moodQueries[mood] ?? ['$mood hindi songs'],
        limitEach: 8);
  }

  Future<List<Song>> getRecommendations(Song current) async =>
      _multiSearch([
        '${current.artist} latest songs',
        'best ${current.language} songs 2025',
        'similar to ${current.title} ${current.artist}',
      ], limitEach: 6);

  // ─── STREAM URL ───────────────────────────────────────────────────
  //
  // KEY FIX: Render.com free tier has 30-60s cold start delays.
  // We cache resolved URLs so skipping back to a song is instant.
  // We also retry once on failure before giving up.

  Future<String> getStreamUrl(String songId) async {
    // Return cached URL immediately if available
    if (_urlCache.containsKey(songId)) {
      _log('URL cache hit: $songId');
      return _urlCache[songId]!;
    }

    // Try up to 2 times (handles Render.com cold start timeout)
    for (int attempt = 1; attempt <= 2; attempt++) {
      try {
        _log('getStreamUrl attempt $attempt for $songId');
        final res = await _dio.get('/songs',
          queryParameters: {'ids': songId});

        final data = res.data['data'] as List?;
        if (data == null || data.isEmpty) {
          _log('getStreamUrl: empty data for $songId');
          continue;
        }

        final song          = data[0];
        final downloadUrls  = song['downloadUrl'] as List?;
        if (downloadUrls == null || downloadUrls.isEmpty) {
          _log('getStreamUrl: no downloadUrl for $songId');
          continue;
        }

        // Prefer 320kbps, fall back to highest available
        final best = downloadUrls.lastWhere(
          (u) => u['quality'] == '320kbps',
          orElse: () => downloadUrls.last,
        );

        final url = best['url'] as String? ?? '';
        if (url.isEmpty) continue;

        // Cache it for instant re-play
        _urlCache[songId] = url;
        _log('getStreamUrl success for $songId');
        return url;

      } on DioException catch (e) {
        _log('getStreamUrl attempt $attempt failed: ${e.type} — ${e.message}');
        if (attempt < 2) {
          // Wait 1s before retry (gives Render cold start a chance)
          await Future.delayed(const Duration(seconds: 1));
        }
      } catch (e) {
        _log('getStreamUrl unexpected error: $e');
        break;
      }
    }

    _log('getStreamUrl failed for $songId after retries');
    return '';
  }

  // Warm up the server — call this on app start so Render.com
  // has time to wake up before user presses play.
  Future<void> warmUp() async {
    try {
      await _dio.get('/search/songs',
        queryParameters: {'query': 'arijit singh', 'limit': 1});
      _log('API warmed up');
    } catch (_) {}
  }
}

void _log(String msg) => print('[API] $msg');

final apiServiceProvider = Provider<ApiService>((ref) => ApiService());