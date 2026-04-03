import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/home/home_screen.dart';
import '../../features/search/search_screen.dart';
import '../../features/library/library_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/admin/admin_layout.dart';
import '../../features/auth/login_screen.dart';
import '../../features/ai/ai_screen.dart';
import '../../features/wrapped/wrapped_screen.dart';
import '../../shared/widgets/main_scaffold.dart';
import '../../features/friends/friends_screen.dart';
import '../../features/friends/chat_screen.dart';
import '../../features/splash/splash_screen.dart';
import 'package:den/features/notifications/notification_inbox_screen.dart';
import '../services/auth_service.dart';
import '../services/admin_service.dart';
import '../services/social_service.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = ValueNotifier<bool>(false);

  ref.listen<AsyncValue<dynamic>>(authStateProvider, (prev, next) {
    refreshNotifier.value = !refreshNotifier.value;
  });

  ref.listen<AsyncValue<Map<String, dynamic>?>>(userProfileProvider, (prev, next) {
    if (next.value?['isBanned'] == true) {
      refreshNotifier.value = !refreshNotifier.value;
    }
  });

  return GoRouter(
    initialLocation: '/splash',          // ← start on splash
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final path = state.uri.toString();

      // Never redirect away from splash — it navigates itself
      if (path == '/splash') return null;

      final authState = ref.read(authStateProvider);

      // Don't redirect while auth is loading
      if (authState.isLoading) return null;

      final isLoggedIn  = authState.value != null;
      final userProfile = ref.read(userProfileProvider).value;
      final isBanned    = userProfile?['isBanned'] == true;

      final isLoginRoute = path == '/login';
      final isAdminRoute = path == '/admin';

      if (isLoggedIn && isBanned) {
        // Force the user out if they are banned
        Future.microtask(() => ref.read(authServiceProvider).signOut());
        return '/login';
      }

      if (!isLoggedIn && !isLoginRoute) return '/login';
      if (isLoggedIn && isLoginRoute)   return '/home';

      // Hard guard — redirect non-admins away from /admin
      if (isAdminRoute && !isAdmin(authState.value)) return '/home';

      return null;
    },
    routes: [

      // ── Splash ─────────────────────────────────────────────────────────────
      GoRoute(
        path: '/splash',
        builder: (context, state) => SplashScreen(
          onComplete: () {
            // After splash, let the redirect logic decide where to go
            context.go('/home');
          },
        ),
      ),

      // ── Auth ───────────────────────────────────────────────────────────────
      GoRoute(
        path: '/login',
        builder: (c, s) => const LoginScreen(),
      ),

      // ── Admin (full screen, outside shell) ─────────────────────────────────
      GoRoute(
        path: '/admin',
        builder: (c, s) => const AdminLayout(),
      ),

      // ── Chat (full screen, outside shell) ──────────────────────────────────
      GoRoute(
        path: '/chat/:uid',
        builder: (c, s) {
          final extras = s.extra as Map<String, dynamic>?;
          return ChatScreen(
            otherUid:   s.pathParameters['uid']!,
            username:   extras?['username'],
            profileUrl: extras?['profileUrl'],
          );
        },
      ),

      // ── Main shell ─────────────────────────────────────────────────────────
      ShellRoute(
        builder: (context, state, child) =>
            MainScaffold(child: child),
        routes: [
          GoRoute(
            path: '/home',
            pageBuilder: (c, s) => CustomTransitionPage(
              child: const HomeScreen(),
              transitionsBuilder: (_, a, __, c) =>
                  FadeTransition(opacity: a, child: c),
              transitionDuration: const Duration(milliseconds: 400),
            ),
          ),
          GoRoute(
            path: '/search',
            pageBuilder: (c, s) => CustomTransitionPage(
              child: const SearchScreen(),
              transitionsBuilder: (_, a, __, c) =>
                  FadeTransition(opacity: a, child: c),
              transitionDuration: const Duration(milliseconds: 400),
            ),
          ),
          GoRoute(
            path: '/ai',
            pageBuilder: (c, s) => CustomTransitionPage(
              child: const AiScreen(),
              transitionsBuilder: (_, a, __, c) =>
                  FadeTransition(opacity: a, child: c),
              transitionDuration: const Duration(milliseconds: 400),
            ),
          ),
          GoRoute(
            path: '/library',
            pageBuilder: (c, s) => CustomTransitionPage(
              child: const LibraryScreen(),
              transitionsBuilder: (_, a, __, c) =>
                  FadeTransition(opacity: a, child: c),
              transitionDuration: const Duration(milliseconds: 400),
            ),
          ),
          GoRoute(
            path: '/friends',
            pageBuilder: (c, s) => CustomTransitionPage(
              child: const FriendsScreen(),
              transitionsBuilder: (_, a, __, c) =>
                  FadeTransition(opacity: a, child: c),
              transitionDuration: const Duration(milliseconds: 400),
            ),
          ),
          GoRoute(
            path: '/wrapped',
            pageBuilder: (c, s) => CustomTransitionPage(
              child: const WrappedScreen(),
              transitionsBuilder: (_, a, __, c) =>
                  FadeTransition(opacity: a, child: c),
              transitionDuration: const Duration(milliseconds: 400),
            ),
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (c, s) => CustomTransitionPage(
              child: const SettingsScreen(),
              transitionsBuilder: (_, a, __, c) =>
                  FadeTransition(opacity: a, child: c),
              transitionDuration: const Duration(milliseconds: 400),
            ),
          ),
          GoRoute(
            path: '/notifications',
            pageBuilder: (c, s) => CustomTransitionPage(
              child: const NotificationInboxScreen(),
              transitionsBuilder: (_, a, __, c) =>
                  FadeTransition(opacity: a, child: c),
              transitionDuration: const Duration(milliseconds: 400),
            ),
          ),
        ],
      ),
    ],
  );
});