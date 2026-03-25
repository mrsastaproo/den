import 'dart:ui';
import 'dart:math' as math;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/services/chat_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models/song.dart';
import '../../core/services/api_service.dart';
import '../../core/services/database_service.dart';
import '../../core/services/social_service.dart';
import '../../core/providers/music_providers.dart';

// ─── GAMING COLOR PALETTE ─────────────────────────────────────────────────────

class _C {
  static const bg           = Color(0xFF020409);
  static const bgPanel      = Color(0xFF070C15);
  static const bgCard       = Color(0xFF0A1020);
  static const bgBubbleMe   = Color(0xFF071520);
  static const bgBubbleThem = Color(0xFF0A0D14);
  static const cyan         = Color(0xFF00F0FF);
  static const cyanDim      = Color(0xFF00AACC);
  static const magenta      = Color(0xFFFF006E);
  static const purple       = Color(0xFF9B30FF);
  static const neonGreen    = Color(0xFF00FF88);
  static const gold         = Color(0xFFFFD700);
  static const border       = Color(0xFF111E30);
  static const borderGlow   = Color(0xFF1A3050);
  static const textPri      = Color(0xFFDCEEFF);
  static const textSec      = Color(0xFF4E7090);
  static const textMuted    = Color(0xFF1E3050);

  static const cyanGrad   = LinearGradient(colors: [cyan, purple], begin: Alignment.topLeft, end: Alignment.bottomRight);
  static const magentaGrad= LinearGradient(colors: [magenta, purple], begin: Alignment.topLeft, end: Alignment.bottomRight);
  static const goldGrad   = LinearGradient(colors: [gold, Color(0xFFFF9500)], begin: Alignment.topLeft, end: Alignment.bottomRight);

  static const bubbleGradMe = LinearGradient(
    colors: [Color(0xFF071828), Color(0xFF050F1E)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
  static const bubbleGradThem = LinearGradient(
    colors: [Color(0xFF0C1018), Color(0xFF080C14)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
}

// ─── CHAT SCREEN ─────────────────────────────────────────────────────────────

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
  late AnimationController _bgPulse;

  @override
  void initState() {
    super.initState();
    _sendAnimController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 180));
    _bgPulse = AnimationController(
        vsync: this, duration: const Duration(seconds: 4))
      ..repeat(reverse: true);

    _msgController.addListener(() {
      final hasText = _msgController.text.trim().isNotEmpty;
      if (hasText != _isTyping) {
        setState(() => _isTyping = hasText);
        ref.read(chatServiceProvider).setTypingStatus(widget.otherUid, hasText);
      }
    });
    Future.microtask(
        () => ref.read(chatServiceProvider).markAsRead(widget.otherUid));
  }

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _sendAnimController.dispose();
    _bgPulse.dispose();
    super.dispose();
  }

  String _formatTime(DateTime t) {
    int h = t.hour;
    int m = t.minute;
    String p = h >= 12 ? 'PM' : 'AM';
    if (h > 12) h -= 12;
    if (h == 0) h = 12;
    return '$h:${m.toString().padLeft(2, '0')} $p';
  }

  String _formatDate(DateTime t) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(t.year, t.month, t.day);
    if (msgDay == today) return 'TODAY';
    if (msgDay == today.subtract(const Duration(days: 1))) return 'YESTERDAY';
    const months = [
      'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'
    ];
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
    final nowPlaying = profile?['nowPlaying'];

