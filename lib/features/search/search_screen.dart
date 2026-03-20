import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/providers/music_providers.dart';
import '../../core/services/player_service.dart';
import '../../core/services/database_service.dart';
import '../../core/theme/app_theme.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchResults = ref.watch(searchResultsProvider);
    final query = ref.watch(searchQueryProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Text('Search',
                style: TextStyle(color: Colors.white,
                  fontSize: 28, fontWeight: FontWeight.w800,
                  letterSpacing: -1)),
            ),

            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.12)),
                ),
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  style: const TextStyle(color: Colors.white,
                    fontSize: 16),
                  cursorColor: AppTheme.pink,
                  decoration: InputDecoration(
                    hintText: 'Songs, artists, albums...',
                    hintStyle: TextStyle(
                      color: Colors.white.withOpacity(0.3)),
                    prefixIcon: ShaderMask(
                      shaderCallback: (b) =>
                        AppTheme.primaryGradient.createShader(b),
                      child: const Icon(Icons.search_rounded,
                        color: Colors.white)),
                    suffixIcon: query.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.close_rounded,
                            color: Colors.white.withOpacity(0.5)),
                          onPressed: () {
                            _controller.clear();
                            ref.read(searchQueryProvider.notifier)
                              .state = '';
                          })
                      : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  ),
                  onChanged: (val) => ref
                    .read(searchQueryProvider.notifier).state = val,
                ),
              ),
            ),

            const SizedBox(height: 16),

            Expanded(
              child: query.isEmpty
                ? _buildEmptyState()
                : searchResults.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.pink)),
                    error: (e, _) => Center(
                      child: Text('Error: $e',
                        style: const TextStyle(color: Colors.red))),
                    data: (songs) => songs.isEmpty
                      ? _buildNoResults(query)
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 160),
                          itemCount: songs.length,
                          itemBuilder: (context, index) {
                            final song = songs[index];
                            return ListTile(
                              contentPadding:
                                const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 4),
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: CachedNetworkImage(
                                  imageUrl: song.image,
                                  width: 50, height: 50,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) =>
                                    Container(
                                      width: 50, height: 50,
                                      decoration: BoxDecoration(
                                        gradient:
                                          AppTheme.primaryGradient,
                                        borderRadius:
                                          BorderRadius.circular(10)),
                                      child: const Icon(
                                        Icons.music_note,
                                        color: Colors.white,
                                        size: 20)),
                                ),
                              ),
                              title: Text(song.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                              subtitle: Text(song.artist,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.4),
                                  fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                              trailing: ShaderMask(
                                shaderCallback: (b) =>
                                  AppTheme.primaryGradient
                                    .createShader(b),
                                child: const Icon(
                                  Icons.play_circle_filled_rounded,
                                  color: Colors.white, size: 36),
                              ),
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
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Browse categories',
            style: TextStyle(color: Colors.white,
              fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.6,
            children: [
              _CategoryCard('Bollywood', AppTheme.pink, ref),
              _CategoryCard('Punjabi', AppTheme.purple, ref),
              _CategoryCard('Romance', AppTheme.pinkDeep, ref),
              _CategoryCard('Party', AppTheme.purpleDeep, ref),
              _CategoryCard('Devotional', AppTheme.pink, ref),
              _CategoryCard('Trending', AppTheme.purple, ref),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNoResults(String query) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ShaderMask(
            shaderCallback: (b) =>
              AppTheme.primaryGradient.createShader(b),
            child: const Icon(Icons.search_off_rounded,
              color: Colors.white, size: 64)),
          const SizedBox(height: 16),
          Text('No results for "$query"',
            style: const TextStyle(color: Colors.white,
              fontSize: 16)),
          const SizedBox(height: 8),
          Text('Try a different keyword',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 14)),
        ],
      ),
    );
  }

  Widget _CategoryCard(String label, Color color, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        _controller.text = label;
        ref.read(searchQueryProvider.notifier).state = label;
      },
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        alignment: Alignment.center,
        child: Text(label,
          style: TextStyle(color: color,
            fontWeight: FontWeight.w700, fontSize: 16)),
      ),
    );
  }
}