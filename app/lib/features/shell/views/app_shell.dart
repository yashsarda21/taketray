import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';

/// Placeholder tab scaffold; phase 1 swaps the stock bar for the TakeTray nav.
class AppShell extends StatelessWidget {
  const new({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final index = navigationShell.currentIndex;
    return PopScope(
      canPop: index == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          navigationShell.goBranch(0);
        }
      },
      child: Scaffold(
        body: navigationShell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (target) => navigationShell.goBranch(
            target,
            initialLocation: target == index,
          ),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.movie_outlined),
              selectedIcon: const Icon(Icons.movie),
              label: l10n.navReels,
            ),
            NavigationDestination(
              icon: const Icon(Icons.label_outline),
              selectedIcon: const Icon(Icons.label),
              label: l10n.navToTag,
            ),
            NavigationDestination(
              icon: const Icon(Icons.settings_outlined),
              selectedIcon: const Icon(Icons.settings),
              label: l10n.navSettings,
            ),
          ],
        ),
      ),
    );
  }
}
