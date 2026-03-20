import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/home/home_screen.dart';
import '../../features/search/search_screen.dart';
import '../../features/library/library_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../shared/widgets/main_scaffold.dart';
import '../services/auth_service.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/home',
    redirect: (context, state) {
      final isLoggedIn = authState.value != null;
      final isLoginRoute = state.uri.toString() == '/login';

      if (!isLoggedIn && !isLoginRoute) return '/login';
      if (isLoggedIn && isLoginRoute) return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (c, s) => const LoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) =>
          MainScaffold(child: child),
        routes: [
          GoRoute(path: '/home',
            builder: (c, s) => const HomeScreen()),
          GoRoute(path: '/search',
            builder: (c, s) => const SearchScreen()),
          GoRoute(path: '/library',
            builder: (c, s) => const LibraryScreen()),
          GoRoute(path: '/settings',
            builder: (c, s) => const SettingsScreen()),
        ],
      ),
    ],
  );
});