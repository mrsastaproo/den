import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/song.dart';

class ApiService {
  // JioSaavn API — using working Vercel-hosted mirror
  // (saavn.dev is dead as of April 2026)
  static const String baseUrl = 'https://jiosaavn-api-privatecvc2.vercel.app';

  // ── Primary client ──
  final Dio _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {'Accept': 'application/json'},
  ));

  // ── Cache ────────────────────────────────────────────────────────
  // Caches search results and stream URLs for instant retrieval
  final Map<String, List<Song>> _searchCache = {};
  final Map<String, String> _urlCache = {};

  // ─── HELPER ───────────────────────────────────────────────────────

  Future<List<Song>> _search(String query, {int limit = 20}) async {
    final cacheKey = '$query|$limit';
    if (_searchCache.containsKey(cacheKey)) return _searchCache[cacheKey]!;

    try {
      final res = await _dio.get('/search/songs',
        queryParameters: {'query': query, 'limit': limit});
      
      // Robust data extraction
      final dynamic rawData = res.data is Map ? (res.data['data'] ?? res.data) : res.data;
      final List results = (rawData is Map ? (rawData['results'] ?? []) : (rawData is List ? rawData : []));
      
      final songs = results.map((e) => Song.fromSumitApi(e)).toList();
      songs.sort((a, b) => b.playCount.compareTo(a.playCount));
      _searchCache[cacheKey] = songs;
      return songs;
    } catch (e) {
      print('Search error [$query]: $e');
      return [];
    }
  }

  Future<List<Song>> _multiSearch(List<String> queries,
      {int limitEach = 10}) async {
    try {
      final List<List<Song>> results = [];
      for (final q in queries) {
        // Use a short timeout per sub-query to prevent one slow query from blocking everything
        try {
          final s = await _search(q, limit: limitEach).timeout(const Duration(seconds: 4));
          results.add(s);
        } catch (_) {}
        // Small delay to prevent hitting the server too fast
        await Future.delayed(const Duration(milliseconds: 150));
      }
      
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

  // ─── SMART RELEVANCE SCORER ───────────────────────────────────────
  // Multi-factor scoring that puts the real/popular version on top.
  // Higher score = better match.
  int _relevanceScore(Song song, String rawQuery) {
    final query = rawQuery.trim().toLowerCase();
    final tokens = query.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    final title  = song.title.toLowerCase();
    final artist = song.artist.toLowerCase();
    final album  = song.album.toLowerCase();
    int score = 0;

    // ── 1. EXACT TITLE MATCH (highest weight) ──────────────────────
    if (title == query) score += 600;
    else if (title.startsWith(query)) score += 400;
    else if (title.contains(query)) score += 260;
    else {
      // Partial token matches
      final matched = tokens.where((t) => title.contains(t)).length;
      score += matched * 60;
    }

    // ── 2. ARTIST MATCH ────────────────────────────────────────────
    if (tokens.any((t) => artist.contains(t))) score += 180;
    if (tokens.any((t) => album.contains(t))) score += 60;

    // ── 3. PENALISE FAKE / COVER / KARAOKE / TRIBUTE VERSIONS ─────
    final fakePhrases = [
      'cover', 'karaoke', 'tribute', 'remake', 'recreation',
      'unplugged version', 'piano version', 'lofi version',
      'instrumental version', 'reprise', 'female version',
      'male version', 'slowed', 'reverb', 'mashup', 'remix version',
      'originally', 'recreated', 'recreation by', 'imitation',
      'unofficial', 'hindi version', 'english version', 'dj version',
    ];
    for (final phrase in fakePhrases) {
      if (title.contains(phrase) || artist.contains(phrase)) {
        score -= 400;
        break;
      }
    }

    // Allow "remix" if user explicitly searched for it
    if (title.contains('remix') && !query.contains('remix')) score -= 250;

    // ── 4. TITLE LENGTH PENALTY (shorter = more likely original) ──
    // A song titled "Bandook 2 (Cover by XYZ)" is much longer
    // than the original "Bandook 2".
    final expectedLen = query.length;
    final excess = (title.length - expectedLen - 4).clamp(0, 999);
    score -= (excess * 1.2).toInt();

    // ── 5. PLAY COUNT (popularity signal) ──────────────────────────
    // Log-scale so 10M plays vs 1M plays is meaningful but
    // doesn't drown out relevance.
    if (song.playCount > 0) {
      score += (math.log(song.playCount + 1) * 18).toInt();
    }

    // ── 6. YEAR RECENCY BONUS (newer = likely original on charts) ─
    final year = int.tryParse(song.year) ?? 0;
    if (year >= 2023) score += 30;
    else if (year >= 2020) score += 15;

    return score;
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

      // Smart ranking: relevance score descending
      songs.sort((a, b) =>
          _relevanceScore(b, query).compareTo(_relevanceScore(a, query)));

      if (!showExplicit) return songs.where((s) => !s.isExplicit).toList();
      return songs;
    } catch (e) {
      print('searchSongs error [$query]: $e');
      return [];
    }
  }

  // ─── SEARCH BROAD ─────────────────────────────────────────────────

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

  // ─── HOME MODULES (OPTIMIZED) ──────────────────────────────────
  // Uses /modules for trending songs + new album/song items.
  // Charts in this API are playlist references (no embedded songs),
  // so we always use search fallback for charts.
  Future<Map<String, List<Song>>> getHomeData({String language = 'Hindi'}) async {
    try {
      final langs = language.toLowerCase().split(RegExp(r'[+,&]')).map((e) => e.trim()).join(',');
      _log('Fetching Home Modules for languages: $langs');
      
      final res = await _dio.get('/modules', queryParameters: {'language': langs}).timeout(const Duration(seconds: 12));
      final data = res.data['data'] ?? res.data ?? {};
      
      final Map<String, List<Song>> result = {
        'trending': [],
        'charts': [],
        'new_releases': [],
      };
      
      // 1. Trending — data['trending']['songs'] contains actual song objects
      final trendingObj = data['trending'];
      if (trendingObj is Map) {
        final List songs = trendingObj['songs'] ?? [];
        for (final s in songs) {
          if (s is Map) {
            try { result['trending']!.add(Song.fromSumitApi(s as Map<String, dynamic>)); } catch (_) {}
          }
        }
        // Also grab trending albums as songs (they have song metadata)
        final List albums = trendingObj['albums'] ?? [];
        for (final a in albums) {
          if (a is Map && a['type'] != 'album') {
            try { result['trending']!.add(Song.fromSumitApi(a as Map<String, dynamic>)); } catch (_) {}
          }
        }
      }
      
      // 2. New Releases — data['albums'] are individual song/album items
      //    In this API, each item has type:'song' with songs:[] (empty).
      //    The item itself IS the song data.
      final List albumsData = data['albums'] is List ? data['albums'] : [];
      for (final item in albumsData) {
        if (item is Map) {
          try {
            final song = Song.fromSumitApi(item as Map<String, dynamic>);
            if (song.title.isNotEmpty && song.title != 'Unknown') {
              result['new_releases']!.add(song);
            }
          } catch (_) {}
        }
      }

      // 3. Charts — the API only returns playlist references (id + title),
      //    NOT actual songs. So we always fill charts via search.
      result['charts'] = await getTopCharts(language: language);

      // Fill trending via search if modules returned too few
      if (result['trending']!.length < 5) {
        _log('Trending has only ${result['trending']!.length} songs — supplementing with search');
        final extra = await getTrending(language: language);
        final seen = result['trending']!.map((s) => s.id).toSet();
        result['trending']!.addAll(extra.where((s) => !seen.contains(s.id)));
      }
      
      _log('Home data loaded: trending=${result['trending']!.length}, new_releases=${result['new_releases']!.length}, charts=${result['charts']!.length}');
      return result;
    } catch (e) {
      _log('Home Data Error: $e — using search fallback');
      return {
        'trending': await getTrending(language: language),
        'charts': await getTopCharts(language: language),
        'new_releases': await getNewReleases(language: language),
      };
    }
  }

  Future<List<Song>> getTrending({String language = 'Hindi'}) async {
    final langs = language.toLowerCase().split(RegExp(r'[+,&]')).map((e) => e.trim()).toList();
    final queries = langs.map((l) => 'trending $l').toList();
    return _multiSearch(queries, limitEach: 15);
  }

  Future<List<Song>> getNewReleases({String language = 'Hindi'}) async {
    final langs = language.toLowerCase().split(RegExp(r'[+,&]')).map((e) => e.trim()).toList();
    final queries = langs.map((l) => 'latest $l hits').toList();
    return _multiSearch(queries, limitEach: 15);
  }

  Future<List<Song>> getTopCharts({String language = 'Hindi'}) async {
    final langs = language.toLowerCase().split(RegExp(r'[+,&]')).map((e) => e.trim()).toList();
    final queries = langs.map((l) => 'top 50 $l songs').toList();
    return _multiSearch(queries, limitEach: 15);
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
    
    // ── 1. Strategy: Artist Radio & Similar Vibe ─────────────
    final queries = <String>[
      '$artist radio',
      '$artist mix',
      '$artist top songs',
      'songs similar to ${current.title}',
    ];

    // ── 2. Specialized Vibes ─────────────────────────────────
    final isLofi = titleLower.contains('lofi') || titleLower.contains('lo-fi');
    final isPhonk = titleLower.contains('phonk');
    final isDevotional = titleLower.contains('bhajan') || 
                        titleLower.contains('chalisa') || 
                        titleLower.contains('aarti') ||
                        titleLower.contains('mantra');

    if (isLofi) {
      queries.addAll(['lofi hindi', 'lofi english hits', 'trending lofi beats']);
    } else if (isPhonk) {
      queries.addAll(['phonk drift', 'phonk gym hits', 'phonk bass boost']);
    } else if (isDevotional) {
      queries.addAll(['$artist bhajan', 'popular $lang devotional', 'morning bhaktisongs']);
    }

    // ── 3. Genre/Mood keywords ───────────────────────────────
    const moods = ['sad', 'romantic', 'party', 'dance', 'gym', 'workout', 'chill', 'acoustic'];
    for (final m in moods) {
      if (titleLower.contains(m)) {
        queries.add('$m $lang hits');
      }
    }

    // ── 4. Language-specific Radio ──────────────────────────
    if (lang.isNotEmpty && lang != 'unknown') {
      queries.add('top $lang hits 2025');
      queries.add('$lang viral songs');
    }

    // Deduplicate and limit queries to keep it fast
    final uniqueQueries = queries.toSet().toList().take(6).toList();
    final results = await _multiSearch(uniqueQueries, limitEach: 6);

    // ── 5. VIBE FILTERING (The most important part) ───────────
    // Filter out results that don't match the language or general vibe
    
    final filtered = results.where((s) {
      // a) Language Lock: English songs should only suggest English songs
      if (lang == 'english' && s.language.toLowerCase() != 'english') return false;
      
      // b) Devotional Lock: If current isn't devotional, don't suggest devotional
      final sTitle = s.title.toLowerCase();
      final isSDevotional = sTitle.contains('bhajan') || sTitle.contains('chalisa') || sTitle.contains('mantra');
      if (!isDevotional && isSDevotional) return false;
      
      return true;
    }).toList();

    // ── 6. RANKING ───────────────────────────────────────────
    filtered.sort((a, b) {
      // Priority 1: Match Artist (exact check)
      final aArtistMatch = a.artist.contains(artist) ? 1 : 0;
      final bArtistMatch = b.artist.contains(artist) ? 1 : 0;
      if (aArtistMatch != bArtistMatch) return bArtistMatch.compareTo(aArtistMatch);

      // Priority 2: Language Match
      final aLangMatch = a.language.toLowerCase() == lang ? 1 : 0;
      final bLangMatch = b.language.toLowerCase() == lang ? 1 : 0;
      if (aLangMatch != bLangMatch) return bLangMatch.compareTo(aLangMatch);

      // Priority 3: Popularity
      return b.playCount.compareTo(a.playCount);
    });

    return filtered;
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
          queryParameters: {'id': songId});

        final dynamic rawData = res.data is Map ? (res.data['data'] ?? res.data) : res.data;
        final List data = rawData is List ? rawData : (rawData is Map ? [rawData] : []);
        
        if (data.isEmpty) {
          _log('getStreamUrl: empty data for $songId');
          continue;
        }

        final song = data[0];
        final downloadUrls  = song['downloadUrl'] as List?;
        if (downloadUrls == null || downloadUrls.isEmpty) {
          _log('getStreamUrl: no downloadUrl for $songId');
          continue;
        }

        // Find the URL that matches the requested quality
        // downloadUrl objects: { "quality": "320kbps", "url"|"link": "..." }
        final best = downloadUrls.firstWhere(
          (u) => u['quality'] == quality,
          orElse: () => downloadUrls.last, // Fallback to highest available
        );

        final url = (best['url'] ?? best['link'] ?? '') as String;
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