import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/models/song.dart';
import '../../core/services/database_service.dart';
import '../../core/theme/app_theme.dart';

class PlaylistSelectorSheet extends ConsumerStatefulWidget {
  final Song song;
  const PlaylistSelectorSheet({super.key, required this.song});

  static Future<void> show(BuildContext context, Song song) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => PlaylistSelectorSheet(song: song),
    );
  }

  @override
  ConsumerState<PlaylistSelectorSheet> createState() =>
      _PlaylistSelectorSheetState();
}

class _PlaylistSelectorSheetState extends ConsumerState<PlaylistSelectorSheet> {
  final _createCtrl = TextEditingController();

  @override
  void dispose() {
    _createCtrl.dispose();
    super.dispose();
  }

  Future<void> _createNew() async {
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('New Playlist', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: _createCtrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'My Vibe...',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
            focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: AppTheme.pink)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: Colors.white.withOpacity(0.5))),
          ),
          TextButton(
            onPressed: () {
              final val = _createCtrl.text.trim();
              if (val.isNotEmpty) Navigator.pop(ctx, val);
            },
            child: const Text('Create', style: TextStyle(color: AppTheme.pink, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (name != null) {
      HapticFeedback.mediumImpact();
      final id = await ref.read(databaseServiceProvider).createPlaylist(name);
      if (id.isNotEmpty) {
        await ref.read(databaseServiceProvider).addSongToPlaylist(id, widget.song);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Added to "$name"')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final playlistsAsync = ref.watch(playlistsProvider);
    final bottom = MediaQuery.of(context).padding.bottom;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          padding: EdgeInsets.fromLTRB(0, 12, 0, bottom + 16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.82),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 42, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 24),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Add to Playlist',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.6,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _createNew,
                      icon: const Icon(Icons.add_circle_outline_rounded,
                          color: AppTheme.pink, size: 28),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              
              Flexible(
                child: playlistsAsync.when(
                  loading: () => const Center(
                      child: CircularProgressIndicator(color: AppTheme.pink)),
                  error: (e, _) => Center(child: Text('Error: $e')),
                  data: (playlists) {
                    if (playlists.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Column(
                          children: [
                            Icon(Icons.playlist_add_rounded,
                                color: Colors.white.withOpacity(0.1), size: 64),
                            const SizedBox(height: 16),
                            Text(
                              'No playlists yet',
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.3)),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: playlists.length,
                      itemBuilder: (context, i) {
                        final p = playlists[i];
                        return _PlaylistTile(
                          name: p['name'] ?? 'Untitled',
                          count: p['songCount'] ?? 0,
                          image: p['coverImage'] ?? '',
                          onTap: () async {
                            HapticFeedback.lightImpact();
                            await ref.read(databaseServiceProvider).addSongToPlaylist(p['id'], widget.song);
                            if (mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Added to "${p['name']}"')),
                              );
                            }
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaylistTile extends StatelessWidget {
  final String name;
  final int count;
  final String image;
  final VoidCallback onTap;

  const _PlaylistTile({
    required this.name,
    required this.count,
    required this.image,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: image.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: image,
                      width: 52, height: 52,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: 52, height: 52,
                      color: Colors.white.withOpacity(0.08),
                      child: const Icon(Icons.music_note, color: AppTheme.pink, size: 24),
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$count songs',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.4), fontSize: 13),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: Colors.white.withOpacity(0.2)),
          ],
        ),
      ),
    );
  }
}
