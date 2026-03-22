import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/chat_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models/song.dart';
import '../../core/services/api_service.dart';
import '../../core/services/database_service.dart';
import '../../core/services/player_service.dart';
import '../../core/providers/music_providers.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String otherUid;
  const ChatScreen({super.key, required this.otherUid});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _msgController = TextEditingController();

  @override
  void dispose() {
    _msgController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(chatMessagesProvider(widget.otherUid));

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('Chat - ${widget.otherUid.substring(0, 5)}...', style: const TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.pink)),
              error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.white70))),
              data: (messages) {
                if (messages.isEmpty) return const Center(child: Text('No messages yet', style: TextStyle(color: Colors.white30)));
                
                return ListView.builder(
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (c, i) => _buildMessageBubble(messages[i]),
                );
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Message message) {
    final isMe = message.senderId != widget.otherUid;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe ? AppTheme.pink.withOpacity(0.8) : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 0),
            bottomRight: Radius.circular(isMe ? 0 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.type != 'text')
              _buildMediaCard(message.type, message.metadata)
            else
              Text(
                message.content,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaCard(String type, Map<String, dynamic>? metadata) {
    if (metadata == null) return const SizedBox();
    
    final title = metadata['title'] ?? metadata['name'] ?? 'Media';
    final subtitle = metadata['artist'] ?? '${metadata['songCount'] ?? 0} tracks';
    final imageUrl = metadata['image'] ?? metadata['coverImage'];

    return GestureDetector(
      onTap: () async {
        try {
          // Provide instant feedback
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Loading $title...')),
          );
          
          List<Song> queue = [];
          if (type == 'song') {
            queue = [Song.fromJson(metadata)];
          } else if (type == 'playlist') {
            // For playlists, check database first, fallback to search API
            final id = metadata['id'] as String?;
            if (id != null) {
              queue = await ref.read(databaseServiceProvider).getPlaylistSongs(id).first;
            }
          } else {
            // Arrays for artist/album fallback to broad search
            queue = await ref.read(apiServiceProvider).searchSongs(title, limit: 10);
          }

          if (queue.isEmpty) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not find tracks for this media.')));
            return;
          }

          ref.read(currentPlaylistProvider.notifier).state = queue;
          ref.read(currentSongIndexProvider.notifier).state = 0;
          playQueue(ref, queue, 0);

        } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Playback failed: $e')));
        }
      },
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  type == 'song' ? Icons.music_note_rounded :
                  type == 'playlist' ? Icons.queue_music_rounded :
                  type == 'artist' ? Icons.person_rounded : Icons.album_rounded,
                  color: AppTheme.pink,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(type.toUpperCase(), style: TextStyle(color: AppTheme.pink, fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (imageUrl != null && imageUrl.toString().isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(imageUrl: imageUrl, width: 40, height: 40, fit: BoxFit.cover, errorWidget: (c, e, _) => Container(width: 40, height: 40, color: Colors.white12, child: const Icon(Icons.music_note, color: Colors.white))),
                  )
                else
                  Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.album, color: Colors.white)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                const Icon(Icons.play_circle_fill_rounded, color: Colors.white54, size: 28),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _msgController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withOpacity(0.06),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () {
              final text = _msgController.text.trim();
              if (text.isEmpty) return;
              ref.read(chatServiceProvider).sendMessage(widget.otherUid, text);
              _msgController.clear();
            },
            icon: const Icon(Icons.send_rounded, color: AppTheme.pink),
          ),
        ],
      ),
    );
  }
}
