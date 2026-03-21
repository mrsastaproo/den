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
import '../../core/providers/queue_meta.dart';
import '../../core/models/song.dart';
import '../../core/theme/app_theme.dart';

// ─── PROVIDERS ────────────────────────────────────────────────

final searchFilterProvider =
    StateProvider<String>((ref) => 'All');

final recentSearchesProvider =
    StateNotifierProvider<RecentSearchesNotifier, List<String>>(
        (ref) => RecentSearchesNotifier());

class RecentSearchesNotifier extends StateNotifier<List<String>> {
  RecentSearchesNotifier() : super([]) { _load(); }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    state = p.getStringList('recent_searches') ?? [];
  }

  Future<void> add(String q) async {
    if (q.trim().isEmpty) return;
    final updated =
        [q.trim(), ...state.where((s) => s != q.trim())].take(10).toList();
    state = updated;
    final p = await SharedPreferences.getInstance();
    await p.setStringList('recent_searches', updated);
  }

  Future<void> remove(String q) async {
    state = state.where((s) => s != q).toList();
    final p = await SharedPreferences.getInstance();
    await p.setStringList('recent_searches', state);
  }

  Future<void> clear() async {
    state = [];
    final p = await SharedPreferences.getInstance();
    await p.remove('recent_searches');
  }
}

// ─── SEARCH SCREEN ────────────────────────────────────────────

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});
  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen>
    with SingleTickerProviderStateMixin {
  final _ctrl    = TextEditingController();
  final _focus   = FocusNode();
  bool _focused  = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() =>
        setState(() => _focused = _focus.hasFocus));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _search(String q) {
    _ctrl.text = q;
    ref.read(searchQueryProvider.notifier).state = q;
    if (q.trim().isNotEmpty) {
      ref.read(recentSearchesProvider.notifier).add(q.trim());
    }
  }

  void _clear() {
    _ctrl.clear();
    ref.read(searchQueryProvider.notifier).state = '';
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final query   = ref.watch(searchQueryProvider);
    final results = ref.watch(searchResultsProvider);
    final filter  = ref.watch(searchFilterProvider);
    final recents = ref.watch(recentSearchesProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(children: [

          // ── Header + Search bar ──────────────────────────
          _SearchHeader(
            ctrl: _ctrl,
            focus: _focus,
            focused: _focused,
            query: query,
            onChanged: (q) =>
                ref.read(searchQueryProvider.notifier).state = q,
            onSubmit: (q) {
              _search(q);
              FocusScope.of(context).unfocus();
            },
            onClear: _clear,
          ),

          // ── Filter chips (only when results) ────────────
          if (query.isNotEmpty)
            _FilterChips(
              selected: filter,
              onSelect: (f) {
                HapticFeedback.selectionClick();
                ref.read(searchFilterProvider.notifier).state = f;
              },
            ),

          // ── Body ─────────────────────────────────────────
          Expanded(
            child: query.isEmpty
                ? _EmptyState(
                    recents: recents,
                    onRecentTap: (q) {
                      _search(q);
                      FocusScope.of(context).unfocus();
                    },
                    onRecentRemove: (q) => ref
                        .read(recentSearchesProvider.notifier)
                        .remove(q),
                    onClearAll: () => ref
                        .read(recentSearchesProvider.notifier)
                        .clear(),
                    onCategoryTap: (cat) {
                      _search(cat);
                      FocusScope.of(context).unfocus();
                    },
                  )
                : _ResultsBody(
                    results: results,
                    filter: filter,
                    query: query,
                  ),
          ),
        ]),
      ),
    );
  }
}

// ─── SEARCH HEADER ────────────────────────────────────────────

class _SearchHeader extends StatelessWidget {
  final TextEditingController ctrl;
  final FocusNode focus;
  final bool focused, query;
  final String queryStr;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmit;
  final VoidCallback onClear;

