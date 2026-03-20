import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/providers/music_providers.dart';
import '../../core/services/player_service.dart';

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
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Text('Search',
                style: TextStyle(color: Colors.white, fontSize: 28,
                  fontWeight: FontWeight.w800, letterSpacing: -1)),
            ),

            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  cursorColor: const Color(0xFFE8383D),
                  decoration: InputDecoration(
                    hintText: 'Songs, artists, albums...',
                    hintStyle: const TextStyle(color: Color(0xFF6B6B6B)),
                    prefixIcon: const Icon(Icons.search_rounded,
                      color: Color(0xFF6B6B6B)),
                    suffixIcon: query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded,
                            color: Color(0xFF6B6B6B)),
                          onPressed: () {
                            _controller.clear();
                            ref.read(searchQueryProvider.notifier).state = '';
                          },
                        )
                      : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  ),
                  onChanged: (val) {
                    ref.read(searchQueryProvider.notifier).state = val;
                  },
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Results
            Expanded(
              child: query.isEmpty
                ? _buildEmptyState()
                : searchResults.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFE8383D))),
                    error: (e, _) => Center(
                      child: Text('Error: $e',
                        style: const TextStyle(color: Colors.red))),
                    data: (songs) => songs.isEmpty
                      ? _buildNoResults(query)
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 100),
                          itemCount: songs.length,
                          itemBuilder: (context, index) {
                            final song = songs[index];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 4),
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CachedNetworkImage(
                                  imageUrl: song.image,
                                  width: 52, height: 52,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => Container(
                                    width: 52, height: 52,
                                    color: const Color(0xFF1E1E1E),
                                    child: const Icon(Icons.music_note,
                                      color: Color(0xFF6B6B6B)),
                                  ),
                                  errorWidget: (_, __, ___) => Container(
                                    width: 52, height: 52,
                                    color: const Color(0xFF1E1E1E),
                                    child: const Icon(Icons.music_note,
                                      color: Color(0xFF6B6B6B)),
                                  ),
                                ),
                              ),
                              title: Text(song.title,
                                style: const TextStyle(color: Colors.white,
                                  fontWeight: FontWeight.w500),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                              subtitle: Text(song.artist,
                                style: const TextStyle(
                                  color: Color(0xFFB3B3B3), fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.play_circle_filled_rounded,
                                  color: Color(0xFFE8383D), size: 36),
                                onPressed: () {
                                  ref.read(currentSongProvider.notifier)
                                    .state = song;
                                  ref.read(playerServiceProvider)
                                    .playSong(song);
                                },
                              ),
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
            style: TextStyle(color: Colors.white, fontSize: 18,
              fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.6,
            children: [
              _CategoryCard('Bollywood', const Color(0xFFE8383D)),
              _CategoryCard('Punjabi', const Color(0xFF6B4FBB)),
              _CategoryCard('Romance', const Color(0xFFE83870)),
              _CategoryCard('Party', const Color(0xFFE88038)),
              _CategoryCard('Devotional', const Color(0xFF38A8E8)),
              _CategoryCard('Trending', const Color(0xFF38E87A)),
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
          const Icon(Icons.search_off_rounded,
            color: Color(0xFF3A3A3A), size: 64),
          const SizedBox(height: 16),
          Text('No results for "$query"',
            style: const TextStyle(color: Color(0xFFB3B3B3), fontSize: 16)),
          const SizedBox(height: 8),
          const Text('Try a different keyword',
            style: TextStyle(color: Color(0xFF6B6B6B), fontSize: 14)),
        ],
      ),
    );
  }

  Widget _CategoryCard(String label, Color color) {
    return GestureDetector(
      onTap: () {
        _controller.text = label;
        ref.read(searchQueryProvider.notifier).state = label;
      },
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        alignment: Alignment.center,
        child: Text(label,
          style: TextStyle(color: color,
            fontWeight: FontWeight.w700, fontSize: 16)),
      ),
    );
  }
}