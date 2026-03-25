import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../services/audius_service.dart';
import '../services/player_service.dart';
import '../services/database_service.dart' as db;
import '../services/settings_service.dart';
import '../providers/queue_meta.dart';
import '../models/song.dart';

// ─── API PROVIDERS ────────────────────────────────────────────

final audiusServiceProvider = Provider<AudiusService>((ref) => AudiusService());
// Seed that changes on every app restart to provide variety
final sessionSeedProvider = Provider<int>((ref) => math.Random().nextInt(1000000));

// ─── JIOSAAVN SECTIONS ────────────────────────────────────────

final trendingProvider = FutureProvider<List<Song>>((ref) async {
  final seed = ref.watch(sessionSeedProvider);
  final lang = ref.watch(musicLanguageProvider);
  final showExplicit = ref.watch(explicitContentProvider);
  
  final timer = Timer(const Duration(minutes: 30), () => ref.invalidateSelf());
  ref.onDispose(() => timer.cancel());

  final api = ref.read(apiServiceProvider);
  
  // 1. Fetch Global Trending
  final globalSongs = await api.getTrending(language: lang);
  
  // 2. Personalize: Watch history
  final historyAsync = ref.watch(db.historyProvider);
  final history = historyAsync.value ?? [];
  final List<Song> personalizedSongs = [];
  
  if (history.isNotEmpty) {
    final topArtists = history.map((s) => s.artist).toSet().take(4).toList();
    for (final artist in topArtists) {
      final extra = await api.getArtistSongs(artist);
      personalizedSongs.addAll(extra.take(10));
    }
  }

  // 3. Merge, Filter and Shuffle
  final allSongs = [...personalizedSongs, ...globalSongs];
  final filtered = showExplicit ? allSongs : allSongs.where((s) => !s.isExplicit).toList();
  filtered.shuffle(math.Random(seed));
  
  final seen = <String>{};
  return filtered.where((s) => seen.add(s.id)).take(30).toList();
});

final globalDiscoveryProvider = FutureProvider<List<Song>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  // Mix of recent English hits + Global Charts
  final queries = [
    'billboard top hits 2024',
    'spotify global top 50',
    'trending english pop 2024',
    'uk top 40 music',
  ];
  
  final futures = queries.map((q) => api.searchSongs(q, limit: 12));
  final results = await Future.wait(futures);
  final allSongs = results.expand((s) => s).toList();
  
  final seen = <String>{};
  final unique = allSongs.where((s) => seen.add(s.title.toLowerCase())).toList();
  
  // Mix it up for a fresh feel on every load
  return unique..shuffle();
});

final trendingEnglishProvider = FutureProvider<List<Song>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  // mapping to real-world Billboard/Spotify charts
  final charts = [
    'Billboard Hot 100',
    'Spotify Global Chart',
  ];
  
  final futures = charts.map((q) => api.searchSongs(q, limit: 15));
  final results = await Future.wait(futures);
  final allSongs = results.expand((s) => s).toList();
  
  final seen = <String>{};
  return allSongs.where((s) => seen.add(s.id)).toList()
    ..sort((a, b) => b.playCount.compareTo(a.playCount));
});


final newReleasesProvider = FutureProvider<List<Song>>((ref) async {
  final seed = ref.watch(sessionSeedProvider);
  final lang = ref.watch(musicLanguageProvider);
  final showExplicit = ref.watch(explicitContentProvider);
  
  final timer = Timer(const Duration(minutes: 30), () => ref.invalidateSelf());
  ref.onDispose(() => timer.cancel());

  final api = ref.read(apiServiceProvider);
  
  final globalSongs = await api.getNewReleases(language: lang);
  
  final likedAsync = ref.watch(db.likedSongsProvider);
  final liked = likedAsync.value ?? [];
  final List<Song> personalizedSongs = [];

  if (liked.isNotEmpty) {
    final topArtists = liked.map((s) => s.artist).toSet().take(3).toList();
    for (final artist in topArtists) {
       final extra = await api.getArtistSongs(artist);
       personalizedSongs.addAll(extra.take(8));
    }
  }

  final allSongs = [...personalizedSongs, ...globalSongs];
  final filtered = showExplicit ? allSongs : allSongs.where((s) => !s.isExplicit).toList();
  filtered.shuffle(math.Random(seed + 777));
  
  final seen = <String>{};
  return filtered.where((s) => seen.add(s.id)).take(20).toList();
});


