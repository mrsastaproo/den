import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/services/admin_service.dart';
import '../../core/services/auth_service.dart';

// ─────────────────────────────────────────────────────────────
// ADMIN PANEL — accessible only for mrsastapro@gmail.com
// ─────────────────────────────────────────────────────────────

final _adminTabProvider = StateProvider<int>((ref) => 0);

Future<bool> _confirm(BuildContext context, String message) async {
  return await showDialog<bool>(
        context: context,
        builder: (ctx) => _AdminDialog(
          title: 'Confirm',
          message: message,
          confirmLabel: 'Yes',
          isDestructive: false,
          onConfirm: () => Navigator.pop(ctx, true),
        ),
      ) ??
      false;
}

String _fmtDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

String _fmtDateTime(DateTime d) =>
    '${d.day}/${d.month}/${d.year}  '
    '${d.hour.toString().padLeft(2, '0')}:'
    '${d.minute.toString().padLeft(2, '0')}';

class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);

    if (!isAdmin) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text('Access Denied',
              style: TextStyle(color: Colors.white, fontSize: 18)),
        ),
      );
    }

    final tab = ref.watch(_adminTabProvider);
    final tabs = [
      _TabData('Dashboard', Icons.dashboard_rounded),
      _TabData('Users', Icons.people_rounded),
      _TabData('Content', Icons.library_music_rounded),
      _TabData('Announcements', Icons.campaign_rounded),
      _TabData('Notifications', Icons.notifications_active_rounded),
      _TabData('Config', Icons.settings_rounded),
      _TabData('Logs', Icons.receipt_long_rounded),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF070707),
      body: Stack(
        children: [
          _AdminAmbient(),
          Column(
            children: [
              _AdminHeader(currentTab: tab, tabs: tabs),
              _AdminTabBar(
                tabs: tabs,
                selected: tab,
                onSelect: (i) {
                  HapticFeedback.selectionClick();
                  ref.read(_adminTabProvider.notifier).state = i;
                },
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: KeyedSubtree(
                    key: ValueKey(tab),
                    child: switch (tab) {
                      0 => const _DashboardTab(),
                      1 => const _UsersTab(),
                      2 => const _ContentTab(),
                      3 => const _AnnouncementsTab(),
                      4 => const _NotificationsTab(),
                      5 => const _ConfigTab(),
                      6 => const _LogsTab(),
                      _ => const _DashboardTab(),
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TabData {
  final String label;
  final IconData icon;
  const _TabData(this.label, this.icon);
}

// ─────────────────────────────────────────────────────────────
// AMBIENT
// ─────────────────────────────────────────────────────────────

class _AdminAmbient extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Positioned(
        top: -80,
        left: -60,
        child: Container(
          width: 280,
          height: 280,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              const Color(0xFFFF3366).withOpacity(0.12),
              Colors.transparent,
            ]),
          ),
        ),
      ),
      Positioned(
        top: 200,
        right: -50,
        child: Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              const Color(0xFF6C63FF).withOpacity(0.1),
              Colors.transparent,
            ]),
          ),
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────
// HEADER
// ─────────────────────────────────────────────────────────────

class _AdminHeader extends ConsumerWidget {
  final int currentTab;
  final List<_TabData> tabs;

  const _AdminHeader({required this.currentTab, required this.tabs});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final top = MediaQuery.of(context).padding.top;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: EdgeInsets.fromLTRB(20, top + 12, 20, 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.black.withOpacity(0.8), Colors.transparent],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            border: Border(
              bottom: BorderSide(
                  color: Colors.white.withOpacity(0.06), width: 0.5),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF3366), Color(0xFF6C63FF)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF3366).withOpacity(0.3),
                      blurRadius: 12,
                      spreadRadius: -3,
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shield_rounded, color: Colors.white, size: 14),
                    SizedBox(width: 5),
                    Text('ADMIN',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        )),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('DEN Admin Panel',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        )),
                    Text(user?.email ?? '',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 11,
                        )),
                  ],
                ),
              ),
              _AdminIconBtn(
                icon: Icons.refresh_rounded,
                onTap: () async {
                  HapticFeedback.lightImpact();
                  await ref.read(adminServiceProvider).refreshStats();
                },
              ),
              const SizedBox(width: 8),
              _AdminIconBtn(
                icon: Icons.close_rounded,
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _AdminIconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Icon(icon, color: Colors.white.withOpacity(0.8), size: 18),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TAB BAR
// ─────────────────────────────────────────────────────────────

class _AdminTabBar extends StatelessWidget {
  final List<_TabData> tabs;
  final int selected;
  final ValueChanged<int> onSelect;

  const _AdminTabBar({
    required this.tabs,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        itemCount: tabs.length,
        itemBuilder: (_, i) {
          final sel = i == selected;
          final tab = tabs[i];
          return GestureDetector(
            onTap: () => onSelect(i),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.only(right: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                gradient: sel
                    ? const LinearGradient(
                        colors: [Color(0xFFFF3366), Color(0xFF6C63FF)],
                      )
                    : null,
                color: sel ? null : Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: sel
                      ? Colors.transparent
                      : Colors.white.withOpacity(0.1),
                  width: 0.8,
                ),
                boxShadow: sel
                    ? [
                        BoxShadow(
                            color: const Color(0xFFFF3366).withOpacity(0.25),
                            blurRadius: 12,
                            spreadRadius: -4)
                      ]
                    : [],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(tab.icon,
                      color:
                          sel ? Colors.white : Colors.white.withOpacity(0.45),
                      size: 13),
                  const SizedBox(width: 5),
                  Text(tab.label,
                      style: TextStyle(
                        color: sel
                            ? Colors.white
                            : Colors.white.withOpacity(0.45),
                        fontSize: 12,
                        fontWeight:
                            sel ? FontWeight.w700 : FontWeight.w500,
                      )),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TAB 0 — DASHBOARD
// ─────────────────────────────────────────────────────────────

class _DashboardTab extends ConsumerWidget {
  const _DashboardTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(adminStatsProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      physics: const BouncingScrollPhysics(),
      children: [
        stats
            .when(
              loading: () => _shimmerGrid(),
              error: (e, _) => _ErrorCard(message: e.toString()),
              data: (s) => Column(
                children: [
                  Row(children: [
                    Expanded(
                        child: _StatCard(
                            label: 'Total Users',
                            value: _fmt(s.totalUsers),
                            icon: Icons.people_rounded,
                            color: const Color(0xFF6C63FF))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _StatCard(
                            label: 'Active Today',
                            value: _fmt(s.activeToday),
                            icon: Icons.trending_up_rounded,
                            color: const Color(0xFF11D47B))),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                        child: _StatCard(
                            label: 'Total Plays',
                            value: _fmt(s.totalPlays),
                            icon: Icons.play_circle_rounded,
                            color: const Color(0xFFFF3366))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _StatCard(
                            label: 'Total Likes',
                            value: _fmt(s.totalLikes),
                            icon: Icons.favorite_rounded,
                            color: const Color(0xFFFF85A1))),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                        child: _StatCard(
                            label: 'Playlists',
                            value: _fmt(s.totalPlaylists),
                            icon: Icons.queue_music_rounded,
                            color: const Color(0xFFFFD700))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _StatCard(
                            label: 'Banned',
                            value: _fmt(s.bannedUsers),
                            icon: Icons.block_rounded,
                            color: const Color(0xFFFF4444))),
                  ]),
                  const SizedBox(height: 10),
                  _StatCard(
                    label: 'Active Announcements',
                    value: _fmt(s.activeAnnouncements),
                    icon: Icons.campaign_rounded,
                    color: const Color(0xFFF7971E),
                    wide: true,
                  ),
                  if (s.lastUpdated != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Last updated: ${_fmtDate(s.lastUpdated!)}',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.25),
                            fontSize: 11),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            )
            .animate()
            .fadeIn(duration: 400.ms),
        const SizedBox(height: 20),
        _AdminSectionHeader(
            title: 'Quick Actions', icon: Icons.bolt_rounded),
        const SizedBox(height: 10),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.2,
          children: [
            _QuickAction(
              label: 'New Announcement',
              icon: Icons.campaign_rounded,
              color: const Color(0xFFF7971E),
              onTap: () =>
                  ref.read(_adminTabProvider.notifier).state = 3,
            ),
            _QuickAction(
              label: 'Refresh All Stats',
              icon: Icons.sync_rounded,
              color: const Color(0xFF6C63FF),
              onTap: () async {
                final confirmed = await _confirm(context,
                    'Sync all user statistics? This will recalculate counts for every user.');
                if (!confirmed) return;
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text(
                          'Starting global sync… stay on this screen.')));
                }
                await ref.read(adminServiceProvider).syncAllUsersStats();
                await ref.read(adminServiceProvider).refreshStats();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('All user stats refreshed!')));
                }
              },
            ),
            _QuickAction(
              label: 'Manage Users',
              icon: Icons.people_rounded,
              color: const Color(0xFF6C63FF),
              onTap: () =>
                  ref.read(_adminTabProvider.notifier).state = 1,
            ),
            _QuickAction(
              label: 'App Config',
              icon: Icons.tune_rounded,
              color: const Color(0xFF11D47B),
              // FIX: Config is tab 5, not tab 4
              onTap: () =>
                  ref.read(_adminTabProvider.notifier).state = 5,
            ),
            _QuickAction(
              label: 'Content',
              icon: Icons.library_music_rounded,
              color: const Color(0xFFFF3366),
              onTap: () =>
                  ref.read(_adminTabProvider.notifier).state = 2,
            ),
            _QuickAction(
              label: 'Send Notification',
              icon: Icons.notifications_active_rounded,
              color: const Color(0xFFFF3366),
              onTap: () =>
                  ref.read(_adminTabProvider.notifier).state = 4,
            ),
          ],
        ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
      ],
    );
  }

  Widget _shimmerGrid() {
    return Column(
        children: List.generate(
            3,
            (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(children: [
                    Expanded(
                        child: Container(
                      height: 90,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    )
                            .animate(onPlay: (c) => c.repeat())
                            .shimmer(
                                duration: 1400.ms,
                                color:
                                    Colors.white.withOpacity(0.04))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Container(
                      height: 90,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    )
                            .animate(onPlay: (c) => c.repeat())
                            .shimmer(
                                duration: 1400.ms,
                                color:
                                    Colors.white.withOpacity(0.04))),
                  ]),
                )));
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

// ─────────────────────────────────────────────────────────────
// TAB 1 — USERS
// ─────────────────────────────────────────────────────────────

class _UsersTab extends ConsumerStatefulWidget {
  const _UsersTab();

  @override
  ConsumerState<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends ConsumerState<_UsersTab> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  // Filter: 'all' | 'banned' | 'online'
  String _filter = 'all';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(adminUsersProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: _AdminSearchBar(
            ctrl: _searchCtrl,
            hint: 'Search users by name or email…',
            onChanged: (q) => setState(() => _query = q.toLowerCase()),
          ),
        ),
        // Filter chips
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            children: [
              _FilterChip(
                  label: 'All',
                  selected: _filter == 'all',
                  onTap: () => setState(() => _filter = 'all')),
              const SizedBox(width: 8),
              _FilterChip(
                  label: 'Banned',
                  selected: _filter == 'banned',
                  color: const Color(0xFFFF4444),
                  onTap: () => setState(() => _filter = 'banned')),
              const SizedBox(width: 8),
              _FilterChip(
                  label: 'Online',
                  selected: _filter == 'online',
                  color: const Color(0xFF11D47B),
                  onTap: () => setState(() => _filter = 'online')),
            ],
          ),
        ),
        Expanded(
          child: usersAsync.when(
            loading: () => _buildShimmer(),
            error: (e, _) => _ErrorCard(message: e.toString()),
            data: (users) {
              var filtered = users;
              if (_query.isNotEmpty) {
                filtered = filtered
                    .where((u) =>
                        u.email.toLowerCase().contains(_query) ||
                        u.displayName.toLowerCase().contains(_query))
                    .toList();
              }
              if (_filter == 'banned') {
                filtered = filtered.where((u) => u.isBanned).toList();
              } else if (_filter == 'online') {
                filtered = filtered.where((u) => u.isOnline).toList();
              }

              if (filtered.isEmpty) {
                return _EmptyState(
                  icon: Icons.person_search_rounded,
                  message: 'No users found',
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                physics: const BouncingScrollPhysics(),
                itemCount: filtered.length,
                itemBuilder: (_, i) => _UserTile(
                  user: filtered[i],
                  index: i,
                ).animate().fadeIn(
                    delay: Duration(milliseconds: i * 25),
                    duration: 280.ms),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 8,
      itemBuilder: (_, __) => Container(
        height: 72,
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
        ),
      )
          .animate(onPlay: (c) => c.repeat())
          .shimmer(
              duration: 1400.ms, color: Colors.white.withOpacity(0.04)),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    this.color = const Color(0xFF6C63FF),
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? color.withOpacity(0.2)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? color.withOpacity(0.5)
                : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Text(label,
            style: TextStyle(
              color: selected ? color : Colors.white.withOpacity(0.5),
              fontSize: 12,
              fontWeight:
                  selected ? FontWeight.w700 : FontWeight.w500,
            )),
      ),
    );
  }
}