  // ignore: avoid_bool_literals_in_conditional_expressions
  const _SearchHeader({
    required this.ctrl,
    required this.focus,
    required this.focused,
    required String query,
    required this.onChanged,
    required this.onSubmit,
    required this.onClear,
  })  : queryStr = query,
        query = query != '';

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16, right: 16, bottom: 12,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.black.withOpacity(0.65),
                Colors.transparent,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Column(children: [
            // Title row
            if (!focused)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(children: [
                  ShaderMask(
                    shaderCallback: (b) =>
                        AppTheme.primaryGradient.createShader(b),
                    child: const Icon(Icons.search_rounded,
                        color: Colors.white, size: 24)),
                  const SizedBox(width: 10),
                  const Text('Search',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5)),
                ]).animate().fadeIn(duration: 300.ms),
              ),

            // Search bar
            Row(children: [
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: focused
                          ? AppTheme.pink.withOpacity(0.45)
                          : Colors.white.withOpacity(0.1),
                      width: focused ? 1.5 : 1,
                    ),
                    boxShadow: focused ? [
                      BoxShadow(
                        color: AppTheme.pink.withOpacity(0.12),
                        blurRadius: 16, spreadRadius: -4),
                    ] : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        color: Colors.white.withOpacity(
                            focused ? 0.07 : 0.05),
                        child: TextField(
                          controller: ctrl,
                          focusNode: focus,
                          onChanged: onChanged,
                          onSubmitted: onSubmit,
                          textInputAction: TextInputAction.search,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 15),
                          cursorColor: AppTheme.pink,
                          decoration: InputDecoration(
                            hintText: 'Songs, artists, albums...',
                            hintStyle: TextStyle(
                              color: Colors.white.withOpacity(0.3),
                              fontSize: 15),
                            prefixIcon: Icon(Icons.search_rounded,
                              color: focused
                                  ? AppTheme.pink.withOpacity(0.8)
                                  : Colors.white.withOpacity(0.35),
                              size: 20),
                            suffixIcon: queryStr.isNotEmpty
                                ? GestureDetector(
                                    onTap: onClear,
                                    child: Icon(Icons.close_rounded,
                                      color: Colors.white.withOpacity(0.4),
                                      size: 18))
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (focused) ...[
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () {
                    FocusScope.of(context).unfocus();
                    if (queryStr.isEmpty) onClear();
                  },
                  child: Text('Cancel',
                    style: TextStyle(
                      color: AppTheme.pink.withOpacity(0.9),
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
                ),
              ],
            ]),
          ]),
        ),
      ),
    );
  }
}

// ─── FILTER CHIPS ─────────────────────────────────────────────

class _FilterChips extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;

  const _FilterChips({required this.selected, required this.onSelect});

  static const _filters = ['All', 'Songs', 'Artists', 'Albums'];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: _filters.length,
        itemBuilder: (_, i) {
          final f = _filters[i];
          final sel = f == selected;
          return GestureDetector(
            onTap: () => onSelect(f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                gradient: sel ? AppTheme.primaryGradient : null,
                color: sel ? null : Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: sel
                      ? Colors.transparent
                      : Colors.white.withOpacity(0.12)),
              ),
              child: Text(f,
                style: TextStyle(
                  color: sel ? Colors.white : Colors.white.withOpacity(0.6),
                  fontSize: 13,
                  fontWeight: sel ? FontWeight.w700 : FontWeight.w500)),
            ),
          );
        },
      ),
    );
  }
}

// ─── EMPTY STATE (recents + browse) ───────────────────────────

class _EmptyState extends StatelessWidget {
  final List<String> recents;
  final ValueChanged<String> onRecentTap;
  final ValueChanged<String> onRecentRemove;
  final VoidCallback onClearAll;
  final ValueChanged<String> onCategoryTap;

