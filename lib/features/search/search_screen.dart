import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/providers/music_providers.dart';
import '../../core/services/player_service.dart';
import '../../core/services/database_service.dart';
import '../../core/services/api_service.dart';
import '../../core/models/song.dart';
import '../../core/theme/app_theme.dart';

// ─── PROVIDERS ────────────────────────────────────────────────

final searchFilterProvider = StateProvider<String>((ref) => 'Songs');
final searchLanguageProvider = StateProvider<String>((ref) => 'All');
final recentSearchesProvider =
  StateNotifierProvider<RecentSearchesNotifier, List<String>>(
    (ref) => RecentSearchesNotifier());

class RecentSearchesNotifier extends StateNotifier<List<String>> {
  RecentSearchesNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getStringList('recent_searches') ?? [];
  }

  Future<void> add(String query) async {
    if (query.isEmpty) return;
    final updated = [query, ...state.where((s) => s != query)]
      .take(8).toList();
    state = updated;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('recent_searches', updated);
  }

  Future<void> remove(String query) async {
    state = state.where((s) => s != query).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('recent_searches', state);
  }

  Future<void> clear() async {
    state = [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('recent_searches');
  }
}

// ─── MAIN SCREEN ──────────────────────────────────────────────

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;
  late AnimationController _searchBarController;
  late Animation<double> _searchBarAnim;

  @override
  void initState() {
    super.initState();
    _searchBarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300));
    _searchBarAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _searchBarController,
        curve: Curves.easeOutCubic));

    _focusNode.addListener(() {
      setState(() => _isFocused = _focusNode.hasFocus);
      if (_focusNode.hasFocus) {
        _searchBarController.forward();
      } else {
        _searchBarController.reverse();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _searchBarController.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    ref.read(searchQueryProvider.notifier).state = query;
    if (query.isNotEmpty) {
      ref.read(recentSearchesProvider.notifier).add(query);
    }
  }

  void _clearSearch() {
    _controller.clear();
    ref.read(searchQueryProvider.notifier).state = '';
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider);
    final searchResults = ref.watch(searchResultsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──
            _buildHeader(),

            // ── Animated Search Bar ──
            _buildSearchBar(query),

            // ── Filter + Language chips ──
            if (query.isNotEmpty) _buildFilterChips(),
            if (query.isNotEmpty) _buildLanguageChips(),

            // ── Content ──
            Expanded(
              child: query.isEmpty
                ? _buildEmptyState()
                : _buildSearchResults(searchResults),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          ShaderMask(
            shaderCallback: (b) =>
              AppTheme.primaryGradient.createShader(b),
            child: const Icon(Icons.search_rounded,
              color: Colors.white, size: 26)),
          const SizedBox(width: 10),
          const Text('Search',
            style: TextStyle(color: Colors.white,
              fontSize: 28, fontWeight: FontWeight.w800,
              letterSpacing: -0.5)),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms)
      .slideX(begin: -0.1, end: 0, duration: 400.ms);
  }

  Widget _buildSearchBar(String query) {
    return AnimatedBuilder(
      animation: _searchBarAnim,
      builder: (_, __) => Padding(
        padding: EdgeInsets.fromLTRB(
          16, 0,
          _isFocused ? 70 : 16,
          12),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _isFocused ? [
                        AppTheme.pink.withOpacity(0.15),
                        AppTheme.purple.withOpacity(0.1),
                      ] : [
                        Colors.white.withOpacity(0.08),
                        Colors.white.withOpacity(0.04),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: _isFocused
                        ? AppTheme.pink.withOpacity(0.4)
                        : Colors.white.withOpacity(0.1),
                      width: _isFocused ? 1.5 : 1),
                    boxShadow: _isFocused ? [
                      BoxShadow(
                        color: AppTheme.pink.withOpacity(0.2),
                        blurRadius: 20, spreadRadius: -5),
                    ] : null,
                  ),
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    style: const TextStyle(
                      color: Colors.white, fontSize: 16),
                    cursorColor: AppTheme.pink,
                    decoration: InputDecoration(
                      hintText: _isFocused
                        ? 'Search songs, artists...'
                        : 'What do you want to listen to?',
                      hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.3),
                        fontSize: 14),
                      prefixIcon: Padding(
                        padding: const EdgeInsets.all(12),
                        child: ShaderMask(
                          shaderCallback: (b) =>
                            AppTheme.primaryGradient.createShader(b),
                          child: const Icon(Icons.search_rounded,
                            color: Colors.white, size: 22)),
                      ),
                      suffixIcon: query.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.close_rounded,
                              color: Colors.white.withOpacity(0.5),
                              size: 20),
                            onPressed: _clearSearch)
                        : Padding(
                            padding: const EdgeInsets.all(12),
                            child: ShaderMask(
                              shaderCallback: (b) =>
                                AppTheme.primaryGradient
                                  .createShader(b),
                              child: const Icon(Icons.mic_rounded,
                                color: Colors.white, size: 20)),
                          ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    ),
                    onChanged: (val) {
                      ref.read(searchQueryProvider.notifier)
                        .state = val;
                    },
                    onSubmitted: _onSearch,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = ['Songs', 'Artists', 'Albums', 'Playlists'];
    final selected = ref.watch(searchFilterProvider);

    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        itemBuilder: (_, i) {
          final isSelected = filters[i] == selected;
          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              ref.read(searchFilterProvider.notifier)
                .state = filters[i];
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: isSelected
                  ? AppTheme.primaryGradient : null,
                color: isSelected ? null
                  : Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                    ? Colors.transparent
                    : Colors.white.withOpacity(0.12)),
                boxShadow: isSelected ? [
                  BoxShadow(
                    color: AppTheme.pink.withOpacity(0.3),
                    blurRadius: 10, spreadRadius: -3),
                ] : null,
              ),
              child: Text(filters[i],
                style: TextStyle(
                  color: isSelected
                    ? Colors.white
                    : Colors.white.withOpacity(0.5),
                  fontSize: 13,
                  fontWeight: isSelected
                    ? FontWeight.w700 : FontWeight.w400)),
            ),
          ).animate()
            .fadeIn(duration: 300.ms, delay: (i * 50).ms)
            .slideX(begin: 0.2, end: 0,
              duration: 300.ms, delay: (i * 50).ms);
        },
      ),
    );
  }

  Widget _buildLanguageChips() {
    final languages = ['All', 'Hindi', 'English', 'Punjabi',
      'Tamil', 'Telugu'];
    final selected = ref.watch(searchLanguageProvider);

    return SizedBox(
      height: 36,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
        itemCount: languages.length,
        itemBuilder: (_, i) {
          final isSelected = languages[i] == selected;
          return GestureDetector(
            onTap: () {
              ref.read(searchLanguageProvider.notifier)
                .state = languages[i];
              final query =
                ref.read(searchQueryProvider);
              if (query.isNotEmpty) {
                final langQuery = languages[i] == 'All'
                  ? query
                  : '$query ${languages[i]}';
                ref.read(searchQueryProvider.notifier)
                  .state = langQuery;
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected
                  ? AppTheme.pink.withOpacity(0.2)
                  : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                    ? AppTheme.pink.withOpacity(0.5)
                    : Colors.white.withOpacity(0.08)),
              ),
              child: Text(languages[i],
                style: TextStyle(
                  color: isSelected
                    ? AppTheme.pink
                    : Colors.white.withOpacity(0.35),
                  fontSize: 11,
                  fontWeight: isSelected
                    ? FontWeight.w700 : FontWeight.w400)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      padding: const EdgeInsets.only(bottom: 160),
      physics: const BouncingScrollPhysics(),
      children: [
        // Recent searches
        _RecentSearches(
          onTap: (q) {
            _controller.text = q;
            ref.read(searchQueryProvider.notifier).state = q;
          },
        ),

        // Discover Premium
        _PremiumFeatureCards(
          onTap: (q) {
            _controller.text = q;
            ref.read(searchQueryProvider.notifier).state = q;
            ref.read(recentSearchesProvider.notifier).add(q);
          },
        ),

        // Trending searches
        _TrendingSearches(
          onTap: (q) {
            _controller.text = q;
            ref.read(searchQueryProvider.notifier).state = q;
            ref.read(recentSearchesProvider.notifier).add(q);
          },
        ),

        // Browse categories
        _BrowseCategories(
          onTap: (q) {
            _controller.text = q;
            ref.read(searchQueryProvider.notifier).state = q;
            ref.read(recentSearchesProvider.notifier).add(q);
          },
        ),
      ],
    );
  }

  Widget _buildSearchResults(AsyncValue<List<Song>> results) {
    return results.when(
      loading: () => _buildResultsShimmer(),
      error: (e, _) => Center(
        child: Text('Error: $e',
          style: const TextStyle(color: Colors.red))),
      data: (songs) => songs.isEmpty
        ? _buildNoResults()
        : _buildSongResults(songs),
    );
  }

  Widget _buildResultsShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 8,
      itemBuilder: (_, i) => Container(
        height: 72,
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16)),
      ).animate(onPlay: (c) => c.repeat())
        .shimmer(duration: 1200.ms,
          color: Colors.white.withOpacity(0.05)),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ShaderMask(
            shaderCallback: (b) =>
              AppTheme.primaryGradient.createShader(b),
            child: const Icon(Icons.search_off_rounded,
              color: Colors.white, size: 72)),
          const SizedBox(height: 16),
          const Text('No results found',
            style: TextStyle(color: Colors.white,
              fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('Try different keywords',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildSongResults(List<Song> songs) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 160),
      physics: const BouncingScrollPhysics(),
      itemCount: songs.length,
      itemBuilder: (context, index) => _SearchResultCard(
        song: songs[index],
        index: index,
      ).animate()
        .fadeIn(duration: 300.ms, delay: (index * 40).ms)
        .slideY(begin: 0.1, end: 0,
          duration: 300.ms, delay: (index * 40).ms),
    );
  }
}

