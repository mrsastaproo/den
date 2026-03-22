import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/services/database_service.dart';
import '../../core/services/player_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/providers/music_providers.dart';
import '../../core/providers/queue_meta.dart';
import '../../core/models/song.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/social_share_sheet.dart';

// ─── VIEW MODE ────────────────────────────────────────────────

enum _ViewMode { list, grid, compact }

enum _FilterChip { all, playlists, liked, artists, albums }

// ─── LOCAL STATE PROVIDERS ────────────────────────────────────

final _libraryFilterProvider =
    StateProvider<_FilterChip>((ref) => _FilterChip.all);

final _libraryViewModeProvider =
    StateProvider<_ViewMode>((ref) => _ViewMode.list);

final _librarySortProvider =
    StateProvider<String>((ref) => 'Recently Added');

// ─── LIBRARY SCREEN ───────────────────────────────────────────

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  bool _isSearching = false;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final filter = ref.watch(_libraryFilterProvider);
    final viewMode = ref.watch(_libraryViewModeProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: Column(
        children: [
          // ── Sticky Header ──────────────────────────────────
          _LibraryHeader(
            isSearching: _isSearching,
            searchController: _searchController,
            onSearchToggle: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchQuery = '';
                  _searchController.clear();
                }
              });
            },
            onSearchChanged: (q) => setState(() => _searchQuery = q),
            onAdd: () => _showAddSheet(context),
            viewMode: viewMode,
            onViewToggle: () {
              HapticFeedback.selectionClick();
              final modes = _ViewMode.values;
              final next = modes[(viewMode.index + 1) % modes.length];
              ref.read(_libraryViewModeProvider.notifier).state = next;
            },
            onSort: () => _showSortSheet(context),
          ),

          // ── Filter Chips ───────────────────────────────────
          if (!_isSearching)
            _FilterChips(selected: filter, onSelect: (f) {
              HapticFeedback.selectionClick();
              ref.read(_libraryFilterProvider.notifier).state = f;
            }),

          // ── Body ───────────────────────────────────────────
          Expanded(
            child: user == null
                ? _LoginPrompt()
                : _LibraryBody(
                    filter: filter,
                    viewMode: viewMode,
                    searchQuery: _searchQuery,
                  ),
          ),
        ],
      ),
    );
  }

  void _showAddSheet(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddSheet(
        onCreatePlaylist: () {
          Navigator.pop(context);
          _showCreatePlaylist(context);
        },
      ),
    );
  }

  void _showCreatePlaylist(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => _CreatePlaylistDialog(
        controller: ctrl,
        onCreate: () async {
          if (ctrl.text.trim().isNotEmpty) {
            await ref.read(databaseServiceProvider)
                .createPlaylist(ctrl.text.trim());
            if (context.mounted) Navigator.pop(context);
            HapticFeedback.mediumImpact();
          }
        },
      ),
    );
  }

  void _showSortSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _SortSheet(
        current: ref.read(_librarySortProvider),
        onSelect: (s) {
          ref.read(_librarySortProvider.notifier).state = s;
          Navigator.pop(context);
        },
      ),
    );
  }
}

// ─── LIBRARY HEADER ───────────────────────────────────────────

class _LibraryHeader extends StatelessWidget {
  final bool isSearching;
  final TextEditingController searchController;
  final VoidCallback onSearchToggle;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onAdd;
  final _ViewMode viewMode;
  final VoidCallback onViewToggle;
  final VoidCallback onSort;

  const _LibraryHeader({
    required this.isSearching,
    required this.searchController,
    required this.onSearchToggle,
    required this.onSearchChanged,
    required this.onAdd,
    required this.viewMode,
    required this.onViewToggle,
    required this.onSort,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 12,
            left: 20, right: 20, bottom: 12,
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
          child: Column(
            children: [
              Row(
                children: [
                  // Title or search bar
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: isSearching
                          ? _SearchField(
                              controller: searchController,
                              onChanged: onSearchChanged,
                            )
                          : Row(
                              children: [
                                ShaderMask(
                                  shaderCallback: (b) =>
                                      AppTheme.primaryGradient
                                          .createShader(b),
                                  child: const Icon(
                                      Icons.library_music_rounded,
                                      color: Colors.white,
                                      size: 26)),
                                const SizedBox(width: 10),
                                const Text(
                                  'Your Library',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Search toggle
                  _HeaderBtn(
                    icon: isSearching
                        ? Icons.close_rounded
                        : Icons.search_rounded,
                    onTap: onSearchToggle,
                  ),
                  const SizedBox(width: 8),
                  // Sort
                  _HeaderBtn(
                    icon: Icons.sort_rounded,
                    onTap: onSort,
                  ),
                  const SizedBox(width: 8),
                  // View toggle
                  _HeaderBtn(
                    icon: viewMode == _ViewMode.grid
                        ? Icons.view_list_rounded
                        : viewMode == _ViewMode.compact
                            ? Icons.grid_view_rounded
                            : Icons.density_small_rounded,
                    onTap: onViewToggle,
                  ),
                  const SizedBox(width: 8),
                  // Add
                  _AddBtn(onTap: onAdd),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _HeaderBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: Colors.white.withOpacity(0.1)),
            ),
            child: Icon(icon,
                color: Colors.white.withOpacity(0.8), size: 17),
          ),
        ),
      ),
    );
  }
}

class _AddBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _AddBtn({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34, height: 34,
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: AppTheme.pink.withOpacity(0.35),
              blurRadius: 10, spreadRadius: -3,
            ),
          ],
        ),
        child: const Icon(Icons.add_rounded,
            color: Colors.white, size: 20),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const _SearchField(
      {required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: TextField(
          controller: controller,
          autofocus: true,
          onChanged: onChanged,
          style: const TextStyle(
              color: Colors.white, fontSize: 14),
          cursorColor: AppTheme.pink,
          decoration: InputDecoration(
            hintText: 'Search in library...',
            hintStyle: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 14),
            prefixIcon: Icon(Icons.search_rounded,
                color: Colors.white.withOpacity(0.4),
                size: 18),
            filled: true,
            fillColor: Colors.white.withOpacity(0.08),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 10),
          ),
        ),
      ),
    );
  }
}

