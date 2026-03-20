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