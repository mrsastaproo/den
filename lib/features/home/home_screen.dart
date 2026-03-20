import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/providers/music_providers.dart';
import '../../core/services/player_service.dart';
import '../../core/models/song.dart';
import '../../core/theme/app_theme.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendingAsync = ref.watch(trendingProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              SliverToBoxAdapter(
                child: trendingAsync.when(
                  loading: () => const SizedBox(height: 200,
                    child: Center(child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))),
                  error: (e, _) => Center(child: Text('$e')),
                  data: (songs) => _buildPlaylistSection(songs),
                ),
              ),
              SliverToBoxAdapter(
                child: trendingAsync.when(
                  loading: () => const SizedBox(),
                  error: (_, __) => const SizedBox(),
                  data: (songs) => _buildRecentlyPlayed(songs, ref),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 160)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good Morning!'
        : hour < 17 ? 'Good Afternoon!' : 'Good Evening!';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(greeting,
                style: const TextStyle(color: Colors.white70,
                  fontSize: 13, fontWeight: FontWeight.w400)),
              const SizedBox(height: 2),
              const Text('Ahmad Fauzi',
                style: TextStyle(color: Colors.white, fontSize: 26,
                  fontWeight: FontWeight.w800, letterSpacing: -0.5)),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.menu_rounded,
                  color: Colors.white, size: 26),
                onPressed: () {},
              ),
              const SizedBox(width: 4),
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.white24,
                child: const Icon(Icons.person_rounded,
                  color: Colors.white, size: 22),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistSection(List<Song> songs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Playlist',
                style: TextStyle(color: Colors.white,
                  fontSize: 18, fontWeight: FontWeight.w700)),
              TextButton(
                onPressed: () {},
                child: const Text('See more',
                  style: TextStyle(color: Colors.white60, fontSize: 13)),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: songs.take(6).length,
            itemBuilder: (context, index) {
              final song = songs[index];
              return _PlaylistCard(song: song, index: index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRecentlyPlayed(List<Song> songs, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Recently Played',
                style: TextStyle(color: Colors.white,
                  fontSize: 18, fontWeight: FontWeight.w700)),
              TextButton(
                onPressed: () {},
                child: const Text('See more',
                  style: TextStyle(color: Colors.white60, fontSize: 13)),
              ),
            ],
          ),
        ),
        // White card container like in the image
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: songs.length > 8 ? 8 : songs.length,
            separatorBuilder: (_, __) => const Divider(
              height: 1, color: Color(0xFFF0F0F0),
              indent: 72, endIndent: 16),
            itemBuilder: (context, index) {
              final song = songs[index];
              return _WhiteSongTile(song: song, ref: ref);
            },
          ),
        ),
      ],
    );
  }
}

class _PlaylistCard extends StatelessWidget {
  final Song song;
  final int index;

  const _PlaylistCard({required this.song, required this.index});

  static const List<List<Color>> _gradients = [
    [Color(0xFF8B5CF6), Color(0xFFEC4899)],
    [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
    [Color(0xFFEC4899), Color(0xFFF97316)],
    [Color(0xFF10B981), Color(0xFF3B82F6)],
    [Color(0xFFF59E0B), Color(0xFFEC4899)],
    [Color(0xFF6366F1), Color(0xFF8B5CF6)],
  ];

  @override
  Widget build(BuildContext context) {
    final gradient = _gradients[index % _gradients.length];

    return Container(
      width: 130,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Album art
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: CachedNetworkImage(
              imageUrl: song.image,
              width: 130, height: 160,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: gradient)),
              ),
            ),
          ),
          // Overlay gradient
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [Colors.transparent,
                  Colors.black.withOpacity(0.7)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          // Song info
          Positioned(
            bottom: 10, left: 10, right: 10,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(song.title,
                  style: const TextStyle(color: Colors.white,
                    fontSize: 12, fontWeight: FontWeight.w700),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.music_note_rounded,
                      color: Colors.white60, size: 10),
                    const SizedBox(width: 3),
                    const Text('12 Tracks',
                      style: TextStyle(color: Colors.white60,
                        fontSize: 10)),
                  ],
                ),
              ],
            ),
          ),
          // Play button
          Positioned(
            bottom: 10, right: 10,
            child: Container(
              width: 28, height: 28,
              decoration: const BoxDecoration(
                color: Colors.white, shape: BoxShape.circle),
              child: const Icon(Icons.play_arrow_rounded,
                color: Color(0xFF6B35B8), size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

class _WhiteSongTile extends StatelessWidget {
  final Song song;
  final WidgetRef ref;

  const _WhiteSongTile({required this.song, required this.ref});

  @override
  Widget build(BuildContext context) {
    final currentSong = ref.watch(currentSongProvider);
    final isPlaying = currentSong?.id == song.id;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: CachedNetworkImage(
          imageUrl: song.image,
          width: 48, height: 48, fit: BoxFit.cover,
          placeholder: (_, __) => Container(
            width: 48, height: 48,
            color: const Color(0xFFEEEEEE),
            child: const Icon(Icons.music_note,
              color: Color(0xFF9B59D4), size: 20),
          ),
          errorWidget: (_, __, ___) => Container(
            width: 48, height: 48,
            color: const Color(0xFFEEEEEE),
            child: const Icon(Icons.music_note,
              color: Color(0xFF9B59D4), size: 20),
          ),
        ),
      ),
      title: Text(song.title,
        style: TextStyle(
          color: isPlaying
            ? const Color(0xFF6B35B8)
            : const Color(0xFF1A1A2E),
          fontWeight: FontWeight.w600, fontSize: 14),
        maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(song.artist,
        style: const TextStyle(
          color: Color(0xFF8B8BAD), fontSize: 12),
        maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isPlaying)
            const Icon(Icons.equalizer_rounded,
              color: Color(0xFF6B35B8), size: 20),
          IconButton(
            icon: Icon(
              isPlaying
                ? Icons.pause_circle_filled_rounded
                : Icons.play_circle_filled_rounded,
              color: const Color(0xFF9B59D4), size: 32),
            onPressed: () {
              ref.read(currentSongProvider.notifier).state = song;
              ref.read(playerServiceProvider).playSong(song);
            },
          ),
        ],
      ),
    );
  }
}