// ─── FILTER CHIPS ─────────────────────────────────────────────

class _FilterChips extends StatelessWidget {
  final _FilterChip selected;
  final ValueChanged<_FilterChip> onSelect;

  const _FilterChips(
      {required this.selected, required this.onSelect});

  static const _labels = {
    _FilterChip.all: 'All',
    _FilterChip.playlists: 'Playlists',
    _FilterChip.liked: 'Liked Songs',
    _FilterChip.artists: 'Artists',
    _FilterChip.albums: 'Albums',
  };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 4),
        children: _FilterChip.values.map((f) {
          final isSelected = f == selected;
          return GestureDetector(
            onTap: () => onSelect(f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? AppTheme.primaryGradient
                    : null,
                color: isSelected
                    ? null
                    : Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? Colors.transparent
                      : Colors.white.withOpacity(0.12),
                ),
              ),
              child: Text(
                _labels[f]!,
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : Colors.white.withOpacity(0.6),
                  fontSize: 13,
                  fontWeight: isSelected
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── LIBRARY BODY ─────────────────────────────────────────────

class _LibraryBody extends ConsumerWidget {
  final _FilterChip filter;
  final _ViewMode viewMode;
  final String searchQuery;

  const _LibraryBody({
    required this.filter,
    required this.viewMode,
    required this.searchQuery,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liked = ref.watch(likedSongsProvider).value ?? [];
    final playlists =
        ref.watch(playlistsProvider).value ?? [];
    final history =
        ref.watch(historyProvider).value ?? [];

    // Apply search filter
    List<Song> filteredLiked = searchQuery.isEmpty
        ? liked
        : liked
            .where((s) =>
                s.title.toLowerCase().contains(
                    searchQuery.toLowerCase()) ||
                s.artist.toLowerCase().contains(
                    searchQuery.toLowerCase()))
            .toList();

    List filteredPlaylists = searchQuery.isEmpty
        ? playlists
        : playlists
            .where((p) => (p['name'] as String)
                .toLowerCase()
                .contains(searchQuery.toLowerCase()))
            .toList();

    return ScrollConfiguration(
      behavior: _NoOverscrollBehavior(),
      child: CustomScrollView(
      physics: const ClampingScrollPhysics(),
      slivers: [
        // ── Pinned Liked Songs card (Spotify-style) ──────
        if (filter == _FilterChip.all ||
            filter == _FilterChip.liked)
          SliverToBoxAdapter(
            child: _LikedSongsBanner(
              count: filteredLiked.length,
              songs: filteredLiked,
            ),
          ),

        // ── Playlists ────────────────────────────────────
        if (filter == _FilterChip.all ||
            filter == _FilterChip.playlists) ...[
          if (filteredPlaylists.isNotEmpty)
            SliverToBoxAdapter(
              child: _SectionLabel(
                  label: 'Playlists',
                  count: filteredPlaylists.length),
            ),
          if (viewMode == _ViewMode.grid)
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16),
              sliver: SliverGrid(
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.82,
                ),
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _PlaylistGridCard(
                      playlist: filteredPlaylists[i]),
                  childCount: filteredPlaylists.length,
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => _PlaylistListTile(
                    playlist: filteredPlaylists[i],
                    compact:
                        viewMode == _ViewMode.compact),
                childCount: filteredPlaylists.length,
              ),
            ),
          if (filteredPlaylists.isEmpty &&
              filter == _FilterChip.playlists)
            SliverToBoxAdapter(
              child: _EmptyState(
                icon: Icons.queue_music_rounded,
                title: 'No playlists yet',
                subtitle: 'Tap + to create your\nfirst playlist',
              ),
            ),
        ],

        // ── Liked Songs List ─────────────────────────────
        if (filter == _FilterChip.liked) ...[
          if (filteredLiked.isNotEmpty)
            SliverToBoxAdapter(
              child: _SectionLabel(
                  label: 'Liked Songs',
                  count: filteredLiked.length),
            ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => _SongTile(
                song: filteredLiked[i],
                playlist: filteredLiked,
                index: i,
                compact: viewMode == _ViewMode.compact,
                trailing: _SongTileTrailing.unlike,
                onTrailing: () => ref
                    .read(databaseServiceProvider)
                    .unlikeSong(filteredLiked[i].id),
              ),
              childCount: filteredLiked.length,
            ),
          ),
          if (filteredLiked.isEmpty)
            SliverToBoxAdapter(
              child: _EmptyState(
                icon: Icons.favorite_border_rounded,
                title: 'No liked songs',
                subtitle:
                    'Tap ♥ on any song\nto save it here',
              ),
            ),
        ],

        // ── Recent History ───────────────────────────────
        if (filter == _FilterChip.all &&
            history.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: _SectionLabel(
                label: 'Recently Played',
                count: history.length),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => _SongTile(
                song: history[i],
                playlist: history,
                index: i,
                compact: viewMode == _ViewMode.compact,
                trailing: _SongTileTrailing.more,
              ),
              childCount:
                  history.length > 10 ? 10 : history.length,
            ),
          ),
        ],

        // ── Artists placeholder ──────────────────────────
        if (filter == _FilterChip.artists)
          SliverToBoxAdapter(
            child: _EmptyState(
              icon: Icons.person_rounded,
              title: 'No followed artists',
              subtitle:
                  'Follow artists to see them here',
              actionLabel: 'Browse Artists',
              onAction: () {},
            ),
          ),

        // ── Albums placeholder ───────────────────────────
        if (filter == _FilterChip.albums)
          SliverToBoxAdapter(
            child: _EmptyState(
              icon: Icons.album_rounded,
              title: 'No saved albums',
              subtitle:
                  'Save albums to listen offline',
              actionLabel: 'Browse Albums',
              onAction: () {},
            ),
          ),

        SliverToBoxAdapter(
            child: SizedBox(height: kDenBottomPadding + 40)),
      ],
    ),
    );
  }
}