class _UserTile extends ConsumerStatefulWidget {
  final AdminUser user;
  final int index;

  const _UserTile({required this.user, required this.index});

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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: u.isBanned
              ? const Color(0xFFFF4444).withOpacity(0.3)
              : Colors.white.withOpacity(0.07),
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0xFF6C63FF).withOpacity(0.3),
            child: u.photoUrl.isNotEmpty
                ? ClipOval(
                    child: CachedNetworkImage(
                      memCacheWidth: 400,
                      imageUrl: u.photoUrl,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _initials(u),
                    ))
                : _initials(u),
          ),
          // Online indicator dot
          Transform.translate(
            offset: const Offset(-10, 16),
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: u.isOnline
                    ? const Color(0xFF11D47B)
                    : Colors.grey,
                shape: BoxShape.circle,
                border: Border.all(
                    color: const Color(0xFF070707), width: 2),
                boxShadow: u.isOnline
                    ? [
                        BoxShadow(
                          color: const Color(0xFF11D47B).withOpacity(0.4),
                          blurRadius: 4,
                          spreadRadius: 1,
                        )
                      ]
                    : [],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(
                    child: Text(
                      u.displayName.isNotEmpty
                          ? u.displayName
                          : u.email.split('@')[0],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (u.isBanned)
                    Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF4444).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color:
                                const Color(0xFFFF4444).withOpacity(0.4)),
                      ),
                      child: const Text('BANNED',
                          style: TextStyle(
                            color: Color(0xFFFF4444),
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          )),
                    ),
                  Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: (u.isOnline
                              ? const Color(0xFF11D47B)
                              : Colors.white)
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: (u.isOnline
                                ? const Color(0xFF11D47B)
                                : Colors.white)
                            .withOpacity(0.2),
                      ),
                    ),
                    child: Text(
                      u.isOnline ? 'ACTIVE' : 'OFFLINE',
                      style: TextStyle(
                        color: u.isOnline
                            ? const Color(0xFF11D47B)
                            : Colors.white.withOpacity(0.5),
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 2),
                Text(u.email,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.38),
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                if (u.createdAt != null)
                  Text(
                    'Joined ${_fmtDate(u.createdAt!)}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.22),
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ),
          // Actions
          _loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Color(0xFFFF3366)))
              : PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert_rounded,
                      color: Colors.white.withOpacity(0.4), size: 18),
                  color: const Color(0xFF1A1A1A),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  onSelected: (action) =>
                      _handleAction(context, action),
                  itemBuilder: (_) => [
                    _menuItem('view', Icons.visibility_rounded,
                        'View Details'),
                    _menuItem('sync', Icons.sync_rounded, 'Sync Stats'),
                    if (!u.isBanned)
                      _menuItem('ban', Icons.block_rounded, 'Ban User',
                          color: const Color(0xFFFF4444))
                    else
                      _menuItem('unban', Icons.check_circle_rounded,
                          'Unban User',
                          color: const Color(0xFF11D47B)),
                    _menuItem('delete', Icons.delete_rounded,
                        'Delete Data',
                        color: const Color(0xFFFF4444)),
                  ],
                ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _menuItem(String value, IconData icon, String label,
      {Color? color}) {
    return PopupMenuItem(
      value: value,
      child: Row(children: [
        Icon(icon,
            color: color ?? Colors.white.withOpacity(0.7), size: 16),
        const SizedBox(width: 10),
        Text(label,
            style: TextStyle(color: color ?? Colors.white, fontSize: 13)),
      ]),
    );
  }

  Widget _initials(AdminUser u) {
    final init = (u.displayName.isNotEmpty
            ? u.displayName[0]
            : u.email.isNotEmpty
                ? u.email[0]
                : 'U')
        .toUpperCase();
    return Text(init,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ));
  }

  Future<void> _handleAction(BuildContext context, String action) async {
    final svc = ref.read(adminServiceProvider);
    final u = widget.user;
    switch (action) {
      case 'view':
        _showUserDetails(context, u);
        break;
      case 'sync':
        setState(() => _loading = true);
        try {
          await svc.syncUserStats(u.uid);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Stats synced successfully')));
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Sync failed: $e')));
          }
        } finally {
          if (mounted) setState(() => _loading = false);
        }
        break;
      case 'ban':
        _showBanDialog(context, svc);
        break;
      case 'unban':
        setState(() => _loading = true);
        try {
          await svc.unbanUser(u.uid);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('User unbanned')));
          }
        } finally {
          if (mounted) setState(() => _loading = false);
        }
        break;
      case 'delete':
        _showDeleteDialog(context, svc);
        break;
    }
  }

  void _showUserDetails(BuildContext context, AdminUser u) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _AdminSheet(
        title: 'User Details',
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailRow('UID', u.uid),
              _DetailRow('Email', u.email),
              _DetailRow('Name',
                  u.displayName.isNotEmpty ? u.displayName : '—'),
              _DetailRow('Status',
                  u.isBanned ? '🔴 Banned' : '🟢 Active'),
              if (u.isBanned) ...[
                _DetailRow('Ban Reason', u.banReason),
                if (u.bannedAt != null)
                  _DetailRow('Banned At', _fmtDate(u.bannedAt!)),
                if (u.bannedBy.isNotEmpty)
                  _DetailRow('Banned By', u.bannedBy),
              ],
              _DetailRow('Online', u.isOnline ? 'Yes' : 'No'),
              _DetailRow('Liked Songs', '${u.likedSongs}'),
              _DetailRow('Playlists', '${u.playlists}'),
              _DetailRow('Total Plays', '${u.totalPlays}'),
              if (u.createdAt != null)
                _DetailRow('Joined', _fmtDate(u.createdAt!)),
              if (u.lastActive != null)
                _DetailRow('Last Active', _fmtDate(u.lastActive!)),
            ],
          ),
        ),
      ),
    );
  }

  void _showBanDialog(BuildContext context, AdminService svc) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => _AdminDialog(
        title: 'Ban User',
        message:
            'Enter the reason for banning ${widget.user.email}:',
        confirmLabel: 'Ban',
        isDestructive: true,
        extraContent: TextField(
          controller: reasonCtrl,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Reason…',
            hintStyle:
                TextStyle(color: Colors.white.withOpacity(0.3)),
            filled: true,
            fillColor: Colors.white.withOpacity(0.06),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        onConfirm: () async {
          Navigator.pop(context);
          setState(() => _loading = true);
          await svc.banUser(widget.user.uid, reasonCtrl.text);
          if (mounted) setState(() => _loading = false);
          reasonCtrl.dispose();
        },
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, AdminService svc) {
    showDialog(
      context: context,
      builder: (_) => _AdminDialog(
        title: 'Delete User Data',
        message:
            'Permanently delete all data for ${widget.user.email}? This cannot be undone.',
        confirmLabel: 'Delete',
        isDestructive: true,
        onConfirm: () async {
          Navigator.pop(context);
          setState(() => _loading = true);
          await svc.deleteUserData(widget.user.uid);
          if (mounted) setState(() => _loading = false);
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TAB 2 — CONTENT
// ─────────────────────────────────────────────────────────────

class _ContentTab extends ConsumerStatefulWidget {
  const _ContentTab();

  @override
  ConsumerState<_ContentTab> createState() => _ContentTabState();
}

class _ContentTabState extends ConsumerState<_ContentTab> {
  final _pageCtrl = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subTabs = ['Banners', 'Sections'];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
          child: Row(
            children: subTabs.asMap().entries.map((e) {
              final sel = e.key == _page;
              return GestureDetector(
                onTap: () {
                  setState(() => _page = e.key);
                  _pageCtrl.animateToPage(e.key,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 7),
                  decoration: BoxDecoration(
                    color: sel
                        ? Colors.white.withOpacity(0.12)
                        : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: sel
                          ? Colors.white.withOpacity(0.2)
                          : Colors.white.withOpacity(0.07),
                    ),
                  ),
                  child: Text(e.value,
                      style: TextStyle(
                        color: sel
                            ? Colors.white
                            : Colors.white.withOpacity(0.4),
                        fontSize: 12,
                        fontWeight: sel
                            ? FontWeight.w700
                            : FontWeight.w500,
                      )),
                ),
              );
            }).toList(),
          ),
        ),
        Expanded(
          child: PageView(
            controller: _pageCtrl,
            onPageChanged: (p) => setState(() => _page = p),
            children: const [
              _BannersPage(),
              _CuratedSectionsPage(),
            ],
          ),
        ),
      ],
    );
  }
}

