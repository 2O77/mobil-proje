import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/role_setup_screen.dart';
import '../../features/home/presentation/home_shell.dart';
import '../../features/splash/splash_screen.dart';
import '../providers/session_provider.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ref.watch(routerRefreshProvider);
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final async = ref.read(sessionStreamProvider);
      return async.when(
        data: (session) {
          if (session == null) {
            if (loc == '/login' || loc == '/register') return null;
            return '/login';
          }
          if (session.needsRole) {
            if (loc == '/role-setup') return null;
            return '/role-setup';
          }
          if (loc == '/login' || loc == '/register' || loc == '/role-setup' || loc == '/splash') {
            return '/home';
          }
          return null;
        },
        loading: () {
          if (loc == '/splash') return null;
          return '/splash';
        },
        error: (_, __) => '/login',
      );
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/role-setup', builder: (_, __) => const RoleSetupScreen()),
      GoRoute(path: '/home', builder: (_, __) => const HomeShell()),
    ],
  );
});
