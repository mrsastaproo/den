import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/services/database_service.dart';
import '../../core/services/player_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/providers/music_providers.dart';
import '../../core/models/song.dart';
import '../../core/theme/app_theme.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Library',
                      style: TextStyle(color: Colors.white,
                        fontSize: 28, fontWeight: FontWeight.w800,
                        letterSpacing: -0.5)),
                    // Create playlist button
                    GestureDetector(
                      onTap: () => _showCreatePlaylistDialog(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.add_rounded,
                          color: Colors.white, size: 22),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Tab bar
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: const Color(0xFF6B35B8),
                  unselectedLabelColor: Colors.white60,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 13),
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(text: 'Liked'),
                    Tab(text: 'Playlists'),
                    Tab(text: 'History'),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Tab views
              Expanded(
                child: user == null
                  ? _buildLoginPrompt()
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _LikedSongsTab(),
                        _PlaylistsTab(),
                        _HistoryTab(),
                      ],
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginPrompt() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_rounded, color: Colors.white38, size: 64),
          const SizedBox(height: 16),
          const Text('Sign in to see your library',
            style: TextStyle(color: Colors.white,
              fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('Your liked songs and playlists\nwill appear here',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 14)),
        ],
      ),
    );
  }

  void _showCreatePlaylistDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2D1B69),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
        title: const Text('New Playlist',
          style: TextStyle(color: Colors.white,
            fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          cursorColor: Colors.white,
          decoration: InputDecoration(
            hintText: 'Playlist name',
            hintStyle: const TextStyle(color: Colors.white38),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.white24)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.white)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
              style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                await ref.read(databaseServiceProvider)
                  .createPlaylist(controller.text.trim());
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF6B35B8)),
            child: const Text('Create',
              style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ─── LIKED SONGS TAB ──────────────────────────────────────────

class _LikedSongsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final likedAsync = ref.watch(likedSongsProvider);

    return likedAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
      error: (e, _) => Center(
        child: Text('Error: $e',
          style: const TextStyle(color: Colors.red))),
      data: (songs) => songs.isEmpty
        ? _buildEmpty(
            Icons.favorite_border_rounded,
            'No liked songs yet',
            'Tap the heart on any song\nto save it here')
        : _buildSongList(songs, ref),
    );
  }

  Widget _buildSongList(List<Song> songs, WidgetRef ref) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 160),
      itemCount: songs.length,
      itemBuilder: (context, index) =>
        _LibrarySongTile(song: songs[index], ref: ref,
          onDismiss: () => ref.read(databaseServiceProvider)
            .unlikeSong(songs[index].id)),
    );
  }
}

// ─── PLAYLISTS TAB ────────────────────────────────────────────

class _PlaylistsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlistsAsync = ref.watch(playlistsProvider);

    return playlistsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
      error: (e, _) => Center(
        child: Text('Error: $e',
          style: const TextStyle(color: Colors.red))),
      data: (playlists) => playlists.isEmpty
        ? _buildEmpty(
            Icons.queue_music_rounded,
            'No playlists yet',
            'Tap + to create your first playlist')
        : GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 160),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
            itemCount: playlists.length,
            itemBuilder: (context, index) =>
              _PlaylistCard(playlist: playlists[index]),
          ),
    );
  }
}

// ─── HISTORY TAB ──────────────────────────────────────────────

class _HistoryTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(historyProvider);

    return historyAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
      error: (e, _) => Center(
        child: Text('Error: $e',
          style: const TextStyle(color: Colors.red))),
      data: (songs) => songs.isEmpty
        ? _buildEmpty(
            Icons.history_rounded,
            'No history yet',
            'Songs you play will\nappear here')
        : _buildSongList(songs, ref),
    );
  }

  Widget _buildSongList(List<Song> songs, WidgetRef ref) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 160),
      itemCount: songs.length,
      itemBuilder: (context, index) =>
        _LibrarySongTile(song: songs[index], ref: ref),
    );
  }
}

// ─── SHARED WIDGETS ───────────────────────────────────────────

Widget _buildEmpty(IconData icon, String title, String subtitle) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: Colors.white24, size: 72),
        const SizedBox(height: 16),
        Text(title,
          style: const TextStyle(color: Colors.white,
            fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white54, fontSize: 14)),
      ],
    ),
  );
}

class _LibrarySongTile extends StatelessWidget {
  final Song song;
  final WidgetRef ref;
  final VoidCallback? onDismiss;

  const _LibrarySongTile({
    required this.song,
    required this.ref,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final tile = ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 20, vertical: 4),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: CachedNetworkImage(
          imageUrl: song.image,
          width: 50, height: 50, fit: BoxFit.cover,
          errorWidget: (_, __, ___) => Container(
            width: 50, height: 50,
            color: Colors.white12,
            child: const Icon(Icons.music_note,
              color: Colors.white38)),
        ),
      ),
      title: Text(song.title,
        style: const TextStyle(color: Colors.white,
          fontWeight: FontWeight.w600, fontSize: 14),
        maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(song.artist,
        style: const TextStyle(color: Colors.white54, fontSize: 12),
        maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: IconButton(
        icon: const Icon(Icons.play_circle_filled_rounded,
          color: Colors.white70, size: 34),
        onPressed: () {
          ref.read(currentSongProvider.notifier).state = song;
          ref.read(playerServiceProvider).playSong(song);
        },
      ),
    );

    if (onDismiss != null) {
      return Dismissible(
        key: Key(song.id),
        direction: DismissDirection.endToStart,
        onDismissed: (_) => onDismiss!(),
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          color: Colors.red.withOpacity(0.3),
          child: const Icon(Icons.delete_rounded,
            color: Colors.red, size: 28),
        ),
        child: tile,
      );
    }
    return tile;
  }
}

class _PlaylistCard extends StatelessWidget {
  final Map<String, dynamic> playlist;
  const _PlaylistCard({required this.playlist});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16)),
              child: playlist['coverImage'] != null &&
                  playlist['coverImage'].toString().isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: playlist['coverImage'],
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _defaultCover(),
                  )
                : _defaultCover(),
            ),
          ),
          // Info
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(playlist['name'] ?? 'Playlist',
                  style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w700, fontSize: 13),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text('${playlist['songCount'] ?? 0} songs',
                  style: const TextStyle(color: Colors.white54,
                    fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _defaultCover() {
    return Container(
      color: const Color(0xFF3D1A7A),
      child: const Center(
        child: Icon(Icons.queue_music_rounded,
          color: Colors.white38, size: 40)),
    );
  }
}