  const _EmptyState({
    required this.recents,
    required this.onRecentTap,
    required this.onRecentRemove,
    required this.onClearAll,
    required this.onCategoryTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // Recent searches
        if (recents.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Recent Searches',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
                GestureDetector(
                  onTap: onClearAll,
                  child: Text('Clear all',
                    style: TextStyle(
                      color: AppTheme.pink.withOpacity(0.8),
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
                ),
              ],
            ),
          ),
          ...recents.asMap().entries.map((e) => _RecentTile(
            query: e.value,
            onTap: () => onRecentTap(e.value),
            onRemove: () => onRecentRemove(e.value),
          ).animate().fadeIn(
              delay: Duration(milliseconds: e.key * 30),
              duration: 300.ms)),
          const SizedBox(height: 8),
          Divider(color: Colors.white.withOpacity(0.06),
              indent: 20, endIndent: 20),
        ],

        // Browse categories
        _BrowseSection(onTap: onCategoryTap),

        const SizedBox(height: 160),
      ],
    );
  }
}

class _RecentTile extends StatelessWidget {
  final String query;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _RecentTile({
    required this.query,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.history_rounded,
              color: Colors.white.withOpacity(0.4), size: 18)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(query,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500)),
          ),
          GestureDetector(
            onTap: onRemove,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(Icons.close_rounded,
                color: Colors.white.withOpacity(0.3), size: 16)),
          ),
        ]),
      ),
    );
  }
}

// ─── BROWSE SECTION ───────────────────────────────────────────

class _BrowseSection extends StatelessWidget {
  final ValueChanged<String> onTap;
  const _BrowseSection({required this.onTap});

  static const _cats = [
    {'label': 'Bollywood',   'emoji': '🎬', 'c1': Color(0xFFFFB3C6), 'c2': Color(0xFFFF85A1)},
    {'label': 'Punjabi',     'emoji': '🎵', 'c1': Color(0xFFB794FF), 'c2': Color(0xFFD4B8FF)},
    {'label': 'Romance',     'emoji': '❤️', 'c1': Color(0xFFFF6B6B), 'c2': Color(0xFFFFB3C6)},
    {'label': 'Party',       'emoji': '🎉', 'c1': Color(0xFFFF85A1), 'c2': Color(0xFFB794FF)},
    {'label': 'Devotional',  'emoji': '🙏', 'c1': Color(0xFFFFD700), 'c2': Color(0xFFFF85A1)},
    {'label': 'Indie',       'emoji': '🎸', 'c1': Color(0xFF89CFF0), 'c2': Color(0xFFB794FF)},
    {'label': 'Hip Hop',     'emoji': '🎤', 'c1': Color(0xFFB794FF), 'c2': Color(0xFF89CFF0)},
    {'label': 'Classical',   'emoji': '🪕', 'c1': Color(0xFFD4B8FF), 'c2': Color(0xFFFFD700)},
    {'label': 'Chill',       'emoji': '🌊', 'c1': Color(0xFF89CFF0), 'c2': Color(0xFFD4B8FF)},
    {'label': 'Workout',     'emoji': '💪', 'c1': Color(0xFFFF6B6B), 'c2': Color(0xFFFFB347)},
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
              child: const Icon(Icons.grid_view_rounded,
                  color: Colors.white, size: 18)),
            const SizedBox(width: 8),
            const Text('Browse All',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700)),
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
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.1,
            ),
            itemCount: _cats.length,
            itemBuilder: (_, i) {
              final cat = _cats[i];
              final c1  = cat['c1'] as Color;
              final c2  = cat['c2'] as Color;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onTap('${cat['label']} hindi songs');
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [c1, c2],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Stack(children: [
                      // Decorative circle
                      Positioned(
                        right: -16, bottom: -16,
                        child: Container(
                          width: 72, height: 72,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.12),
                            shape: BoxShape.circle)),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        child: Row(children: [
                          Text(cat['emoji'] as String,
                            style: const TextStyle(fontSize: 22)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(cat['label'] as String,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.2),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis)),
                        ]),
                      ),
                    ]),
                  ),
                ),
              ).animate()
                  .fadeIn(delay: Duration(milliseconds: i * 35), duration: 300.ms)
                  .scale(begin: const Offset(0.92, 0.92),
                    delay: Duration(milliseconds: i * 35),
                    duration: 300.ms, curve: Curves.easeOutBack);
            },
          ),
        ),
      ],
    );
  }
}