final topChartsProvider = FutureProvider<List<Song>>((ref) async {
  final seed = ref.watch(sessionSeedProvider);
  final lang = ref.watch(musicLanguageProvider);
  final showExplicit = ref.watch(explicitContentProvider);
  final songs = await ref.read(apiServiceProvider).getTopCharts(language: lang);
  final filtered = showExplicit ? songs : songs.where((s) => !s.isExplicit).toList();
  filtered.shuffle(math.Random(seed + 2));
  return filtered;
});


final throwbackProvider = FutureProvider<List<Song>>((ref) async {
  // Changes based on the hour for variety
  final hour = DateTime.now().hour;
  final seed = ref.watch(sessionSeedProvider) ^ hour;
  
  final songs = await ref.read(apiServiceProvider).getThrowback();
  songs.shuffle(math.Random(seed));
  return songs;
});

final timeBasedSongsProvider = FutureProvider<List<Song>>((ref) async =>
    ref.read(apiServiceProvider).getTimeBased());

// ─── AUDIUS ───────────────────────────────────────────────────

final audiusTrendingProvider = FutureProvider<List<Song>>((ref) async =>
    ref.read(audiusServiceProvider).getTrending(limit: 15));

// ─── ARTIST SPOTLIGHT ─────────────────────────────────────────

const spotlightArtists = [
  {'name': 'Arijit Singh',   'emoji': '🎤'},
  {'name': 'AP Dhillon',     'emoji': '🎵'},
  {'name': 'Shreya Ghoshal', 'emoji': '🌟'},
];

final spotlightArtistIndexProvider = StateProvider<int>((ref) => 0);

final spotlightSongsProvider = FutureProvider<List<Song>>((ref) async {
  final index = ref.watch(spotlightArtistIndexProvider);
  final name  = spotlightArtists[index]['name']!;
  return ref.read(apiServiceProvider).getArtistSongs(name);
});

// ─── MOOD MIX ─────────────────────────────────────────────────

final selectedMoodProvider = StateProvider<String?>((ref) => null);

final moodMixProvider = FutureProvider<List<Song>>((ref) async {
  final mood = ref.watch(selectedMoodProvider);
  if (mood == null) return [];
  return ref.read(apiServiceProvider).getMoodMix(mood);
});

// ─── SEARCH ───────────────────────────────────────────────────

final searchQueryProvider = StateProvider<String>((ref) => '');

// Bumped on every new search so the shuffle seed changes
final searchShuffleSeedProvider = StateProvider<int>((ref) => 0);

// ── Genre-aware query expansion map ───────────────────────────
const _queryExpansions = <String, List<String>>{
  // ── Specific viral phonk songs / artists ─────────────────
  // These need artist-name queries because JioSaavn doesn't
  // surface them by title alone.
  'fendi 2': [
    'Fendi 2 Rakhim',
    'Rakhim Khim ayv1o',
    'Rakhim phonk',
    'Rakhim songs',
    'Fendi Rakhim',
  ],
  'fendi': [
    'Fendi Rakhim',
    'Rakhim songs',
    'Fendi 2 Rakhim',
    'Rakhim phonk',
  ],
  'rakhim': [
    'Rakhim songs',
    'Rakhim phonk',
    'Rakhim Khim',
    'Fendi Rakhim',
  ],

  // ── Phonk & derivatives ──────────────────────────────────
  'phonk': [
    'phonk music', 'phonk drift', 'phonk russian',
    'phonk hard bass', 'cowbell phonk', 'memphis phonk',
    'phonk edit', 'phonk remix', 'drift phonk', 'villain phonk',
    'Rakhim phonk', 'ghostemane', 'phonk trap',
  ],
  'drift phonk': ['drift phonk music', 'phonk drift', 'drift phonk car'],
  'cowbell phonk': ['cowbell phonk', 'phonk cowbell', 'phonk trumpet'],
  'russian phonk': ['russian phonk', 'Rakhim', 'russian hard bass phonk'],
  'memphis phonk': ['memphis phonk', 'memphis rap phonk'],

  // ── EDM ──────────────────────────────────────────────────
  'edm': ['edm songs', 'edm drop', 'edm festival', 'electronic dance music'],
  'house': ['house music', 'deep house', 'tech house'],
  'techno': ['techno music', 'techno hard', 'dark techno'],
  'dubstep': ['dubstep', 'dubstep bass drop', 'heavy dubstep'],
  'trap': ['trap music', 'trap beat', 'hard trap', 'trap bass'],
  'bass': ['bass music', 'heavy bass', 'bass house', 'future bass'],
  'future bass': ['future bass', 'future bass music', 'melodic future bass'],
  'drum and bass': ['drum and bass', 'dnb music', 'liquid drum bass'],
  'dnb': ['drum and bass', 'dnb', 'liquid dnb'],
  'hardstyle': ['hardstyle', 'hardstyle music', 'hardstyle kicks'],
  'lofi': ['lofi hip hop', 'lo fi music', 'lofi chill beats', 'lofi study'],
  'lo fi': ['lo fi', 'lofi chill', 'lo fi hip hop beats'],
  'synthwave': ['synthwave', 'retro synthwave', '80s synthwave'],
  'retrowave': ['retrowave', 'synthwave retrowave', 'retro 80s music'],
  'dark': ['dark music', 'dark ambient', 'dark trap', 'dark phonk'],
  'aggressive': ['aggressive music', 'aggressive phonk', 'aggressive bass'],
  'slap house': ['slap house', 'slap house music'],
  'mafia': ['mafia music', 'mafia phonk', 'dark mafia music'],

  // ── Hip hop ──────────────────────────────────────────────
  'hip hop': ['hip hop music', 'hip hop rap', 'best hip hop'],
  'rap': ['rap music', 'hindi rap', 'best rap songs', 'rap beats'],
  'drill': ['drill music', 'uk drill', 'dark drill beats'],

  // ── Vibes ────────────────────────────────────────────────
  'workout': ['workout motivation music', 'gym motivation songs', 'training music'],
  'gaming': ['gaming music', 'gaming background music', 'gaming phonk'],
  'night drive': ['night drive music', 'night drive songs', 'late night driving'],
  'road trip': ['road trip songs', 'driving music', 'road trip music'],
  'motivational': ['motivational music', 'motivation songs', 'inspirational music'],
};

