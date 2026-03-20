import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/providers/music_providers.dart';
import '../../core/models/song.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendingAsync = ref.watch(trendingProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Good ${_greeting()}!',
                          style: const TextStyle(color: Color(0xFFB3B3B3), fontSize: 14)),
                        const Text('DEN',
                          style: TextStyle(color: Colors.white, fontSize: 28,
                            fontWeight: FontWeight.w800, letterSpacing: -1)),
                      ],
                    ),
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: const Color(0xFFE8383D),
                      child: const Text('M', style: TextStyle(color: Colors.white,
                        fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),

            // Trending label
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Text('Trending Now',
                  style: TextStyle(color: Colors.white, fontSize: 20,
                    fontWeight: FontWeight.w700)),
              ),
            ),

            // Trending songs
            trendingAsync.when(
              loading: () => const SliverToBoxAdapter(
                child: Center(child: CircularProgressIndicator(color: Color(0xFFE8383D))),
              ),
              error: (e, _) => SliverToBoxAdapter(
                child: Center(child: Text('Error: $e',
                  style: const TextStyle(color: Colors.red))),
              ),
              data: (songs) => SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _SongTile(song: songs[index]),
                  childCount: songs.length,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Morning';
    if (h < 17) return 'Afternoon';
    return 'Evening';
  }
}

class _SongTile extends ConsumerWidget {
  final Song song;
  const _SongTile({required this.song});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: song.image,
          width: 52, height: 52, fit: BoxFit.cover,
          placeholder: (_, __) => Container(
            width: 52, height: 52,
            color: const Color(0xFF1E1E1E),
            child: const Icon(Icons.music_note, color: Color(0xFF6B6B6B)),
          ),
          errorWidget: (_, __, ___) => Container(
            width: 52, height: 52,
            color: const Color(0xFF1E1E1E),
            child: const Icon(Icons.music_note, color: Color(0xFF6B6B6B)),
          ),
        ),
      ),
      title: Text(song.title,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(song.artist,
        style: const TextStyle(color: Color(0xFFB3B3B3), fontSize: 12),
        maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: IconButton(
        icon: const Icon(Icons.play_circle_filled_rounded,
          color: Color(0xFFE8383D), size: 36),
        onPressed: () {
          ref.read(currentSongProvider.notifier).state = song;
        },
      ),
    );
  }
}