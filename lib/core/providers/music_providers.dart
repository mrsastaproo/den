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
// Maps user search terms → best JioSaavn query variants that
// actually return the right songs. JioSaavn indexes by song
// name / artist, not genre tags, so raw genre words often fail.
const _queryExpansions = <String, List<String>>{
  // ── Phonk & derivatives ───────────────────────────────────
  'phonk': [
    'phonk music',
    'phonk drift',
    'phonk russian',
    'phonk hard bass',
    'cowbell phonk',
    'memphis phonk',
    'phonk edit',
    'phonk remix',
    'drift phonk',
    'villain phonk',
  ],
  'drift phonk': [
    'drift phonk music',
    'phonk drift',
    'drift phonk car',
    'phonk hard bass drift',
  ],
  'cowbell phonk': [
    'cowbell phonk',
    'phonk cowbell',
    'phonk trumpet cowbell',
  ],
  'russian phonk': [
    'russian phonk',
    'russian hard bass phonk',
    'slap house phonk',
  ],
  'memphis phonk': [
    'memphis phonk',
    'memphis rap phonk',
  ],

  // ── EDM sub-genres ────────────────────────────────────────
  'edm': [
    'edm songs',
    'edm drop',
    'edm festival',
    'electronic dance music',
    'edm bass',
  ],
  'house': [
    'house music',
    'deep house',
    'tech house',
    'house vibes',
  ],
  'techno': [
    'techno music',
    'techno hard',
    'dark techno',
    'techno rave',
  ],
  'dubstep': [
    'dubstep',
    'dubstep bass drop',
    'heavy dubstep',
    'riddim dubstep',
  ],
  'trap': [
    'trap music',
    'trap beat',
    'hard trap',
    'trap hip hop',
    'trap bass',
  ],
  'bass': [
    'bass music',
    'heavy bass',
    'bass house',
    'future bass',
    'bass boosted',
  ],
  'future bass': [
    'future bass',
    'future bass music',
    'melodic future bass',
  ],
  'drum and bass': [
    'drum and bass',
    'dnb music',
    'liquid drum bass',
    'neurofunk',
  ],
  'dnb': [
    'drum and bass',
    'dnb',
    'liquid dnb',
  ],
  'hardstyle': [
    'hardstyle',
    'hardstyle music',
    'hardstyle kicks',
    'frenchcore hardstyle',
  ],
  'lofi': [
    'lofi hip hop',
    'lo fi music',
    'lofi chill beats',
    'lofi study',
    'chill lofi',
  ],
  'lo fi': [
    'lo fi',
    'lofi chill',
    'lo fi hip hop beats',
  ],
  'synthwave': [
    'synthwave',
    'retro synthwave',
    'synthwave outrun',
    '80s synthwave',
  ],
  'retrowave': [
    'retrowave',
    'synthwave retrowave',
    'retro 80s music',
  ],
  'dark': [
    'dark music',
    'dark ambient',
    'dark trap',
    'dark phonk',
    'dark bass',
  ],
  'aggressive': [
    'aggressive music',
    'aggressive phonk',
    'aggressive bass',
    'aggressive rap',
  ],
  'slap house': [
    'slap house',
    'slap house music',
    'slap bass house',
  ],
  'mafia': [
    'mafia music',
    'mafia phonk',
    'dark mafia music',
    'gangster music',
  ],

  // ── Hip hop ───────────────────────────────────────────────
  'hip hop': [
    'hip hop music',
    'hip hop rap',
    'best hip hop',
    'hip hop beats',
  ],
  'rap': [
    'rap music',
    'hindi rap',
    'best rap songs',
    'rap beats',
  ],
  'drill': [
    'drill music',
    'uk drill',
    'chicago drill',
    'dark drill beats',
  ],

  // ── Vibes ─────────────────────────────────────────────────
  'workout': [
    'workout motivation music',
    'gym motivation songs',
    'workout beats',
    'training music',
  ],
  'gaming': [
    'gaming music',
    'gaming background music',
    'gaming phonk',
    'gaming edm',
  ],
  'night drive': [
    'night drive music',
    'night drive songs',
    'late night driving music',
    'phonk night drive',
  ],
  'road trip': [
    'road trip songs',
    'driving music',
    'road trip music playlist',
  ],
  'motivational': [
    'motivational music',
    'motivation songs',
    'workout motivation',
    'inspirational music',
  ],
};

