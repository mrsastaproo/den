import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'glass_bottom_nav.dart';
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
      backgroundColor: const Color(0xFF080808),
      extendBody: true,
      body: child,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Mini player
          const MiniPlayer(),
          // Floating glass nav
          GlassBottomNav(
            currentIndex: currentIndex,
            onTap: (i) {
              switch (i) {
                case 0: context.go('/home'); break;
                case 1: context.go('/search'); break;
                case 2: context.go('/library'); break;
                case 3: context.go('/settings'); break;
              }
            },
          ),
        ],
      ),
    );
  }
}