// Returns expanded queries for a given search term
List<String> _expandQuery(String query) {
  final q = query.trim().toLowerCase();
  if (_queryExpansions.containsKey(q)) return _queryExpansions[q]!;
  for (final entry in _queryExpansions.entries) {
    if (q.contains(entry.key) || entry.key.contains(q)) {
      return entry.value;
    }
  }
  // Default generic expansion
  return [query, '$query songs', '$query music', '$query hits'];
}

// Whether to also search Audius (better for Western/EDM/phonk)
bool _shouldUseAudius(String query) {
  final q = query.trim().toLowerCase();
  const audiusGenres = {
    'phonk', 'drift phonk', 'cowbell phonk', 'russian phonk',
    'edm', 'house', 'techno', 'dubstep', 'trap', 'bass',
    'future bass', 'drum and bass', 'dnb', 'hardstyle',
    'lofi', 'lo fi', 'synthwave', 'retrowave', 'dark',
    'aggressive', 'mafia', 'slap house', 'drill',
    'gaming', 'night drive', 'workout', 'motivational',
    // Specific viral artists / songs that live on Audius
    'fendi', 'rakhim', 'khim', 'ayv1o',
  };
  return audiusGenres.any((g) => q.contains(g) || g.contains(q));
}

// Whether the query looks like a specific song/artist name
// (not a genre keyword) — triggers title-focused search strategy
bool _isSpecificTitle(String query) {
  final q = query.trim().toLowerCase();
  // If it matches a genre keyword, it's NOT a specific title
  for (final key in _queryExpansions.keys) {
    if (q == key || q.contains(key)) return false;
  }
  // Likely a specific song/artist if it's short and not a common genre word
  const genericWords = {
    'songs', 'music', 'hits', 'playlist', 'mix', 'best',
    'top', 'new', 'latest', 'hindi', 'bollywood', 'trending',
  };
  final words = q.split(RegExp(r'\s+'));
  final nonGeneric = words.where((w) => !genericWords.contains(w)).length;
  return nonGeneric >= 1;
}