// Returns expanded queries for a given search term.
// Falls back to [query, "$query songs", "$query music"] if not in map.
List<String> _expandQuery(String query) {
  final q = query.trim().toLowerCase();

  // Direct match
  if (_queryExpansions.containsKey(q)) {
    return _queryExpansions[q]!;
  }

  // Partial match — check if query contains any known keyword
  for (final entry in _queryExpansions.entries) {
    if (q.contains(entry.key) || entry.key.contains(q)) {
      return entry.value;
    }
  }

  // Default: generic expansion
  return [query, '$query songs', '$query music', '$query hits'];
}

// Whether this query should also hit Audius (better for Western/EDM/phonk)
bool _shouldUseAudius(String query) {
  final q = query.trim().toLowerCase();
  const audiusGenres = {
    'phonk', 'drift phonk', 'cowbell phonk', 'russian phonk',
    'edm', 'house', 'techno', 'dubstep', 'trap', 'bass',
    'future bass', 'drum and bass', 'dnb', 'hardstyle',
    'lofi', 'lo fi', 'synthwave', 'retrowave', 'dark',
    'aggressive', 'mafia', 'slap house', 'drill',
    'gaming', 'night drive', 'workout', 'motivational',
  };
  return audiusGenres.any((g) => q.contains(g) || g.contains(q));
}

final searchResultsProvider = FutureProvider<List<Song>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  final seed  = ref.watch(searchShuffleSeedProvider);
  if (query.isEmpty) return [];

  final api    = ref.read(apiServiceProvider);
  final audius = ref.read(audiusServiceProvider);

  final expanded = _expandQuery(query);
  final useAudius = _shouldUseAudius(query);

  // ── Fire all requests in parallel ─────────────────────────
  final jioFutures = <Future<List<Song>>>[];

  // Always fetch page 1 of the original query
  jioFutures.add(api.searchSongs(query, page: 1));
  jioFutures.add(api.searchSongs(query, page: 2));

  // Add expanded queries (up to 4 more)
  for (final eq in expanded.take(4)) {
    jioFutures.add(api.searchSongs(eq, page: 1));
  }

  // Audius for EDM/phonk/Western genres — runs in parallel
  Future<List<Song>> audiusFuture = Future.value([]);
  if (useAudius) {
    audiusFuture = audius.searchTracks(query, limit: 20);
  }

  final results = await Future.wait([
    Future.wait(jioFutures),
    audiusFuture,
  ]);

  final jioResults = (results[0] as List<List<Song>>)
      .expand((l) => l)
      .toList();
  final audiusResults = results[1] as List<Song>;

  // ── Merge: JioSaavn first, Audius fills the gaps ──────────
  final seen = <String>{};
  final all = [
    ...jioResults.where((s) => seen.add(s.id)),
    ...audiusResults.where((s) => seen.add(s.id)),
  ];

  if (all.isEmpty) return [];

  // ── Pin exact / closest title match to position 0 ─────────
  final q = query.trim().toLowerCase();

  int pinIdx = all.indexWhere((s) => s.title.toLowerCase() == q);
  if (pinIdx < 0) {
    pinIdx = all.indexWhere(
        (s) => s.title.toLowerCase().startsWith(q));
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

  ref.read(currentPlaylistProvider.notifier).state  = playlist;
  ref.read(currentSongIndexProvider.notifier).state = index;
  ref.read(currentSongProvider.notifier).state      = playlist[index];
  ref.read(playerServiceProvider).playSong(playlist[index]);
}