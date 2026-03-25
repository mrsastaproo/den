import 'dart:ui';
import 'dart:math' as math;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/services/social_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_theme.dart';

// ─── GAMING COLOR CONSTANTS ───────────────────────────────────────────────────

class _GC {
  static const bgDeep       = Color(0xFF020409);
  static const bgPanel      = Color(0xFF080D18);
  static const bgCard       = Color(0xFF0C1220);
  static const bgCardHover  = Color(0xFF101828);
  static const cyan         = Color(0xFF00F5FF);
  static const cyanDim      = Color(0xFF00BFCC);
  static const magenta      = Color(0xFFFF006E);
  static const magentaDim   = Color(0xFFCC0058);
  static const gold         = Color(0xFFFFD700);
  static const goldDim      = Color(0xFFC8A800);
  static const neonGreen    = Color(0xFF00FF88);
  static const purple       = Color(0xFF9B30FF);
  static const purpleDim    = Color(0xFF6B1FCC);
  static const border       = Color(0xFF1A2840);
  static const borderGlow   = Color(0xFF1E3A5F);
  static const textPrimary  = Color(0xFFE8F4FF);
  static const textSecond   = Color(0xFF6B8CAE);
  static const textMuted    = Color(0xFF2D4A6A);

  static const primaryGrad = LinearGradient(
    colors: [cyan, purple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const magentaGrad = LinearGradient(
    colors: [magenta, purple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const goldGrad = LinearGradient(
    colors: [gold, Color(0xFFFF9500)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const cardGrad = LinearGradient(
    colors: [Color(0xFF0C1220), Color(0xFF080D18)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static BoxDecoration scanlineCard({Color? glowColor, double opacity = 0.06}) =>
    BoxDecoration(
      gradient: cardGrad,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: (glowColor ?? cyan).withValues(alpha: 0.18),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: (glowColor ?? cyan).withValues(alpha: 0.04),
          blurRadius: 20,
          spreadRadius: 0,
        ),
      ],
    );
}

// ─── MAIN SCREEN ─────────────────────────────────────────────────────────────

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  late TabController _tabController;
  late AnimationController _glowPulse;
  bool _isSearching = false;
  List<Map<String, dynamic>> _searchResults = [];
  String _activeQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _glowPulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _usernameController.dispose();
    _tabController.dispose();
    _glowPulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: _GC.bgDeep,
      body: Stack(
        children: [
          // Animated background grid
          Positioned.fill(child: RepaintBoundary(child: _HexGrid())),
          // Deep radial glow
          Positioned(
            top: -120,
            left: -80,
            child: AnimatedBuilder(
              animation: _glowPulse,
              builder: (_, __) => Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _GC.cyan.withValues(alpha: 0.06 + _glowPulse.value * 0.03),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            right: -60,
            child: AnimatedBuilder(
              animation: _glowPulse,
              builder: (_, __) => Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _GC.magenta.withValues(alpha: 0.05 + _glowPulse.value * 0.03),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Main content
          profileAsync.when(
            loading: () => const Center(
              child: _GamingLoader(),
            ),
            error: (e, _) => Center(
              child: Text('ERROR: $e',
                  style: const TextStyle(color: _GC.magenta, fontFamily: 'monospace')),
            ),
            data: (profile) {
              if (profile == null || profile['username'] == null) {
                return _buildClaimUsernamePrompt(profile);
              }
              return _buildFriendsHub(profile);
            },
          ),
        ],
      ),
    );
  }

  // ─── Claim Username ──────────────────────────────────────────────────────

  Widget _buildClaimUsernamePrompt(Map<String, dynamic>? profile) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon with glow ring
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: _GC.cyan.withValues(alpha: 0.3), width: 1),
                    ),
                  ),
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0A1520), Color(0xFF051020)],
                      ),
                      border: Border.all(color: _GC.cyan.withValues(alpha: 0.6), width: 1.5),
                      boxShadow: [
                        BoxShadow(color: _GC.cyan.withValues(alpha: 0.3), blurRadius: 20),
                      ],
                    ),
                    child: const Icon(Icons.alternate_email_rounded, size: 34, color: _GC.cyan),
                  ),
                ],
              ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
              const SizedBox(height: 24),
              // Title
              _GlitchText(
                'CLAIM YOUR TAG',
                style: const TextStyle(
                  color: _GC.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                ),
              ).animate().fadeIn(delay: 200.ms),
              const SizedBox(height: 8),
              Text(
                'Your unique identifier in the network',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _GC.textSecond.withValues(alpha: 0.7),
                  fontSize: 13,
                  letterSpacing: 1,
                ),
              ).animate().fadeIn(delay: 300.ms),
              const SizedBox(height: 32),
              // Input
              _GamingTextField(
                controller: _usernameController,
                hint: 'yourhandle',
                prefix: '@ ',
                prefixColor: _GC.cyan,
              ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2, end: 0),
              const SizedBox(height: 20),
              // CTA button
              _GamingButton(
                label: 'CLAIM HANDLE',
                icon: Icons.flash_on_rounded,
                gradient: const LinearGradient(colors: [_GC.cyan, _GC.purple]),
                glowColor: _GC.cyan,
                onTap: () async {
                  final username = _usernameController.text.trim().toLowerCase();
                  if (username.length < 3) {
                    _showGamingSnack('Username must be at least 3 characters', isError: true);
                    return;
                  }
                  final success = await ref.read(socialServiceProvider).claimUsername(
                    username,
                    profile?['displayName'] ?? 'User',
                    profile?['photoUrl'],
                  );
                  if (mounted) {
                    _showGamingSnack(success ? '⚡ @$username CLAIMED!' : '✗ Handle taken. Try another.', isError: !success);
                  }
                },
              ).animate().fadeIn(delay: 500.ms),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Friends Hub ──────────────────────────────────────────────────────────

  Widget _buildFriendsHub(Map<String, dynamic> profile) {
    final requestsAsync = ref.watch(incomingRequestsProvider);
    final requestsCount = requestsAsync.value?.length ?? 0;

    return Column(
      children: [
        _buildHeader(profile, requestsCount),
        _buildTabBar(requestsCount),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildFriendsTab(),
              _buildRequestsTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(Map<String, dynamic> profile, int requestsCount) {
    final username = profile['username'] ?? '';
    final String? photoUrl = (profile['photoUrl'] != null && profile['photoUrl']!.toString().isNotEmpty)
        ? profile['photoUrl']
        : ref.read(authStateProvider).value?.photoURL;

    return Container(
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 0),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar with scanner ring
              _ScannerAvatar(
                radius: 24,
                photoUrl: photoUrl,
                initial: username.isNotEmpty ? username[0].toUpperCase() : '?',
                isOnline: true,
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'SQUAD',
                        style: TextStyle(
                          color: _GC.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          border: Border.all(color: _GC.cyan.withValues(alpha: 0.5)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'HQ',
                          style: TextStyle(
                            color: _GC.cyan,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: _GC.neonGreen,
                          shape: BoxShape.circle,
                        ),
                      ).animate(onPlay: (c) => c.repeat(reverse: true))
                        .fade(begin: 0.4, end: 1.0, duration: 1200.ms),
                      const SizedBox(width: 6),
                      ShaderMask(
                        shaderCallback: (b) => _GC.primaryGrad.createShader(b),
                        child: Text(
                          '@$username',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              // Add friend button — neon hexagonal style
              _HexButton(
                icon: Icons.person_add_alt_1_rounded,
                onTap: () => _showAddFriendSheet(context),
                color: _GC.cyan,
              ).animate().scale(delay: 200.ms, duration: 400.ms, curve: Curves.easeOutBack),
            ],
          ),
          const SizedBox(height: 16),
          // Search bar — cyberpunk style
          _CyberSearchBar(
            controller: _searchController,
            onChanged: _searchUsers,
            activeQuery: _activeQuery,
            onClear: () {
              _searchController.clear();
              _searchUsers('');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(int requestsCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: _GC.bgPanel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _GC.border),
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            gradient: const LinearGradient(colors: [_GC.cyan, _GC.purple]),
            borderRadius: BorderRadius.circular(9),
            boxShadow: [
              BoxShadow(color: _GC.cyan.withValues(alpha: 0.4), blurRadius: 12),
            ],
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: _GC.bgDeep,
          unselectedLabelColor: _GC.textSecond,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 12,
            letterSpacing: 2,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            letterSpacing: 2,
          ),
          padding: const EdgeInsets.all(4),
          tabs: [
            const Tab(text: 'FRIENDS'),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('REQUESTS'),
                  if (requestsCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: _GC.magenta,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: _GC.magenta, blurRadius: 8),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          '$requestsCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ).animate(onPlay: (c) => c.repeat(reverse: true))
                      .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.1, 1.1), duration: 800.ms),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Friends Tab ─────────────────────────────────────────────────────────

  Widget _buildFriendsTab() {
    if (_isSearching) return _buildSearchResults();

    final friendsAsync = ref.watch(friendsListProvider);
    return friendsAsync.when(
      loading: () => const Center(child: _GamingLoader()),
      error: (e, _) => _buildEmpty('CONNECTION LOST', Icons.wifi_off_rounded, _GC.magenta),
      data: (friends) {
        if (friends.isEmpty) {
          return _buildEmpty(
            'SQUAD IS EMPTY\nFIND YOUR CREW →',
            Icons.people_outline_rounded,
            _GC.cyan,
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
          itemCount: friends.length,
          itemBuilder: (c, i) => _FriendCard(
            data: friends[i],
            onTap: () => context.push(
              '/chat/${friends[i]['uid']}',
              extra: {
                'username': friends[i]['username'],
                'profileUrl': friends[i]['photoUrl'],
              },
            ),
          ).animate(delay: (i * 60).ms).fadeIn(duration: 400.ms).slideX(begin: 0.15, end: 0),
        );
      },
    );
  }

  // ─── Requests Tab ────────────────────────────────────────────────────────

  Widget _buildRequestsTab() {
    final requestsAsync = ref.watch(incomingRequestsProvider);
    return requestsAsync.when(
      loading: () => const Center(child: _GamingLoader()),
      error: (e, _) => _buildEmpty('CONNECTION LOST', Icons.wifi_off_rounded, _GC.magenta),
      data: (requests) {
        if (requests.isEmpty) {
          return _buildEmpty(
            'NO PENDING REQUESTS',
            Icons.mark_email_read_rounded,
            _GC.textMuted,
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
          itemCount: requests.length,
          itemBuilder: (c, i) => _RequestCard(
            data: requests[i],
            onAccept: () {
              HapticFeedback.lightImpact();
              ref.read(socialServiceProvider).acceptFriendRequest(requests[i]['fromUid']);
            },
            onDecline: () {
              HapticFeedback.lightImpact();
              ref.read(socialServiceProvider).declineFriendRequest(requests[i]['fromUid']);
            },
          ).animate(delay: (i * 60).ms).fadeIn(duration: 400.ms).slideX(begin: 0.15, end: 0),
        );
      },
    );
  }

  // ─── Search Results ──────────────────────────────────────────────────────

  Widget _buildSearchResults({bool isDiscover = false}) {
    if (!isDiscover && _searchResults.isEmpty && _activeQuery.isEmpty) {
      return _buildEmpty('SEARCH FOR PLAYERS ABOVE', Icons.search_rounded, _GC.textMuted);
    }
    if (_searchResults.isEmpty && _activeQuery.isNotEmpty) {
      return _buildEmpty('NO RESULTS FOR "$_activeQuery"', Icons.person_search_rounded, _GC.magenta);
    }
    if (_searchResults.isEmpty && isDiscover) {
      return _buildEmpty('TYPE TO SEARCH\nFOR PLAYERS', Icons.person_search_rounded, _GC.textMuted);
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
      itemCount: _searchResults.length,
      itemBuilder: (c, i) => _SearchResultCard(
        data: _searchResults[i],
        onAdd: () async {
          HapticFeedback.lightImpact();
          await ref.read(socialServiceProvider).sendFriendRequest(_searchResults[i]['uid']);
          if (mounted) {
            _showGamingSnack('REQUEST SENT TO @${_searchResults[i]['username']}');
          }
        },
      ).animate(delay: (i * 60).ms).fadeIn(duration: 300.ms).slideX(begin: 0.1, end: 0),
    );
  }

  Future<void> _searchUsers(String query) async {
    setState(() => _activeQuery = query);
    if (query.isEmpty) {
      setState(() { _isSearching = false; _searchResults = []; });
      return;
    }
    setState(() => _isSearching = true);
    final results = await ref.read(socialServiceProvider).searchUsersByUsername(query.toLowerCase());
    setState(() => _searchResults = results);
  }

  Widget _buildEmpty(String text, IconData icon, Color color) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withValues(alpha: 0.15), width: 1),
                ),
              ),
              Icon(icon, size: 38, color: color.withValues(alpha: 0.25))
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .fade(begin: 0.15, end: 0.4, duration: 2000.ms),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color.withValues(alpha: 0.35),
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Add Friend Sheet ────────────────────────────────────────────────────

  void _showAddFriendSheet(BuildContext context) {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          decoration: BoxDecoration(
            color: _GC.bgPanel,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: _GC.cyan.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(color: _GC.cyan.withValues(alpha: 0.08), blurRadius: 30),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 14),
                width: 40,
                height: 3,
                decoration: BoxDecoration(
                  color: _GC.cyan.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _GC.cyan.withValues(alpha: 0.4)),
                            color: _GC.cyan.withValues(alpha: 0.08),
                          ),
                          child: const Icon(Icons.person_add_alt_1_rounded, color: _GC.cyan, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'ADD PLAYER',
                              style: TextStyle(
                                color: _GC.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                              ),
                            ),
                            Text(
                              'Enter their @handle to connect',
                              style: TextStyle(
                                color: _GC.textSecond.withValues(alpha: 0.6),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    _GamingTextField(
                      controller: ctrl,
                      hint: 'username',
                      prefix: '@ ',
                      prefixColor: _GC.cyan,
                      autofocus: true,
                    ),
                    const SizedBox(height: 16),
                    _GamingButton(
                      label: 'SEND REQUEST',
                      icon: Icons.send_rounded,
                      gradient: const LinearGradient(colors: [_GC.cyan, _GC.purple]),
                      glowColor: _GC.cyan,
                      onTap: () async {
                        final username = ctrl.text.trim().toLowerCase();
                        if (username.isEmpty) return;
                        HapticFeedback.lightImpact();
                        final uid = await ref.read(socialServiceProvider).getUidByUsername(username);
                        if (uid != null) {
                          await ref.read(socialServiceProvider).sendFriendRequest(uid);
                          if (c.mounted) {
                            Navigator.pop(c);
                            _showGamingSnack('⚡ REQUEST SENT TO @$username');
                          }
                        } else {
                          if (c.mounted) {
                            _showGamingSnack('✗ @$username NOT FOUND', isError: true);
                          }
                        }
                      },
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

  void _showGamingSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
              color: isError ? _GC.magenta : _GC.neonGreen,
              size: 16,
            ),
            const SizedBox(width: 10),
            Text(
              message,
              style: const TextStyle(
                color: _GC.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        backgroundColor: _GC.bgCard,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: (isError ? _GC.magenta : _GC.neonGreen).withValues(alpha: 0.4),
          ),
        ),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      ),
    );
  }
}

// ─── FRIEND CARD ─────────────────────────────────────────────────────────────

class _FriendCard extends ConsumerWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;
  const _FriendCard({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(otherUserProfileProvider(data['uid'] ?? ''));
    final liveData    = profileAsync.value;
    final lastActive  = liveData?['lastActive'] as Timestamp?;
    final isOnline    = liveData?['isOnline'] == true &&
                        (lastActive != null && DateTime.now().difference(lastActive.toDate()).inMinutes < 10);
    final isListening = liveData?['nowPlaying'] != null;
    final username    = liveData?['username'] ?? data['username'] ?? 'User';
    final photoUrl    = liveData?['photoUrl'] ?? data['photoUrl'];

    return GestureDetector(
      onTap: () { HapticFeedback.lightImpact(); onTap(); },
      onLongPress: () {
        HapticFeedback.mediumImpact();
        _showContextMenu(context, ref, username, data['uid'] ?? '');
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          gradient: _GC.cardGrad,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isOnline
                ? _GC.neonGreen.withValues(alpha: 0.25)
                : _GC.border,
            width: 1,
          ),
          boxShadow: isOnline
              ? [BoxShadow(color: _GC.neonGreen.withValues(alpha: 0.06), blurRadius: 12)]
              : [],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(17),
          child: Stack(
            children: [
              // Left accent bar
              Positioned(
                left: 0, top: 0, bottom: 0,
                child: Container(
                  width: 3,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isOnline
                          ? [_GC.neonGreen, _GC.cyan]
                          : [_GC.border, _GC.border],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
              // Card content
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
                child: Row(
                  children: [
                    _ScannerAvatar(
                      radius: 24,
                      photoUrl: photoUrl,
                      initial: username.isNotEmpty ? username[0].toUpperCase() : '?',
                      isOnline: isOnline,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '@$username',
                            style: const TextStyle(
                              color: _GC.textPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 3),
                          if (isListening)
                            Row(
                              children: [
                                ShaderMask(
                                  shaderCallback: (b) => _GC.primaryGrad.createShader(b),
                                  child: const Icon(Icons.graphic_eq_rounded, size: 12, color: Colors.white),
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    liveData!['nowPlaying']['title'] ?? 'Playing music',
                                    style: const TextStyle(
                                      color: _GC.cyanDim,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.3,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ).animate(onPlay: (c) => c.repeat())
                                    .shimmer(duration: 2000.ms, color: _GC.cyan.withValues(alpha: 0.3)),
                                ),
                              ],
                            )
                          else
                            Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isOnline ? _GC.neonGreen : _GC.textMuted,
                                    boxShadow: isOnline
                                        ? [const BoxShadow(color: _GC.neonGreen, blurRadius: 4)]
                                        : [],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isOnline ? 'ONLINE' : 'OFFLINE',
                                  style: TextStyle(
                                    color: isOnline ? _GC.neonGreen.withValues(alpha: 0.8) : _GC.textMuted,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    // Chat button
                    Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        border: Border.all(color: _GC.cyan.withValues(alpha: 0.3)),
                        borderRadius: BorderRadius.circular(10),
                        color: _GC.cyan.withValues(alpha: 0.06),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chat_bubble_rounded, color: _GC.cyan, size: 13),
                          SizedBox(width: 6),
                          Text(
                            'CHAT',
                            style: TextStyle(
                              color: _GC.cyan,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
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

  void _showContextMenu(BuildContext context, WidgetRef ref, String username, String uid) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (c) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 28),
        decoration: BoxDecoration(
          color: _GC.bgPanel,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _GC.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 14),
              width: 36,
              height: 3,
              decoration: BoxDecoration(
                color: _GC.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Text(
                '@$username',
                style: const TextStyle(
                  color: _GC.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(height: 8),
            _ContextOption(
              icon: Icons.person_remove_rounded,
              label: 'Remove from Squad',
              color: _GC.textSecond,
              onTap: () {
                Navigator.pop(c);
                ref.read(socialServiceProvider).removeFriend(uid);
              },
            ),
            _ContextOption(
              icon: Icons.block_flipped,
              label: 'Block Player',
              color: _GC.magenta,
              onTap: () {
                Navigator.pop(c);
                ref.read(socialServiceProvider).blockUser(uid);
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

// ─── CONTEXT OPTION ──────────────────────────────────────────────────────────

class _ContextOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ContextOption({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 14,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── REQUEST CARD ─────────────────────────────────────────────────────────────

class _RequestCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  const _RequestCard({required this.data, required this.onAccept, required this.onDecline});

  @override
  Widget build(BuildContext context) {
    final username = data['username'] ?? data['fromUid'] ?? 'User';
    final photoUrl = data['photoUrl'];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        gradient: _GC.cardGrad,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _GC.magenta.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(color: _GC.magenta.withValues(alpha: 0.04), blurRadius: 12),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: Stack(
          children: [
            Positioned(
              left: 0, top: 0, bottom: 0,
              child: Container(
                width: 3,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_GC.magenta, _GC.purple],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
              child: Row(
                children: [
                  _ScannerAvatar(
                    radius: 23,
                    photoUrl: photoUrl,
                    initial: username.isNotEmpty ? username[0].toUpperCase() : '?',
                    isOnline: false,
                    ringColor: _GC.magenta,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '@$username',
                          style: const TextStyle(
                            color: _GC.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'WANTS TO JOIN YOUR SQUAD',
                          style: TextStyle(
                            color: _GC.magenta.withValues(alpha: 0.7),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Decline
                  GestureDetector(
                    onTap: () { HapticFeedback.lightImpact(); onDecline(); },
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.05),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: const Icon(Icons.close_rounded, color: Colors.white38, size: 17),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Accept
                  GestureDetector(
                    onTap: () { HapticFeedback.lightImpact(); onAccept(); },
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: [_GC.neonGreen, _GC.cyan]),
                        boxShadow: [
                          BoxShadow(color: _GC.neonGreen, blurRadius: 10, spreadRadius: 0),
                        ],
                      ),
                      child: const Icon(Icons.check_rounded, color: _GC.bgDeep, size: 19),
                    ),
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

// ─── SEARCH RESULT CARD ───────────────────────────────────────────────────────

class _SearchResultCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final VoidCallback onAdd;
  const _SearchResultCard({required this.data, required this.onAdd});

  @override
  State<_SearchResultCard> createState() => _SearchResultCardState();
}

class _SearchResultCardState extends State<_SearchResultCard> {
  bool _sent = false;

  @override
  Widget build(BuildContext context) {
    final username    = widget.data['username'] ?? 'User';
    final displayName = widget.data['displayName'] ?? '';
    final photoUrl    = widget.data['photoUrl'];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: _GC.scanlineCard(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          child: Row(
            children: [
              _ScannerAvatar(
                radius: 23,
                photoUrl: photoUrl,
                initial: username.isNotEmpty ? username[0].toUpperCase() : '?',
                isOnline: false,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '@$username',
                      style: const TextStyle(
                        color: _GC.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (displayName.isNotEmpty)
                      Text(
                        displayName,
                        style: const TextStyle(
                          color: _GC.textSecond,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _sent ? null : () {
                  setState(() => _sent = true);
                  widget.onAdd();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    gradient: _sent ? null : const LinearGradient(colors: [_GC.cyan, _GC.purple]),
                    color: _sent ? Colors.white.withValues(alpha: 0.05) : null,
                    borderRadius: BorderRadius.circular(10),
                    border: _sent ? Border.all(color: Colors.white12) : null,
                    boxShadow: _sent ? [] : [
                      const BoxShadow(color: _GC.cyan, blurRadius: 8, spreadRadius: 0),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      _sent ? 'SENT ✓' : 'ADD +',
                      style: TextStyle(
                        color: _sent ? Colors.white24 : _GC.bgDeep,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── REUSABLE COMPONENTS ──────────────────────────────────────────────────────

/// Animated avatar with scanner ring effect
class _ScannerAvatar extends StatefulWidget {
  final double radius;
  final String? photoUrl;
  final String initial;
  final bool isOnline;
  final Color ringColor;
  const _ScannerAvatar({
    required this.radius,
    required this.photoUrl,
    required this.initial,
    required this.isOnline,
    this.ringColor = _GC.cyan,
  });

  @override
  State<_ScannerAvatar> createState() => _ScannerAvatarState();
}

class _ScannerAvatarState extends State<_ScannerAvatar> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Rotating scanner ring
        if (widget.isOnline)
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => Transform.rotate(
              angle: _ctrl.value * 6.28,
              child: Container(
                width: widget.radius * 2 + 12,
                height: widget.radius * 2 + 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.ringColor.withValues(alpha: 0.0),
                    width: 1.5,
                  ),
                  gradient: SweepGradient(
                    colors: [
                      widget.ringColor.withValues(alpha: 0.0),
                      widget.ringColor.withValues(alpha: 0.7),
                      widget.ringColor.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
        // Static ring
        Container(
          width: widget.radius * 2 + 6,
          height: widget.radius * 2 + 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: widget.isOnline
                  ? widget.ringColor.withValues(alpha: 0.4)
                  : _GC.border,
              width: 1.5,
            ),
          ),
        ),
        // Avatar
        CircleAvatar(
          radius: widget.radius,
          backgroundColor: const Color(0xFF0A1525),
          backgroundImage: widget.photoUrl != null && widget.photoUrl!.isNotEmpty && widget.photoUrl!.startsWith('http')
              ? NetworkImage(widget.photoUrl!)
              : null,
          child: widget.photoUrl != null && widget.photoUrl!.isNotEmpty && !widget.photoUrl!.startsWith('http')
              ? ClipOval(
                  child: Image.memory(
                    base64Decode(widget.photoUrl!),
                    fit: BoxFit.cover,
                    width: widget.radius * 2,
                    height: widget.radius * 2,
                    errorBuilder: (context, error, stackTrace) => Text(
                      widget.initial,
                      style: TextStyle(
                        color: widget.ringColor,
                        fontWeight: FontWeight.w900,
                        fontSize: widget.radius * 0.75,
                      ),
                    ),
                  ),
                )
              : (widget.photoUrl == null || widget.photoUrl!.isEmpty)
                  ? Text(
                      widget.initial,
                      style: TextStyle(
                        color: widget.ringColor,
                        fontWeight: FontWeight.w900,
                        fontSize: widget.radius * 0.75,
                      ),
                    )
                  : null,
        ),
        // Online dot
        Positioned(
          right: 2,
          bottom: 2,
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.isOnline ? _GC.neonGreen : _GC.bgPanel,
              border: Border.all(color: _GC.bgDeep, width: 1.5),
              boxShadow: widget.isOnline
                  ? [const BoxShadow(color: _GC.neonGreen, blurRadius: 5)]
                  : [],
            ),
          ),
        ),
      ],
    );
  }
}

/// Cyberpunk search bar
class _CyberSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String activeQuery;
  final VoidCallback onClear;
  const _CyberSearchBar({
    required this.controller,
    required this.onChanged,
    required this.activeQuery,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _GC.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: activeQuery.isNotEmpty ? _GC.cyan.withValues(alpha: 0.4) : _GC.border,
        ),
        boxShadow: activeQuery.isNotEmpty
            ? [BoxShadow(color: _GC.cyan.withValues(alpha: 0.08), blurRadius: 12)]
            : [],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(
          color: _GC.textPrimary,
          fontSize: 14,
          letterSpacing: 0.5,
        ),
        decoration: InputDecoration(
          hintText: 'SEARCH PLAYERS...',
          hintStyle: const TextStyle(
            color: _GC.textMuted,
            fontSize: 12,
            letterSpacing: 2,
            fontWeight: FontWeight.w600,
          ),
          prefixIcon: const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Icon(Icons.search_rounded, color: _GC.cyanDim, size: 20),
          ),
          suffixIcon: activeQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, color: _GC.textMuted, size: 18),
                  onPressed: onClear,
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

/// Gaming text field
class _GamingTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String prefix;
  final Color prefixColor;
  final bool autofocus;
  const _GamingTextField({
    required this.controller,
    required this.hint,
    required this.prefix,
    required this.prefixColor,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _GC.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: prefixColor.withValues(alpha: 0.2)),
      ),
      child: TextField(
        controller: controller,
        autofocus: autofocus,
        autocorrect: false,
        style: const TextStyle(
          color: _GC.textPrimary,
          fontSize: 16,
          letterSpacing: 0.5,
        ),
        decoration: InputDecoration(
          hintText: hint,
          prefixText: prefix,
          prefixStyle: TextStyle(
            color: prefixColor,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
          hintStyle: const TextStyle(color: _GC.textMuted),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }
}

/// Gaming primary button
class _GamingButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final LinearGradient gradient;
  final Color glowColor;
  final VoidCallback onTap;
  const _GamingButton({
    required this.label,
    required this.icon,
    required this.gradient,
    required this.glowColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () { HapticFeedback.lightImpact(); onTap(); },
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: glowColor.withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: _GC.bgDeep, size: 18),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                color: _GC.bgDeep,
                fontWeight: FontWeight.w900,
                fontSize: 14,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hexagonal icon button
class _HexButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  const _HexButton({required this.icon, required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () { HapticFeedback.lightImpact(); onTap(); },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.4)),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 12),
          ],
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}

/// Glitch text effect widget
class _GlitchText extends StatefulWidget {
  final String text;
  final TextStyle style;
  const _GlitchText(this.text, {required this.style});

  @override
  State<_GlitchText> createState() => _GlitchTextState();
}

class _GlitchTextState extends State<_GlitchText> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 100))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Text(widget.text, style: widget.style),
        AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) => Transform.translate(
            offset: Offset(_ctrl.value * 2, 0),
            child: Text(
              widget.text,
              style: widget.style.copyWith(
                color: _GC.cyan.withValues(alpha: 0.3),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Gaming loading indicator
class _GamingLoader extends StatefulWidget {
  const _GamingLoader();

  @override
  State<_GamingLoader> createState() => _GamingLoaderState();
}

class _GamingLoaderState extends State<_GamingLoader> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();
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
            width: 42,
            height: 42,
            child: CircularProgressIndicator(
              value: null,
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                Color.lerp(_GC.cyan, _GC.purple, _ctrl.value)!,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'CONNECTING...',
            style: TextStyle(
              color: _GC.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Background hex grid painter
class _HexGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _HexGridPainter(),
    );
  }
}

class _HexGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0D1926).withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    const spacing = 48.0;
    const hexH = spacing * 0.866;

    for (double y = -hexH; y < size.height + hexH * 2; y += hexH) {
      final offset = ((y / hexH).floor() % 2) * spacing * 0.5;
      for (double x = -spacing + offset; x < size.width + spacing; x += spacing) {
        _drawHex(canvas, paint, x, y, spacing * 0.48);
      }
    }
  }

  void _drawHex(Canvas canvas, Paint paint, double cx, double cy, double r) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (i * 60 - 30) * math.pi / 180;
      final px = cx + r * 0.7 * math.cos(angle);
      final py = cy + r * 0.7 * math.sin(angle);
      if (i == 0) path.moveTo(px, py); else path.lineTo(px, py);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_HexGridPainter old) => false;
}