import 'package:dcpl_shared/dcpl_shared.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

import '../../features/features.dart';
import '../routes/app_routes.dart';
import 'auth_refresh.dart';

class AppRouter {
  AppRouter._();

  static final GoRouter router = GoRouter(
    initialLocation: AppRoutes.workOrders,
    // Re-run `redirect` on sign-in/out AND whenever the session gate resolves or
    // the must-change-password flag flips.
    refreshListenable: Listenable.merge([
      AuthRefresh(Get.find<AuthService>().authStateChanges),
      AuthRefresh(Get.find<SessionController>().profileResolved.stream),
      AuthRefresh(Get.find<SessionController>().mustChangePassword.stream),
    ]),
    redirect: (context, state) {
      final loggedIn = Get.find<AuthService>().isLoggedIn;
      final session = Get.find<SessionController>();
      final loc = state.matchedLocation;
      final onLogin = loc == AppRoutes.login;
      final onSetPassword = loc == AppRoutes.setPassword;

      if (!loggedIn) return onLogin ? null : AppRoutes.login;

      // Logged in: hold navigation until the first profile load settles, so we
      // route straight to the gate or the app (no flash of app content).
      if (!session.profileResolved.value) return null;

      // First-login gate: a supervisor on a temporary password is pinned here.
      if (session.mustChangePassword.value) {
        return onSetPassword ? null : AppRoutes.setPassword;
      }

      // Authenticated and clear — keep them out of the auth-only routes.
      if (onLogin || onSetPassword || state.uri.path == '/') {
        return AppRoutes.workOrders;
      }
      return null;
    },
    routes: [
      GoRoute(path: AppRoutes.login, builder: (_, _) => const LoginView()),
      GoRoute(
        path: AppRoutes.setPassword,
        builder: (_, _) => const SetPasswordView(),
      ),
      // Full-screen submit form, pushed over the shell. Optional ?workOrderId= locks the WO.
      GoRoute(
        path: AppRoutes.newRequest,
        builder: (_, state) => NewRequestView(
          workOrderId: state.uri.queryParameters['workOrderId'],
        ),
      ),
      // Persistent shell with each section as a state-preserving branch. The
      // custom container cross-fades branches (instead of the default instant
      // IndexedStack swap) while keeping every branch alive.
      StatefulShellRoute(
        builder: (context, state, navigationShell) =>
            HomeShell(navigationShell: navigationShell),
        navigatorContainerBuilder: (context, navigationShell, children) =>
            FadeThroughBranchContainer(
              currentIndex: navigationShell.currentIndex,
              children: children,
            ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.workOrders,
                pageBuilder: (_, _) =>
                    const NoTransitionPage(child: WorkOrdersView()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.requests,
                pageBuilder: (_, _) =>
                    const NoTransitionPage(child: RequestsView()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.account,
                pageBuilder: (_, _) =>
                    const NoTransitionPage(child: AccountView()),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
