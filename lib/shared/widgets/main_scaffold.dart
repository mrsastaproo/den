import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import 'mini_player.dart';

class MainScaffold extends ConsumerWidget {
  final Widget child;
  const MainScaffold({super.key, required this.child});

  int _locationToIndex(String location) {
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/search')) return 1;
    if (location.startsWith('/library')) return 2;
    if (location.startsWith('/settings')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.toString();
    final currentIndex = _locationToIndex(location);

    return Scaffold(
      body: child,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Mini player sits above bottom nav
          const MiniPlayer(),
          Container(
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Color(0xFF2A2A2A), width: 0.5),
              ),
            ),
            child: BottomNavigationBar(
              currentIndex: currentIndex,
              onTap: (i) {
                switch (i) {
                  case 0: context.go('/home'); break;
                  case 1: context.go('/search'); break;
                  case 2: context.go('/library'); break;
                  case 3: context.go('/settings'); break;
                }
              },
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_rounded), label: 'Home'),
                BottomNavigationBarItem(
                  icon: Icon(Icons.search_rounded), label: 'Search'),
                BottomNavigationBarItem(
                  icon: Icon(Icons.library_music_rounded), label: 'Library'),
                BottomNavigationBarItem(
                  icon: Icon(Icons.settings_rounded), label: 'Settings'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}