class _BannersPage extends ConsumerWidget {
  const _BannersPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminBannersProvider);
    return async.when(
      loading: () => const Center(child: _Loader()),
      error: (e, _) => _ErrorCard(message: e.toString()),
      data: (banners) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
        physics: const BouncingScrollPhysics(),
        children: [
          _AddButton(
            label: 'Add Banner',
            onTap: () => _showBannerForm(context, ref, null),
          ),
          const SizedBox(height: 10),
          ...banners.map((b) => _BannerTile(
                banner: b,
                onEdit: () => _showBannerForm(context, ref, b),
                onDelete: () async {
                  final ok = await _confirm(
                      context, 'Delete banner "${b.title}"?');
                  if (!ok) return;
                  await ref
                      .read(adminServiceProvider)
                      .deleteBanner(b.id);
                },
                onToggle: (v) async {
                  await ref
                      .read(adminServiceProvider)
                      .updateBanner(b.id, {'isActive': v});
                },
              )),
        ],
      ),
    );
  }

  void _showBannerForm(
      BuildContext context, WidgetRef ref, FeaturedBanner? banner) {
    final titleCtrl =
        TextEditingController(text: banner?.title ?? '');
    final subtitleCtrl =
        TextEditingController(text: banner?.subtitle ?? '');
    final imageCtrl =
        TextEditingController(text: banner?.imageUrl ?? '');
    final queryCtrl =
        TextEditingController(text: banner?.actionQuery ?? '');
    final orderCtrl = TextEditingController(
        text: '${banner?.order ?? 0}');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AdminFormSheet(
        title: banner == null ? 'Add Banner' : 'Edit Banner',
        fields: [
          _FormField('Title', titleCtrl,
              hint: 'e.g. Featured Playlist'),
          _FormField('Subtitle', subtitleCtrl,
              hint: 'e.g. Hand-picked for you'),
          _FormField('Image URL', imageCtrl,
              hint: 'https://…'),
          _FormField('Search Query / Action', queryCtrl,
              hint: 'e.g. top bollywood hits'),
          _FormField('Display Order', orderCtrl, hint: '0'),
        ],
        onSave: () async {
          final order = int.tryParse(orderCtrl.text) ?? 0;
          if (banner == null) {
            await ref.read(adminServiceProvider).createBanner(
                  title: titleCtrl.text,
                  subtitle: subtitleCtrl.text,
                  imageUrl: imageCtrl.text,
                  actionQuery: queryCtrl.text,
                  order: order,
                );
          } else {
            await ref.read(adminServiceProvider).updateBanner(
                  banner.id,
                  {
                    'title': titleCtrl.text,
                    'subtitle': subtitleCtrl.text,
                    'imageUrl': imageCtrl.text,
                    'actionQuery': queryCtrl.text,
                    'order': order,
                  },
                );
          }
          if (context.mounted) Navigator.pop(context);
        },
      ),
    );
  }
}