// ─── SEARCH RESULT CARD ───────────────────────────────────────

class _SearchResultCard extends ConsumerWidget {
  final Song song;
  final int index;

  const _SearchResultCard({
    required this.song,
    required this.index,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentSong = ref.watch(currentSongProvider);
    final isPlaying = currentSong?.id == song.id;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        ref.read(currentSongProvider.notifier).state = song;
        ref.read(playerServiceProvider).playSong(song);
        ref.read(databaseServiceProvider).addToHistory(song);
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isPlaying ? [
                  AppTheme.pink.withOpacity(0.2),
                  AppTheme.purple.withOpacity(0.15),
                ] : [
                  Colors.white.withOpacity(0.06),
                  Colors.white.withOpacity(0.03),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isPlaying
                  ? AppTheme.pink.withOpacity(0.4)
                  : Colors.white.withOpacity(0.08),
                width: isPlaying ? 1.5 : 1),
              boxShadow: isPlaying ? [
                BoxShadow(
                  color: AppTheme.pink.withOpacity(0.2),
                  blurRadius: 15, spreadRadius: -5),
              ] : null,
            ),
            child: Row(
              children: [
                // Album art
                Stack(
                  children: [
                    Container(
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
                          width: 56, height: 56,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                            width: 56, height: 56,
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius:
                                BorderRadius.circular(12)),
                            child: const Icon(Icons.music_note,
                              color: Colors.white, size: 24),
                          ),
                        ),
                      ),
                    ),
                    // Playing indicator overlay
                    if (isPlaying)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(12)),
                          child: const Icon(
                            Icons.equalizer_rounded,
                            color: Colors.white, size: 20),
                        ),
                      ),
                  ],
                ),

                const SizedBox(width: 14),

                // Song info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(song.title,
                        style: TextStyle(
                          color: isPlaying
                            ? AppTheme.pink : Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(song.artist,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      // Language + duration tag
                      Row(
                        children: [
                          if (song.language.isNotEmpty)
                            _Tag(song.language.capitalize()),
                          const SizedBox(width: 6),
                          if (song.duration != '0')
                            _Tag(_formatDuration(song.duration)),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Play button
                Column(
                  children: [
                    Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                        gradient: isPlaying
                          ? AppTheme.primaryGradient
                          : LinearGradient(colors: [
                              Colors.white.withOpacity(0.1),
                              Colors.white.withOpacity(0.05),
                            ]),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isPlaying
                            ? Colors.transparent
                            : Colors.white.withOpacity(0.1)),
                        boxShadow: isPlaying ? [
                          BoxShadow(
                            color: AppTheme.pink.withOpacity(0.4),
                            blurRadius: 10, spreadRadius: -3),
                        ] : null,
                      ),
                      child: Icon(
                        isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                        color: Colors.white, size: 20),
                    ),
                    const SizedBox(height: 4),
                    // More options
                    Icon(Icons.more_vert_rounded,
                      color: Colors.white.withOpacity(0.3),
                      size: 16),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDuration(String seconds) {
    final s = int.tryParse(seconds) ?? 0;
    final m = s ~/ 60;
    final sec = s % 60;
    return '$m:${sec.toString().padLeft(2, '0')}';
  }
}

class _Tag extends StatelessWidget {
  final String label;
  const _Tag(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Colors.white.withOpacity(0.1))),
      child: Text(label,
        style: TextStyle(
          color: Colors.white.withOpacity(0.4),
          fontSize: 9,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5)),
    );
  }
}