    return Scaffold(
      backgroundColor: _C.bg,
      body: Stack(
        children: [
          // ── Animated background ──────────────────────────────────────────
          Positioned.fill(child: _ChatBgPainter()),
          // Ambient glow top
          Positioned(
            top: -80, left: 0, right: 0,
            child: AnimatedBuilder(
              animation: _bgPulse,
              builder: (_, __) => Container(
                height: 260,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topCenter,
                    radius: 1.2,
                    colors: [
                      _C.cyan.withValues(alpha: 0.04 + _bgPulse.value * 0.02),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Ambient glow bottom
          Positioned(
            bottom: -40, left: 0, right: 0,
            child: AnimatedBuilder(
              animation: _bgPulse,
              builder: (_, __) => Container(
                height: 200,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.bottomCenter,
                    radius: 1.0,
                    colors: [
                      _C.purple.withValues(alpha: 0.05 + _bgPulse.value * 0.02),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          // ── Main layout ──────────────────────────────────────────────────
          Column(
            children: [
              _buildAppBar(displayUser, displayPhoto, isOnline, nowPlaying),
              Expanded(
                child: GestureDetector(
                  onTap: () => _focusNode.unfocus(),
                  child: messagesAsync.when(
                    loading: () => const Center(child: _GamingLoader()),
                    error: (e, _) => Center(
                      child: Text('ERROR: $e',
                          style: const TextStyle(
                              color: _C.magenta, fontFamily: 'monospace')),
                    ),
                    data: (messages) {
                      if (messages.isEmpty) {
                        return _buildEmptyState(displayUser);
                      }
                      return Column(
                        children: [
                          Expanded(child: _buildMessageList(messages)),
                          _buildTypingIndicator(displayUser),
                        ],
                      );
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

  // ─── AppBar ─────────────────────────────────────────────────────────────────

  Widget _buildAppBar(
      String displayUser, String? displayPhoto, bool isOnline, dynamic nowPlaying) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 8,
            bottom: 12,
            left: 4,
            right: 12,
          ),
          decoration: BoxDecoration(
            color: _C.bgPanel.withValues(alpha: 0.92),
            border: Border(
              bottom: BorderSide(
                  color: _C.cyan.withValues(alpha: 0.12), width: 1),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  // Back button — angular style
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      margin: const EdgeInsets.only(left: 8, right: 4),
                      decoration: BoxDecoration(
                        color: _C.border,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: _C.borderGlow.withValues(alpha: 0.5)),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: _C.cyanDim, size: 16),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Avatar with status ring
                  _StatusAvatar(
                    photoUrl: displayPhoto,
                    initial: displayUser.isNotEmpty
                        ? displayUser[0].toUpperCase()
                        : '?',
                    isOnline: isOnline,
                    radius: 22,
                  ),
                  const SizedBox(width: 12),
                  // Name + status
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '@$displayUser',
                          style: const TextStyle(
                            color: _C.textPri,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 400),
                          child: nowPlaying != null
                              ? _NowPlayingBadge(
                                  key: const ValueKey('playing'),
                                  title: nowPlaying['title'] ?? 'Unknown',
                                )
                              : Row(
                                  key: ValueKey(isOnline),
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isOnline
                                            ? _C.neonGreen
                                            : _C.textMuted,
                                        boxShadow: isOnline
                                            ? [BoxShadow(
                                                color: _C.neonGreen,
                                                blurRadius: 6)]
                                            : [],
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      isOnline ? 'ONLINE' : 'OFFLINE',
                                      style: TextStyle(
                                        color: isOnline
                                            ? _C.neonGreen.withValues(alpha: 0.85)
                                            : _C.textSec,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 2,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                  // Music share button
                  _AppBarIconBtn(
                    icon: Icons.queue_music_rounded,
                    color: _C.cyan,
                    onTap: _showAttachmentSheet,
                  ),
                  const SizedBox(width: 4),
                  // Options button
                  _AppBarIconBtn(
                    icon: Icons.more_vert_rounded,
                    color: _C.textSec,
                    onTap: _showChatOptions,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Empty State ─────────────────────────────────────────────────────────────

  Widget _buildEmptyState(String displayUser) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: _C.cyan.withValues(alpha: 0.1), width: 1),
                ),
              ),
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _C.bgCard,
                  border: Border.all(
                      color: _C.cyan.withValues(alpha: 0.25), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                        color: _C.cyan.withValues(alpha: 0.12),
                        blurRadius: 20)
                  ],
                ),
                child: const Icon(Icons.waving_hand_rounded,
                    size: 30, color: _C.cyanDim),
              ),
            ],
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(
                  begin: const Offset(0.96, 0.96),
                  end: const Offset(1.04, 1.04),
                  duration: 2500.ms),
          const SizedBox(height: 24),
          Text(
            'OPEN CHANNEL',
            style: const TextStyle(
              color: _C.cyan,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a convo with @$displayUser',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _C.textSec.withValues(alpha: 0.7),
              fontSize: 13,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Share music · Send messages',
            style: TextStyle(
              color: _C.textMuted.withValues(alpha: 0.9),
              fontSize: 11,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Typing Indicator ────────────────────────────────────────────────────────

  Widget _buildTypingIndicator(String displayUser) {
    final otherTyping =
        ref.watch(typingStatusProvider(widget.otherUid)).value ?? false;
    if (!otherTyping) return const SizedBox();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildMiniAvatar(),
          const SizedBox(width: 10),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF0A1020), Color(0xFF070C18)]),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: _C.cyan.withValues(alpha: 0.15)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _TypingDots(),
                const SizedBox(width: 8),
                Text(
                  '@$displayUser',
                  style: const TextStyle(
                    color: _C.cyanDim,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.4, end: 0),
    );
  }

  // ─── Message List ────────────────────────────────────────────────────────────

  Widget _buildMessageList(List<Message> messages) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(top: 12, bottom: 12),
      reverse: true,
      itemCount: messages.length,
      itemBuilder: (ctx, i) {
        final msg = messages[i];
        final prevMsg = i < messages.length - 1 ? messages[i + 1] : null;
        final nextMsg = i > 0 ? messages[i - 1] : null;
        final showDateBadge =
            prevMsg == null || !_isSameDay(msg.createdAt, prevMsg.createdAt);

        return Column(
          children: [
            if (showDateBadge) _buildDateBadge(msg.createdAt),
            _buildBubble(msg, prevMsg, nextMsg)
                .animate(delay: (i % 10 * 40).ms)
                .fadeIn(duration: 350.ms)
                .slideX(
                  begin: msg.senderId == widget.otherUid ? -0.08 : 0.08,
                  end: 0,
                  curve: Curves.easeOutCubic,
                ),
          ],
        );
      },
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // ─── Date Badge ──────────────────────────────────────────────────────────────

  Widget _buildDateBadge(DateTime date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  Colors.transparent,
                  _C.cyan.withValues(alpha: 0.15),
                ]),
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 14),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: _C.bgCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _C.cyan.withValues(alpha: 0.2)),
              boxShadow: [
                BoxShadow(
                    color: _C.cyan.withValues(alpha: 0.06),
                    blurRadius: 8)
              ],
            ),
            child: Text(
              _formatDate(date),
              style: const TextStyle(
                color: _C.cyanDim,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  _C.cyan.withValues(alpha: 0.15),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Message Bubble ──────────────────────────────────────────────────────────

  Widget _buildBubble(Message message, Message? prev, Message? next) {
    final isMe = message.senderId != widget.otherUid;
    final isFirstInGroup = prev == null || prev.senderId != message.senderId;
    final isLastInGroup = next == null || next.senderId != message.senderId;
    final isMedia = message.type != 'text';
    final isRead = message.readBy.contains(widget.otherUid);

    const r = Radius.circular(20);
    const rTail = Radius.circular(5);

    return Padding(
      padding: EdgeInsets.only(
        left: isMe ? 56 : 12,
        right: isMe ? 12 : 56,
        top: isFirstInGroup ? 8 : 2,
        bottom: isLastInGroup ? 6 : 2,
      ),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            if (isLastInGroup)
              _buildMiniAvatar()
            else
              const SizedBox(width: 28),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.72),
                  decoration: BoxDecoration(
                    gradient: isMe ? _C.bubbleGradMe : _C.bubbleGradThem,
                    borderRadius: BorderRadius.only(
                      topLeft: isMe || !isFirstInGroup ? r : rTail,
                      topRight: !isMe || !isFirstInGroup ? r : rTail,
                      bottomLeft:
                          isMe ? r : (isLastInGroup ? rTail : r),
                      bottomRight:
                          !isMe ? r : (isLastInGroup ? rTail : r),
                    ),
                    border: Border.all(
                      color: isMe
                          ? _C.cyan.withValues(alpha: 0.18)
                          : _C.border,
                      width: 1,
                    ),
                    boxShadow: [
                      if (isMe)
                        BoxShadow(
                          color: _C.cyan.withValues(alpha: 0.07),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                    ],
                  ),
                  child: isMedia
                      ? Padding(
                          padding: const EdgeInsets.all(10),
                          child: _buildMediaCard(
                              message.type, message.metadata),
                        )
                      : Padding(
                          padding:
                              const EdgeInsets.fromLTRB(14, 10, 14, 8),
                          child: Column(
                            crossAxisAlignment: isMe
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              Text(
                                message.content,
                                style: const TextStyle(
                                  color: _C.textPri,
                                  fontSize: 14.5,
                                  height: 1.45,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _formatTime(message.createdAt),
                                    style: TextStyle(
                                      color: isMe
                                          ? _C.cyanDim.withValues(alpha: 0.5)
                                          : _C.textSec,
                                      fontSize: 10,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  if (isMe) ...[
                                    const SizedBox(width: 5),
                                    Icon(
                                      Icons.done_all_rounded,
                                      size: 13,
                                      color: isRead
                                          ? _C.cyan
                                          : _C.textSec,
                                    )
                                        .animate(
                                            target: isRead ? 1 : 0)
                                        .shimmer(
                                            color: _C.cyan
                                                .withValues(alpha: 0.4),
                                            duration: 2000.ms),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                ),
                if (isMedia)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
                    child: Text(
                      _formatTime(message.createdAt),
                      style: TextStyle(
                          color: _C.textSec.withValues(alpha: 0.6),
                          fontSize: 10),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniAvatar() {
    final profileAsync =
        ref.watch(otherUserProfileProvider(widget.otherUid));
    final profile = profileAsync.value;
    final photoUrl = profile?['photoUrl'] ?? widget.profileUrl;
    final username =
        profile?['username'] ?? widget.username ?? '?';

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _C.cyanDim.withValues(alpha: 0.3)),
      ),
      child: CircleAvatar(
        radius: 13,
        backgroundColor: const Color(0xFF0A1525),
        backgroundImage:
            photoUrl != null ? NetworkImage(photoUrl) : null,
        child: photoUrl == null
            ? Text(
                username.isNotEmpty ? username[0].toUpperCase() : '?',
                style: const TextStyle(
                    color: _C.cyan,
                    fontSize: 10,
                    fontWeight: FontWeight.w900),
              )
            : null,
      ),
    );
  }

  // ─── Input Bar ───────────────────────────────────────────────────────────────

  Widget _buildInputBar() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          padding: EdgeInsets.fromLTRB(
              12, 10, 12, MediaQuery.of(context).padding.bottom + 10),
          decoration: BoxDecoration(
            color: _C.bgPanel.withValues(alpha: 0.95),
            border: Border(
                top: BorderSide(
                    color: _C.cyan.withValues(alpha: 0.1), width: 1)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Attach button
              GestureDetector(
                onTap: _showAttachmentSheet,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _isTyping
                        ? _C.bgCard
                        : _C.cyan.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: _isTyping
                          ? _C.border
                          : _C.cyan.withValues(alpha: 0.3),
                    ),
                  ),
                  child: AnimatedRotation(
                    turns: _isTyping ? 0.125 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: Icon(
                      _isTyping
                          ? Icons.close_rounded
                          : Icons.add_rounded,
                      color: _isTyping ? _C.textSec : _C.cyanDim,
                      size: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Text input — cyber styled
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 120),
                  decoration: BoxDecoration(
                    color: _C.bgCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _isTyping
                          ? _C.cyan.withValues(alpha: 0.3)
                          : _C.border,
                    ),
                    boxShadow: _isTyping
                        ? [
                            BoxShadow(
                              color: _C.cyan.withValues(alpha: 0.06),
                              blurRadius: 10,
                            )
                          ]
                        : [],
                  ),
                  child: TextField(
                    controller: _msgController,
                    focusNode: _focusNode,
                    maxLines: null,
                    style: const TextStyle(
                        color: _C.textPri, fontSize: 14.5, height: 1.4),
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Send a message...',
                      hintStyle: TextStyle(
                        color: _C.textSec.withValues(alpha: 0.6),
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Send button — animated neon
              GestureDetector(
                onTap: _sendMessage,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: _isTyping ? _C.cyanGrad : null,
                    color: _isTyping ? null : _C.bgCard,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: _isTyping
                          ? Colors.transparent
                          : _C.border,
                    ),
                    boxShadow: _isTyping
                        ? [
                            BoxShadow(
                              color: _C.cyan.withValues(alpha: 0.5),
                              blurRadius: 18,
                              offset: const Offset(0, 4),
                            )
                          ]
                        : [],
                  ),
                  child: Icon(
                    Icons.send_rounded,
                    color: _isTyping ? _C.bg : _C.textSec,
                    size: 19,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Media Card ──────────────────────────────────────────────────────────────

  Widget _buildMediaCard(String type, Map<String, dynamic>? metadata) {
    if (metadata == null) return const SizedBox();

    final title = metadata['title'] ?? metadata['name'] ?? 'Media';
    final subtitle =
        metadata['artist'] ?? '${metadata['songCount'] ?? '–'} tracks';
    final imageUrl = metadata['image'] ?? metadata['coverImage'];

    final IconData typeIcon = type == 'song'
        ? Icons.music_note_rounded
        : type == 'playlist'
            ? Icons.queue_music_rounded
            : type == 'artist'
                ? Icons.mic_rounded
                : Icons.album_rounded;

    final Color typeColor = type == 'song'
        ? _C.cyan
        : type == 'playlist'
            ? _C.purple
            : _C.gold;

    return GestureDetector(
      onTap: () async {
        try {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Loading $title...'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: _C.bgCard,
              duration: const Duration(seconds: 1),
            ),
          );
          List<Song> queue = [];
          if (type == 'song') {
            queue = [Song.fromJson(metadata)];
          } else if (type == 'playlist') {
            final id = metadata['id'] as String?;
            if (id != null) {
              queue = await ref
                  .read(databaseServiceProvider)
                  .getPlaylistSongs(id)
                  .first;
            }
          } else {
            queue = await ref
                .read(apiServiceProvider)
                .searchSongs(title, limit: 10);
          }
          if (queue.isEmpty) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No tracks found.')));
            }
            return;
          }
          ref.read(currentPlaylistProvider.notifier).state = queue;
          ref.read(currentSongIndexProvider.notifier).state = 0;
          playQueue(ref, queue, 0);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Playback failed: $e')));
          }
        }
      },
      child: Container(
        width: 245,
        decoration: BoxDecoration(
          color: _C.bgPanel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: typeColor.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
                color: typeColor.withValues(alpha: 0.06), blurRadius: 14)
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Type badge row
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: typeColor.withValues(alpha: 0.4)),
                      borderRadius: BorderRadius.circular(6),
                      color: typeColor.withValues(alpha: 0.08),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(typeIcon, size: 11, color: typeColor),
                        const SizedBox(width: 5),
                        Text(
                          type.toUpperCase(),
                          style: TextStyle(
                            color: typeColor,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Cover + info + play
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  // Album art
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: CachedNetworkImage(
                      memCacheWidth: 400,
                      imageUrl: imageUrl ?? '',
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                      errorWidget: (c, e, _) => Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: typeColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: typeColor.withValues(alpha: 0.2)),
                        ),
                        child: Icon(typeIcon,
                            color: typeColor.withValues(alpha: 0.5),
                            size: 24),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: _C.textPri,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: _C.textSec.withValues(alpha: 0.8),
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Play button
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                          colors: [typeColor, _C.purple]),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: typeColor.withValues(alpha: 0.4),
                            blurRadius: 10)
                      ],
                    ),
                    child: Icon(Icons.play_arrow_rounded,
                        color: _C.bg, size: 20),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Attachment Sheet ────────────────────────────────────────────────────────

  void _showAttachmentSheet() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => _InlineLibraryPicker(otherUid: widget.otherUid),
    );
  }

  // ─── Chat Options ────────────────────────────────────────────────────────────

  void _showChatOptions() {
    final chatSvc = ref.read(chatServiceProvider);
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (c) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 28),
        decoration: BoxDecoration(
          color: _C.bgPanel,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: _C.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 14),
              width: 36,
              height: 3,
              decoration: BoxDecoration(
                color: _C.borderGlow,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            _GamingOptionTile(
              icon: Icons.delete_outline_rounded,
              label: 'Clear Chat',
              subtitle: 'Remove all messages from this conversation',
              color: _C.magenta,
              onTap: () async {
                Navigator.pop(c);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (d) => AlertDialog(
                    backgroundColor: _C.bgPanel,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18)),
                    title: const Text('Clear Chat?',
                        style: TextStyle(
                            color: _C.textPri,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1)),
                    content: Text(
                        'This will delete all messages in this conversation.',
                        style: TextStyle(color: _C.textSec)),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(d, false),
                          child: const Text('Cancel',
                              style: TextStyle(color: _C.textSec))),
                      TextButton(
                        onPressed: () => Navigator.pop(d, true),
                        child: const Text('CLEAR',
                            style: TextStyle(
                                color: _C.magenta,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await chatSvc.clearChat(widget.otherUid);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Chat cleared'),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: _C.bgCard,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                                color: _C.magenta.withValues(alpha: 0.3))),
                      ),
                    );
                  }
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ─── STATUS AVATAR ────────────────────────────────────────────────────────────

class _StatusAvatar extends StatefulWidget {
  final String? photoUrl;
  final String initial;
  final bool isOnline;
  final double radius;
  const _StatusAvatar({
    required this.photoUrl,
    required this.initial,
    required this.isOnline,
    required this.radius,
  });

  @override
  State<_StatusAvatar> createState() => _StatusAvatarState();
}

class _StatusAvatarState extends State<_StatusAvatar>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = widget.photoUrl != null && widget.photoUrl!.isNotEmpty;
    final isBase64 = hasPhoto && widget.photoUrl!.startsWith('data:image');

    ImageProvider? bgImage;
    if (isBase64) {
      try {
        final base64String = widget.photoUrl!.split(',').last;
        bgImage = MemoryImage(base64Decode(base64String));
      } catch (_) {
        bgImage = null;
      }
    } else if (hasPhoto) {
      bgImage = widget.photoUrl!.startsWith('http')
          ? CachedNetworkImageProvider(widget.photoUrl!)
          : NetworkImage(widget.photoUrl!) as ImageProvider;
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        if (widget.isOnline)
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => Transform.rotate(
              angle: _ctrl.value * 2 * math.pi,
              child: Container(
                width: widget.radius * 2 + 10,
                height: widget.radius * 2 + 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    colors: [
                      _C.cyan.withValues(alpha: 0),
                      _C.cyan.withValues(alpha: 0.7),
                      _C.cyan.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
        Container(
          width: widget.radius * 2 + 4,
          height: widget.radius * 2 + 4,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: widget.isOnline
                  ? _C.cyan.withValues(alpha: 0.4)
                  : _C.border,
              width: 1.5,
            ),
          ),
        ),
        CircleAvatar(
          radius: widget.radius,
          backgroundColor: const Color(0xFF0A1525),
          backgroundImage: bgImage,
          child: !hasPhoto || bgImage == null
              ? Text(
                  widget.initial,
                  style: TextStyle(
                    color: _C.cyan,
                    fontWeight: FontWeight.w900,
                    fontSize: widget.radius * 0.72,
                  ),
                )
              : null,
        ),
        Positioned(
          right: 1,
          bottom: 1,
          child: Container(
            width: 11,
            height: 11,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.isOnline ? _C.neonGreen : _C.bgPanel,
              border: Border.all(color: _C.bg, width: 1.5),
              boxShadow: widget.isOnline
                  ? [const BoxShadow(color: _C.neonGreen, blurRadius: 6)]
                  : [],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── NOW PLAYING BADGE ────────────────────────────────────────────────────────

class _NowPlayingBadge extends StatelessWidget {
  final String title;
  const _NowPlayingBadge({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ShaderMask(
          shaderCallback: (b) => _C.cyanGrad.createShader(b),
          child: const Icon(Icons.graphic_eq_rounded,
              size: 12, color: Colors.white),
        )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scaleY(begin: 0.6, end: 1.0, duration: 600.ms),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            title,
            style: const TextStyle(
              color: _C.cyanDim,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ).animate(onPlay: (c) => c.repeat())
            .shimmer(
              duration: 2200.ms,
              color: _C.cyan.withValues(alpha: 0.3),
            ),
        ),
      ],
    );
  }
}

// ─── TYPING DOTS ─────────────────────────────────────────────────────────────

class _TypingDots extends StatefulWidget {
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final delay = i / 3;
          final t = (_ctrl.value - delay).clamp(0.0, 1.0);
          final scale =
              0.6 + 0.6 * math.sin(t * math.pi);
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _C.cyan.withValues(alpha: 0.4 + scale * 0.6),
              boxShadow: [
                BoxShadow(
                    color: _C.cyan.withValues(alpha: scale * 0.4),
                    blurRadius: 4),
              ],
            ),
            transform: Matrix4.identity()
              ..scale(0.7 + scale * 0.5),
            transformAlignment: Alignment.center,
          );
        }),
      ),
    );
  }
}

// ─── APPBAR ICON BUTTON ───────────────────────────────────────────────────────

class _AppBarIconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _AppBarIconBtn(
      {required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }
}

// ─── GAMING OPTION TILE ───────────────────────────────────────────────────────

class _GamingOptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const _GamingOptionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withValues(alpha: 0.2)),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        letterSpacing: 0.5)),
                Text(subtitle,
                    style: TextStyle(
                        color: _C.textSec.withValues(alpha: 0.6),
                        fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── GAMING LOADER ────────────────────────────────────────────────────────────

class _GamingLoader extends StatefulWidget {
  const _GamingLoader();

  @override
  State<_GamingLoader> createState() => _GamingLoaderState();
}

class _GamingLoaderState extends State<_GamingLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 1))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              value: null,
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                Color.lerp(_C.cyan, _C.purple, _ctrl.value)!,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'LOADING...',
            style: TextStyle(
              color: _C.textSec.withValues(alpha: 0.6),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 3,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── CHAT BACKGROUND PAINTER ─────────────────────────────────────────────────

class _ChatBgPainter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DotGridPainter(),
      child: Container(color: _C.bg),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0D1A2A)
      ..style = PaintingStyle.fill;

    const spacing = 28.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.0, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotGridPainter old) => false;
}

// ─── ATTACHMENT TILE ─────────────────────────────────────────────────────────
// (kept for _showChatOptions compatibility - now replaced by _GamingOptionTile)

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
    return _GamingOptionTile(
      icon: icon,
      label: label,
      subtitle: subtitle,
      color: color,
      onTap: onTap,
    );
  }
}

// ─── INLINE LIBRARY PICKER ───────────────────────────────────────────────────

class _InlineLibraryPicker extends ConsumerStatefulWidget {
  final String otherUid;
  const _InlineLibraryPicker({required this.otherUid});

