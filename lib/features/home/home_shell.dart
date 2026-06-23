import 'package:dcpl_shared/dcpl_shared.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n.dart';

/// App shell over the three branches (Work Orders · Requests · Account). The branches keep
/// their state (StatefulShellRoute); the Molten [DcplNavScaffold] drives it — a labeled rail on
/// tablet, a floating bottom bar on phones (the supervisor's primary device).
class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DcplNavScaffold(
      items: [
        DcplNavItem(
          icon: Icons.assignment_outlined,
          selectedIcon: Icons.assignment,
          label: l10n.navWorkOrders,
          section: l10n.navSectionWorkspace,
        ),
        DcplNavItem(
          icon: Icons.inventory_2_outlined,
          selectedIcon: Icons.inventory_2,
          label: l10n.navRequests,
          section: l10n.navSectionWorkspace,
        ),
        DcplNavItem(
          icon: Icons.person_outline,
          selectedIcon: Icons.person,
          label: l10n.navAccount,
          section: l10n.navSectionAccount,
        ),
      ],
      selectedIndex: navigationShell.currentIndex,
      onDestinationSelected: (i) => navigationShell.goBranch(
        i,
        initialLocation: i == navigationShell.currentIndex,
      ),
      railHeader: const Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: BrandWordmark(height: 40),
      ),
      appBarTitle: const BrandWordmark(height: 40),
      body: navigationShell,
    );
  }
}