// ─── RECENT SEARCHES ──────────────────────────────────────────

class _RecentSearches extends ConsumerWidget {
  final Function(String) onTap;
  const _RecentSearches({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recents = ref.watch(recentSearchesProvider);
    if (recents.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                ShaderMask(
                  shaderCallback: (b) =>
                    AppTheme.primaryGradient.createShader(b),
                  child: const Icon(Icons.history_rounded,
                    color: Colors.white, size: 18)),
                const SizedBox(width: 8),
                const Text('Recent',
                  style: TextStyle(color: Colors.white,
                    fontSize: 16, fontWeight: FontWeight.w700)),
              ]),
              GestureDetector(
                onTap: () => ref.read(
                  recentSearchesProvider.notifier).clear(),
                child: Text('Clear all',
                  style: TextStyle(
                    color: AppTheme.pink, fontSize: 12,
                    fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
        ...recents.map((q) => ListTile(
          contentPadding:
            const EdgeInsets.symmetric(horizontal: 20),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1))),
                child: Icon(Icons.history_rounded,
                  color: Colors.white.withOpacity(0.4),
                  size: 16)),
            ),
          ),
          title: Text(q,
            style: const TextStyle(color: Colors.white,
              fontSize: 14, fontWeight: FontWeight.w500)),
          trailing: GestureDetector(
            onTap: () => ref.read(
              recentSearchesProvider.notifier).remove(q),
            child: Icon(Icons.close_rounded,
              color: Colors.white.withOpacity(0.3), size: 16)),
          onTap: () => onTap(q),
        )),
        const SizedBox(height: 8),
      ],
    ).animate().fadeIn(duration: 400.ms);
  }
}