// Removes the overscroll glow and tightens drag start distance
class _NoOverscrollBehavior extends ScrollBehavior {
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const ClampingScrollPhysics();

  @override
  Widget buildOverscrollIndicator(
          BuildContext context, Widget child, ScrollableDetails details) =>
      child;
}

// ─── LIKED SONGS BANNER ───────────────────────────────────────
// The big Spotify-style gradient card at the top

class _LikedSongsBanner extends ConsumerWidget {
  final int count;
  final List<Song> songs;
  const _LikedSongsBanner(
      {required this.count, required this.songs});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Mosaic of up to 4 album arts
    final arts = songs.take(4).map((s) => s.image).toList();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (songs.isNotEmpty) {
          playQueue(ref, songs, 0,
              meta: const QueueMeta(
                  context: QueueContext.general));
          HapticFeedback.mediumImpact();
        }
      },
      child: Padding(
        padding:
            const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Container(
            height: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.pink.withOpacity(0.35),
                  AppTheme.purple.withOpacity(0.25),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color:
                      Colors.white.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                // Mosaic / gradient art
                ClipRRect(
                  borderRadius:
                      const BorderRadius.horizontal(
                          left: Radius.circular(20)),
                  child: SizedBox(
                    width: 100,
                    child: arts.length >= 4
                        ? GridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            physics:
                                const NeverScrollableScrollPhysics(),
                            children: arts
                                .take(4)
                                .map((url) =>
                                    CachedNetworkImage(
                                      imageUrl: url,
                                      fit: BoxFit.cover,
                                      errorWidget: (_,
                                              __,
                                              ___) =>
                                          Container(
                                              color:
                                                  AppTheme.bgTertiary),
                                    ))
                                .toList(),
                          )
                        : Container(
                            decoration: const BoxDecoration(
                                gradient:
                                    AppTheme.primaryGradient),
                            child: const Center(
                              child: Icon(
                                  Icons.favorite_rounded,
                                  color: Colors.white,
                                  size: 36),
                            ),
                          ),
                  ),
                ),

                const SizedBox(width: 16),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [
                      const Text('Liked Songs',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight:
                                FontWeight.w800,
                          )),
                      const SizedBox(height: 3),
                      Text(
                        '$count ${count == 1 ? 'song' : 'songs'}',
                        style: TextStyle(
                          color: Colors.white
                              .withOpacity(0.55),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                // Play button
                Padding(
                  padding:
                      const EdgeInsets.only(right: 16),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: count > 0
                          ? Colors.white
                          : Colors.white
                              .withOpacity(0.2),
                      shape: BoxShape.circle,
                      boxShadow: count > 0
                          ? [
                              BoxShadow(
                                color: Colors.white
                                    .withOpacity(0.3),
                                blurRadius: 12,
                                spreadRadius: -2,
                              )
                            ]
                          : null,
                    ),
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: count > 0
                          ? Colors.black
                          : Colors.white
                              .withOpacity(0.4),
                      size: 26,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ).animate().fadeIn(duration: 400.ms).slideY(
          begin: -0.05,
          end: 0,
          duration: 400.ms,
          curve: Curves.easeOutCubic),
    );
  }
}

