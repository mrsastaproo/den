import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/services/social_service.dart';
import '../../core/theme/app_theme.dart';

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
  bool _isSearching = false;
  List<Map<String, dynamic>> _searchResults = [];
  String _activeQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _usernameController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.bgGradient,
        ),
        child: profileAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.pink, strokeWidth: 2)),
          error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.white70))),
          data: (profile) {
            if (profile == null || profile['username'] == null) {
              return _buildClaimUsernamePrompt(profile);
            }
            return _buildFriendsHub(profile);
          },
        ),
      ),
    );
  }

  // ─── Claim Username ────────────────────────────────────────────────────────

  Widget _buildClaimUsernamePrompt(Map<String, dynamic>? profile) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.white.withValues(alpha: 0.07), Colors.white.withValues(alpha: 0.03)],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ShaderMask(
                      shaderCallback: (b) => AppTheme.primaryGradient.createShader(b),
                      child: const Icon(Icons.alternate_email_rounded, size: 56, color: Colors.white),
                    ),
                    const SizedBox(height: 20),
                    const Text('Claim Your Handle', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                    const SizedBox(height: 8),
                    Text(
                      'Pick a unique @username so friends can find and share music with you.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 14, height: 1.5),
                    ),
                    const SizedBox(height: 28),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: TextField(
                        controller: _usernameController,
                        autocorrect: false,
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                        decoration: InputDecoration(
                          hintText: 'yourhandle',
                          prefixText: '@ ',
                          prefixStyle: const TextStyle(color: AppTheme.pink, fontWeight: FontWeight.bold),
                          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: () async {
                        final username = _usernameController.text.trim().toLowerCase();
                        if (username.length < 3) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Username must be at least 3 characters')));
                          return;
                        }
                        final success = await ref.read(socialServiceProvider).claimUsername(
                          username,
                          profile?['displayName'] ?? 'User',
                          profile?['photoUrl'],
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(success ? '✅ @$username claimed!' : '❌ Username taken. Try another.')));
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: AppTheme.pink.withValues(alpha: 0.35), blurRadius: 20, offset: const Offset(0, 8))],
                        ),
                        child: const Center(child: Text('Claim Handle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16))),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Friends Hub ───────────────────────────────────────────────────────────

  Widget _buildFriendsHub(Map<String, dynamic> profile) {
    final requestsAsync = ref.watch(incomingRequestsProvider);
    final requestsCount = requestsAsync.value?.length ?? 0;

    return Column(
      children: [
        _buildHeader(profile),
        _buildTabBar(requestsCount),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildFriendsTab(),
              _buildDiscoverTab(),
              _buildRequestsTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(Map<String, dynamic> profile) {
    final username = profile['username'] ?? '';
    final photoUrl = profile['photoUrl'];

    return Container(
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 14, 20, 0),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppTheme.primaryGradient,
                ),
                padding: const EdgeInsets.all(2),
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: const Color(0xFF1A1A2E),
                  backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                  child: photoUrl == null ? const Icon(Icons.person, color: Colors.white70) : null,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Friends', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                  ShaderMask(
                    shaderCallback: (b) => AppTheme.primaryGradient.createShader(b),
                    child: Text('@$username', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const Spacer(),
              _GlowButton(
                icon: Icons.person_add_alt_1_rounded,
                onTap: () => _showAddFriendSheet(context),
              ).animate().scale(delay: 200.ms, duration: 400.ms, curve: Curves.easeOutBack),
            ],
          ),
          const SizedBox(height: 16),
          // Search bar
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.neonBlue.withValues(alpha: 0.1)),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _searchUsers,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search for handles...',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
                    prefixIcon: Icon(Icons.search_rounded, color: AppTheme.neonBlue.withValues(alpha: 0.4), size: 20),
                    suffixIcon: _activeQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.close_rounded, color: Colors.white.withValues(alpha: 0.4), size: 20),
                            onPressed: () {
                              _searchController.clear();
                              _searchUsers('');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(int requestsCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            gradient: AppTheme.cyberGradient,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(color: AppTheme.neonBlue.withValues(alpha: 0.3), blurRadius: 10),
            ],
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white38,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          padding: const EdgeInsets.all(4),
          tabs: [
            const Tab(text: 'Friends'),
            const Tab(text: 'Discover'),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Requests'),
                  if (requestsCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      width: 18, height: 18,
                      decoration: const BoxDecoration(
                        color: AppTheme.neonPurple,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text('$requestsCount', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Friends Tab ───────────────────────────────────────────────────────────

  Widget _buildFriendsTab() {
    if (_isSearching) return _buildSearchResults();

    final friendsAsync = ref.watch(friendsListProvider);
    return friendsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.pink, strokeWidth: 2)),
      error: (e, _) => _buildEmpty('Something went wrong', Icons.wifi_off_rounded),
      data: (friends) {
        if (friends.isEmpty) {
          return _buildEmpty('No friends yet\nTap + to find someone!', Icons.people_outline_rounded);
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
          itemCount: friends.length,
          itemBuilder: (c, i) => _FriendCard(
            data: friends[i],
            onTap: () => context.push(
              '/chat/${friends[i]['uid']}',
              extra: {'username': friends[i]['username'], 'profileUrl': friends[i]['photoUrl']},
            ),
          ).animate(delay: (i * 50).ms).fadeIn(duration: 400.ms).slideX(begin: 0.1, end: 0),
        );
      },
    );
  }

  // ─── Discover Tab ──────────────────────────────────────────────────────────

  Widget _buildDiscoverTab() {
    final discoverAsync = ref.watch(discoverUsersProvider);
    return discoverAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.pink, strokeWidth: 2)),
      error: (e, _) => _buildEmpty('Something went wrong', Icons.wifi_off_rounded),
      data: (users) {
        if (users.isEmpty) return _buildEmpty('No users found', Icons.person_search_rounded);
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
          itemCount: users.length,
          itemBuilder: (c, i) => _DiscoverCard(data: users[i]).animate(delay: (i * 50).ms).fadeIn(duration: 400.ms).slideX(begin: 0.1, end: 0),
        );
      },
    );
  }

  // ─── Requests Tab ──────────────────────────────────────────────────────────

  Widget _buildRequestsTab() {
    final requestsAsync = ref.watch(incomingRequestsProvider);
    return requestsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.pink, strokeWidth: 2)),
      error: (e, _) => _buildEmpty('Something went wrong', Icons.wifi_off_rounded),
      data: (requests) {
        if (requests.isEmpty) {
          return _buildEmpty('No pending requests', Icons.mark_email_read_rounded);
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
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
          ),
        );
      },
    );
  }

  // ─── Search Results ────────────────────────────────────────────────────────

  Widget _buildSearchResults({bool isDiscover = false}) {
    if (!isDiscover && _searchResults.isEmpty && _activeQuery.isEmpty) {
      return _buildEmpty('Search for people above', Icons.search_rounded);
    }
    if (_searchResults.isEmpty && _activeQuery.isNotEmpty) {
      return _buildEmpty('No users found for "$_activeQuery"', Icons.person_search_rounded);
    }
    if (_searchResults.isEmpty && isDiscover) {
      return _buildEmpty('Type in the search box above\nto find friends', Icons.person_search_rounded);
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
      itemCount: _searchResults.length,
      itemBuilder: (c, i) => _SearchResultCard(
        data: _searchResults[i],
        onAdd: () async {
          HapticFeedback.lightImpact();
          await ref.read(socialServiceProvider).sendFriendRequest(_searchResults[i]['uid']);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Friend request sent to @${_searchResults[i]['username']}!'),
                behavior: SnackBarBehavior.floating,
                backgroundColor: const Color(0xFF1E1E30),
              ),
            );
          }
        },
      ),
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

  Widget _buildEmpty(String text, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 52, color: AppTheme.neonBlue.withValues(alpha: 0.2)).animate(onPlay: (c) => c.repeat(reverse: true)).shimmer(color: AppTheme.neonBlue.withValues(alpha: 0.2), duration: 2500.ms),
          const SizedBox(height: 16),
          Text(text, textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 15, height: 1.5)),
        ],
      ),
    );
  }

  // ─── Add Friend Bottom Sheet ───────────────────────────────────────────────

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
            color: const Color(0xFF121220),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(margin: const EdgeInsets.symmetric(vertical: 14), width: 40, height: 4, decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShaderMask(
                      shaderCallback: (b) => AppTheme.primaryGradient.createShader(b),
                      child: const Icon(Icons.person_add_alt_1_rounded, size: 32, color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    const Text('Add a Friend', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text("Enter their exact @handle to send a request.", style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13)),
                    const SizedBox(height: 20),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: TextField(
                        controller: ctrl,
                        autofocus: true,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'username',
                          prefixText: '@ ',
                          prefixStyle: const TextStyle(color: AppTheme.pink, fontWeight: FontWeight.bold),
                          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () async {
                        final username = ctrl.text.trim().toLowerCase();
                        if (username.isEmpty) return;
                        HapticFeedback.lightImpact();
                        final uid = await ref.read(socialServiceProvider).getUidByUsername(username);
                        if (uid != null) {
                          await ref.read(socialServiceProvider).sendFriendRequest(uid);
                          if (c.mounted) {
                            Navigator.pop(c);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('🎉 Request sent to @$username!'),
                                backgroundColor: const Color(0xFF1E1E30),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        } else {
                          if (c.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ User not found. Check the handle!'), behavior: SnackBarBehavior.floating));
                          }
                        }
                      },
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: AppTheme.pink.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))],
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.send_rounded, color: Colors.white, size: 18),
                            SizedBox(width: 8),
                            Text('Send Request', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                          ],
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

// ─── Friend Card ──────────────────────────────────────────────────────────────

class _FriendCard extends ConsumerWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;
  const _FriendCard({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(otherUserProfileProvider(data['uid'] ?? ''));
    final liveData     = profileAsync.value;
    final lastActive   = liveData?['lastActive'] as Timestamp?;
    final isOnline     = liveData?['isOnline'] == true &&
                        (lastActive != null && DateTime.now().difference(lastActive.toDate()).inMinutes < 10);
    final username = liveData?['username'] ?? data['username'] ?? 'User';
    final photoUrl = liveData?['photoUrl'] ?? data['photoUrl'];

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      onLongPress: () {
        HapticFeedback.mediumImpact();
        showModalBottomSheet(
          context: context,
          useRootNavigator: true,
          backgroundColor: Colors.transparent,
          builder: (c) => Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 28),
            decoration: BoxDecoration(
              color: const Color(0xFF0E0E1A),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(margin: const EdgeInsets.symmetric(vertical: 14), width: 36, height: 4, decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(2))),
                ListTile(
                  leading: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.block_flipped, color: Colors.redAccent, size: 20),
                  ),
                  title: const Text('Block User', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
                  subtitle: Text('Remove friend and block completely', style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 12)),
                  onTap: () {
                    Navigator.pop(c);
                    ref.read(socialServiceProvider).blockUser(data['uid'] ?? '');
                  },
                ),
                ListTile(
                  leading: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.person_remove_rounded, color: Colors.white70, size: 20),
                  ),
                  title: Text('Remove @$username', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  subtitle: Text('Remove from your friends list', style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 12)),
                  onTap: () {
                    Navigator.pop(c);
                    ref.read(socialServiceProvider).removeFriend(data['uid'] ?? '');
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },

      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: const Color(0xFF2A1F3D),
                  backgroundImage: photoUrl != null && photoUrl.startsWith('http') ? NetworkImage(photoUrl) : null,
                  child: photoUrl != null && !photoUrl.startsWith('http')
                      ? ClipOval(child: Image.memory(base64Decode(photoUrl), fit: BoxFit.cover, width: 52, height: 52))
                      : photoUrl == null
                          ? Text(username.isNotEmpty ? username[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))
                          : null,
                ),
                Positioned(
                  right: 0, bottom: 0,
                  child: Container(
                    width: 12, height: 12,
                    decoration: BoxDecoration(
                      color: isOnline ? Colors.greenAccent : Colors.white30,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF0A0A12), width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('@$username', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 2),
                  if (liveData?['nowPlaying'] != null)
                    Row(
                      children: [
                        Icon(Icons.music_note_rounded, size: 10, color: AppTheme.neonBlue.withValues(alpha: 0.8)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Listening to ${liveData!['nowPlaying']['title']}',
                            style: TextStyle(color: AppTheme.neonBlue.withValues(alpha: 0.7), fontSize: 11, fontWeight: FontWeight.w500),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 2000.ms, color: Colors.white24),
                        ),
                      ],
                    )
                  else
                    Text(
                      isOnline ? '🟢 Online' : '⚫ Offline',
                      style: TextStyle(color: isOnline ? AppTheme.neonGreen.withValues(alpha: 0.8) : Colors.white30, fontSize: 12),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: AppTheme.cyberGradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: AppTheme.neonBlue.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: const Row(
                children: [
                  Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 14),
                  SizedBox(width: 6),
                  Text('Chat', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Request Card ─────────────────────────────────────────────────────────────

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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.pink.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFF2A1F3D),
            backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
            child: photoUrl == null ? Text(username.isNotEmpty ? username[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)) : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('@$username', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                Text('Wants to be your friend', style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () { HapticFeedback.lightImpact(); onDecline(); },
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), shape: BoxShape.circle),
              child: const Icon(Icons.close_rounded, color: Colors.white38, size: 18),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () { HapticFeedback.lightImpact(); onAccept(); },
            child: Container(
              width: 38, height: 38,
              decoration: const BoxDecoration(gradient: AppTheme.primaryGradient, shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Search Result Card ───────────────────────────────────────────────────────

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
    final username = widget.data['username'] ?? 'User';
    final displayName = widget.data['displayName'] ?? '';
    final photoUrl = widget.data['photoUrl'];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFF2A1F3D),
            backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
            child: photoUrl == null ? Text(username.isNotEmpty ? username[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)) : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('@$username', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                if (displayName.isNotEmpty)
                  Text(displayName, style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 12)),
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: _sent ? null : AppTheme.primaryGradient,
                color: _sent ? Colors.white.withValues(alpha: 0.08) : null,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _sent ? 'Sent ✓' : 'Add',
                style: TextStyle(color: _sent ? Colors.white38 : Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Glowing Icon Button ──────────────────────────────────────────────────────

class _GlowButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _GlowButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () { HapticFeedback.lightImpact(); onTap(); },
      child: Container(
        width: 42, height: 42,
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: AppTheme.pink.withOpacity(0.4), blurRadius: 14, spreadRadius: 0)],
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

class _DiscoverCard extends ConsumerWidget {
  final Map<String, dynamic> data;
  const _DiscoverCard({required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(otherUserProfileProvider(data['uid'] ?? ''));
    final liveData     = profileAsync.value;
    final lastActive   = liveData?['lastActive'] as Timestamp?;
    final isOnline     = liveData?['isOnline'] == true &&
                        (lastActive != null && DateTime.now().difference(lastActive.toDate()).inMinutes < 10);
    final username     = liveData?['username'] ?? data['username'] ?? 'User';
    final photoUrl     = liveData?['photoUrl'] ?? data['photoUrl'];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFF2A1F3D),
            backgroundImage: photoUrl != null && photoUrl.startsWith('http') ? NetworkImage(photoUrl) : null,
            child: photoUrl != null && !photoUrl.startsWith('http')
                ? ClipOval(child: Image.memory(base64Decode(photoUrl), fit: BoxFit.cover, width: 48, height: 48))
                : photoUrl == null
                    ? Text(username.isNotEmpty ? username[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                    : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('@$username', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 4),
                if (liveData?['nowPlaying'] != null)
                  Row(
                    children: [
                      Icon(Icons.music_note_rounded, size: 10, color: AppTheme.neonBlue.withValues(alpha: 0.8)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Listening to ${liveData!['nowPlaying']['title']}',
                          style: TextStyle(color: AppTheme.neonBlue.withValues(alpha: 0.7), fontSize: 11, fontWeight: FontWeight.w500),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    isOnline ? '🟢 Online' : '⚫ Offline',
                    style: TextStyle(color: isOnline ? AppTheme.neonGreen.withValues(alpha: 0.8) : Colors.white30, fontSize: 12),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
