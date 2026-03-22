import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/social_service.dart';
import '../../core/theme/app_theme.dart';

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  bool _isSearching = false;
  List<Map<String, dynamic>> _searchResults = [];

  @override
  void dispose() {
    _searchController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.pink)),
        error: (e, _) => Center(child: Text('Error loading profile: $e', style: const TextStyle(color: Colors.white70))),
        data: (profile) {
          if (profile == null || profile['username'] == null) {
            return _buildClaimUsernamePrompt(context, profile);
          }
          return _buildFriendsHub(context, profile);
        },
      ),
    );
  }

  Widget _buildClaimUsernamePrompt(BuildContext context, Map<String, dynamic>? profile) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        margin: const EdgeInsets.symmetric(horizontal: 32),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.stars_rounded, size: 48, color: AppTheme.pink),
            const SizedBox(height: 16),
            const Text(
              'Claim Your Username',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Pick a unique handle so friends can find you and share music.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _usernameController,
              autocorrect: false,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'username',
                prefixText: '@ ',
                prefixStyle: const TextStyle(color: AppTheme.pink),
                filled: true,
                fillColor: Colors.white.withOpacity(0.06),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                final username = _usernameController.text.trim();
                if (username.length < 3) return;

                final success = await ref.read(socialServiceProvider).claimUsername(
                      username,
                      profile?['displayName'] ?? 'User',
                      profile?['photoUrl'],
                    );

                if (success && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Username claimed successfully!')),
                  );
                } else if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Username already taken or invalid!')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.pink,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                minimumSize: const Size(double.infinity, 48),
              ),
              child: const Text('Claim Handle'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendsHub(BuildContext context, Map<String, dynamic> profile) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          _buildHeader(profile['username']),
          const TabBar(
            dividerColor: Colors.transparent,
            indicatorColor: AppTheme.pink,
            tabs: [
              Tab(text: 'Friends'),
              Tab(text: 'Requests'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildFriendsList(),
                _buildRequestsList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String username) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('@$username', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
              IconButton(onPressed: () => _showAddFriendDialog(context), icon: const Icon(Icons.person_add_rounded, color: AppTheme.pink)),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            onChanged: (v) => _searchUsers(v),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search friends by @username...',
              prefixIcon: const Icon(Icons.search_rounded, color: Colors.white54),
              filled: true,
              fillColor: Colors.white.withOpacity(0.06),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
      return;
    }
    setState(() => _isSearching = true);
    final results = await ref.read(socialServiceProvider).searchUsersByUsername(query.toLowerCase());
    setState(() => _searchResults = results);
  }

  Widget _buildFriendsList() {
    if (_isSearching) return _buildSearchResultsList();

    final friendsAsync = ref.watch(friendsListProvider);
    return friendsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (friends) {
        if (friends.isEmpty) return const Center(child: Text('No friends yet', style: TextStyle(color: Colors.white38)));
        return ListView.builder(
          itemCount: friends.length,
          itemBuilder: (c, i) => ListTile(
            leading: const CircleAvatar(backgroundColor: AppTheme.purple, child: Icon(Icons.person)),
            title: Text(friends[i]['username'] ?? friends[i]['uid'], style: const TextStyle(color: Colors.white)),
            trailing: const Icon(Icons.chat_bubble_outline_rounded, color: AppTheme.pink),
            onTap: () => context.push('/chat/${friends[i]['uid']}'),
          ),
        );
      },
    );
  }

  Widget _buildRequestsList() {
    final requestsAsync = ref.watch(incomingRequestsProvider);
    return requestsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (requests) {
        if (requests.isEmpty) {
          return const Center(child: Text('No pending requests', style: TextStyle(color: Colors.white38)));
        }
        return ListView.builder(
          itemCount: requests.length,
          itemBuilder: (c, i) => ListTile(
            title: Text(requests[i]['username'] ?? requests[i]['fromUid'], style: const TextStyle(color: Colors.white)),
            trailing: IconButton(
              icon: const Icon(Icons.check_circle_rounded, color: AppTheme.pink),
              onPressed: () => ref.read(socialServiceProvider).acceptFriendRequest(requests[i]['fromUid']),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchResultsList() {
    if (_searchResults.isEmpty) {
      return const Center(child: Text('No users found', style: TextStyle(color: Colors.white38)));
    }
    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (c, i) => ListTile(
        title: Text(_searchResults[i]['username'] ?? 'User', style: const TextStyle(color: Colors.white)),
        subtitle: Text(_searchResults[i]['displayName'] ?? '', style: const TextStyle(color: Colors.white54)),
        trailing: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.pink, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          onPressed: () async {
            await ref.read(socialServiceProvider).sendFriendRequest(_searchResults[i]['uid']);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Friend request sent!')));
            }
          },
          child: const Text('Add'),
        ),
      ),
    );
  }

  void _showAddFriendDialog(BuildContext context) {
    final TextEditingController usernameCtrl = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add Friend', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter your friend\'s exact @username to send a request.', style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 16),
            TextField(
              controller: usernameCtrl,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'username',
                prefixText: '@ ',
                prefixStyle: const TextStyle(color: AppTheme.pink),
                filled: true,
                fillColor: Colors.white.withOpacity(0.06),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.pink),
            onPressed: () async {
              final username = usernameCtrl.text.trim();
              if (username.isEmpty) return;

              final uid = await ref.read(socialServiceProvider).getUidByUsername(username);
              if (uid != null) {
                await ref.read(socialServiceProvider).sendFriendRequest(uid);
                Navigator.pop(c);
                messenger.showSnackBar(const SnackBar(content: Text('Request sent!')));
              } else {
                messenger.showSnackBar(const SnackBar(content: Text('User not found. Check the handle!')));
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }
}