// Builds title-focused query variants for specific song searches.
// Also checks _queryExpansions for known artist pairings.
List<String> _buildTitleQueries(String query) {
  final q = query.trim();
  final lower = q.toLowerCase();
  final words = q.split(RegExp(r'\s+'));

  final queries = <String>{};

  // If we have a specific expansion for this title, use those first
  // (they include artist names which massively improve results)
  if (_queryExpansions.containsKey(lower)) {
    queries.addAll(_queryExpansions[lower]!);
  } else {
    // Check partial match
    for (final entry in _queryExpansions.entries) {
      if (lower.contains(entry.key) || entry.key.contains(lower)) {
        queries.addAll(entry.value);
        break;
      }
    }
  }

  // Always also add the raw query and common variants
  queries.add(q);
  queries.add('$q song');
  queries.add('$q official');

  // Individual words
  for (final word in words) {
    if (word.length > 2) {
      queries.add(word);
      queries.add('$word song');
    }
  }

  // Word combinations
  if (words.length >= 2) {
    queries.add(words.first);
    queries.add(words.last);
    queries.add('${words.first} ${words.last}');
  }

  // Number ↔ Roman numeral swap
  final withRoman = lower
      .replaceAll(RegExp(r'\b2\b'), 'ii')
      .replaceAll(RegExp(r'\b3\b'), 'iii')
      .replaceAll(RegExp(r'\b4\b'), 'iv');
  if (withRoman != lower) queries.add(withRoman);

  final withArabic = lower
      .replaceAll(RegExp(r'\bii\b'), '2')
      .replaceAll(RegExp(r'\biii\b'), '3');
  if (withArabic != lower) queries.add(withArabic);

  return queries.toList();
}

final searchResultsProvider = FutureProvider<List<Song>>((ref) async {
  final query = ref.watch(searchQueryProvider).trim();
  if (query.isEmpty) return [];

  // Keep results for 5 mins to make navigation snappy
  final link = ref.keepAlive();
  Timer? timer;
  ref.onDispose(() => timer?.cancel());
  ref.onCancel(() {
    timer = Timer(const Duration(minutes: 5), () => link.close());
  });

  final api    = ref.read(apiServiceProvider);
  final audius = ref.read(audiusServiceProvider);

  final isTitle   = _isSpecificTitle(query);
  final useAudius = _shouldUseAudius(query);

  // ── Build query list based on type ──────────────────────────
  final List<String> queriesToFire;
  if (isTitle) {
    // Specific song/artist search — use title-focused variants
    queriesToFire = _buildTitleQueries(query);
  } else {
    // Genre/vibe search — use genre expansion
    final expanded = _expandQuery(query);
    queriesToFire = [query, ...expanded];
  }

  // ── Fire JioSaavn requests in parallel ──────────────────────
  final showExplicit = ref.watch(explicitContentProvider);
  final jioFutures = <Future<List<Song>>>[
    api.searchSongs(query, page: 1, limit: 20, showExplicit: showExplicit),
  ];


  // Only fire deep parallel searches for meaningful queries
  if (query.length >= 3) {
    jioFutures.add(api.searchSongs(query, page: 2, limit: 20, showExplicit: showExplicit));
    jioFutures.add(api.searchBroad(query, showExplicit: showExplicit));


    final extras = queriesToFire
        .where((q) => q.toLowerCase() != query.toLowerCase())
        .take(isTitle ? 4 : 2) // Fewer extras to keep it fast
        .toList();
    for (final q in extras) {
      jioFutures.add(api.searchSongs(q, page: 1, limit: 20, showExplicit: showExplicit));
    }
  }


  // Audius & Jamendo parallel fetch
  Future<List<Song>> audiusFuture = Future.value([]);
  Future<List<Song>> jamendoFuture = Future.value([]);
  
  if (useAudius || query.length >= 3) {
    audiusFuture = audius.searchTracks(query, limit: 20);
    jamendoFuture = api.searchJamendo(query, limit: 20);
  }

  // ── Await everything ─────────────────────────────────────────
  final allResults = await Future.wait([
    Future.wait(jioFutures),
    audiusFuture,
    jamendoFuture,
  ]);

  // ── Unified Smart Ranking Engine ──────────────────────────
  final jioResults = (allResults[0] as List<List<Song>>).expand((l) => l).toList();
  final audiusResults = allResults[1] as List<Song>;
  final jamResults  = allResults[2] as List<Song>;

  final Map<String, Song> uniqueSongs = {};
  final Map<String, double> scores = {};
  final Map<Song, String> songToKey = {}; // Cache keys for fast sorting

  final allSources = [
    ...jioResults,
    ...audiusResults,
    ...jamResults,
  ];

  final qNormal = query.toLowerCase().trim();
  final qWords = qNormal.split(RegExp(r'\s+')).where((w) => w.length > 2).toList();

  for (final s in allSources) {
    // 1. DEDUPLICATION KEY (Title + First Artist)
    final firstArtist = s.artist.split(',').first.trim().toLowerCase();
    final titleClean = s.title.toLowerCase()
        .replaceAll(RegExp(r'\(.*?\)|\[.*?\]'), '') // remove video/label tags from key
        .trim();
    final key = '$titleClean|$firstArtist';

    double score = 0;
    final sTitle = s.title.toLowerCase();
    final sArtist = s.artist.toLowerCase();
    
    // ── A. DIRECT RELEVANCE ─────────────────────────────────────
    if (sTitle == qNormal) score += 500; // Total match
    else if (sTitle.startsWith(qNormal)) score += 300;
    else if (sTitle.contains(qNormal)) score += 150;
    
    // Partial word matches
    for (final word in qWords) {
      if (sTitle.contains(word)) score += 30;
      if (sArtist.contains(word)) score += 20;
    }

    // ── B. QUALITY & OFFICIAL STATUS ────────────────────────────
    bool isOfficial = sTitle.contains('official') || 
                      sTitle.contains('original') || 
                      sTitle.contains('vevo') ||
                      sTitle.contains('music video');
    if (isOfficial) score += 150;

    // ── C. MODIFIED VERSION PENALTIES ───────────────────────────
    final modifiedTags = {
      'slowed': -400,
      'reverb': -400,
      'sped up': -400,
      'speed up': -400,
      '8d': -300,
      'lofi': -200,
      'lo-fi': -200,
      'remix': -250,
      'cover': -450,
      'lyrics': -50,
      'karaoke': -300,
      'instrumental': -200,
    };

    modifiedTags.forEach((tag, penalty) {
      if (sTitle.contains(tag) && !qNormal.contains(tag)) {
        score += penalty;
      }
    });

    // ── D. POPULARITY & SOURCE RELIABILITY ─────────────────────
    // Play count bonus (scaled)
    score += (s.playCount / 2000000).clamp(0, 100); 

    // JioSaavn/Platform source bonus for quality
    if (s.id.startsWith('saavn_') || !s.id.contains('_')) score += 50;

    // ── E. UPDATE UNIQUE LIST ──────────────────────────────────
    final existingScore = scores[key] ?? -99999.0;
    if (score > existingScore) {
      scores[key] = score;
      uniqueSongs[key] = s;
      songToKey[s] = key; // Cache for sort
    }
  }

  // ── FINAL SORTING ───────────────────────────────────────────
  final results = uniqueSongs.values.toList();
  results.sort((a, b) {
    final sA = scores[songToKey[a]] ?? 0.0;
    final sB = scores[songToKey[b]] ?? 0.0;
    return sB.compareTo(sA);
  });

  return results.take(60).toList();
});
// ─── PLAYER STATE ─────────────────────────────────────────────