class _BannerTile extends StatelessWidget {
  final FeaturedBanner banner;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggle;

  const _BannerTile({
    required this.banner,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (banner.imageUrl.isNotEmpty)
            SizedBox(
              height: 80,
              width: double.infinity,
              child: Image.network(
                banner.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.white.withOpacity(0.05),
                  child: const Center(
                      child: Icon(Icons.broken_image_rounded,
                          color: Colors.white24)),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(banner.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            )),
                        Text(banner.subtitle,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.4),
                              fontSize: 11,
                            )),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: banner.isActive,
                    onChanged: onToggle,
                    activeColor: const Color(0xFF11D47B),
                  ),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  _Pill(
                      label: 'Order: ${banner.order}',
                      color: Colors.white38),
                  const Spacer(),
                  _ChipBtn(
                      label: 'Edit',
                      icon: Icons.edit_rounded,
                      color: const Color(0xFF6C63FF),
                      onTap: onEdit),
                  const SizedBox(width: 8),
                  _ChipBtn(
                      label: 'Delete',
                      icon: Icons.delete_rounded,
                      color: const Color(0xFFFF4444),
                      onTap: onDelete),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CuratedSectionsPage extends ConsumerWidget {
  const _CuratedSectionsPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminCuratedProvider);
    return async.when(
      loading: () => const Center(child: _Loader()),
      error: (e, _) => _ErrorCard(message: e.toString()),
      data: (sections) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
        physics: const BouncingScrollPhysics(),
        children: [
          _AddButton(
            label: 'Add Section',
            onTap: () => _showSectionForm(context, ref, null),
          ),
          const SizedBox(height: 10),
          ...sections.map((s) => _SectionTile(
                section: s,
                onEdit: () => _showSectionForm(context, ref, s),
                onDelete: () async {
                  final ok = await _confirm(context,
                      'Delete section "${s['title']}"?');
                  if (!ok) return;
                  await ref
                      .read(adminServiceProvider)
                      .deleteCuratedSection(s['id']);
                },
                onToggle: (v) async {
                  await ref
                      .read(adminServiceProvider)
                      .updateCuratedSection(
                          s['id'], {'isActive': v});
                },
              )),
        ],
      ),
    );
  }

  void _showSectionForm(BuildContext context, WidgetRef ref,
      Map<String, dynamic>? section) {
    final titleCtrl =
        TextEditingController(text: section?['title'] ?? '');
    final subtitleCtrl =
        TextEditingController(text: section?['subtitle'] ?? '');
    final queryCtrl =
        TextEditingController(text: section?['query'] ?? '');
    final orderCtrl = TextEditingController(
        text: '${section?['order'] ?? 99}');
    String style = section?['style'] ?? 'standard';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AdminFormSheet(
        title: section == null ? 'Add Section' : 'Edit Section',
        fields: [
          _FormField('Title', titleCtrl,
              hint: 'e.g. Trending Now'),
          _FormField('Subtitle', subtitleCtrl,
              hint: 'e.g. what everyone\'s playing'),
          _FormField('Search Query', queryCtrl,
              hint: 'e.g. trending hindi songs 2025'),
          _FormField('Display Order', orderCtrl, hint: '99'),
        ],
        extraContent: StatefulBuilder(
          builder: (_, setS) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Card Style',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  )),
              const SizedBox(height: 8),
              Row(
                  children: ['standard', 'wide', 'ranked']
                      .map((s) {
                    final sel = s == style;
                    return GestureDetector(
                      onTap: () => setS(() => style = s),
                      child: AnimatedContainer(
                        duration:
                            const Duration(milliseconds: 180),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: sel
                              ? const Color(0xFFFF3366)
                                  .withOpacity(0.2)
                              : Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: sel
                                ? const Color(0xFFFF3366)
                                    .withOpacity(0.4)
                                : Colors.white.withOpacity(0.08),
                          ),
                        ),
                        child: Text(s,
                            style: TextStyle(
                              color: sel
                                  ? const Color(0xFFFF3366)
                                  : Colors.white.withOpacity(0.5),
                              fontSize: 12,
                              fontWeight: sel
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            )),
                      ),
                    );
                  }).toList()),
            ],
          ),
        ),
        onSave: () async {
          final order = int.tryParse(orderCtrl.text) ?? 99;
          if (section == null) {
            await ref
                .read(adminServiceProvider)
                .createCuratedSection(
                  title: titleCtrl.text,
                  subtitle: subtitleCtrl.text,
                  query: queryCtrl.text,
                  style: style,
                  order: order,
                );
          } else {
            await ref
                .read(adminServiceProvider)
                .updateCuratedSection(section['id'], {
              'title': titleCtrl.text,
              'subtitle': subtitleCtrl.text,
              'query': queryCtrl.text,
              'style': style,
              'order': order,
            });
          }
          if (context.mounted) Navigator.pop(context);
        },
      ),
    );
  }
}

