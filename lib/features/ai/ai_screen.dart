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

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    _focusNode.unfocus();
    ref.read(playlistGeneratorProvider.notifier).handlePrompt(text);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playlistGeneratorProvider);

    // Auto-scroll when messages update
    ref.listen(playlistGeneratorProvider, (_, __) => _scrollToBottom());

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
                  letterSpacing: 1.5,
                ),
              ),
            ),
            Text(
              'Playlist Generator',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
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
                  color: Colors.white.withOpacity(0.6)),
              onPressed: () {
                HapticFeedback.lightImpact();
                ref.read(playlistGeneratorProvider.notifier).reset();
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Chat area ──────────────────────────────────────────
          Expanded(
            child: state.messages.isEmpty
                ? _EmptyState(onSuggestionTap: (s) {
                    _controller.text = s;
                    _send();
                  })
                : ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top + 80,
                      bottom: 16,
                      left: 16,
                      right: 16,
                    ),
                    itemCount: state.messages.length +
                        (state.status == GeneratorStatus.thinking ||
                                state.status == GeneratorStatus.searching
                            ? 1
                            : 0),
                    itemBuilder: (context, i) {
                      // Loading bubble
                      if (i == state.messages.length) {
                        return _ThinkingBubble(
                            message: state.statusMessage);
                      }
                      final msg = state.messages[i];
                      return msg.isUser
                          ? _UserBubble(text: msg.text)
                          : _AiBubble(
                              text: msg.text,
                              playlist: msg.playlist,
                              onPlay: (songs) =>
                                  _playPlaylist(songs),
                              onSave: (playlist) =>
                                  _savePlaylist(playlist),
                            );
                    },
                  ),
          ),

          // ── Input bar ──────────────────────────────────────────
          _InputBar(
            controller: _controller,
            focusNode: _focusNode,
            isLoading: state.status == GeneratorStatus.thinking ||
                state.status == GeneratorStatus.searching,
            onSend: _send,
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text(
          id != null
              ? '✓ "${playlist.name}" saved to your library!'
              : 'Failed to save — try again.',
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}

// ─── Empty state with suggestion chips ───────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final Function(String) onSuggestionTap;
  const _EmptyState({required this.onSuggestionTap});

  static const _suggestions = [
    '🎧 Chill lo-fi beats for studying',
    '🔥 90s hip hop bangers',
    '💃 Bollywood party songs',
    '😢 Heartbreak sad songs',
    '🌅 Morning motivation workout',
    '🌙 Late night chill vibes',
    '🎸 Rock classics mix',
    '💕 Romantic Hindi love songs',
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
            shaderCallback: (b) =>
                AppTheme.primaryGradient.createShader(b),
            child: const Text(
              'What\'s your vibe?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
            ),
          ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.2, end: 0),
          const SizedBox(height: 8),
          Text(
            'Describe the mood, genre, or occasion and I\'ll build you a perfect playlist.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 14,
              height: 1.5,
            ),
          ).animate().fadeIn(duration: 500.ms, delay: 100.ms),
          const SizedBox(height: 32),
          Text(
            'TRY ASKING',
            style: TextStyle(
              color: Colors.white.withOpacity(0.3),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
            ),
          ).animate().fadeIn(delay: 200.ms),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _suggestions.asMap().entries.map((e) {
              return GestureDetector(
                onTap: () => onSuggestionTap(e.value),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          Colors.white.withOpacity(0.07),
                          AppTheme.purple.withOpacity(0.08),
                        ]),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.1)),
                      ),
                      child: Text(
                        e.value,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
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

// ─── Chat bubbles ─────────────────────────────────────────────────────────────

class _UserBubble extends StatelessWidget {
  final String text;
  const _UserBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, left: 60),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
          style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideX(begin: 0.1, end: 0);
  }
}

class _AiBubble extends StatelessWidget {
  final String text;
  final GeneratedPlaylist? playlist;
  final Function(List<Song>) onPlay;
  final Function(GeneratedPlaylist) onSave;

  const _AiBubble({
    required this.text,
    this.playlist,
    required this.onPlay,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, right: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // AI avatar + text
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                          color: Colors.white.withOpacity(0.07),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.1)),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            topRight: Radius.circular(18),
                            bottomLeft: Radius.circular(18),
                            bottomRight: Radius.circular(18),
                          ),
                        ),
                        child: Text(
                          text,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Playlist card
            if (playlist != null) ...[
              const SizedBox(height: 12),
              _PlaylistCard(
                playlist: playlist!,
                onPlay: () => onPlay(playlist!.songs),
                onSave: () => onSave(playlist!),
              ),
            ],
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideX(begin: -0.1, end: 0);
  }
}

class _ThinkingBubble extends StatelessWidget {
  final String message;
  const _ThinkingBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, left: 42),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(18),
          border:
              Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(AppTheme.purple),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              message,
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn().shimmer(duration: 1500.ms);
  }
}

// ─── Playlist card shown inside AI bubble ─────────────────────────────────────

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
                AppTheme.purple.withOpacity(0.2),
                AppTheme.pink.withOpacity(0.1),
                Colors.white.withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with artwork grid
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // 2x2 artwork grid
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
                                          imageUrl: url,
                                          fit: BoxFit.cover,
                                          errorWidget: (_, __, ___) =>
                                              Container(
                                                  color: AppTheme.purple
                                                      .withOpacity(0.3)),
                                        ))
                                    .toList(),
                              )
                            : Container(
                                decoration: BoxDecoration(
                                  gradient: AppTheme.primaryGradient,
                                ),
                                child: const Icon(Icons.queue_music_rounded,
                                    color: Colors.white, size: 32),
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
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            playlist.description,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.4),
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

              // Song preview list (first 4)
              ...songs.take(4).map((song) => Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: CachedNetworkImage(
                            imageUrl: song.image,
                            width: 38,
                            height: 38,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(
                              width: 38,
                              height: 38,
                              color: Colors.white.withOpacity(0.1),
                              child: const Icon(Icons.music_note,
                                  color: Colors.white54, size: 16),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
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
                                  color: Colors.white.withOpacity(0.4),
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
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  child: Text(
                    '+${songs.length - 4} more songs',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.3),
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
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
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
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.15)),
                        ),
                        child: Icon(
                          Icons.library_add_rounded,
                          color: Colors.white.withOpacity(0.8),
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
          16, 12, 16, MediaQuery.of(context).padding.bottom + 100),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(28),
              border:
                  Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onSend(),
                    enabled: !isLoading,
                    decoration: InputDecoration(
                      hintText: 'Describe your perfect playlist...',
                      hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.3),
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
                                Colors.white.withOpacity(0.1),
                                Colors.white.withOpacity(0.1),
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
                                    Colors.white.withOpacity(0.5)),
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