// ─── SECTION LABEL ────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final int count;
  const _SectionLabel(
      {required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── SONG TILE ────────────────────────────────────────────────

enum _SongTileTrailing { unlike, more, none }

class _SongTile extends ConsumerWidget {
  final Song song;
  final List<Song> playlist;
  final int index;
  final bool compact;
  final _SongTileTrailing trailing;
  final VoidCallback? onTrailing;

  const _SongTile({
    required this.song,
    required this.playlist,
    required this.index,
    this.compact = false,
    this.trailing = _SongTileTrailing.none,
    this.onTrailing,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imgSize = compact ? 40.0 : 52.0;

    Widget tile = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.lightImpact();
        playQueue(ref, playlist, index,
            meta:
                const QueueMeta(context: QueueContext.general));
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: compact ? 6 : 9,
        ),
        child: Row(
          children: [
            // Art
            ClipRRect(
              borderRadius: BorderRadius.circular(
                  compact ? 6 : 10),
              child: CachedNetworkImage(
                imageUrl: song.image,
                width: imgSize,
                height: imgSize,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  width: imgSize,
                  height: imgSize,
                  color: AppTheme.bgTertiary,
                  child: const Icon(Icons.music_note,
                      color: AppTheme.pink, size: 20),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Title + artist
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: compact ? 13 : 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    song.artist,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.45),
                      fontSize: compact ? 11 : 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Duration
            if (!compact)
              Text(
                _fmt(int.tryParse(song.duration) ?? 0),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.3),
                  fontSize: 12,
                ),
              ),

            const SizedBox(width: 4),

            // Trailing action
            if (trailing == _SongTileTrailing.unlike)
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onTrailing?.call();
                },
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(Icons.favorite_rounded,
                      color: AppTheme.pink, size: 20),
                ),
              )
            else if (trailing == _SongTileTrailing.more)
              GestureDetector(
                onTap: () => _showSongOptions(
                    context, ref, song),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                      Icons.more_vert_rounded,
                      color:
                          Colors.white.withOpacity(0.4),
                      size: 20),
                ),
              ),
          ],
        ),
      ),
    );

    // Swipe to unlike for liked songs
    if (trailing == _SongTileTrailing.unlike) {
      return Dismissible(
        key: Key('song_${song.id}_$index'),
        direction: DismissDirection.endToStart,
        onDismissed: (_) {
          HapticFeedback.mediumImpact();
          onTrailing?.call();
        },
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          color: Colors.red.withOpacity(0.15),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.heart_broken_rounded,
                  color: Colors.red, size: 24),
              const SizedBox(height: 4),
              Text('Unlike',
                  style: TextStyle(
                      color: Colors.red.withOpacity(0.8),
                      fontSize: 10,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        child: tile,
      );
    }

    return tile;
  }

  void _showSongOptions(
      BuildContext context, WidgetRef ref, Song song) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _SongOptionsSheet(song: song, ref: ref),
    );
  }

  String _fmt(int s) {
    if (s <= 0) return '';
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }
}

// ─── PLAYLIST LIST TILE ───────────────────────────────────────

class _PlaylistListTile extends ConsumerWidget {
  final Map<String, dynamic> playlist;
  final bool compact;
  const _PlaylistListTile(
      {required this.playlist, this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imgSize = compact ? 44.0 : 56.0;
    final hasCover = playlist['coverImage'] != null &&
        playlist['coverImage'].toString().isNotEmpty;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openPlaylist(context, ref),
      onLongPress: () {
        HapticFeedback.mediumImpact();
        _showPlaylistOptions(context, ref);
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: compact ? 6 : 8,
        ),
        child: Row(
          children: [
            // Cover
            ClipRRect(
              borderRadius: BorderRadius.circular(
                  compact ? 6 : 10),
              child: hasCover
                  ? CachedNetworkImage(
                      imageUrl: playlist['coverImage'],
                      width: imgSize,
                      height: imgSize,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) =>
                          _defaultCover(imgSize),
                    )
                  : _defaultCover(imgSize),
            ),
            const SizedBox(width: 12),

            // Name + count
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    playlist['name'] ?? 'Playlist',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: compact ? 13 : 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.queue_music_rounded,
                          color:
                              Colors.white.withOpacity(0.3),
                          size: 12),
                      const SizedBox(width: 4),
                      Text(
                        '${playlist['songCount'] ?? 0} songs',
                        style: TextStyle(
                          color:
                              Colors.white.withOpacity(0.4),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // More
            GestureDetector(
              onTap: () => _showPlaylistOptions(context, ref),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(Icons.more_vert_rounded,
                    color: Colors.white.withOpacity(0.35),
                    size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _defaultCover(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(Icons.queue_music_rounded,
          color: AppTheme.pink.withOpacity(0.7), size: size * 0.45),
    );
  }

  void _openPlaylist(BuildContext context, WidgetRef ref) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PlaylistDetailSheet(
          playlist: playlist),
    );
  }

  void _showPlaylistOptions(
      BuildContext context, WidgetRef ref) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _PlaylistOptionsSheet(
          playlist: playlist, ref: ref),
    );
  }
}

// ─── PLAYLIST GRID CARD ───────────────────────────────────────

class _PlaylistGridCard extends ConsumerWidget {
  final Map<String, dynamic> playlist;
  const _PlaylistGridCard({required this.playlist});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasCover = playlist['coverImage'] != null &&
        playlist['coverImage'].toString().isNotEmpty;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) =>
              _PlaylistDetailSheet(playlist: playlist),
        );
      },
      onLongPress: () {
        HapticFeedback.mediumImpact();
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (_) => _PlaylistOptionsSheet(
              playlist: playlist, ref: ref),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  hasCover
                      ? CachedNetworkImage(
                          imageUrl: playlist['coverImage'],
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              _defaultCover(),
                        )
                      : _defaultCover(),
                  // Play overlay
                  Positioned(
                    bottom: 8, right: 8,
                    child: Container(
                      width: 34, height: 34,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.black,
                          size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            playlist['name'] ?? 'Playlist',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            '${playlist['songCount'] ?? 0} songs',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 11,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms).scale(
        begin: const Offset(0.95, 0.95),
        duration: 350.ms,
        curve: Curves.easeOutBack);
  }

  Widget _defaultCover() {
    return Container(
      decoration: const BoxDecoration(
          gradient: AppTheme.cardGradient),
      child: const Center(
        child: Icon(Icons.queue_music_rounded,
            color: AppTheme.pink, size: 40),
      ),
    );
  }
}