class _SectionTile extends StatelessWidget {
  final Map<String, dynamic> section;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggle;

  const _SectionTile({
    required this.section,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = section['isActive'] ?? true;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(section['title'] ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    )),
                const SizedBox(height: 2),
                Text(section['subtitle'] ?? '',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.35),
                      fontSize: 11,
                    )),
                const SizedBox(height: 4),
                Row(children: [
                  _Pill(
                      label: section['style'] ?? 'standard',
                      color: const Color(0xFF6C63FF)),
                  const SizedBox(width: 6),
                  _Pill(
                      label: 'Order: ${section['order'] ?? 0}',
                      color: Colors.white38),
                ]),
              ],
            ),
          ),
          Column(children: [
            Switch.adaptive(
              value: isActive,
              onChanged: onToggle,
              activeColor: const Color(0xFF11D47B),
            ),
            Row(children: [
              GestureDetector(
                  onTap: onEdit,
                  child: Icon(Icons.edit_rounded,
                      color: Colors.white.withOpacity(0.4),
                      size: 16)),
              const SizedBox(width: 12),
              GestureDetector(
                  onTap: onDelete,
                  child: const Icon(Icons.delete_rounded,
                      color: Color(0xFFFF4444), size: 16)),
            ]),
          ]),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TAB 3 — ANNOUNCEMENTS
// ─────────────────────────────────────────────────────────────

class _AnnouncementsTab extends ConsumerWidget {
  const _AnnouncementsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminAnnouncementsProvider);
    return async.when(
      loading: () => const Center(child: _Loader()),
      error: (e, _) => _ErrorCard(message: e.toString()),
      data: (announcements) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
        physics: const BouncingScrollPhysics(),
        children: [
          _AddButton(
            label: 'New Announcement',
            onTap: () =>
                _showAnnouncementForm(context, ref, null),
          ),
          const SizedBox(height: 10),
          ...announcements.asMap().entries.map((e) =>
              _AnnouncementTile(
                ann: e.value,
                index: e.key,
                onEdit: () =>
                    _showAnnouncementForm(context, ref, e.value),
                onDelete: () async {
                  final ok = await _confirm(context,
                      'Delete announcement "${e.value.title}"?');
                  if (!ok) return;
                  await ref
                      .read(adminServiceProvider)
                      .deleteAnnouncement(e.value.id);
                },
                onToggle: (v) async {
                  await ref
                      .read(adminServiceProvider)
                      .updateAnnouncement(e.value.id,
                          isActive: v);
                },
              ).animate().fadeIn(
                    delay:
                        Duration(milliseconds: e.key * 40),
                    duration: 280.ms)),
        ],
      ),
    );
  }

  void _showAnnouncementForm(BuildContext context, WidgetRef ref,
      AppAnnouncement? ann) {
    final titleCtrl =
        TextEditingController(text: ann?.title ?? '');
    final msgCtrl =
        TextEditingController(text: ann?.message ?? '');
    String type = ann?.type ?? 'info';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AdminFormSheet(
        title: ann == null
            ? 'New Announcement'
            : 'Edit Announcement',
        fields: [
          _FormField('Title', titleCtrl,
              hint: 'e.g. New Feature!'),
          _FormField('Message', msgCtrl,
              hint: 'Announcement body…', maxLines: 3),
        ],
        extraContent: StatefulBuilder(
          builder: (_, setS) {
            final types = [
              ('info', const Color(0xFF6C63FF),
                  Icons.info_rounded),
              ('success', const Color(0xFF11D47B),
                  Icons.check_circle_rounded),
              ('warning', const Color(0xFFF7971E),
                  Icons.warning_rounded),
              ('promo', const Color(0xFFFF3366),
                  Icons.local_offer_rounded),
            ];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Type',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    )),
                const SizedBox(height: 8),
                Wrap(
                    spacing: 8,
                    children: types.map((t) {
                      final sel = t.$1 == type;
                      return GestureDetector(
                        onTap: () => setS(() => type = t.$1),
                        child: AnimatedContainer(
                          duration:
                              const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: sel
                                ? t.$2.withOpacity(0.2)
                                : Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: sel
                                  ? t.$2.withOpacity(0.5)
                                  : Colors.white.withOpacity(0.08),
                            ),
                          ),
                          child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(t.$3,
                                    color: sel
                                        ? t.$2
                                        : Colors.white38,
                                    size: 13),
                                const SizedBox(width: 4),
                                Text(t.$1,
                                    style: TextStyle(
                                      color: sel
                                          ? t.$2
                                          : Colors.white
                                              .withOpacity(0.4),
                                      fontSize: 11,
                                      fontWeight: sel
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    )),
                              ]),
                        ),
                      );
                    }).toList()),
              ],
            );
          },
        ),
        onSave: () async {
          if (titleCtrl.text.isEmpty || msgCtrl.text.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Title and message are required')));
            return;
          }
          if (ann == null) {
            await ref.read(adminServiceProvider).createAnnouncement(
                  title: titleCtrl.text,
                  message: msgCtrl.text,
                  type: type,
                );
          } else {
            await ref.read(adminServiceProvider).updateAnnouncement(
                  ann.id,
                  title: titleCtrl.text,
                  message: msgCtrl.text,
                  type: type,
                );
          }
          if (context.mounted) Navigator.pop(context);
        },
      ),
    );
  }
}

class _AnnouncementTile extends StatelessWidget {
  final AppAnnouncement ann;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggle;

  const _AnnouncementTile({
    required this.ann,
    required this.index,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  static const _typeColors = {
    'info': Color(0xFF6C63FF),
    'success': Color(0xFF11D47B),
    'warning': Color(0xFFF7971E),
    'promo': Color(0xFFFF3366),
  };

  static const _typeIcons = {
    'info': Icons.info_rounded,
    'success': Icons.check_circle_rounded,
    'warning': Icons.warning_rounded,
    'promo': Icons.local_offer_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final color = _typeColors[ann.type] ?? const Color(0xFF6C63FF);
    final icon = _typeIcons[ann.type] ?? Icons.info_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: ann.isActive
              ? color.withOpacity(0.25)
              : Colors.white.withOpacity(0.07),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Row(children: [
              Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 16)),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(ann.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ))),
              Switch.adaptive(
                value: ann.isActive,
                onChanged: onToggle,
                activeColor: const Color(0xFF11D47B),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Text(ann.message,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 12,
                  height: 1.4,
                )),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(18)),
            ),
            child: Row(children: [
              _Pill(label: ann.type, color: color),
              if (ann.createdAt != null) ...[
                const SizedBox(width: 8),
                Text(_fmtDate(ann.createdAt!),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.25),
                      fontSize: 10,
                    )),
              ],
              const Spacer(),
              _ChipBtn(
                  label: 'Edit',
                  icon: Icons.edit_rounded,
                  color: const Color(0xFF6C63FF),
                  onTap: onEdit),
              const SizedBox(width: 6),
              _ChipBtn(
                  label: 'Delete',
                  icon: Icons.delete_rounded,
                  color: const Color(0xFFFF4444),
                  onTap: onDelete),
            ]),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TAB 4 — NOTIFICATIONS
// ─────────────────────────────────────────────────────────────

