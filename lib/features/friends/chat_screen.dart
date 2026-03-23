import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/services/chat_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models/song.dart';
import '../../core/services/api_service.dart';
import '../../core/services/database_service.dart';
import '../../core/services/social_service.dart';
import '../../core/providers/music_providers.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String otherUid;
  final String? username;
  final String? profileUrl;

  const ChatScreen({
    super.key,
    required this.otherUid,
    this.username,
    this.profileUrl,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen>
    with TickerProviderStateMixin {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  bool _isTyping = false;
  late AnimationController _sendAnimController;

  @override
  void initState() {
    super.initState();
    _sendAnimController = AnimationController(vsync: this, duration: const Duration(milliseconds: 180));
    _msgController.addListener(() {
      final hasText = _msgController.text.trim().isNotEmpty;
      if (hasText != _isTyping) setState(() => _isTyping = hasText);
    });
  }

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _sendAnimController.dispose();
    super.dispose();
  }

  String _formatTime(DateTime t) {
    int h = t.hour; int m = t.minute;
    String p = h >= 12 ? 'PM' : 'AM';
    if (h > 12) h -= 12;
    if (h == 0) h = 12;
    return '$h:${m.toString().padLeft(2, '0')} $p';
  }

  String _formatDate(DateTime t) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(t.year, t.month, t.day);
    if (msgDay == today) return 'Today';
    if (msgDay == today.subtract(const Duration(days: 1))) return 'Yesterday';
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[t.month - 1]} ${t.day}';
  }

  void _sendMessage() {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.lightImpact();
    _sendAnimController.forward().then((_) => _sendAnimController.reverse());
    ref.read(chatServiceProvider).sendMessage(widget.otherUid, text);
    _msgController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(chatMessagesProvider(widget.otherUid));
    final profileAsync = ref.watch(otherUserProfileProvider(widget.otherUid));
    final profile = profileAsync.value;
    final displayUser = profile?['username'] ?? widget.username ?? widget.otherUid.substring(0, 6);
    final displayPhoto = profile?['photoUrl'] ?? widget.profileUrl;
    final isOnline = profile?['isOnline'] == true;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0D0D18), Color(0xFF080810), Color(0xFF030308)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          // Very subtle grid lines for depth
          Opacity(
            opacity: 0.03,
            child: Image.network(
              'https://www.transparenttextures.com/patterns/carbon-fibre.png',
              repeat: ImageRepeat.repeat,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (c, e, s) => const SizedBox(),
            ),
          ),
          Column(
            children: [
              _buildAppBar(displayUser, displayPhoto, isOnline),
              Expanded(
                child: GestureDetector(
                  onTap: () => _focusNode.unfocus(),
                  child: messagesAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.pink, strokeWidth: 2)),
                    error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.white54))),
                    data: (messages) {
                      if (messages.isEmpty) return _buildEmptyState(displayUser);
                      return _buildMessageList(messages);
                    },
                  ),
                ),
              ),
              _buildInputBar(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(String displayUser, String? displayPhoto, bool isOnline) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: Container(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 8,
            bottom: 14,
            left: 4,
            right: 16,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.45),
            border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.06), width: 0.5)),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 19),
              ),
              GestureDetector(
                onTap: () {}, // Future: view profile
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: isOnline ? AppTheme.primaryGradient : null,
                        color: isOnline ? null : Colors.white12,
                      ),
                      padding: const EdgeInsets.all(1.5),
                      child: CircleAvatar(
                        radius: 19,
                        backgroundColor: const Color(0xFF1A1A30),
                        backgroundImage: displayPhoto != null ? NetworkImage(displayPhoto) : null,
                        child: displayPhoto == null
                            ? Text(displayUser.isNotEmpty ? displayUser[0].toUpperCase() : '?',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))
                            : null,
                      ),
                    ),
                    Positioned(
                      right: 0, bottom: 0,
                      child: Container(
                        width: 10, height: 10,
                        decoration: BoxDecoration(
                          color: isOnline ? Colors.greenAccent : Colors.white30,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black, width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '@$displayUser',
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: -0.2),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Row(
                        key: ValueKey(isOnline),
                        children: [
                          Container(
                            width: 5, height: 5,
                            decoration: BoxDecoration(
                              color: isOnline ? Colors.greenAccent : Colors.white30,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            isOnline ? 'Online' : 'Offline',
                            style: TextStyle(
                              color: isOnline ? Colors.greenAccent.withOpacity(0.85) : Colors.white30,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Quick share music icon
              IconButton(
                icon: ShaderMask(
                  shaderCallback: (b) => AppTheme.primaryGradient.createShader(b),
                  child: const Icon(Icons.queue_music_rounded, color: Colors.white, size: 22),
                ),
                onPressed: () => _showAttachmentSheet(),
              ),
              IconButton(
                icon: const Icon(Icons.more_vert_rounded, color: Colors.white38, size: 22),
                onPressed: () => _showChatOptions(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String displayUser) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ShaderMask(
            shaderCallback: (b) => AppTheme.primaryGradient.createShader(b),
            child: const Icon(Icons.waving_hand_rounded, size: 56, color: Colors.white),
          ),
          const SizedBox(height: 16),
          Text('Start a conversation with @$displayUser', textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 15, height: 1.5)),
          const SizedBox(height: 8),
          Text('Share music, send messages 🎵', style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildMessageList(List<Message> messages) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(top: 16, bottom: 16),
      reverse: true,
      itemCount: messages.length,
      itemBuilder: (ctx, i) {
        final msg = messages[i];
        final prevMsg = i < messages.length - 1 ? messages[i + 1] : null;
        final nextMsg = i > 0 ? messages[i - 1] : null;

        // Date separator between days
        final showDateBadge = prevMsg == null ||
            !_isSameDay(msg.createdAt, prevMsg.createdAt);

        return Column(
          children: [
            if (showDateBadge) _buildDateBadge(msg.createdAt),
            _buildBubble(msg, prevMsg, nextMsg),
          ],
        );
      },
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _buildDateBadge(DateTime date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.white.withOpacity(0.06), thickness: 0.5)),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Text(_formatDate(date),
                style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11, fontWeight: FontWeight.w600)),
          ),
          Expanded(child: Divider(color: Colors.white.withOpacity(0.06), thickness: 0.5)),
        ],
      ),
    );
  }

  Widget _buildBubble(Message message, Message? prev, Message? next) {
    final isMe = message.senderId != widget.otherUid;
    final isFirstInGroup = prev == null || prev.senderId != message.senderId;
    final isLastInGroup = next == null || next.senderId != message.senderId;
    final isMedia = message.type != 'text';

    const r = Radius.circular(20);
    const rSmall = Radius.circular(4);

    return Padding(
      padding: EdgeInsets.only(
        left: isMe ? 60 : 12,
        right: isMe ? 12 : 60,
        top: isFirstInGroup ? 8 : 2,
        bottom: isLastInGroup ? 8 : 2,
      ),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar for incoming (only on last in group)
          if (!isMe) ...[
            if (isLastInGroup)
              _buildMiniAvatar()
            else
              const SizedBox(width: 34),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                  decoration: BoxDecoration(
                    gradient: isMe
                        ? AppTheme.primaryGradient
                        : LinearGradient(colors: [
                            Colors.white.withOpacity(0.10),
                            Colors.white.withOpacity(0.07),
                          ]),
                    borderRadius: BorderRadius.only(
                      topLeft: isMe || !isFirstInGroup ? r : rSmall,
                      topRight: !isMe || !isFirstInGroup ? r : rSmall,
                      bottomLeft: isMe ? r : (isLastInGroup ? rSmall : r),
                      bottomRight: !isMe ? r : (isLastInGroup ? rSmall : r),
                    ),
                    border: isMe ? null : Border.all(color: Colors.white.withOpacity(0.07), width: 0.5),
                    boxShadow: isMe
                        ? [BoxShadow(color: AppTheme.pink.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))]
                        : [],
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(isMedia ? 10 : 0),
                    child: isMedia
                        ? _buildMediaCard(message.type, message.metadata)
                        : Padding(
                            padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                            child: Column(
                              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                              children: [
                                Text(message.content,
                                    style: const TextStyle(color: Colors.white, fontSize: 14.5, height: 1.4)),
                                const SizedBox(height: 3),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(_formatTime(message.createdAt),
                                        style: TextStyle(color: Colors.white.withOpacity(isMe ? 0.65 : 0.35), fontSize: 10)),
                                    if (isMe) ...[
                                      const SizedBox(width: 4),
                                      Icon(Icons.done_all_rounded, size: 13, color: Colors.white.withOpacity(0.65)),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
                // Time outside bubble for media messages
                if (isMedia)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
                    child: Text(_formatTime(message.createdAt),
                        style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniAvatar() {
    final profileAsync = ref.watch(otherUserProfileProvider(widget.otherUid));
    final profile = profileAsync.value;
    final photoUrl = profile?['photoUrl'] ?? widget.profileUrl;
    final username = profile?['username'] ?? widget.username ?? '?';

    return CircleAvatar(
      radius: 13,
      backgroundColor: const Color(0xFF2A1F3D),
      backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
      child: photoUrl == null
          ? Text(username.isNotEmpty ? username[0].toUpperCase() : '?',
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))
          : null,
    );
  }

  Widget _buildInputBar() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          padding: EdgeInsets.fromLTRB(12, 10, 12, MediaQuery.of(context).padding.bottom + 10),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6),
            border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05), width: 0.5)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // + button
              GestureDetector(
                onTap: _showAttachmentSheet,
                child: Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.07),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: AnimatedRotation(
                    turns: _isTyping ? 0.125 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: Icon(
                      _isTyping ? Icons.close_rounded : Icons.add_rounded,
                      color: _isTyping ? Colors.white30 : Colors.white54,
                      size: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Text input
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 120),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: TextField(
                    controller: _msgController,
                    focusNode: _focusNode,
                    maxLines: null,
                    style: const TextStyle(color: Colors.white, fontSize: 14.5),
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Message...',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.28)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Send button
              GestureDetector(
                onTap: _sendMessage,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: _isTyping ? AppTheme.primaryGradient : null,
                    color: _isTyping ? null : Colors.white.withOpacity(0.07),
                    shape: BoxShape.circle,
                    boxShadow: _isTyping
                        ? [BoxShadow(color: AppTheme.pink.withOpacity(0.45), blurRadius: 14, spreadRadius: 0)]
                        : [],
                  ),
                  child: Icon(
                    Icons.send_rounded,
                    color: _isTyping ? Colors.white : Colors.white30,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Attachment Sheet ─────────────────────────────────────────────────────

  void _showAttachmentSheet() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => _InlineLibraryPicker(
        otherUid: widget.otherUid,
      ),
    );
  }

  // ─── Chat Options ─────────────────────────────────────────────────────────

  void _showChatOptions() {
    final chatSvc = ref.read(chatServiceProvider);
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (c) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 28),
        decoration: BoxDecoration(
          color: const Color(0xFF0E0E1A),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 14),
              width: 36, height: 4,
              decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(2)),
            ),
            _AttachmentTile(
              icon: Icons.delete_outline_rounded,
              label: 'Clear Chat',
              subtitle: 'Remove all messages from this conversation',
              color: Colors.redAccent,
              onTap: () async {
                Navigator.pop(c);
                // Show a confirmation dialog
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (d) => AlertDialog(
                    backgroundColor: const Color(0xFF121220),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    title: const Text('Clear Chat?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    content: const Text('This will delete all messages in this conversation.', style: TextStyle(color: Colors.white54)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel', style: TextStyle(color: Colors.white38))),
                      TextButton(
                        onPressed: () => Navigator.pop(d, true),
                        child: const Text('Clear', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await chatSvc.clearChat(widget.otherUid);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Chat cleared'), behavior: SnackBarBehavior.floating),
                    );
                  }
                }
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // ─── Media Card ───────────────────────────────────────────────────────────

  Widget _buildMediaCard(String type, Map<String, dynamic>? metadata) {
    if (metadata == null) return const SizedBox();

    final title = metadata['title'] ?? metadata['name'] ?? 'Media';
    final subtitle = metadata['artist'] ?? '${metadata['songCount'] ?? '–'} tracks';
    final imageUrl = metadata['image'] ?? metadata['coverImage'];

    final IconData typeIcon = type == 'song'
        ? Icons.music_note_rounded
        : type == 'playlist'
            ? Icons.queue_music_rounded
            : type == 'artist'
                ? Icons.mic_rounded
                : Icons.album_rounded;

    return GestureDetector(
      onTap: () async {
        try {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Loading $title...'), behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFF1E1E30), duration: const Duration(seconds: 1)),
          );
          List<Song> queue = [];
          if (type == 'song') {
            queue = [Song.fromJson(metadata)];
          } else if (type == 'playlist') {
            final id = metadata['id'] as String?;
            if (id != null) queue = await ref.read(databaseServiceProvider).getPlaylistSongs(id).first;
          } else {
            queue = await ref.read(apiServiceProvider).searchSongs(title, limit: 10);
          }
          if (queue.isEmpty) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No tracks found.')));
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
        width: 245,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.35),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1), width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Type badge
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(typeIcon, size: 11, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(type.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Cover + info
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: CachedNetworkImage(
                      imageUrl: imageUrl ?? '',
                      width: 52, height: 52, fit: BoxFit.cover,
                      errorWidget: (c, e, _) => Container(
                        width: 52, height: 52,
                        decoration: BoxDecoration(
                          gradient: AppTheme.cardGradient,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(typeIcon, color: Colors.white38, size: 24),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 3),
                        Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  // Play button
                  Container(
                    width: 34, height: 34,
                    decoration: const BoxDecoration(gradient: AppTheme.primaryGradient, shape: BoxShape.circle),
                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Attachment Tile ──────────────────────────────────────────────────────────

class _AttachmentTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _AttachmentTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
      trailing: Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(0.2)),
      onTap: onTap,
    );
  }
}

// ─── Inline Library Picker ────────────────────────────────────────────────────
// Shows user's playlists + liked songs without any navigation, loading them
// from Firestore via Riverpod providers directly inside the bottom sheet.

class _InlineLibraryPicker extends ConsumerStatefulWidget {
  final String otherUid;
  const _InlineLibraryPicker({required this.otherUid});

  @override
  ConsumerState<_InlineLibraryPicker> createState() => _InlineLibraryPickerState();
}

class _InlineLibraryPickerState extends ConsumerState<_InlineLibraryPicker> {
  int _tab = 0; // 0 = playlists, 1 = liked songs

  @override
  Widget build(BuildContext context) {
    final playlistsAsync = ref.watch(playlistsProvider);
    final likedAsync = ref.watch(likedSongsProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (c, scroll) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0E0E1A),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 14),
              width: 36, height: 4,
              decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(2)),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
              child: Row(
                children: [
                  ShaderMask(
                    shaderCallback: (b) => AppTheme.primaryGradient.createShader(b),
                    child: const Icon(Icons.library_music_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 10),
                  const Text('Share from Library', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                ],
              ),
            ),
            // Tab row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _tab == 0
                      ? _activeTab('Playlists')
                      : _inactiveTab('Playlists', () => setState(() => _tab = 0)),
                  const SizedBox(width: 10),
                  _tab == 1
                      ? _activeTab('Liked Songs')
                      : _inactiveTab('Liked Songs', () => setState(() => _tab = 1)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Content
            Expanded(
              child: _tab == 0
                  ? _buildPlaylists(playlistsAsync, scroll)
                  : _buildLikedSongs(likedAsync, scroll),
            ),
          ],
        ),
      ),
    );
  }

  Widget _activeTab(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
    decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(20)),
    child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
  );

  Widget _inactiveTab(String label, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13)),
    ),
  );

  Widget _buildPlaylists(AsyncValue<List<Map<String, dynamic>>> async, ScrollController scroll) {
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.pink, strokeWidth: 2)),
      error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.white54))),
      data: (playlists) {
        if (playlists.isEmpty) return Center(child: Text('No playlists yet', style: TextStyle(color: Colors.white.withOpacity(0.3))));
        return ListView.builder(
          controller: scroll,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: playlists.length,
          itemBuilder: (c, i) {
            final p = playlists[i];
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              leading: Container(
                width: 46, height: 46,
                decoration: BoxDecoration(gradient: AppTheme.cardGradient, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.queue_music_rounded, color: AppTheme.purple, size: 22),
              ),
              title: Text(p['name'] ?? 'Playlist', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              subtitle: Text('${p['songCount'] ?? 0} songs', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(10)),
                child: const Text('Share', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              onTap: () async {
                Navigator.pop(context);
                await ref.read(chatServiceProvider).shareMedia(widget.otherUid, 'playlist', {
                  'id': p['id'],
                  'name': p['name'],
                  'songCount': p['songCount'],
                  'coverImage': p['coverImage'] ?? '',
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Shared playlist "${p['name']}"!'), behavior: SnackBarBehavior.floating, backgroundColor: const Color(0xFF1E1E30)),
                  );
                }
              },
            );
          },
        );
      },
    );
  }

  Widget _buildLikedSongs(AsyncValue<List<Song>> async, ScrollController scroll) {
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.pink, strokeWidth: 2)),
      error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.white54))),
      data: (songs) {
        if (songs.isEmpty) return Center(child: Text('No liked songs yet', style: TextStyle(color: Colors.white.withOpacity(0.3))));
        return ListView.builder(
          controller: scroll,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: songs.length,
          itemBuilder: (c, i) {
            final s = songs[i];
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CachedNetworkImage(
                  imageUrl: s.image,
                  width: 46, height: 46, fit: BoxFit.cover,
                  errorWidget: (c, e, _) => Container(
                    width: 46, height: 46,
                    decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.music_note, color: Colors.white38),
                  ),
                ),
              ),
              title: Text(s.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(s.artist, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(10)),
                child: const Text('Share', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              onTap: () async {
                Navigator.pop(context);
                await ref.read(chatServiceProvider).shareMedia(widget.otherUid, 'song', s.toJson());
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Shared "${s.title}"!'), behavior: SnackBarBehavior.floating, backgroundColor: const Color(0xFF1E1E30)),
                  );
                }
              },
            );
          },
        );
      },
    );
  }
}
