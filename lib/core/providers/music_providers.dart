import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../services/audius_service.dart';
import '../models/song.dart';

// ─── API PROVIDERS ────────────────────────────────────────────

final audiusServiceProvider = Provider<AudiusService>(
  (ref) => AudiusService());

// ─── JIOSAAVN SECTIONS ────────────────────────────────────────

final trendingProvider = FutureProvider<List<Song>>((ref) async {
  return ref.read(apiServiceProvider).getTrending();
});

final newReleasesProvider = FutureProvider<List<Song>>((ref) async {
  return ref.read(apiServiceProvider).getNewReleases();
});

final topChartsProvider = FutureProvider<List<Song>>((ref) async {
  return ref.read(apiServiceProvider).getTopCharts();
});

final throwbackProvider = FutureProvider<List<Song>>((ref) async {
  return ref.read(apiServiceProvider).getThrowback();
});

final timeBasedSongsProvider = FutureProvider<List<Song>>((ref) async {
  return ref.read(apiServiceProvider).getTimeBased();
});

// ─── AUDIUS SECTIONS ──────────────────────────────────────────

final audiusTrendingProvider = FutureProvider<List<Song>>((ref) async {
  return ref.read(audiusServiceProvider).getTrending(limit: 15);
});

// ─── ARTIST SPOTLIGHT ─────────────────────────────────────────

const spotlightArtists = [
  {'name': 'Arijit Singh', 'emoji': '🎤'},
  {'name': 'AP Dhillon',   'emoji': '🎵'},
  {'name': 'Shreya Ghoshal','emoji': '🌟'},
];

final spotlightArtistIndexProvider =
  StateProvider<int>((ref) => 0);

final spotlightSongsProvider = FutureProvider<List<Song>>((ref) async {
  final index = ref.watch(spotlightArtistIndexProvider);
  final name = spotlightArtists[index]['name']!;
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

final searchResultsProvider = FutureProvider<List<Song>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.isEmpty) return [];
  return ref.read(apiServiceProvider).searchSongs(query);
});

// ─── PLAYER STATE ─────────────────────────────────────────────

final currentSongProvider = StateProvider<Song?>((ref) => null);
final currentPlaylistProvider = StateProvider<List<Song>>((ref) => []);
final currentSongIndexProvider = StateProvider<int>((ref) => -1);
final isPlayingProvider = StateProvider<bool>((ref) => false);