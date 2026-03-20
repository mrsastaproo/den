import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../models/song.dart';

// API service provider
final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

// Trending songs provider
final trendingProvider = FutureProvider<List<Song>>((ref) async {
  return ref.read(apiServiceProvider).getTrending();
});

// Search query state
final searchQueryProvider = StateProvider<String>((ref) => '');

// Search results provider
final searchResultsProvider = FutureProvider<List<Song>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.isEmpty) return [];
  return ref.read(apiServiceProvider).searchSongs(query);
});

// Currently playing song
final currentSongProvider = StateProvider<Song?>((ref) => null);

// Is playing state
final isPlayingProvider = StateProvider<bool>((ref) => false);

// New releases provider
final newReleasesProvider = FutureProvider<List<Song>>((ref) async {
  return ref.read(apiServiceProvider).getNewReleases();
});

// Top charts provider
final topChartsProvider = FutureProvider<List<Song>>((ref) async {
  try {
    final results = await Future.wait([
      ref.read(apiServiceProvider).searchSongs('top charts hindi 2025', page: 1),
      ref.read(apiServiceProvider).searchSongs('bollywood hits 2025', page: 1),
    ]);
    final songs = [...results[0], ...results[1]];
    final seen = <String>{};
    return songs.where((s) => seen.add(s.id)).take(15).toList();
  } catch (e) {
    return [];
  }
});