// ─── RESULTS BODY ─────────────────────────────────────────────

class _ResultsBody extends ConsumerWidget {
  final AsyncValue<List<Song>> results;
  final String filter;
  final String query;

  const _ResultsBody({
    required this.results,
    required this.filter,
    required this.query,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return results.when(
      loading: () => _buildShimmer(),
      error: (e, _) => Center(
        child: Text('Search error: $e',
          style: const TextStyle(color: Colors.red))),
      data: (songs) {
        if (songs.isEmpty) {
          return _NoResults(query: query);
        }

        // Filter songs by type chip (simplified since API returns songs)
        final display = filter == 'All' ? songs : songs;

        return ListView(
          padding: const EdgeInsets.only(bottom: 160),
          children: [
            // Result count
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
              child: Text(
                '${display.length} results for "$query"',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
            ),

            // Top result card (first song, prominent)
            if (display.isNotEmpty)
              _TopResult(
                song: display.first,
                onTap: () => playQueue(ref, display, 0,
                  meta: const QueueMeta(context: QueueContext.general)),
              ).animate().fadeIn(duration: 350.ms)
                  .slideY(begin: 0.05, end: 0, duration: 350.ms),

            // Rest of results
            ...display.skip(1).toList().asMap().entries.map((e) {
              final i    = e.key;
              final song = e.value;
              return _ResultTile(
                song: song,
                index: i + 1,
                onTap: () => playQueue(ref, display, i + 1,
                  meta: const QueueMeta(context: QueueContext.general)),
                onMore: () => _showSongOptions(context, ref, song, display, i + 1),
              ).animate()
                  .fadeIn(delay: Duration(milliseconds: i * 30), duration: 300.ms)
                  .slideX(begin: 0.05, end: 0,
                    delay: Duration(milliseconds: i * 30), duration: 300.ms);
            }),
          ],
        );
      },
    );
  }

  Widget _buildShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 8,
      itemBuilder: (_, i) => Container(
        height: 64, margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14)),
      ).animate(onPlay: (c) => c.repeat())
          .shimmer(duration: 1200.ms,
            color: Colors.white.withOpacity(0.04)),
    );
  }

  void _showSongOptions(BuildContext context, WidgetRef ref,
      Song song, List<Song> playlist, int index) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _SongOptionsSheet(song: song, ref: ref,
          playlist: playlist, index: index),
    );
  }
}

// ─── TOP RESULT ───────────────────────────────────────────────

class _TopResult extends StatelessWidget {
  final Song song;
  final VoidCallback onTap;

  const _TopResult({required this.song, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              ShaderMask(
                shaderCallback: (b) =>
                    AppTheme.primaryGradient.createShader(b),
                child: const Icon(Icons.star_rounded,
                    color: Colors.white, size: 16)),
              const SizedBox(width: 6),
              const Text('Top Result',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
            ]),
          ),
          GestureDetector(
            onTap: onTap,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      Colors.white.withOpacity(0.07),
                      Colors.white.withOpacity(0.03),
                    ]),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.1))),
                  child: Row(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: CachedNetworkImage(
                        imageUrl: song.image,
                        width: 72, height: 72, fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          width: 72, height: 72,
                          color: AppTheme.bgTertiary,
                          child: const Icon(Icons.music_note,
                              color: AppTheme.pink, size: 32)))),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(song.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Text(song.artist,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    Container(
                      width: 42, height: 42,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle),
                      child: const Icon(Icons.play_arrow_rounded,
                          color: Colors.black, size: 24)),
                  ]),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── RESULT TILE ──────────────────────────────────────────────

class _ResultTile extends StatelessWidget {
  final Song song;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onMore;

