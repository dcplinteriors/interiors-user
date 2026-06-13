import 'package:dcpl_shared/dcpl_shared.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n.dart';

/// App shell over the two branches (Projects, Requests). The branches keep their
/// state (StatefulShellRoute); the adaptive nav drives it via `currentIndex` /
/// `goBranch` — a rail on tablet/desktop, a bottom bar on phones (the supervisor's
/// primary device). See [AdaptiveNavScaffold].
class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = Get.find<AuthService>();

    return AdaptiveNavScaffold(
      title: l10n.appTitle,
      actions: [
        PopupMenuButton<String>(
          tooltip: auth.currentUser?.email ?? '',
          icon: const Icon(Icons.account_circle_outlined),
          onSelected: (value) {
            if (value == 'signOut') auth.signOut();
          },
          itemBuilder: (context) => [
            if (auth.currentUser?.email != null)
              PopupMenuItem<String>(
                enabled: false,
                child: Text(auth.currentUser!.email!),
              ),
            PopupMenuItem<String>(
              value: 'signOut',
              child: Row(
                children: [
                  const Icon(Icons.logout, size: 20),
                  const SizedBox(width: 12),
                  Text(l10n.signOut),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(width: 8),
      ],
      selectedIndex: navigationShell.currentIndex,
      onDestinationSelected: (i) => navigationShell.goBranch(
        i,
        initialLocation: i == navigationShell.currentIndex,
      ),
      destinations: [
        AdaptiveDestination(
          icon: Icons.folder_outlined,
          selectedIcon: Icons.folder,
          label: l10n.navProjects,
        ),
        AdaptiveDestination(
          icon: Icons.inventory_2_outlined,
          selectedIcon: Icons.inventory_2,
          label: l10n.navRequests,
        ),
      ],
      body: navigationShell,
    );
  }
}
