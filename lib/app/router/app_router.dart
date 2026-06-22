import 'package:dcpl_shared/dcpl_shared.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

import '../../features/features.dart';
import '../routes/app_routes.dart';
import 'auth_refresh.dart';

class AppRouter {
  AppRouter._();

  static final GoRouter router = GoRouter(
    initialLocation: AppRoutes.workOrders,
    refreshListenable: AuthRefresh(Get.find<AuthService>().authStateChanges),
    redirect: (context, state) {
      final loggedIn = Get.find<AuthService>().isLoggedIn;
      final onLogin = state.matchedLocation == AppRoutes.login;
      if (!loggedIn) return onLogin ? null : AppRoutes.login;
      if (onLogin || state.uri.path == '/') return AppRoutes.workOrders;
      return null;
    },
    routes: [
      GoRoute(path: AppRoutes.login, builder: (_, _) => const LoginView()),
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