  const _ResultTile({
    required this.song,
    required this.index,
    required this.onTap,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        child: Row(children: [
          // Art
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: CachedNetworkImage(
              imageUrl: song.image,
              width: 52, height: 52, fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Container(
                width: 52, height: 52, color: AppTheme.bgTertiary,
                child: const Icon(Icons.music_note,
                    color: AppTheme.pink, size: 22)))),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(song.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(song.artist,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.45),
                    fontSize: 12),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          // Duration
          Text(_fmt(int.tryParse(song.duration) ?? 0),
            style: TextStyle(
              color: Colors.white.withOpacity(0.3),
              fontSize: 12)),
          const SizedBox(width: 4),
          // More
          GestureDetector(
            onTap: onMore,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(Icons.more_vert_rounded,
                color: Colors.white.withOpacity(0.4), size: 18)),
          ),
        ]),
      ),
    );
  }

  String _fmt(int s) {
    if (s <= 0) return '';
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }
}

// ─── NO RESULTS ───────────────────────────────────────────────

class _NoResults extends StatelessWidget {
  final String query;
  const _NoResults({required this.query});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ShaderMask(
              shaderCallback: (b) =>
                  AppTheme.primaryGradient.createShader(b),
              child: const Icon(Icons.search_off_rounded,
                  color: Colors.white, size: 64)),
            const SizedBox(height: 16),
            Text('No results for',
              style: TextStyle(
                color: Colors.white.withOpacity(0.45),
                fontSize: 14)),
            const SizedBox(height: 4),
            Text('"$query"',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700),
              textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('Try different keywords or\ncheck spelling',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.35),
                fontSize: 13,
                height: 1.5)),
          ],
        ),
      ).animate().fadeIn(duration: 400.ms)
          .scale(begin: const Offset(0.95, 0.95),
            duration: 400.ms, curve: Curves.easeOutBack),
    );
  }
}

// ─── SONG OPTIONS SHEET ───────────────────────────────────────

class _SongOptionsSheet extends StatelessWidget {
  final Song song;
  final WidgetRef ref;
  final List<Song> playlist;
  final int index;

  const _SongOptionsSheet({
    required this.song,
    required this.ref,
    required this.playlist,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.75),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: Colors.white.withOpacity(0.08))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 36, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Row(children: [
                ClipRRect(borderRadius: BorderRadius.circular(10),
                  child: CachedNetworkImage(imageUrl: song.image,
                    width: 50, height: 50, fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                      width: 50, height: 50, color: AppTheme.bgTertiary,
                      child: const Icon(Icons.music_note, color: AppTheme.pink)))),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(song.title,
                      style: const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.w700, fontSize: 14),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(song.artist,
                      style: TextStyle(color: Colors.white.withOpacity(0.5),
                        fontSize: 12),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                )),
              ]),
              const SizedBox(height: 14),
              Divider(color: Colors.white.withOpacity(0.08)),
              const SizedBox(height: 6),
              ...[
                (Icons.favorite_rounded,     'Like Song',          AppTheme.pink),
                (Icons.playlist_add_rounded, 'Add to Playlist',    AppTheme.purple),
                (Icons.queue_rounded,        'Add to Queue',       AppTheme.pinkDeep),
                (Icons.person_rounded,       'Go to Artist',       Colors.white70),
                (Icons.share_rounded,        'Share',              Colors.white70),
              ].map((o) => ListTile(
                leading: Icon(o.$1, color: o.$3, size: 22),
                title: Text(o.$2,
                  style: const TextStyle(color: Colors.white,
                    fontSize: 14, fontWeight: FontWeight.w500)),
                onTap: () async {
                  if (o.$2 == 'Like Song') {
                    await ref.read(databaseServiceProvider).likeSong(song);
                  } else if (o.$2 == 'Add to Queue') {
                    final pl  = ref.read(currentPlaylistProvider);
                    final idx = ref.read(currentSongIndexProvider);
                    final nl  = [...pl]..insert(idx + 1, song);
                    ref.read(currentPlaylistProvider.notifier).state = nl;
                  }
                  if (context.mounted) Navigator.pop(context);
                  HapticFeedback.selectionClick();
                },
                contentPadding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              )),
            ],
          ),
        ),
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}