final currentSongProvider     = StateProvider<Song?>((ref) => null);
final currentPlaylistProvider = StateProvider<List<Song>>((ref) => []);
final currentSongIndexProvider = StateProvider<int>((ref) => -1);
final isPlayingProvider       = StateProvider<bool>((ref) => false);

/// True while the full PlayerScreen modal is open.
/// DynamicIsland watches this to hide itself when the player is visible.
final playerScreenOpenProvider = StateProvider<bool>((ref) => false);

// ─── PLAY QUEUE ───────────────────────────────────────────────
//
// Use this everywhere to start playback.
// meta tells the smart queue what genre/vibe to continue with
// when the playlist runs out.
//
// Usage:
//   playQueue(ref, songs, 0)
//   playQueue(ref, songs, 2, meta: QueueMeta(context: QueueContext.mood, mood: 'Love'))

void playQueue(
  WidgetRef ref,
  List<Song> playlist,
  int index, {
  QueueMeta meta = const QueueMeta(),
}) {
  if (playlist.isEmpty || index < 0 || index >= playlist.length) return;

  // Save context so PlayerService knows how to continue
  ref.read(queueMetaProvider.notifier).state = meta;

  List<Song> finalPlaylist = playlist;
  int finalIndex = index;

  if (meta.context == QueueContext.search) {
    // For search, play ONLY the selected song initially.
    // This forces smart queue continuation when it ends.
    finalPlaylist = [playlist[index]];
    finalIndex = 0;
  }

  ref.read(currentPlaylistProvider.notifier).state  = finalPlaylist;
  ref.read(currentSongIndexProvider.notifier).state = finalIndex;
  ref.read(currentSongProvider.notifier).state      = finalPlaylist[finalIndex];
  ref.read(playerServiceProvider).playSong(finalPlaylist[finalIndex]);
}