// ─── TRENDING SEARCHES ────────────────────────────────────────

class _TrendingSearches extends StatelessWidget {
  final Function(String) onTap;
  const _TrendingSearches({required this.onTap});

  static const _trending = [
    '🔥 Arijit Singh', '💜 AP Dhillon', '🎵 Trending 2025',
    '❤️ Romantic Hindi', '🌙 Night Vibes', '💃 Party Songs',
    '🎤 Shreya Ghoshal', '🎸 Bollywood Hits',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Row(children: [
            ShaderMask(
              shaderCallback: (b) =>
                AppTheme.primaryGradient.createShader(b),
              child: const Icon(Icons.trending_up_rounded,
                color: Colors.white, size: 18)),
            const SizedBox(width: 8),
            const Text('Trending Searches',
              style: TextStyle(color: Colors.white,
                fontSize: 16, fontWeight: FontWeight.w700)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8, runSpacing: 8,
            children: _trending.asMap().entries.map((e) =>
              GestureDetector(
                onTap: () => onTap(e.value
                  .replaceAll(RegExp(r'[^\w\s]'), '').trim()),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          AppTheme.pink.withOpacity(0.12),
                          AppTheme.purple.withOpacity(0.08),
                        ]),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppTheme.pink.withOpacity(0.2))),
                      child: Text(e.value,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                          fontWeight: FontWeight.w500)),
                    ),
                  ),
                ),
              ).animate()
                .fadeIn(duration: 300.ms,
                  delay: (e.key * 50).ms)
                .scale(begin: const Offset(0.9, 0.9),
                  duration: 300.ms,
                  delay: (e.key * 50).ms,
                  curve: Curves.easeOutBack),
            ).toList(),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ─── PREMIUM FEATURE CARDS ──────────────────────────────────────

class _PremiumFeatureCards extends StatelessWidget {
  final Function(String) onTap;
  const _PremiumFeatureCards({required this.onTap});