  @override
  ConsumerState<_InlineLibraryPicker> createState() =>
      _InlineLibraryPickerState();
}

class _InlineLibraryPickerState extends ConsumerState<_InlineLibraryPicker> {
  int _tab = 0;

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
          color: _C.bgPanel,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          border: Border.all(color: _C.cyan.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(
                color: _C.cyan.withValues(alpha: 0.06), blurRadius: 30)
          ],
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 14),
              width: 36,
              height: 3,
              decoration: BoxDecoration(
                color: _C.cyan.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _C.cyan.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: _C.cyan.withValues(alpha: 0.25)),
                    ),
                    child: const Icon(Icons.library_music_rounded,
                        color: _C.cyanDim, size: 18),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'SHARE FROM LIBRARY',
                    style: TextStyle(
                      color: _C.textPri,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
            // Tabs
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _LibTab(
                    label: 'PLAYLISTS',
                    active: _tab == 0,
                    onTap: () => setState(() => _tab = 0),
                  ),
                  const SizedBox(width: 10),
                  _LibTab(
                    label: 'LIKED',
                    active: _tab == 1,
                    onTap: () => setState(() => _tab = 1),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
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

  Widget _buildPlaylists(
      AsyncValue<List<Map<String, dynamic>>> async,
      ScrollController scroll) {
    return async.when(
      loading: () => const Center(child: _GamingLoader()),
      error: (e, _) => Center(
          child: Text('Error: $e',
              style: const TextStyle(color: _C.magenta))),
      data: (playlists) {
        if (playlists.isEmpty) {
          return Center(
              child: Text('No playlists yet',
                  style:
                      TextStyle(color: _C.textSec.withValues(alpha: 0.4))));
        }
        return ListView.builder(
          controller: scroll,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: playlists.length,
          itemBuilder: (c, i) {
            final p = playlists[i];
            return _LibraryItem(
              icon: Icons.queue_music_rounded,
              color: _C.purple,
              title: p['name'] ?? 'Playlist',
              subtitle: '${p['songCount'] ?? 0} tracks',
              onTap: () async {
                Navigator.pop(context);
                await ref.read(chatServiceProvider).shareMedia(
                      widget.otherUid,
                      'playlist',
                      {
                        'id': p['id'],
                        'name': p['name'],
                        'songCount': p['songCount'],
                        'coverImage': p['coverImage'] ?? '',
                      },
                    );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text('Shared playlist "${p['name']}"!'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: _C.bgCard,
                    ),
                  );
                }
              },
            );
          },
        );
      },
    );
  }

  Widget _buildLikedSongs(
      AsyncValue<List<Song>> async, ScrollController scroll) {
    return async.when(
      loading: () => const Center(child: _GamingLoader()),
      error: (e, _) => Center(
          child: Text('Error: $e',
              style: const TextStyle(color: _C.magenta))),
      data: (songs) {
        if (songs.isEmpty) {
          return Center(
              child: Text('No liked songs yet',
                  style: TextStyle(
                      color: _C.textSec.withValues(alpha: 0.4))));
        }
        return ListView.builder(
          controller: scroll,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: songs.length,
          itemBuilder: (c, i) {
            final s = songs[i];
            return _LibraryItem(
              imageUrl: s.image,
              color: _C.cyan,
              title: s.title,
              subtitle: s.artist,
              onTap: () async {
                Navigator.pop(context);
                await ref
                    .read(chatServiceProvider)
                    .shareMedia(widget.otherUid, 'song', s.toJson());
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Shared "${s.title}"!'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: _C.bgCard,
                    ),
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

// ─── LIBRARY TAB ─────────────────────────────────────────────────────────────

class _LibTab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _LibTab(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          gradient: active ? _C.cyanGrad : null,
          color: active ? null : _C.bgCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active
                ? Colors.transparent
                : _C.border,
          ),
          boxShadow: active
              ? [BoxShadow(color: _C.cyan.withValues(alpha: 0.3), blurRadius: 10)]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? _C.bg : _C.textSec,
            fontWeight: FontWeight.w800,
            fontSize: 11,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }
}

// ─── LIBRARY ITEM ─────────────────────────────────────────────────────────────

class _LibraryItem extends StatelessWidget {
  final IconData? icon;
  final String? imageUrl;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _LibraryItem({
    this.icon,
    this.imageUrl,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _C.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _C.border),
        ),
        child: Row(
          children: [
            // Artwork
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: imageUrl != null
                  ? CachedNetworkImage(
                      memCacheWidth: 400,
                      imageUrl: imageUrl!,
                      width: 46,
                      height: 46,
                      fit: BoxFit.cover,
                      errorWidget: (c, e, _) => _iconBox(color),
                    )
                  : _iconBox(color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: _C.textPri,
                          fontWeight: FontWeight.w700,
                          fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(subtitle,
                      style: TextStyle(
                          color: _C.textSec.withValues(alpha: 0.7),
                          fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: color.withValues(alpha: 0.4)),
                borderRadius: BorderRadius.circular(8),
                color: color.withValues(alpha: 0.08),
              ),
              child: Text(
                'SHARE',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconBox(Color c) => Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.withValues(alpha: 0.2)),
        ),
        child: Icon(icon ?? Icons.music_note_rounded,
            color: c.withValues(alpha: 0.5), size: 22),
      );
}