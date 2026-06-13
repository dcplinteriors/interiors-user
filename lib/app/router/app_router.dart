import 'package:dcpl_shared/dcpl_shared.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

import '../../features/features.dart';
import '../routes/app_routes.dart';
import 'auth_refresh.dart';

class AppRouter {
  AppRouter._();

  static final GoRouter router = GoRouter(
    initialLocation: AppRoutes.projects,
    refreshListenable: AuthRefresh(Get.find<AuthService>().authStateChanges),
    redirect: (context, state) {
      final loggedIn = Get.find<AuthService>().isLoggedIn;
      final onLogin = state.matchedLocation == AppRoutes.login;
      if (!loggedIn) return onLogin ? null : AppRoutes.login;
      if (onLogin || state.uri.path == '/') return AppRoutes.projects;
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        builder: (_, _) => const LoginView(),
      ),
      // Full-screen submit form, pushed over the shell. Optional ?projectId= locks the project.
      GoRoute(
        path: AppRoutes.newRequest,
        builder: (_, state) => NewRequestView(
          projectId: state.uri.queryParameters['projectId'],
        ),
      ),
      // Persistent rail shell with each section as a state-preserving branch.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            HomeShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.projects,
                pageBuilder: (_, _) => const NoTransitionPage(child: ProjectsView()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.requests,
                pageBuilder: (_, _) => const NoTransitionPage(child: RequestsView()),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