// ─── PLAYLIST DETAIL SHEET ────────────────────────────────────

class _PlaylistDetailSheet extends ConsumerWidget {
  final Map<String, dynamic> playlist;
  const _PlaylistDetailSheet({required this.playlist});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlistId = playlist['id'] as String? ?? '';
    final songsAsync =
        ref.watch(_playlistSongsProvider(playlistId));

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, ctrl) => ClipRRect(
        borderRadius: const BorderRadius.vertical(
            top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.85),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28)),
              border: Border.all(
                  color: Colors.white.withOpacity(0.08)),
            ),
            child: Column(
              children: [
                // Handle
                const SizedBox(height: 10),
                Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                Expanded(
                  child: CustomScrollView(
                    controller: ctrl,
                    slivers: [
                      // Header
                      SliverToBoxAdapter(
                        child: _PlaylistDetailHeader(
                            playlist: playlist,
                            onPlay: () {
                              final songs = ref
                                  .read(_playlistSongsProvider(
                                      playlistId))
                                  .value ?? [];
                              if (songs.isNotEmpty) {
                                playQueue(ref, songs, 0);
                                Navigator.pop(context);
                                HapticFeedback.mediumImpact();
                              }
                            }),
                      ),

                      // Songs
                      songsAsync.when(
                        loading: () =>
                            const SliverToBoxAdapter(
                          child: Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child:
                                  CircularProgressIndicator(
                                color: AppTheme.pink,
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                        ),
                        error: (_, __) =>
                            const SliverToBoxAdapter(
                                child: SizedBox.shrink()),
                        data: (songs) => songs.isEmpty
                            ? SliverToBoxAdapter(
                                child: _EmptyState(
                                icon:
                                    Icons.music_off_rounded,
                                title: 'Empty playlist',
                                subtitle:
                                    'Add songs to get started',
                              ))
                            : SliverList(
                                delegate:
                                    SliverChildBuilderDelegate(
                                  (_, i) => _SongTile(
                                    song: songs[i],
                                    playlist: songs,
                                    index: i,
                                    trailing:
                                        _SongTileTrailing.more,
                                  ),
                                  childCount: songs.length,
                                ),
                              ),
                      ),

                      const SliverToBoxAdapter(
                          child: SizedBox(height: 40)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Provider for playlist songs
final _playlistSongsProvider = StreamProvider.family<
    List<Song>, String>((ref, id) {
  return ref
      .watch(databaseServiceProvider)
      .getPlaylistSongs(id);
});

class _PlaylistDetailHeader extends StatelessWidget {
  final Map<String, dynamic> playlist;
  final VoidCallback onPlay;
  const _PlaylistDetailHeader(
      {required this.playlist, required this.onPlay});

  @override
  Widget build(BuildContext context) {
    final hasCover = playlist['coverImage'] != null &&
        playlist['coverImage'].toString().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Cover
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              width: 160, height: 160,
              child: hasCover
                  ? CachedNetworkImage(
                      imageUrl: playlist['coverImage'],
                      fit: BoxFit.cover)
                  : Container(
                      decoration: const BoxDecoration(
                          gradient: AppTheme.primaryGradient),
                      child: const Center(
                        child: Icon(
                            Icons.queue_music_rounded,
                            color: Colors.white,
                            size: 60),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),

          // Name
          Text(
            playlist['name'] ?? 'Playlist',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            '${playlist['songCount'] ?? 0} songs',
            style: TextStyle(
              color: Colors.white.withOpacity(0.45),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 20),

          // Controls row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Shuffle
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color:
                          Colors.white.withOpacity(0.1)),
                ),
                child: Icon(Icons.shuffle_rounded,
                    color:
                        Colors.white.withOpacity(0.7),
                    size: 22),
              ),
              const SizedBox(width: 16),
              // Play
              GestureDetector(
                onTap: onPlay,
                child: Container(
                  width: 60, height: 60,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.black,
                      size: 32),
                ),
              ),
              const SizedBox(width: 16),
              // Download
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color:
                          Colors.white.withOpacity(0.1)),
                ),
                child: Icon(Icons.download_rounded,
                    color:
                        Colors.white.withOpacity(0.7),
                    size: 22),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── SONG OPTIONS SHEET ───────────────────────────────────────

class _SongOptionsSheet extends StatelessWidget {
  final Song song;
  final WidgetRef ref;
  const _SongOptionsSheet(
      {required this.song, required this.ref});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
          top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).padding.bottom + 24),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.75),
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28)),
            border: Border.all(
                color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              // Song info
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: song.image,
                      width: 48, height: 48,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) =>
                          Container(
                        width: 48, height: 48,
                        color: AppTheme.bgTertiary,
                        child: const Icon(Icons.music_note,
                            color: AppTheme.pink),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(song.title,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14),
                            maxLines: 1,
                            overflow:
                                TextOverflow.ellipsis),
                        Text(song.artist,
                            style: TextStyle(
                                color: Colors.white
                                    .withOpacity(0.5),
                                fontSize: 12),
                            maxLines: 1,
                            overflow:
                                TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(
                  color: Colors.white.withOpacity(0.08)),
              const SizedBox(height: 8),
              ..._buildOptions(context),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddToPlaylistSheet(BuildContext context) {
    final playlists = ref.read(playlistsProvider).value ?? [];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
            padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).padding.bottom + 24),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.75),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 36, height: 4,
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),
                const Text('Add to Playlist', style: TextStyle(color: Colors.white,
                    fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                if (playlists.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text('No playlists yet. Create one first.',
                        style: TextStyle(color: Colors.white.withOpacity(0.5))),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: playlists.length,
                      itemBuilder: (_, i) {
                        final pl = playlists[i];
                        return ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: (pl['coverImage'] as String?)?.isNotEmpty == true
                                ? CachedNetworkImage(imageUrl: pl['coverImage']!,
                                    width: 44, height: 44, fit: BoxFit.cover)
                                : Container(width: 44, height: 44,
                                    decoration: const BoxDecoration(gradient: AppTheme.cardGradient),
                                    child: const Icon(Icons.queue_music_rounded,
                                        color: AppTheme.pink, size: 20)),
                          ),
                          title: Text(pl['name'] ?? 'Playlist',
                              style: const TextStyle(color: Colors.white,
                                  fontSize: 14, fontWeight: FontWeight.w600)),
                          subtitle: Text('${pl['songCount'] ?? 0} songs',
                              style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
                          contentPadding: EdgeInsets.zero,
                          onTap: () async {
                            await ref.read(databaseServiceProvider)
                                .addSongToPlaylist(pl['id'] as String, song);
                            if (context.mounted) Navigator.pop(context);
                            HapticFeedback.mediumImpact();
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildOptions(BuildContext context) {
    return [
      ListTile(
        leading: const Icon(Icons.favorite_rounded, color: AppTheme.pink, size: 22),
        title: const Text('Like Song',
            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
        contentPadding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        onTap: () async {
          Navigator.pop(context);
          await ref.read(databaseServiceProvider).likeSong(song);
          HapticFeedback.lightImpact();
        },
      ),
      ListTile(
        leading: const Icon(Icons.playlist_add_rounded, color: AppTheme.purple, size: 22),
        title: const Text('Add to Playlist',
            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
        contentPadding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        onTap: () {
          Navigator.pop(context);
          _showAddToPlaylistSheet(context);
        },
      ),
      ListTile(
        leading: const Icon(Icons.queue_rounded, color: AppTheme.pinkDeep, size: 22),
        title: const Text('Add to Queue',
            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
        contentPadding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        onTap: () {
          Navigator.pop(context);
          // Add to existing queue without changing current song
          final playlist = ref.read(currentPlaylistProvider);
          final current = ref.read(currentSongIndexProvider);
          final newList = [...playlist];
          newList.insert(current + 1, song);
          ref.read(currentPlaylistProvider.notifier).state = newList;
          HapticFeedback.lightImpact();
        },
      ),
      ListTile(
        leading: Icon(Icons.person_rounded, color: Colors.white.withOpacity(0.7), size: 22),
        title: const Text('Go to Artist',
            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
        contentPadding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        onTap: () { Navigator.pop(context); HapticFeedback.selectionClick(); },
      ),
      ListTile(
        leading: Icon(Icons.share_rounded, color: Colors.white.withOpacity(0.7), size: 22),
        title: const Text('Share Song',
            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
        contentPadding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        onTap: () {
          Navigator.pop(context);
          SocialShareSheet.show(context, type: 'song', metadata: song.toJson());
        },
      ),
    ];
  }
}

// ─── PLAYLIST OPTIONS SHEET ───────────────────────────────────

class _PlaylistOptionsSheet extends StatelessWidget {
  final Map<String, dynamic> playlist;
  final WidgetRef ref;
  const _PlaylistOptionsSheet(
      {required this.playlist, required this.ref});

  void _showRenameDialog(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController(
        text: playlist['name'] as String? ?? '');
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Rename Playlist',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: ctrl,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    cursorColor: AppTheme.pink,
                    decoration: InputDecoration(
                      hintText: 'Playlist name',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.07),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: AppTheme.pink.withOpacity(0.5)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(children: [
                    Expanded(child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Center(child: Text('Cancel',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
                      ),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: GestureDetector(
                      onTap: () async {
                        if (ctrl.text.trim().isNotEmpty) {
                          final id = playlist['id'] as String? ?? '';
                          await ref.read(databaseServiceProvider)
                              .renamePlaylist(id, ctrl.text.trim());
                          if (context.mounted) Navigator.pop(context);
                          HapticFeedback.mediumImpact();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: const BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.all(Radius.circular(14)),
                        ),
                        child: const Center(child: Text('Save',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
                      ),
                    )),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Delete Playlist',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  Text(
                    'Delete "${playlist['name']}"? This cannot be undone.',
                    style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  Row(children: [
                    Expanded(child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Center(child: Text('Cancel',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
                      ),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: GestureDetector(
                      onTap: () async {
                        final id = playlist['id'] as String? ?? '';
                        await ref.read(databaseServiceProvider).deletePlaylist(id);
                        if (context.mounted) Navigator.pop(context);
                        HapticFeedback.mediumImpact();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [Color(0xFFFF4444), Color(0xFFCC0000)]),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Center(child: Text('Delete',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
                      ),
                    )),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
          top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).padding.bottom + 24),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.75),
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28)),
            border: Border.all(
                color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                playlist['name'] ?? 'Playlist',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                '${playlist['songCount'] ?? 0} songs',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 12),
              ),
              const SizedBox(height: 16),
              Divider(
                  color: Colors.white.withOpacity(0.08)),
              const SizedBox(height: 8),
              // Rename
              ListTile(
                leading: const Icon(Icons.edit_rounded, color: Colors.white, size: 22),
                title: const Text('Rename Playlist',
                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                contentPadding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                onTap: () {
                  Navigator.pop(context);
                  _showRenameDialog(context, ref);
                },
              ),
              // Share
              ListTile(
                leading: const Icon(Icons.share_rounded, color: Colors.white, size: 22),
                title: const Text('Share Playlist',
                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                contentPadding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                onTap: () {
                  Navigator.pop(context);
                  SocialShareSheet.show(context, type: 'playlist', metadata: playlist);
                },
              ),
              // Download
              ListTile(
                leading: const Icon(Icons.download_rounded, color: Colors.white, size: 22),
                title: const Text('Download Playlist',
                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                contentPadding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                onTap: () {
                  Navigator.pop(context);
                  HapticFeedback.selectionClick();
                },
              ),
              // Delete
              ListTile(
                leading: const Icon(Icons.delete_rounded, color: Colors.red, size: 22),
                title: const Text('Delete Playlist',
                    style: TextStyle(color: Colors.red, fontSize: 14, fontWeight: FontWeight.w500)),
                contentPadding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                onTap: () {
                  Navigator.pop(context);
                  _confirmDelete(context, ref);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── ADD SHEET ────────────────────────────────────────────────

class _AddSheet extends StatelessWidget {
  final VoidCallback onCreatePlaylist;
  const _AddSheet({required this.onCreatePlaylist});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
          top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).padding.bottom + 24),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.75),
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28)),
            border: Border.all(
                color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Add to Library',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              _AddOption(
                icon: Icons.playlist_add_rounded,
                label: 'Create Playlist',
                subtitle: 'Start a new collection',
                colors: [AppTheme.pink, AppTheme.purple],
                onTap: onCreatePlaylist,
              ),
              const SizedBox(height: 10),
              _AddOption(
                icon: Icons.folder_rounded,
                label: 'Create Folder',
                subtitle: 'Organise playlists into folders',
                colors: [AppTheme.purple, AppTheme.purpleDeep],
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddOption extends StatelessWidget {
  final IconData icon;
  final String label, subtitle;
  final List<Color> colors;
  final VoidCallback onTap;

  const _AddOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            colors[0].withOpacity(0.12),
            colors[1].withOpacity(0.06),
          ]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: colors[0].withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: colors),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon,
                  color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
                Text(subtitle,
                    style: TextStyle(
                        color:
                            Colors.white.withOpacity(0.45),
                        fontSize: 12)),
              ],
            ),
            const Spacer(),
            Icon(Icons.chevron_right_rounded,
                color: Colors.white.withOpacity(0.3),
                size: 20),
          ],
        ),
      ),
    );
  }
}

// ─── SORT SHEET ───────────────────────────────────────────────

class _SortSheet extends StatelessWidget {
  final String current;
  final ValueChanged<String> onSelect;
  const _SortSheet(
      {required this.current, required this.onSelect});

  static const _options = [
    'Recently Added',
    'Recently Played',
    'Alphabetical',
    'Creator',
  ];

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
          top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).padding.bottom + 24),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.75),
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28)),
            border: Border.all(
                color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Sort By',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              ..._options.map((o) {
                final isSel = o == current;
                return GestureDetector(
                  onTap: () => onSelect(o),
                  child: Container(
                    margin: const EdgeInsets.only(
                        bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 13),
                    decoration: BoxDecoration(
                      gradient: isSel
                          ? LinearGradient(colors: [
                              AppTheme.pink
                                  .withOpacity(0.15),
                              AppTheme.purple
                                  .withOpacity(0.08),
                            ])
                          : null,
                      color: isSel
                          ? null
                          : Colors.white
                              .withOpacity(0.04),
                      borderRadius:
                          BorderRadius.circular(14),
                      border: Border.all(
                          color: isSel
                              ? AppTheme.pink
                                  .withOpacity(0.3)
                              : Colors.white
                                  .withOpacity(0.07)),
                    ),
                    child: Row(
                      children: [
                        Text(o,
                            style: TextStyle(
                                color: isSel
                                    ? AppTheme.pink
                                    : Colors.white,
                                fontSize: 14,
                                fontWeight: isSel
                                    ? FontWeight.w700
                                    : FontWeight.w500)),
                        const Spacer(),
                        if (isSel)
                          ShaderMask(
                            shaderCallback: (b) =>
                                AppTheme.primaryGradient
                                    .createShader(b),
                            child: const Icon(
                                Icons
                                    .check_circle_rounded,
                                color: Colors.white,
                                size: 20)),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── CREATE PLAYLIST DIALOG ───────────────────────────────────

class _CreatePlaylistDialog extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onCreate;
  const _CreatePlaylistDialog(
      {required this.controller, required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.8),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                  color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text('New Playlist',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  autofocus: true,
                  style: const TextStyle(
                      color: Colors.white),
                  cursorColor: AppTheme.pink,
                  decoration: InputDecoration(
                    hintText: 'Give it a name...',
                    hintStyle: TextStyle(
                        color:
                            Colors.white.withOpacity(0.3)),
                    filled: true,
                    fillColor:
                        Colors.white.withOpacity(0.07),
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(14),
                      borderSide: BorderSide(
                          color: AppTheme.pink
                              .withOpacity(0.5)),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () =>
                            Navigator.pop(context),
                        child: Container(
                          padding:
                              const EdgeInsets.symmetric(
                                  vertical: 13),
                          decoration: BoxDecoration(
                            color: Colors.white
                                .withOpacity(0.07),
                            borderRadius:
                                BorderRadius.circular(14),
                          ),
                          child: const Center(
                            child: Text('Cancel',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight:
                                        FontWeight.w600)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: onCreate,
                        child: Container(
                          padding:
                              const EdgeInsets.symmetric(
                                  vertical: 13),
                          decoration: BoxDecoration(
                            gradient:
                                AppTheme.primaryGradient,
                            borderRadius:
                                BorderRadius.circular(14),
                          ),
                          child: const Center(
                            child: Text('Create',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight:
                                        FontWeight.w700)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── EMPTY STATE ──────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: 40, vertical: 60),
      child: Column(
        children: [
          ShaderMask(
            shaderCallback: (b) =>
                AppTheme.primaryGradient.createShader(b),
            child: Icon(icon,
                color: Colors.white, size: 64)),
          const SizedBox(height: 16),
          Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.45),
                  fontSize: 14,
                  height: 1.4)),
          if (actionLabel != null) ...[
            const SizedBox(height: 20),
            GestureDetector(
              onTap: onAction,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius:
                      BorderRadius.circular(24),
                ),
                child: Text(actionLabel!,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
              ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).scale(
        begin: const Offset(0.95, 0.95),
        duration: 400.ms,
        curve: Curves.easeOutBack);
  }
}

// ─── LOGIN PROMPT ─────────────────────────────────────────────

class _LoginPrompt extends StatelessWidget {
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
              child: const Icon(
                  Icons.library_music_rounded,
                  color: Colors.white,
                  size: 72)),
            const SizedBox(height: 20),
            const Text('Your Library',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Text(
              'Sign in to see your liked songs,\nplaylists and listening history.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 14,
                  height: 1.5),
            ),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 32, vertical: 14),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.pink.withOpacity(0.35),
                    blurRadius: 20,
                    spreadRadius: -5,
                  ),
                ],
              ),
              child: const Text('Sign In',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 500.ms).scale(
          begin: const Offset(0.95, 0.95),
          duration: 500.ms,
          curve: Curves.easeOutBack),
    );
  }
}