class _NotificationsTab extends ConsumerWidget {
  const _NotificationsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final broadcastsAsync = ref.watch(adminBroadcastsProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      physics: const BouncingScrollPhysics(),
      children: [
        _AdminSectionHeader(
            title: 'Push Notifications',
            icon: Icons.notifications_active_rounded),
        const SizedBox(height: 10),
        _GlassCard(children: [
          _QuickAction(
            label: 'Send New Broadcast',
            icon: Icons.send_rounded,
            color: const Color(0xFF6C63FF),
            onTap: () => _showBroadcastForm(context, ref),
          ),
        ]),
        const SizedBox(height: 24),
        _AdminSectionHeader(
            title: 'Broadcast History',
            icon: Icons.history_rounded),
        const SizedBox(height: 10),
        broadcastsAsync.when(
          loading: () => const Center(
              child: Padding(
                  padding: EdgeInsets.all(24), child: _Loader())),
          error: (e, _) => _ErrorCard(message: e.toString()),
          data: (broadcasts) {
            if (broadcasts.isEmpty) {
              return _EmptyState(
                icon: Icons.history_rounded,
                message: 'No broadcasts sent yet',
              );
            }
            return Column(
              children: broadcasts
                  .asMap()
                  .entries
                  .map((e) => _BroadcastHistoryTile(
                        broadcast: e.value,
                        onDelete: () async {
                          final ok = await _confirm(context,
                              'Delete this broadcast record?');
                          if (!ok) return;
                          await ref
                              .read(adminServiceProvider)
                              .deleteBroadcast(e.value.id);
                        },
                      )
                          .animate()
                          .fadeIn(
                              delay: Duration(
                                  milliseconds: e.key * 30),
                              duration: 260.ms))
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  void _showBroadcastForm(BuildContext context, WidgetRef ref) {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    final imgCtrl = TextEditingController();
    final linkCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AdminFormSheet(
        title: 'Send Broadcast',
        fields: [
          _FormField('Title', titleCtrl,
              hint: 'Notification heading…'),
          _FormField('Message Body', bodyCtrl,
              hint: 'What users will see…', maxLines: 3),
          _FormField('Image URL (Optional)', imgCtrl,
              hint: 'https://…'),
          _FormField('Link / Action (Optional)', linkCtrl,
              hint: 'den://playlist/…'),
        ],
        onSave: () async {
          if (titleCtrl.text.isEmpty || bodyCtrl.text.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content:
                    Text('Title and message are required')));
            return;
          }
          HapticFeedback.mediumImpact();
          await ref
              .read(adminServiceProvider)
              .sendBroadcastNotification(
                title: titleCtrl.text,
                body: bodyCtrl.text,
                imageUrl: imgCtrl.text.isEmpty
                    ? null
                    : imgCtrl.text,
                link: linkCtrl.text.isEmpty ? null : linkCtrl.text,
              );
          if (context.mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Broadcast triggered!'),
                backgroundColor:
                    const Color(0xFF11D47B).withOpacity(0.9),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            );
          }
        },
      ),
    );
  }
}

class _BroadcastHistoryTile extends StatelessWidget {
  final BroadcastNotification broadcast;
  final VoidCallback onDelete;

  const _BroadcastHistoryTile({
    required this.broadcast,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (broadcast.status) {
      'sent' => const Color(0xFF11D47B),
      'failed' => const Color(0xFFFF4444),
      _ => const Color(0xFFF7971E),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: Colors.white.withOpacity(0.07), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.send_rounded,
                  color: Color(0xFF6C63FF), size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(broadcast.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      )),
                  if (broadcast.sentAt != null)
                    Text(_fmtDateTime(broadcast.sentAt!),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.3),
                          fontSize: 10,
                        )),
                ],
              ),
            ),
            _Pill(label: broadcast.status, color: statusColor),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onDelete,
              child: Icon(Icons.delete_outline_rounded,
                  color: Colors.white.withOpacity(0.3), size: 18),
            ),
          ]),
          const SizedBox(height: 8),
          Text(broadcast.body,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 12,
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          if (broadcast.imageUrl != null ||
              broadcast.link != null) ...[
            const SizedBox(height: 6),
            Row(children: [
              if (broadcast.imageUrl != null)
                _Pill(
                    label: '📷 Image',
                    color: Colors.white38),
              if (broadcast.link != null) ...[
                const SizedBox(width: 6),
                _Pill(
                    label: '🔗 Link',
                    color: Colors.white38),
              ],
            ]),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TAB 5 — CONFIG
// ─────────────────────────────────────────────────────────────

class _ConfigTab extends ConsumerWidget {
  const _ConfigTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminConfigProvider);
    return async.when(
      loading: () => const Center(child: _Loader()),
      error: (e, _) => _ErrorCard(message: e.toString()),
      data: (config) => _ConfigBody(config: config),
    );
  }
}

class _ConfigBody extends ConsumerStatefulWidget {
  final AppConfig config;
  const _ConfigBody({required this.config});

  @override
  ConsumerState<_ConfigBody> createState() => _ConfigBodyState();
}

