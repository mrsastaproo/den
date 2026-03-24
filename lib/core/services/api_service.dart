import 'dart:math' as math;
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
      {int page = 1, int limit = 20, bool showExplicit = true}) async {
    try {
      final res = await _dio.get('/search/songs',
        queryParameters: {
          'query': query,
          'page':  page,
          'limit': limit,
        });
      final results = res.data['data']?['results'] as List? ?? [];
      final songs = results.map((e) => Song.fromSumitApi(e)).toList();
      if (!showExplicit) return songs.where((s) => !s.isExplicit).toList();
      return songs;
    } catch (e) {
      print('searchSongs error [$query]: $e');
      return [];
    }
  }

  Future<List<Song>> searchBroad(String query, {bool showExplicit = true}) async {
    try {
      final res = await _dio.get('/search',
        queryParameters: {'query': query});
      final songsData =
          res.data['data']?['songs']?['results'] as List? ?? [];
      final songs = songsData.map((e) => Song.fromSumitApi(e)).toList();
      if (!showExplicit) return songs.where((s) => !s.isExplicit).toList();
      return songs;
    } catch (e) {
      return [];
    }
  }

  // ─── CONTENT FEEDS ────────────────────────────────────────────────

  String _getRandomNoise() {
    final noise = ['hits', 'best', 'latest', 'fresh', 'viral', 'top', 'new', 'popular'];
    return noise[math.Random().nextInt(noise.length)];
  }

  Future<List<Song>> getTrending({String language = 'Hindi'}) async {
    final year = DateTime.now().year;
    final lang = language.toLowerCase();
    
    // Choose a random pool on every call for maximum freshness
    final pools = [
      ['trending $lang $_getRandomNoise()', 'top $lang songs $year'],
      ['viral $lang hits', 'popular $lang $_getRandomNoise()'],
      ['top $lang $_getRandomNoise()', '$lang pop viral'],
      ['$lang romance $year', 'non stop $lang hits'],
      ['latest $lang releases', 'india viral $lang hits'],
    ];
    
    final selectedPool = pools[math.Random().nextInt(pools.length)];
    
    return _multiSearch([
      ...selectedPool,
      'top indian $lang songs',
      'trending now $lang',
    ], limitEach: 25);
  }

  Future<List<Song>> getNewReleases({String language = 'Hindi'}) async {
    final year = DateTime.now().year;
    final lang = language.toLowerCase();

    final genrePools = [
      ['new $lang releases $year', 'fresh indie $lang'],
      ['latest $lang hits', 'fresh $lang $_getRandomNoise()'],
      ['fresh $lang pop', 'latest soul $lang'],
      ['new romantic $lang', 'fresh acoustic $lang'],
    ];

    final selectedGenre = genrePools[math.Random().nextInt(genrePools.length)];

    return _multiSearch([
      ...selectedGenre,
      'new songs $lang $year',
      'latest and greatest $lang',
    ], limitEach: 15);
  }

  Future<List<Song>> getTopCharts({String language = 'Hindi'}) async {
    final lang = language.toLowerCase();
    return _multiSearch([
      'top 50 $lang songs',
      '$lang number one charts',
      'trending $lang top songs',
    ], limitEach: 15);
  }


  Future<List<Song>> getThrowback() async {
    final pools = [
      ['bollywood classic 90s', 'kishore kumar hits'],
      ['2000s bollywood hits', 'kk best songs', 'emraan hashmi hits'],
      ['hindi gazals classic', 'jagjit singh best'],
      ['retro bollywood 70s 80s', 'r d burman hits'],
    ];
    // Rotate pool based on the day of the week
    final pool = pools[DateTime.now().weekday % pools.length];
    return _multiSearch(pool, limitEach: 12);
  }

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
      _search('$artistName ${_getRandomNoise()} songs 2025', limit: 15);

  Future<List<Song>> getMoodMix(String mood) async {
    final noise = _getRandomNoise();
    final moodQueries = <String, List<String>>{
      'Happy':  ['happy hollywood $noise', 'fun upbeat hindi'],
      'Sad':    ['sad hindi $noise', 'heartbreak bollywood'],
      'Hype':   ['party dance $noise', 'dj remix bollywood'],
      'Chill':  ['chill lofi $noise', 'calm soft bollywood'],
      'Focus':  ['instrumental $noise', 'focus study music hindi'],
      'Love':   ['romantic love $noise', 'bollywood love 2025'],
    };
    return _multiSearch(moodQueries[mood] ?? ['$mood $noise hindi'],
        limitEach: 12);
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

  Future<String> getStreamUrl(String songId, {String quality = '320kbps'}) async {
    // Quality-specific cache key to avoid returning wrong quality from cache
    final cacheKey = '${songId}_$quality';
    
    // Return cached URL immediately if available
    if (_urlCache.containsKey(cacheKey)) {
      _log('URL cache hit: $cacheKey');
      return _urlCache[cacheKey]!;
    }

    // Try up to 2 times (handles Render.com cold start timeout)
    for (int attempt = 1; attempt <= 2; attempt++) {
      try {
        _log('getStreamUrl attempt $attempt for $songId ($quality)');
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

        // Find the URL that matches the requested quality
        // downloadUrl objects look like: { "quality": "320kbps", "url": "..." }
        final best = downloadUrls.firstWhere(
          (u) => u['quality'] == quality,
          orElse: () => downloadUrls.last, // Fallback to highest available if requested not found
        );

        final url = best['url'] as String? ?? '';
        if (url.isEmpty) continue;

        // Cache it for instant re-play
        _urlCache[cacheKey] = url;
        _log('getStreamUrl success for $songId ($quality)');
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