  static const _cards = [
    {
      'title': 'New In Pop',
      'subtitle': 'The latest hits',
      'image': 'https://picsum.photos/seed/pop/400/400',
      'query': 'new pop songs'
    },
    {
      'title': 'Chill Vibes',
      'subtitle': 'Relaxing tunes',
      'image': 'https://picsum.photos/seed/chill/400/400',
      'query': 'chill relax lofi'
    },
    {
      'title': 'Workout',
      'subtitle': 'Beast mode',
      'image': 'https://picsum.photos/seed/workout/400/400',
      'query': 'workout gym hype'
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Row(children: [
            ShaderMask(
              shaderCallback: (b) =>
                AppTheme.primaryGradient.createShader(b),
              child: const Icon(Icons.star_rounded,
                color: Colors.white, size: 18)),
            const SizedBox(width: 8),
            const Text('Discover',
              style: TextStyle(color: Colors.white,
                fontSize: 16, fontWeight: FontWeight.w700)),
          ]),
        ),
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _cards.length,
            itemBuilder: (_, i) {
              final card = _cards[i];
              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onTap(card['query']!);
                },
                child: Container(
                  width: 240,
                  margin: const EdgeInsets.only(right: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(
                          imageUrl: card['image']!,
                          fit: BoxFit.cover,
                          memCacheWidth: 400,
                          placeholder: (context, url) => Container(
                            color: Colors.grey[900],
                            child: const Center(
                              child: CircularProgressIndicator(color: AppTheme.pink),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey[900],
                            child: const Icon(Icons.music_note_rounded, color: Colors.white54, size: 40),
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.9),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 16, left: 16, right: 16,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(card['title']!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900)),
                              const SizedBox(height: 2),
                              Text(card['subtitle']!,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 13)),
                            ],
                          ),
                        ),
                        Positioned(
                          top: 12, right: 12,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.3),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.play_arrow_rounded,
                                  color: Colors.white, size: 16),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ).animate()
                .fadeIn(duration: 400.ms, delay: (i * 100).ms)
                .slideX(begin: 0.1, end: 0, duration: 400.ms, delay: (i * 100).ms);
            },
          ),
        ),
      ],
    );
  }
}

// ─── BROWSE CATEGORIES ────────────────────────────────────────

class _BrowseCategories extends StatelessWidget {
  final Function(String) onTap;
  const _BrowseCategories({required this.onTap});

  static const _categories = [
    {'label': 'Bollywood', 'emoji': '🎬', 'image': 'https://picsum.photos/seed/bollywood/400/400'},
    {'label': 'Punjabi', 'emoji': '🎵', 'image': 'https://picsum.photos/seed/punjabi/400/400'},
    {'label': 'Romance', 'emoji': '❤️', 'image': 'https://picsum.photos/seed/romance/400/400'},
    {'label': 'Party', 'emoji': '🎉', 'image': 'https://picsum.photos/seed/party/400/400'},
    {'label': 'Devotional', 'emoji': '🙏', 'image': 'https://picsum.photos/seed/devotional/400/400'},
    {'label': 'Indie', 'emoji': '🎸', 'image': 'https://picsum.photos/seed/indie/400/400'},
    {'label': 'Hip Hop', 'emoji': '🎤', 'image': 'https://picsum.photos/seed/hiphop/400/400'},
    {'label': 'Classical', 'emoji': '🪕', 'image': 'https://picsum.photos/seed/classical/400/400'},
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Row(children: [
            ShaderMask(
              shaderCallback: (b) =>
                AppTheme.primaryGradient.createShader(b),
              child: const Icon(Icons.grid_view_rounded,
                color: Colors.white, size: 18)),
            const SizedBox(width: 8),
            const Text('Browse All',
              style: TextStyle(color: Colors.white,
                fontSize: 16, fontWeight: FontWeight.w700)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.4,
              ),
            itemCount: _categories.length,
            itemBuilder: (_, i) {
              final cat = _categories[i];
              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onTap(cat['label'] as String);
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: cat['image'] as String,
                        fit: BoxFit.cover,
                        memCacheWidth: 400,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[900],
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[900],
                          child: const Icon(Icons.error_outline, color: Colors.white54),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.8),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 12, left: 12, right: 12,
                        child: Row(
                          children: [
                            Text(cat['emoji'] as String,
                              style: const TextStyle(fontSize: 18)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(cat['label'] as String,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate()
                .fadeIn(duration: 300.ms, delay: (i * 40).ms)
                .scale(begin: const Offset(0.9, 0.9),
                  end: const Offset(1, 1),
                  duration: 300.ms, delay: (i * 40).ms,
                  curve: Curves.easeOutBack);
            },
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}


// ─── EXTENSION ────────────────────────────────────────────────

extension StringExtension on String {
  String capitalize() => isEmpty ? this
    : '${this[0].toUpperCase()}${substring(1)}';
}