import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models/song.dart';
import '../../core/services/playlist_generator_service.dart';
import '../../core/services/player_service.dart';
import '../../core/providers/music_providers.dart';
import '../../core/providers/queue_meta.dart';

class AiScreen extends ConsumerStatefulWidget {
  const AiScreen({super.key});

  @override
  ConsumerState<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends ConsumerState<AiScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _send([String? quickReply]) {
    final text = quickReply ?? _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    _focusNode.unfocus();
    ref.read(playlistGeneratorProvider.notifier).handlePrompt(text);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playlistGeneratorProvider);

    ref.listen(playlistGeneratorProvider, (_, __) => _scrollToBottom());

    final isLoading = state.status == GeneratorStatus.thinking ||
        state.status == GeneratorStatus.searching;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Column(
          children: [
            ShaderMask(
              shaderCallback: (bounds) =>
                  AppTheme.primaryGradient.createShader(bounds),
              child: const Text(
                'DEN AI',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
            ),
            Text(
              'Your Music Curator ✨',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 11,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        actions: [
          if (state.messages.isNotEmpty)
            IconButton(
              icon: Icon(Icons.refresh_rounded,
                  color: Colors.white.withValues(alpha: 0.6)),
              onPressed: () {
                HapticFeedback.lightImpact();
                ref.read(playlistGeneratorProvider.notifier).reset();
              },
              tooltip: 'Start over',
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Chat / Empty area ──────────────────────────────────────
          Expanded(
            child: state.messages.isEmpty
                ? _EmptyState(onSuggestionTap: _send)
                : ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top + 80,
                      bottom: 12,
                      left: 16,
                      right: 16,
                    ),
                    itemCount: state.messages.length + (isLoading ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i == state.messages.length) {
                        return _ThinkingBubble(message: state.statusMessage);
                      }
                      final msg = state.messages[i];
                      if (msg.isUser) return _UserBubble(text: msg.text);

                      return _AiBubble(
                        message: msg,
                        onQuickReply: _send,
                        onPlay: _playPlaylist,
                        onSave: _savePlaylist,
                      );
                    },
                  ),
          ),

          // ── Input bar ──────────────────────────────────────────────
          _InputBar(
            controller: _controller,
            focusNode: _focusNode,
            isLoading: isLoading,
            onSend: () => _send(),
          ),
        ],
      ),
    );
  }

  void _playPlaylist(List<Song> songs) {
    if (songs.isEmpty) return;
    HapticFeedback.mediumImpact();
    ref.read(currentPlaylistProvider.notifier).state = songs;
    ref.read(currentSongIndexProvider.notifier).state = 0;
    ref.read(currentSongProvider.notifier).state = songs.first;
    ref.read(queueMetaProvider.notifier).state = const QueueMeta(
      context: QueueContext.general,
      searchQuery: '',
    );
    ref.read(playerServiceProvider).playSong(songs.first);
  }

  Future<void> _savePlaylist(GeneratedPlaylist playlist) async {
    HapticFeedback.mediumImpact();
    final id = await ref
        .read(playlistGeneratorProvider.notifier)
        .savePlaylistToLibrary(playlist);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: id != null ? AppTheme.purple : Colors.red.shade800,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text(
          id != null
              ? '✓ "${playlist.name}" library mein save ho gayi!'
              : 'Save nahi hua — phir try kar.',
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final Function(String) onSuggestionTap;
  const _EmptyState({required this.onSuggestionTap});

  static const _suggestions = [
    '🎧  Studying ke liye chill songs',
    '🔥  90s hip hop bangers',
    '💃  Bollywood party songs',
    '😢  Heartbreak sad Punjabi',
    '🌅  Morning workout motivation',
    '🌙  Late night chill vibes',
    '💕  Romantic Hindi love songs',
    '😤  Attitude wale Punjabi songs',
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 100,
        bottom: 24,
        left: 24,
        right: 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShaderMask(
            shaderCallback: (b) => AppTheme.primaryGradient.createShader(b),
            child: const Text(
              'Kya sun-na hai aaj? 🎵',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
          ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.2, end: 0),
          const SizedBox(height: 10),
          Text(
            'Bata apna mood, occasion ya genre — main banaunga perfect playlist sirf tere liye.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 14,
              height: 1.6,
            ),
          ).animate().fadeIn(duration: 500.ms, delay: 100.ms),
          const SizedBox(height: 32),
          Text(
            'KUCH IDEAS 👇',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
            ),
          ).animate().fadeIn(delay: 200.ms),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _suggestions.asMap().entries.map((e) {
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onSuggestionTap(e.value.replaceAll(RegExp(r'^[\S]+\s+'), '').trim());
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          Colors.white.withValues(alpha: 0.07),
                          AppTheme.purple.withValues(alpha: 0.08),
                        ]),
                        borderRadius: BorderRadius.circular(20),
                        border:
                            Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Text(
                        e.value,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              ).animate().fadeIn(
                  delay: Duration(milliseconds: 200 + e.key * 60));
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ─── User bubble ──────────────────────────────────────────────────────────────

class _UserBubble extends StatelessWidget {
  final String text;
  const _UserBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, left: 60),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(4),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
              color: Colors.white, fontSize: 14, height: 1.4),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideX(begin: 0.1, end: 0);
  }
}

// ─── AI bubble (text + optional playlist + optional quick replies) ────────────

class _AiBubble extends StatelessWidget {
  final ChatMessage message;
  final Function(String) onQuickReply;
  final Function(List<Song>) onPlay;
  final Function(GeneratedPlaylist) onSave;