class _ConfigBodyState extends ConsumerState<_ConfigBody> {
  late bool _maintenance;
  late bool _forceUpdate;
  late bool _audius;
  late bool _jiosaavn;
  late bool _registration;
  late String _maintenanceMsg;
  late String _welcomeMsg;
  late String _minVersion;
  late String _latestVersion;
  late String _updateMsg;
  late int _maxSearch;
  late int _maxHistory;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _reset(widget.config);
  }

  @override
  void didUpdateWidget(_ConfigBody old) {
    super.didUpdateWidget(old);
    // Sync if a new config snapshot arrives from Firestore
    if (old.config != widget.config && !_saving) {
      _reset(widget.config);
    }
  }

  void _reset(AppConfig c) {
    _maintenance = c.maintenanceMode;
    _forceUpdate = c.forceUpdate;
    _audius = c.audiusEnabled;
    _jiosaavn = c.jiosaavnEnabled;
    _registration = c.registrationEnabled;
    _maintenanceMsg = c.maintenanceMessage;
    _welcomeMsg = c.welcomeMessage;
    _minVersion = c.minVersion;
    _latestVersion = c.latestVersion;
    _updateMsg = c.updateMessage;
    _maxSearch = c.maxSearchResults;
    _maxHistory = c.maxHistoryItems;
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      physics: const BouncingScrollPhysics(),
      children: [
        // App Status
        _AdminSectionHeader(
            title: 'App Status',
            icon: Icons.power_settings_new_rounded),
        const SizedBox(height: 8),
        _GlassCard(children: [
          _ConfigSwitch(
            label: 'Maintenance Mode',
            subtitle: 'Block all users from accessing the app',
            icon: Icons.construction_rounded,
            color: const Color(0xFFFF4444),
            value: _maintenance,
            onChanged: (v) => setState(() => _maintenance = v),
          ),
          if (_maintenance)
            _ConfigTextField(
              label: 'Maintenance Message',
              value: _maintenanceMsg,
              onChanged: (v) =>
                  setState(() => _maintenanceMsg = v),
            ),
          _ConfigSwitch(
            label: 'Force Update',
            subtitle: 'Force users to update before using the app',
            icon: Icons.system_update_rounded,
            color: const Color(0xFFF7971E),
            value: _forceUpdate,
            onChanged: (v) => setState(() => _forceUpdate = v),
          ),
          if (_forceUpdate)
            _ConfigTextField(
              label: 'Update Message',
              value: _updateMsg,
              onChanged: (v) => setState(() => _updateMsg = v),
            ),
          _ConfigSwitch(
            label: 'New Registrations',
            subtitle: 'Allow new users to sign up',
            icon: Icons.person_add_rounded,
            color: const Color(0xFF11D47B),
            value: _registration,
            onChanged: (v) => setState(() => _registration = v),
          ),
        ]),

        const SizedBox(height: 16),

        // Version management
        _AdminSectionHeader(
            title: 'Version Control',
            icon: Icons.new_releases_rounded),
        const SizedBox(height: 8),
        _GlassCard(children: [
          _ConfigTextField(
            label: 'Min Supported Version',
            value: _minVersion,
            onChanged: (v) => setState(() => _minVersion = v),
          ),
          _ConfigTextField(
            label: 'Latest Version',
            value: _latestVersion,
            onChanged: (v) => setState(() => _latestVersion = v),
          ),
        ]),

        const SizedBox(height: 16),

        // APIs
        _AdminSectionHeader(
            title: 'Music Sources', icon: Icons.api_rounded),
        const SizedBox(height: 8),
        _GlassCard(children: [
          _ConfigSwitch(
            label: 'JioSaavn API',
            subtitle: 'Main Hindi / Bollywood music source',
            icon: Icons.music_note_rounded,
            color: const Color(0xFFFF3366),
            value: _jiosaavn,
            onChanged: (v) => setState(() => _jiosaavn = v),
          ),
          _ConfigSwitch(
            label: 'Audius API',
            subtitle: 'English / independent music source',
            icon: Icons.headphones_rounded,
            color: const Color(0xFF6C63FF),
            value: _audius,
            onChanged: (v) => setState(() => _audius = v),
          ),
        ]),

        const SizedBox(height: 16),

        // Limits
        _AdminSectionHeader(
            title: 'App Limits', icon: Icons.tune_rounded),
        const SizedBox(height: 8),
        _GlassCard(children: [
          _ConfigSlider(
            label: 'Max Search Results',
            value: _maxSearch.toDouble(),
            min: 10,
            max: 100,
            icon: Icons.search_rounded,
            color: const Color(0xFF6C63FF),
            onChanged: (v) =>
                setState(() => _maxSearch = v.toInt()),
          ),
          _ConfigSlider(
            label: 'Max History Items',
            value: _maxHistory.toDouble(),
            min: 10,
            max: 200,
            icon: Icons.history_rounded,
            color: const Color(0xFFFF3366),
            onChanged: (v) =>
                setState(() => _maxHistory = v.toInt()),
          ),
        ]),

        const SizedBox(height: 16),

        // Messages
        _AdminSectionHeader(
            title: 'Messages', icon: Icons.message_rounded),
        const SizedBox(height: 8),
        _GlassCard(children: [
          _ConfigTextField(
            label: 'Welcome Message',
            value: _welcomeMsg,
            onChanged: (v) => setState(() => _welcomeMsg = v),
          ),
        ]),

        const SizedBox(height: 20),

        // Save button
        GestureDetector(
          onTap: _saving ? null : _save,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFFFF3366), Color(0xFF6C63FF)]),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF3366).withOpacity(0.3),
                  blurRadius: 16,
                  spreadRadius: -4,
                ),
              ],
            ),
            child: Center(
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.save_rounded,
                            color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text('Save Configuration',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            )),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(adminServiceProvider).updateAppConfig({
        'maintenanceMode': _maintenance,
        'maintenanceMessage': _maintenanceMsg,
        'forceUpdate': _forceUpdate,
        'updateMessage': _updateMsg,
        'audiusEnabled': _audius,
        'jiosaavnEnabled': _jiosaavn,
        'registrationEnabled': _registration,
        'maxSearchResults': _maxSearch,
        'maxHistoryItems': _maxHistory,
        'welcomeMessage': _welcomeMsg,
        'minVersion': _minVersion,
        'latestVersion': _latestVersion,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Configuration saved!',
              style: TextStyle(color: Colors.white)),
          backgroundColor:
              const Color(0xFF11D47B).withOpacity(0.9),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          duration: const Duration(milliseconds: 2000),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Save failed: $e'),
          backgroundColor: const Color(0xFFFF4444),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ─────────────────────────────────────────────────────────────
// TAB 6 — ACTIVITY LOGS
// ─────────────────────────────────────────────────────────────

class _LogsTab extends ConsumerWidget {
  const _LogsTab();

  static const _actionIcons = <String, IconData>{
    'ban_user': Icons.block_rounded,
    'unban_user': Icons.check_circle_rounded,
    'delete_user_data': Icons.delete_forever_rounded,
    'sync_all_stats': Icons.sync_rounded,
    'refresh_stats': Icons.refresh_rounded,
    'send_broadcast': Icons.send_rounded,
    'delete_broadcast': Icons.notifications_off_rounded,
    'create_announcement': Icons.campaign_rounded,
    'delete_announcement': Icons.remove_circle_rounded,
    'update_config': Icons.settings_rounded,
    'create_banner': Icons.image_rounded,
    'delete_banner': Icons.image_not_supported_rounded,
    'create_curated_section': Icons.playlist_add_rounded,
    'delete_curated_section': Icons.playlist_remove_rounded,
  };

  static const _actionColors = <String, Color>{
    'ban_user': Color(0xFFFF4444),
    'unban_user': Color(0xFF11D47B),
    'delete_user_data': Color(0xFFFF4444),
    'sync_all_stats': Color(0xFF6C63FF),
    'refresh_stats': Color(0xFF6C63FF),
    'send_broadcast': Color(0xFF6C63FF),
    'update_config': Color(0xFFF7971E),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminActivityProvider);
    return async.when(
      loading: () => const Center(child: _Loader()),
      error: (e, _) => _ErrorCard(message: e.toString()),
      data: (logs) {
        if (logs.isEmpty) {
          return _EmptyState(
            icon: Icons.receipt_long_rounded,
            message: 'No activity logs yet',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          physics: const BouncingScrollPhysics(),
          itemCount: logs.length,
          itemBuilder: (_, i) {
            final log = logs[i];
            final ts =
                (log['timestamp'] as Timestamp?)?.toDate();
            final action = log['action'] as String? ?? '';
            final color = _actionColors[action] ??
                const Color(0xFF6C63FF);
            final icon =
                _actionIcons[action] ?? Icons.bolt_rounded;
            final details =
                log['details'] as Map<String, dynamic>? ?? {};

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: Colors.white.withOpacity(0.06)),
              ),
              child: Row(children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 18)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        action.replaceAll('_', ' ').toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (details.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          details.entries
                              .take(2)
                              .map((e) =>
                                  '${e.key}: ${e.value}')
                              .join(' · '),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.35),
                            fontSize: 10,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (ts != null)
                        Text(_fmtDateTime(ts),
                            style: TextStyle(
                              color:
                                  Colors.white.withOpacity(0.25),
                              fontSize: 10,
                            )),
                    ],
                  ),
                ),
                if (log['adminEmail'] != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'admin',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.25),
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ]),
            ).animate().fadeIn(
                delay: Duration(milliseconds: i * 20),
                duration: 250.ms);
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// REUSABLE COMPONENTS
// ─────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool wide;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: wide ? double.infinity : null,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  )),
              Text(label,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  )),
            ],
          ),
        ),
      ]),
    );
  }
}

class _QuickAction extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  State<_QuickAction> createState() => _QuickActionState();
}

