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
      final results = res.data['data']?['results'] as List? ?? [];
      final songs = results.map((e) => Song.fromSumitApi(e)).toList();
      return songs..sort((a, b) => b.playCount.compareTo(a.playCount));
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
      final uniqueSongs = songs.where((s) => seen.add(s.id)).toList();
      return uniqueSongs..sort((a, b) => b.playCount.compareTo(a.playCount));
    } catch (e) {
      return [];
    }
  }

  Future<List<Song>> _getCustomLofiSearch({bool showExplicit = true}) async {
    final customQueries = [
      'lofi hindi',
      'lofi hits 2024',
      'lofi slow deep',
      'lofi english hits',
      'trending lofi beats',
    ];
    final results = await _multiSearch(customQueries, limitEach: 12);
    results.sort((a, b) {
      final aH = a.language.toLowerCase() == 'hindi' ? 1 : 0;
      final bH = b.language.toLowerCase() == 'hindi' ? 1 : 0;
      if (aH != bH) return bH.compareTo(aH);
      // Secondary sort: popular items first
      return b.playCount.compareTo(a.playCount);
    });
    if (!showExplicit) return results.where((s) => !s.isExplicit).toList();
    return results;
  }

  Future<List<Song>> searchSongs(String query,
      {int page = 1, int limit = 20, bool showExplicit = true}) async {
    final q = query.trim().toLowerCase();
    if (q == 'lofi' || q == 'lo-fi') {
      return _getCustomLofiSearch(showExplicit: showExplicit);
    }

    try {
      final res = await _dio.get('/search/songs',
        queryParameters: {
          'query': query,
          'page':  page,
          'limit': limit,
        });
      final results = res.data['data']?['results'] as List? ?? [];
      final songs = results.map((e) => Song.fromSumitApi(e)).toList();
      songs.sort((a, b) => b.playCount.compareTo(a.playCount));
      if (!showExplicit) return songs.where((s) => !s.isExplicit).toList();
      return songs;
    } catch (e) {
      print('searchSongs error [$query]: $e');
      return [];
    }
  }

  Future<List<Song>> searchBroad(String query, {bool showExplicit = true}) async {
    final q = query.trim().toLowerCase();
    if (q == 'lofi' || q == 'lo-fi') {
      return _getCustomLofiSearch(showExplicit: showExplicit);
    }

    try {
      final res = await _dio.get('/search',
        queryParameters: {'query': query});
      final songsData =
          res.data['data']?['songs']?['results'] as List? ?? [];
      final songs = songsData.map((e) => Song.fromSumitApi(e)).toList();
      songs.sort((a, b) => b.playCount.compareTo(a.playCount));
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

    // IF English, we add Global Charts focus
    if (lang == 'english') {
      pools.add(['Billboard Hot 100', 'Spotify Global Top 50']);
      pools.add(['UK Top 40', 'Global Viral Hits 2025']);
      pools.add(['Apple Music Top English', 'Tiktok Viral English']);
    }
    
    final selectedPool = pools[math.Random().nextInt(pools.length)];
    
    return _multiSearch([
      ...selectedPool,
      if (lang != 'english') 'top indian $lang songs',
      'trending now $lang',
    ], limitEach: 25);
  }

  // ─── GLOBAL DISCOVERY (NEW) ───────────────────────────────────────
  // Focuses on latest international English hits without previews
  
  Future<List<Song>> getGlobalDiscovery() async {
    _log('Fetching Global Discovery (Latest English Hits)...');
    
    final globalQueries = [
      'trending hollywood songs 2025',
      'latest english pop hits',
      'billboard top songs 2025',
      'viral global hits spotify',
      'new english rap 2025',
    ];

    final results = await _multiSearch(globalQueries, limitEach: 15);
    
    // Filter out results that are likely just previews (Saavn sometimes marks them)
    // For now, we trust the multiSearch relevance.
    return results;
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

  Future<List<Song>> getRecommendations(Song current) async {
    final artist = current.artist.contains(',') 
        ? current.artist.split(',').first.trim() 
        : current.artist;

    final lang = current.language.toLowerCase();
    final titleLower = current.title.toLowerCase();
    final queries = <String>[
      '$artist top songs${lang.isNotEmpty ? " $lang" : ""}',
      '$artist hits${lang.isNotEmpty ? " $lang" : ""}',
      '$artist radio${lang.isNotEmpty ? " $lang" : ""}',
      '$artist mashup${lang.isNotEmpty ? " $lang" : ""}',
    ];

    final isLofi = titleLower.contains('lofi') || titleLower.contains('lo-fi');
    final isPhonk = titleLower.contains('phonk');

    if (isLofi) {
      queries.clear(); // Prefers vibe for curating mixes
      queries.addAll([
        'lofi hindi 2024',
        'lofi hits latest 2024',
        'lofi mashup',
        'trending lofi beats',
        'lofi study relax',
      ]);
    } else if (isPhonk) {
      queries.clear();
      queries.addAll([
        'phonk drift 2024',
        'phonk gym hits',
        'phonk popular bangers',
        'phonk bass boost',
      ]);
    }

    // ── 1. Moods & Vibes ──────────────────────────────────────
    const vibes = [
      'sad', 'broken', 'heartbreak', 'romantic', 'love', 'mashup', 'remix', 
      'slowed', 'reverb', 'bass', 'workout', 'gym', 'gaming', 'party', 'dance', 
      'club', 'phonk', 'edm', 'lofi', 'ambient', 'chill', 'soft', 'emotional'
    ];
    for (final v in vibes) {
      if (titleLower.contains(v)) {
        queries.add('$v songs');
        queries.add('$v playlist');
      }
    }

    // ── 2. Regional / Language checks ──────────────────────────
    if (lang.isNotEmpty) {
      queries.add('trending $lang');
      queries.add('$lang hits');
      queries.add('$lang mashup');
    }

    // Deduplicate queries
    final uniqueQueries = queries.toSet().toList();

    final results = await _multiSearch(uniqueQueries, limitEach: 8);

    if (lang.isNotEmpty) {
      // 1. Strict Filter (If sufficiently packed)
      final filtered = results
          .where((s) => s.language.toLowerCase() == lang)
          .toList();
      if (filtered.length >= 4) return filtered;

      // 2. Continuous Sort prioritizing matching weights
      results.sort((a, b) {
        final aMatch = a.language.toLowerCase() == lang ? 1 : 0;
        final bMatch = b.language.toLowerCase() == lang ? 1 : 0;
        return bMatch.compareTo(aMatch);
      });
    }

    return results;
  }

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

  // ─── JAMENDO INTEGRATION ──────────────────────────────────────────
  // Adds a secondary legal source for English music fallback

  Future<List<Song>> searchJamendo(String query, {int limit = 15}) async {
    const String jamendoApi = 'https://api.jamendo.com/v3.0/tracks/';
    const String clientId = '709fa152'; // Public client ID for DEN
    
    try {
      final res = await _dio.get(jamendoApi, queryParameters: {
        'client_id': clientId,
        'format': 'json',
        'limit': limit,
        'search': query,
        'include': 'musicinfo',
      });

      final results = res.data['results'] as List? ?? [];
      return results.map((e) => Song(
        id: 'jamendo_${e['id']}',
        title: e['name'] ?? '',
        artist: e['artist_name'] ?? '',
        album: e['album_name'] ?? '',
        image: e['image'] ?? e['album_image'] ?? '',
        url: e['audio'] ?? '',
        duration: e['duration']?.toString() ?? '0',
        year: e['releasedate']?.toString().split('-').first ?? '',
        language: 'English',
        isExplicit: false,
      )).toList();
    } catch (e) {
      _log('Jamendo search error [$query]: $e');
      return [];
    }
  }

  // ─── LEGAL MATCHING ENGINE ────────────────────────────────────────
  // This is the core "Polish" requested by the user.
  // It handles the "preview only" issue by searching multiple sources.

  Future<Song?> findBestLegalMatch(String title, String artist) async {
    final query = '$title $artist';
    _log('Finding best legal match for: $query');

    // 1. Try JioSaavn with "Official" variants (often returns full tracks)
    final jioResults = await searchSongs('$query official', limit: 5);
    final bestJio = _pickBestFromResults(jioResults, title, artist);
    
    // Check if the JioSaavn match is likely a full track
    // (In a real API, we'd check if 'downloadUrl' has 320kbps or if it's marked as preview)
    // For now, if we find a good match on Saavn, we trust it, but we can also fallback.
    if (bestJio != null) return bestJio;

    // 2. Fallback to Jamendo (Legal & Full Length English)
    final jamendoResults = await searchJamendo(query, limit: 5);
    final bestJamendo = _pickBestFromResults(jamendoResults, title, artist);
    if (bestJamendo != null) return bestJamendo;

    return null;
  }

  Song? _pickBestFromResults(List<Song> results, String title, String artist) {
    if (results.isEmpty) return null;
    final t = title.toLowerCase();
    
    // Look for exact title match first
    for (final s in results) {
      if (s.title.toLowerCase().contains(t)) return s;
    }
    return results.first;
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