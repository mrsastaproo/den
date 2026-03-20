import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/providers/music_providers.dart';
import '../../core/services/player_service.dart';
import '../../core/services/database_service.dart';
import '../../core/services/api_service.dart';
import '../../core/models/song.dart';
import '../../core/theme/app_theme.dart';

const _spotlightArtists = [
  {'name': 'Arijit Singh', 'query': 'arijit singh latest 2025',
    'emoji': '🎤'},
  {'name': 'AP Dhillon', 'query': 'ap dhillon songs 2025',
    'emoji': '🎵'},
  {'name': 'Shreya Ghoshal', 'query': 'shreya ghoshal hits',
    'emoji': '🌟'},
];

final spotlightArtistIndexProvider = StateProvider<int>((ref) => 0);

final spotlightSongsProvider = FutureProvider<List<Song>>((ref) async {
  final index = ref.watch(spotlightArtistIndexProvider);
  final query = _spotlightArtists[index]['query']!;
  return ref.read(apiServiceProvider).searchSongs(query, page: 1);
});

class ArtistSpotlightSection extends ConsumerWidget {
  const ArtistSpotlightSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artistIndex = ref.watch(spotlightArtistIndexProvider);
    final songsAsync = ref.watch(spotlightSongsProvider);
    final artist = _spotlightArtists[artistIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 14),
          child: Row(
            children: [
              ShaderMask(
                shaderCallback: (b) =>
                  AppTheme.primaryGradient.createShader(b),
                child: const Icon(Icons.mic_rounded,
                  color: Colors.white, size: 22)),
              const SizedBox(width: 8),
              const Text('Artist Spotlight',
                style: TextStyle(color: Colors.white,
                  fontSize: 20, fontWeight: FontWeight.w700)),
            ],
          ),
        ).animate().fadeIn(duration: 500.ms),

        // Artist selector tabs
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: List.generate(
              _spotlightArtists.length,
              (i) => GestureDetector(
                onTap: () => ref.read(
                  spotlightArtistIndexProvider.notifier).state = i,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: i == artistIndex
                      ? AppTheme.primaryGradient : null,
                    color: i != artistIndex
                      ? Colors.white.withOpacity(0.08) : null,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: i == artistIndex
                        ? Colors.transparent
                        : Colors.white.withOpacity(0.12)),
                    boxShadow: i == artistIndex ? [
                      BoxShadow(
                        color: AppTheme.pink.withOpacity(0.3),
                        blurRadius: 12, spreadRadius: -3),
                    ] : null,
                  ),
                  child: Text(
                    '${_spotlightArtists[i]['emoji']} '
                    '${_spotlightArtists[i]['name']}',
                    style: TextStyle(
                      color: i == artistIndex
                        ? Colors.white
                        : Colors.white.withOpacity(0.5),
                      fontSize: 12,
                      fontWeight: i == artistIndex
                        ? FontWeight.w700
                        : FontWeight.w400)),
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 14),

        // Songs
        songsAsync.when(
          loading: () => _buildShimmer(),
          error: (_, __) => const SizedBox.shrink(),
          data: (songs) => ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.pink.withOpacity(0.1),
                      AppTheme.purple.withOpacity(0.06),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1)),
                ),
                child: Column(
                  children: [
                    // Artist header
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 50, height: 50,
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.pink.withOpacity(0.4),
                                  blurRadius: 12, spreadRadius: -2),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                artist['emoji']!,
                                style: const TextStyle(fontSize: 22)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment:
                              CrossAxisAlignment.start,
                            children: [
                              Text(artist['name']!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800)),
                              Text('Top songs this week',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.4),
                                  fontSize: 12)),
                            ],
                          ),
                          Spacer(),
                          GestureDetector(
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Successfully followed ${artist['name']}! 🎉'),
                                  backgroundColor: Colors.black.withOpacity(0.8),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  margin: const EdgeInsets.all(16),
                                ),
                              );
                            },
                            child: ShaderMask(
                              shaderCallback: (b) =>
                                AppTheme.primaryGradient.createShader(b),
                              child: const Text('Follow',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Top 5 songs
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 8),
                      itemCount: songs.take(5).length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        color: Colors.white.withOpacity(0.05),
                        indent: 70, endIndent: 16),
                      itemBuilder: (context, index) {
                        final song = songs[index];
                        return ListTile(
                          contentPadding:
                            const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 2),
                          leading: Stack(
                            children: [
                              ClipRRect(
                                borderRadius:
                                  BorderRadius.circular(10),
                                child: CachedNetworkImage(
                                  imageUrl: song.image,
                                  width: 44, height: 44,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) =>
                                    Container(
                                      width: 44, height: 44,
                                      decoration: BoxDecoration(
                                        gradient:
                                          AppTheme.primaryGradient,
                                        borderRadius:
                                          BorderRadius.circular(10)),
                                    ),
                                ),
                              ),
                              Positioned(
                                bottom: 0, right: 0,
                                child: Container(
                                  width: 16, height: 16,
                                  decoration: BoxDecoration(
                                    gradient:
                                      AppTheme.primaryGradient,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.black,
                                      width: 1.5)),
                                  child: const Icon(
                                    Icons.play_arrow_rounded,
                                    color: Colors.white, size: 9),
                                ),
                              ),
                            ],
                          ),
                          title: Text(song.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                          subtitle: Text(song.artist,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.4),
                              fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                          trailing: Text('#${index + 1}',
                            style: TextStyle(
                              color: index < 3
                                ? AppTheme.pink
                                : Colors.white.withOpacity(0.3),
                              fontSize: 13,
                              fontWeight: FontWeight.w800)),
                          onTap: () {
                            ref.read(currentSongProvider.notifier)
                              .state = song;
                            ref.read(playerServiceProvider)
                              .playSong(song);
                            ref.read(databaseServiceProvider)
                              .addToHistory(song);
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildShimmer() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      height: 300,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(24)),
    ).animate(onPlay: (c) => c.repeat())
      .shimmer(duration: 1200.ms,
        color: Colors.white.withOpacity(0.05));
  }
}