class _QuickActionState extends State<_QuickAction> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: widget.color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: widget.color.withOpacity(0.2)),
          ),
          child: Row(children: [
            Icon(widget.icon, color: widget.color, size: 18),
            const SizedBox(width: 8),
            Flexible(
                child: Text(widget.label,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis)),
          ]),
        ),
      ),
    );
  }
}

class _AdminSectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _AdminSectionHeader(
      {required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, color: Colors.white.withOpacity(0.3), size: 14),
      const SizedBox(width: 7),
      Text(title.toUpperCase(),
          style: TextStyle(
            color: Colors.white.withOpacity(0.3),
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          )),
    ]);
  }
}

class _GlassCard extends StatelessWidget {
  final List<Widget> children;
  const _GlassCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(18),
            border:
                Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(
              children: children.asMap().entries.map((e) {
            final isLast = e.key == children.length - 1;
            return Column(children: [
              e.value,
              if (!isLast)
                Divider(
                    height: 1,
                    color: Colors.white.withOpacity(0.05),
                    indent: 54),
            ]);
          }).toList()),
        ),
      ),
    );
  }
}

class _ConfigSwitch extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ConfigSwitch({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 12),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  )),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.35),
                    fontSize: 11,
                  )),
            ],
          ),
        ),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeColor: const Color(0xFF11D47B),
          activeTrackColor:
              const Color(0xFF11D47B).withOpacity(0.3),
          inactiveThumbColor: Colors.white.withOpacity(0.4),
          inactiveTrackColor: Colors.white.withOpacity(0.1),
        ),
      ]),
    );
  }
}

class _ConfigTextField extends StatelessWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  const _ConfigTextField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              )),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: value,
            onChanged: onChanged,
            style: const TextStyle(
                color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfigSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min, max;
  final IconData icon;
  final Color color;
  final ValueChanged<double> onChanged;

  const _ConfigSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.icon,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Column(children: [
        Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600))),
          Text('${value.toInt()}',
              style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w800)),
        ]),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: color,
            inactiveTrackColor: color.withOpacity(0.2),
            thumbColor: color,
            overlayColor: color.withOpacity(0.15),
            trackHeight: 3,
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SHARED SHEET / FORM COMPONENTS
// ─────────────────────────────────────────────────────────────

class _AdminSearchBar extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final ValueChanged<String> onChanged;

  const _AdminSearchBar({
    required this.ctrl,
    required this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: TextField(
        controller: ctrl,
        onChanged: onChanged,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
              color: Colors.white.withOpacity(0.3), fontSize: 13),
          prefixIcon: Icon(Icons.search_rounded,
              color: Colors.white.withOpacity(0.3), size: 18),
          suffixIcon: ctrl.text.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    ctrl.clear();
                    onChanged('');
                  },
                  child: Icon(Icons.close_rounded,
                      color: Colors.white.withOpacity(0.3),
                      size: 16),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _AddButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFFFF3366), Color(0xFF6C63FF)]),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF3366).withOpacity(0.2),
              blurRadius: 12,
              spreadRadius: -4,
            )
          ],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center,
            children: [
          const Icon(Icons.add_rounded,
              color: Colors.white, size: 18),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              )),
        ]),
      ),
    );
  }
}

class _AdminSheet extends StatelessWidget {
  final String title;
  final Widget child;

  const _AdminSheet({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0E0E0E),
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
        border:
            Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Text(title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  )),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Icon(Icons.close_rounded,
                    color: Colors.white.withOpacity(0.4),
                    size: 20),
              ),
            ]),
          ),
          const SizedBox(height: 8),
          Flexible(child: SingleChildScrollView(child: child)),
        ],
      ),
    );
  }
}

class _AdminFormSheet extends StatelessWidget {
  final String title;
  final List<_FormField> fields;
  final Widget? extraContent;
  final VoidCallback onSave;

  const _AdminFormSheet({
    required this.title,
    required this.fields,
    this.extraContent,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottom + 24),
      decoration: BoxDecoration(
        color: const Color(0xFF0E0E0E),
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
        border:
            Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  )),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Icon(Icons.close_rounded,
                    color: Colors.white.withOpacity(0.4),
                    size: 20),
              ),
            ]),
            const SizedBox(height: 16),
            ...fields.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(f.label.toUpperCase(),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          )),
                      const SizedBox(height: 6),
                      TextField(
                        controller: f.ctrl,
                        maxLines: f.maxLines,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: f.hint,
                          hintStyle: TextStyle(
                              color:
                                  Colors.white.withOpacity(0.25),
                              fontSize: 12),
                          filled: true,
                          fillColor:
                              Colors.white.withOpacity(0.05),
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(12),
                            borderSide: BorderSide(
                                color: const Color(0xFFFF3366)
                                    .withOpacity(0.5)),
                          ),
                          contentPadding:
                              const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                )),
            if (extraContent != null) ...[
              const SizedBox(height: 4),
              extraContent!,
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 8),
            GestureDetector(
              onTap: onSave,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [
                    Color(0xFFFF3366),
                    Color(0xFF6C63FF)
                  ]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                    child: Text('Save',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormField {
  final String label;
  final TextEditingController ctrl;
  final String? hint;
  final int maxLines;

  const _FormField(this.label, this.ctrl,
      {this.hint, this.maxLines = 1});
}

class _AdminDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final bool isDestructive;
  final Widget? extraContent;
  final VoidCallback onConfirm;

  const _AdminDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.isDestructive,
    required this.onConfirm,
    this.extraContent,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: const Color(0xFF0E0E0E).withOpacity(0.92),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                  color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    )),
                const SizedBox(height: 10),
                Text(message,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 13,
                      height: 1.5,
                    )),
                if (extraContent != null) ...[
                  const SizedBox(height: 14),
                  extraContent!,
                ],
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 12),
                        decoration: BoxDecoration(
                          color:
                              Colors.white.withOpacity(0.07),
                          borderRadius:
                              BorderRadius.circular(14),
                          border: Border.all(
                              color: Colors.white
                                  .withOpacity(0.1)),
                        ),
                        child: const Center(
                            child: Text('Cancel',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ))),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: onConfirm,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 12),
                        decoration: BoxDecoration(
                          gradient: isDestructive
                              ? const LinearGradient(colors: [
                                  Color(0xFFFF4444),
                                  Color(0xFFCC0000)
                                ])
                              : const LinearGradient(colors: [
                                  Color(0xFFFF3366),
                                  Color(0xFF6C63FF)
                                ]),
                          borderRadius:
                              BorderRadius.circular(14),
                        ),
                        child: Center(
                            child: Text(confirmLabel,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ))),
                      ),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 12,
                )),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                )),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_rounded,
                color: Color(0xFFFF4444), size: 48),
            const SizedBox(height: 12),
            Text('Error: $message',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 13),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              color: Colors.white.withOpacity(0.15), size: 56),
          const SizedBox(height: 14),
          Text(message,
              style: TextStyle(
                color: Colors.white.withOpacity(0.35),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              )),
        ],
      ),
    );
  }
}

class _Loader extends StatelessWidget {
  const _Loader();

  @override
  Widget build(BuildContext context) {
    return const CircularProgressIndicator(
      strokeWidth: 2,
      color: Color(0xFFFF3366),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  const _Pill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          )),
    );
  }
}

class _ChipBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ChipBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              )),
        ]),
      ),
    );
  }
}