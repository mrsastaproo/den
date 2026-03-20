import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/providers/music_providers.dart';
import '../../core/services/player_service.dart';
import '../../core/services/database_service.dart';
import '../../core/models/song.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/glass_container.dart';
import '../../shared/widgets/featured_banner.dart';
import '../../shared/widgets/trending_section.dart';
import '../../shared/widgets/top_charts_section.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendingAsync = ref.watch(trendingProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader()),
          const SliverToBoxAdapter(child: FeaturedBanner()),
          const SliverToBoxAdapter(child: TrendingSection()),
          const SliverToBoxAdapter(child: TopChartsSection()),
          SliverToBoxAdapter(
            child: trendingAsync.when(
              loading: () => const SizedBox(),
              error: (_, __) => const SizedBox(),
              data: (songs) => _buildRecentlyPlayed(songs, ref),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 200)),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good Morning!'
        : hour < 17 ? 'Good Afternoon!' : 'Good Evening!';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(greeting,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 13, fontWeight: FontWeight.w400)),
              const SizedBox(height: 2),
              const Text('DEN',
                style: TextStyle(color: Colors.white,
                  fontSize: 32, fontWeight: FontWeight.w900,
                  letterSpacing: -1.5)),
            ],
          ),
          GlassContainer(
            padding: const EdgeInsets.all(10),
            borderRadius: 14,
            child: ShaderMask(
              shaderCallback: (bounds) =>
                AppTheme.primaryGradient.createShader(bounds),
              child: const Icon(Icons.person_rounded,
                color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
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
              const Text('All Songs',
                style: TextStyle(color: Colors.white,
                  fontSize: 20, fontWeight: FontWeight.w700)),
              ShaderMask(
                shaderCallback: (b) =>
                  AppTheme.primaryGradient.createShader(b),
                child: const Text('See all',
                  style: TextStyle(color: Colors.white,
                    fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
        GlassContainer(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          borderRadius: 24,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: songs.length > 10 ? 10 : songs.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              color: Colors.white.withOpacity(0.06),
              indent: 72, endIndent: 16),
            itemBuilder: (context, index) =>
              _SongTile(song: songs[index], ref: ref),
          ),
        ),
      ],
    );
  }
}

class _SongTile extends StatelessWidget {
  final Song song;
  final WidgetRef ref;

  const _SongTile({required this.song, required this.ref});

  @override
  Widget build(BuildContext context) {
    final currentSong = ref.watch(currentSongProvider);
    final isPlaying = currentSong?.id == song.id;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16, vertical: 4),
      leading: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: isPlaying ? [
            BoxShadow(
              color: AppTheme.pink.withOpacity(0.4),
              blurRadius: 12, spreadRadius: -2),
          ] : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CachedNetworkImage(
            imageUrl: song.image,
            width: 48, height: 48, fit: BoxFit.cover,
            errorWidget: (_, __, ___) => Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.music_note,
                color: Colors.white, size: 20),
            ),
          ),
        ),
      ),
      title: Text(song.title,
        style: TextStyle(
          color: isPlaying ? AppTheme.pink : Colors.white,
          fontWeight: FontWeight.w600, fontSize: 14),
        maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(song.artist,
        style: TextStyle(
          color: Colors.white.withOpacity(0.4), fontSize: 12),
        maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: ShaderMask(
        shaderCallback: (b) =>
          AppTheme.primaryGradient.createShader(b),
        child: Icon(
          isPlaying
            ? Icons.pause_circle_filled_rounded
            : Icons.play_circle_filled_rounded,
          color: Colors.white, size: 34),
      ),
      onTap: () {
        ref.read(currentSongProvider.notifier).state = song;
        ref.read(playerServiceProvider).playSong(song);
        ref.read(databaseServiceProvider).addToHistory(song);
      },
    );
  }
}