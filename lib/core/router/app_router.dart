import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/home/home_screen.dart';
import '../../features/search/search_screen.dart';
import '../../features/library/library_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/settings/admin_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/ai/ai_screen.dart';
import '../../features/wrapped/wrapped_screen.dart';
import '../../shared/widgets/main_scaffold.dart';
import '../services/auth_service.dart';
import '../services/admin_service.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/home',
    redirect: (context, state) {
      final isLoggedIn = authState.value != null;
      final isLoginRoute = state.uri.toString() == '/login';
      final isAdminRoute = state.uri.toString() == '/admin';

      if (!isLoggedIn && !isLoginRoute) return '/login';
      if (isLoggedIn && isLoginRoute) return '/home';

      // Hard guard — redirect non-admins away from /admin
      if (isAdminRoute && !isAdmin(authState.value)) return '/home';

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (c, s) => const LoginScreen(),
      ),
      // Admin panel — full screen, outside the shell
      GoRoute(
        path: '/admin',
        builder: (c, s) => const AdminScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) =>
          MainScaffold(child: child),
        routes: [
          GoRoute(
            path: '/home',
            pageBuilder: (c, s) => CustomTransitionPage(
              child: const HomeScreen(),
              transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
              transitionDuration: const Duration(milliseconds: 400),
            ),
          ),
          GoRoute(
            path: '/search',
            pageBuilder: (c, s) => CustomTransitionPage(
              child: const SearchScreen(),
              transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
              transitionDuration: const Duration(milliseconds: 400),
            ),
          ),
          GoRoute(
            path: '/ai',
            pageBuilder: (c, s) => CustomTransitionPage(
              child: const AiScreen(),
              transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
              transitionDuration: const Duration(milliseconds: 400),
            ),
          ),
          GoRoute(
            path: '/library',
            pageBuilder: (c, s) => CustomTransitionPage(
              child: const LibraryScreen(),
              transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
              transitionDuration: const Duration(milliseconds: 400),
            ),
          ),
          GoRoute(
            path: '/wrapped',
            pageBuilder: (c, s) => CustomTransitionPage(
              child: const WrappedScreen(),
              transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
              transitionDuration: const Duration(milliseconds: 400),
            ),
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (c, s) => CustomTransitionPage(
              child: const SettingsScreen(),
              transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
              transitionDuration: const Duration(milliseconds: 400),
            ),
          ),
        ],
      ),
    ],
  );
});