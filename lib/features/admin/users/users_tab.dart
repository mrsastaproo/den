import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/services/admin_service.dart';
import '../core/admin_core_widgets.dart';

class UsersTab extends ConsumerStatefulWidget {
  const UsersTab({super.key});

  @override
  ConsumerState<UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends ConsumerState<UsersTab> {
  final _searchCtrl = TextEditingController();
  
  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(adminUserSearchQueryProvider);
    final usersAsync = query.isEmpty
        ? ref.watch(adminUsersProvider) // real-time new users stream
        : ref.watch(_tempSearchProvider(query)); // server-side search stream

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
          child: AdminSearchBar(
            ctrl: _searchCtrl,
            hint: 'Search users by email prefix...',
            onChanged: (v) => ref.read(adminUserSearchQueryProvider.notifier).state = v,
          ),
        ),
        Expanded(
          child: usersAsync.when(
            loading: () => const AdminLoader(),
            error: (e, _) => AdminErrorCard(message: e.toString()),
            data: (users) {
              if (users.isEmpty) {
                return const Center(
                  child: Text('No users found', style: TextStyle(color: Colors.white54)),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                physics: const BouncingScrollPhysics(),
                itemCount: users.length,
                itemBuilder: (_, i) {
                  return _UserTile(user: users[i])
                      .animate()
                      .fadeIn(delay: Duration(milliseconds: i * 20), duration: 250.ms);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

final _tempSearchProvider = StreamProvider.family<List<AdminUser>, String>((ref, query) {
  return ref.watch(adminServiceProvider).searchUsers(query);
});

class _UserTile extends ConsumerStatefulWidget {
  final AdminUser user;
  const _UserTile({required this.user});

  @override
  ConsumerState<_UserTile> createState() => _UserTileState();
}

class _UserTileState extends ConsumerState<_UserTile> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: u.isBanned
              ? const Color(0xFFFF4444).withOpacity(0.3)
              : Colors.white.withOpacity(0.06),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFFFF3366), Color(0xFF6C63FF)]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                (u.displayName.isNotEmpty ? u.displayName[0] : (u.email.isNotEmpty ? u.email[0] : 'U')).toUpperCase(),
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          Transform.translate(
            offset: const Offset(-10, 16),
            child: Container(
              width: 12, height: 12,
              decoration: BoxDecoration(
                color: u.isOnline ? const Color(0xFF11D47B) : Colors.grey,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF070707), width: 2),
                boxShadow: u.isOnline
                    ? [BoxShadow(color: const Color(0xFF11D47B).withOpacity(0.4), blurRadius: 4, spreadRadius: 1)]
                    : [],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(
                    child: Text(
                      u.displayName.isNotEmpty 
                          ? u.displayName 
                          : (u.email.isNotEmpty ? u.email.split('@')[0] : 'Anonymous User'),
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (u.isBanned)
                    Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF4444).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFFF4444).withOpacity(0.4)),
                      ),
                      child: const Text('BANNED', style: TextStyle(color: Color(0xFFFF4444), fontSize: 8, fontWeight: FontWeight.w900)),
                    ),
                ]),
                const SizedBox(height: 2),
                Text(
                  u.email.isNotEmpty ? u.email : 'No email provided', 
                  style: TextStyle(color: Colors.white.withOpacity(0.38), fontSize: 11), 
                  maxLines: 1, 
                  overflow: TextOverflow.ellipsis
                ),
              ],
            ),
          ),
          _loading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF3366)))
              : PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert_rounded, color: Colors.white.withOpacity(0.4), size: 18),
                  color: const Color(0xFF1A1A1A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  onSelected: (action) => _handleAction(action),
                  itemBuilder: (_) => [
                    _menuItem('view', Icons.visibility_rounded, 'View Details'),
                    if (!u.isBanned)
                      _menuItem('ban', Icons.block_rounded, 'Ban User', color: const Color(0xFFFF4444))
                    else
                      _menuItem('unban', Icons.check_circle_rounded, 'Unban User', color: const Color(0xFF11D47B)),
                    _menuItem('delete', Icons.delete_rounded, 'Delete Data', color: const Color(0xFFFF4444)),
                  ],
                ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _menuItem(String value, IconData icon, String label, {Color? color}) {
    return PopupMenuItem(
      value: value,
      child: Row(children: [
        Icon(icon, color: color ?? Colors.white.withOpacity(0.7), size: 16),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: color ?? Colors.white, fontSize: 13)),
      ]),
    );
  }

  Future<void> _handleAction(String action) async {
    final svc = ref.read(adminServiceProvider);
    final u = widget.user;
    switch (action) {
      case 'view':
        _showUserDetails(u);
        break;
      case 'ban':
        _showBanDialog(svc);
        break;
      case 'unban':
        setState(() => _loading = true);
        try {
          await svc.unbanUser(u.uid);
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User unbanned')));
        } finally {
          if (mounted) setState(() => _loading = false);
        }
        break;
      case 'delete':
        _showDeleteDialog(svc);
        break;
    }
  }

  void _showUserDetails(AdminUser u) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => AdminSheet(
        title: 'User Details',
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailRow('UID', u.uid),
              _DetailRow('Email', u.email.isNotEmpty ? u.email : 'None (Anonymous)'),
              _DetailRow('Name', u.displayName.isNotEmpty ? u.displayName : '—'),
              _DetailRow('User Status', u.isOnline ? '🟢 Online' : '⚪ Offline'),
              _DetailRow('Account', u.isBanned ? '🔴 Banned' : '✅ Active'),
              if (u.isBanned) ...[
                _DetailRow('Ban Reason', u.banReason),
                if (u.bannedAt != null) _DetailRow('Banned At', u.bannedAt.toString()),
              ],
              _DetailRow('Liked Songs', '${u.likedSongs}'),
              _DetailRow('Playlists', '${u.playlists}'),
              _DetailRow('Total Plays', '${u.totalPlays}'),
            ],
          ),
        ),
      ),
    );
  }

  void _showBanDialog(AdminService svc) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Ban User', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: reasonCtrl,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: 'Reason...', hintStyle: TextStyle(color: Colors.white54)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _loading = true);
              await svc.banUser(widget.user.uid, reasonCtrl.text);
              if (mounted) setState(() => _loading = false);
            },
            child: const Text('Ban', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(AdminService svc) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Delete Data?', style: TextStyle(color: Colors.white)),
        content: const Text('Permanently delete all user data?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _loading = true);
              await svc.deleteUserData(widget.user.uid);
              if (mounted) setState(() => _loading = false);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label, value;
  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 13))),
        ],
      ),
    );
  }
}