  const _AiBubble({
    required this.message,
    required this.onQuickReply,
    required this.onPlay,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16, right: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar + text bubble
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // DEN AI avatar
                Container(
                  width: 32,
                  height: 32,
                  margin: const EdgeInsets.only(right: 10, top: 2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppTheme.primaryGradient,
                  ),
                  child: const Icon(Icons.auto_awesome,
                      color: Colors.white, size: 16),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(18),
                      bottomLeft: Radius.circular(18),
                      bottomRight: Radius.circular(18),
                    ),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.07),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1)),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            topRight: Radius.circular(18),
                            bottomLeft: Radius.circular(18),
                            bottomRight: Radius.circular(18),
                          ),
                        ),
                        child: Text(
                          message.text,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 14,
                            height: 1.55,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Playlist card (indented to align with bubble)
            if (message.playlist != null) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(left: 42),
                child: _PlaylistCard(
                  playlist: message.playlist!,
                  onPlay: () => onPlay(message.playlist!.songs),
                  onSave: () => onSave(message.playlist!),
                ),
              ),
            ],

            // Quick reply chips
            if (message.quickReplies != null &&
                message.quickReplies!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(left: 42),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: message.quickReplies!.map((reply) {
                    return _QuickReplyChip(
                      label: reply,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onQuickReply(reply);
                      },
                    );
                  }).toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    ).animate().fadeIn(duration: 350.ms).slideX(begin: -0.08, end: 0);
  }
}

// ─── Quick reply chip ─────────────────────────────────────────────────────────

class _QuickReplyChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickReplyChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.purple.withValues(alpha: 0.5)),
          gradient: LinearGradient(colors: [
            AppTheme.purple.withValues(alpha: 0.12),
            AppTheme.pink.withValues(alpha: 0.06),
          ]),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ─── Thinking bubble ──────────────────────────────────────────────────────────

class _ThinkingBubble extends StatelessWidget {
  final String message;
  const _ThinkingBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, left: 42, right: 60),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(AppTheme.purple),
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                message,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn().shimmer(duration: 1500.ms);
  }
}

// ─── Playlist card ────────────────────────────────────────────────────────────

class _PlaylistCard extends StatelessWidget {
  final GeneratedPlaylist playlist;
  final VoidCallback onPlay;
  final VoidCallback onSave;

  const _PlaylistCard({
    required this.playlist,
    required this.onPlay,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final songs = playlist.songs;
    final previewImages = songs
        .where((s) => s.image.isNotEmpty)
        .take(4)
        .map((s) => s.image)
        .toList();

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.purple.withValues(alpha: 0.2),
                AppTheme.pink.withValues(alpha: 0.1),
                Colors.white.withValues(alpha: 0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border:
                Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: artwork + info
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 72,
                        height: 72,
                        child: previewImages.length >= 4
                            ? GridView.count(
                                crossAxisCount: 2,
                                physics:
                                    const NeverScrollableScrollPhysics(),
                                children: previewImages
                                    .map((url) => CachedNetworkImage(
                                          memCacheWidth: 200,
                                          imageUrl: url,
                                          fit: BoxFit.cover,
                                          errorWidget: (_, __, ___) =>
                                              Container(
                                                  color: AppTheme.purple
                                                      .withValues(alpha: 0.3)),
                                        ))
                                    .toList(),
                              )
                            : Container(
                                decoration: BoxDecoration(
                                  gradient: AppTheme.primaryGradient,
                                ),
                                child: const Icon(
                                    Icons.queue_music_rounded,
                                    color: Colors.white,
                                    size: 32),
                              ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            playlist.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${songs.length} songs',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            playlist.description,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 11,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Divider
              Divider(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.08),
                  indent: 16,
                  endIndent: 16),
              const SizedBox(height: 8),

              // Song preview list (first 4)
              ...songs.take(4).map((song) => Padding(
                    padding:
                        const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: CachedNetworkImage(
                            memCacheWidth: 120,
                            imageUrl: song.image,
                            width: 38,
                            height: 38,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(Icons.music_note,
                                  color: Colors.white54, size: 16),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                song.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                song.artist,
                                style: TextStyle(
                                  color:
                                      Colors.white.withValues(alpha: 0.4),
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )),

              if (songs.length > 4)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                  child: Text(
                    '+${songs.length - 4} more songs',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 12,
                    ),
                  ),
                ),

              // Action buttons
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: onPlay,
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius:
                                BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              Icon(Icons.play_arrow_rounded,
                                  color: Colors.white, size: 20),
                              SizedBox(width: 6),
                              Text(
                                'Play Now',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: onSave,
                      child: Container(
                        height: 44,
                        width: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius:
                              BorderRadius.circular(12),
                          border: Border.all(
                              color:
                                  Colors.white.withValues(alpha: 0.15)),
                        ),
                        child: Icon(
                          Icons.library_add_rounded,
                          color: Colors.white.withValues(alpha: 0.8),
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Input bar ────────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isLoading;
  final VoidCallback onSend;

  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.isLoading,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).padding.bottom + 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(28),
              border:
                  Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 14),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onSend(),
                    enabled: !isLoading,
                    decoration: InputDecoration(
                      hintText: isLoading
                          ? 'DEN AI is thinking...'
                          : 'Bata apna mood ya genre...',
                      hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                          fontSize: 14),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: isLoading ? null : onSend,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: isLoading
                            ? LinearGradient(colors: [
                                Colors.white.withValues(alpha: 0.1),
                                Colors.white.withValues(alpha: 0.1),
                              ])
                            : AppTheme.primaryGradient,
                        shape: BoxShape.circle,
                      ),
                      child: isLoading
                          ? Padding(
                              padding: const EdgeInsets.all(12),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(
                                    Colors.white.withValues(alpha: 0.5)),
                              ),
                            )
                          : const Icon(Icons.arrow_upward_rounded,
                              color: Colors.white, size: 20),
                    ),
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