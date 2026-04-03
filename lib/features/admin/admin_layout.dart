import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/admin_service.dart';
import '../../core/services/auth_service.dart';

import 'dashboard/dashboard_tab.dart';
import 'users/users_tab.dart';
import 'content/content_tab.dart';
import 'announcements/announcements_tab.dart';
import 'notifications/notifications_tab.dart';
import 'settings/config_tab.dart';
import 'logs/logs_tab.dart';
import 'diagnostic/diagnostic_tab.dart';

// Provides the current active tab index (0-6)
final adminTabProvider = StateProvider<int>((ref) => 0);

class AdminLayout extends ConsumerWidget {
  const AdminLayout({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);

    if (!isAdmin) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text('Access Denied. Admins only.',
              style: TextStyle(color: Colors.white, fontSize: 18)),
        ),
      );
    }

    final tabIndex = ref.watch(adminTabProvider);
    final tabs = [
      _TabData('Dashboard', Icons.dashboard_rounded),
      _TabData('Users', Icons.people_rounded),
      _TabData('Content', Icons.library_music_rounded),
      _TabData('Announcements', Icons.campaign_rounded),
      _TabData('Notifications', Icons.notifications_active_rounded),
      _TabData('Config', Icons.settings_rounded),
      _TabData('Logs', Icons.receipt_long_rounded),
      _TabData('Diagnostic', Icons.auto_fix_high_rounded),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF070707),
      body: Stack(
        children: [
          const AdminAmbientOverlay(),
          Column(
            children: [
              AdminHeader(currentTab: tabIndex, tabs: tabs),
              AdminTabBar(
                tabs: tabs,
                selected: tabIndex,
                onSelect: (i) {
                  HapticFeedback.selectionClick();
                  ref.read(adminTabProvider.notifier).state = i;
                },
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: KeyedSubtree(
                    key: ValueKey(tabIndex),
                    child: _getTabContent(tabIndex),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _getTabContent(int index) {
    switch (index) {
      case 0: return const DashboardTab();
      case 1: return const UsersTab();
      case 2: return const ContentTab();
      case 3: return const AnnouncementsTab();
      case 4: return const NotificationsTab();
      case 5: return const ConfigTab();
      case 6: return const LogsTab();
      case 7: return const DiagnosticTab();
      default: return const DashboardTab();
    }
  }
}

class _TabData {
  final String label;
  final IconData icon;
  const _TabData(this.label, this.icon);
}

// ─────────────────────────────────────────────────────────────
// AMBIENT OVERLAY
// ─────────────────────────────────────────────────────────────
class AdminAmbientOverlay extends StatelessWidget {
  const AdminAmbientOverlay({super.key});

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
// HEADER COMPONENT
// ─────────────────────────────────────────────────────────────
class AdminHeader extends ConsumerWidget {
  final int currentTab;
  final List<_TabData> tabs;

  const AdminHeader({super.key, required this.currentTab, required this.tabs});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final top = MediaQuery.of(context).padding.top;

    return ClipRect(
      child: Container(child: Container(
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
              GestureDetector(
                onTap: () async {
                  HapticFeedback.lightImpact();
                  await ref.read(adminServiceProvider).refreshStats();
                },
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Icon(Icons.refresh_rounded, color: Colors.white.withOpacity(0.8), size: 18),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                     if (context.canPop()) {
                        context.pop();
                     } else {
                        context.go('/home');
                     }
                },
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Icon(Icons.close_rounded, color: Colors.white.withOpacity(0.8), size: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TAB BAR COMPONENT
// ─────────────────────────────────────────────────────────────
class AdminTabBar extends StatelessWidget {
  final List<_TabData> tabs;
  final int selected;
  final ValueChanged<int> onSelect;

  const AdminTabBar({
    super.key,
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                gradient: sel
                    ? const LinearGradient(colors: [Color(0xFFFF3366), Color(0xFF6C63FF)])
                    : null,
                color: sel ? null : Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: sel ? Colors.transparent : Colors.white.withOpacity(0.1),
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
                      color: sel ? Colors.white : Colors.white.withOpacity(0.45),
                      size: 13),
                  const SizedBox(width: 5),
                  Text(tab.label,
                      style: TextStyle(
                        color: sel ? Colors.white : Colors.white.withOpacity(0.45),
                        fontSize: 12,
                        fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
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
