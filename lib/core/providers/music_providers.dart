import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../services/audius_service.dart';
import '../services/player_service.dart';
import '../providers/queue_meta.dart';
import '../models/song.dart';

// ─── API PROVIDERS ────────────────────────────────────────────

final audiusServiceProvider = Provider<AudiusService>((ref) => AudiusService());

// ─── JIOSAAVN SECTIONS ────────────────────────────────────────

final trendingProvider = FutureProvider<List<Song>>((ref) async =>
    ref.read(apiServiceProvider).getTrending());

final newReleasesProvider = FutureProvider<List<Song>>((ref) async =>
    ref.read(apiServiceProvider).getNewReleases());

final topChartsProvider = FutureProvider<List<Song>>((ref) async =>
    ref.read(apiServiceProvider).getTopCharts());

final throwbackProvider = FutureProvider<List<Song>>((ref) async =>
    ref.read(apiServiceProvider).getThrowback());

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
  final query = ref.watch(searchQueryProvider);
  final seed  = ref.watch(searchShuffleSeedProvider);
  if (query.isEmpty) return [];

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
  // Always include: exact query p1, exact query p2, broad search
  // Plus up to 6 of the computed variants
  final jioFutures = <Future<List<Song>>>[
    api.searchSongs(query, page: 1, limit: 20),
    api.searchSongs(query, page: 2, limit: 20),
    api.searchBroad(query),               // hits /search endpoint
  ];

  // Add computed variants (skip duplicates of main query)
  final extras = queriesToFire
      .where((q) => q.toLowerCase() != query.toLowerCase())
      .take(6)
      .toList();
  for (final q in extras) {
    jioFutures.add(api.searchSongs(q, page: 1, limit: 20));
  }

  // Audius parallel fetch
  Future<List<Song>> audiusFuture = Future.value([]);
  if (useAudius) {
    audiusFuture = audius.searchTracks(query, limit: 20);
  }

  // ── Await everything ─────────────────────────────────────────
  final allResults = await Future.wait([
    Future.wait(jioFutures),
    audiusFuture,
  ]);

  final jioResults = (allResults[0] as List<List<Song>>)
      .expand((l) => l)
      .toList();
  final audiusResults = allResults[1] as List<Song>;

  // ── Merge and deduplicate ────────────────────────────────────
  final seen = <String>{};
  final all = [
    ...jioResults.where((s) => seen.add(s.id)),
    ...audiusResults.where((s) => seen.add(s.id)),
  ];

  if (all.isEmpty) return [];

  // ── Pin best match to position 0 ─────────────────────────────
  // Priority: exact title → starts with → contains → artist match
  final q = query.trim().toLowerCase();

  int pinIdx = all.indexWhere(
      (s) => s.title.toLowerCase() == q);
  if (pinIdx < 0) {
    pinIdx = all.indexWhere(
        (s) => s.title.toLowerCase().startsWith(q));
  }
  if (pinIdx < 0) {
    pinIdx = all.indexWhere(
        (s) => s.title.toLowerCase().contains(q));
  }
  if (pinIdx < 0) {
    // Try matching by first word of query against title
    final firstWord = q.split(' ').first;
    if (firstWord.length > 2) {
      pinIdx = all.indexWhere(
          (s) => s.title.toLowerCase().contains(firstWord));
    }
  }

  final Song pinned;
  final List<Song> rest;

  if (pinIdx > 0) {
    pinned = all[pinIdx];
    rest = [...all]..removeAt(pinIdx);
  } else {
    pinned = all.first;
    rest = all.sublist(1);
  }

  // Shuffle rest with a fresh seed every search
  rest.shuffle(math.Random(seed ^ DateTime.now().millisecondsSinceEpoch));

  return [pinned, ...rest].take(50).toList();
});
// ─── PLAYER STATE ─────────────────────────────────────────────

final currentSongProvider     = StateProvider<Song?>((ref) => null);
final currentPlaylistProvider = StateProvider<List<Song>>((ref) => []);
final currentSongIndexProvider = StateProvider<int>((ref) => -1);
final isPlayingProvider       = StateProvider<bool>((ref) => false);

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