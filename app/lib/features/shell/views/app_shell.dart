import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray_ui/taketray_ui.dart';

/// The number of clips waiting to be tagged, for the badge on the To tag tab.
/// A constant 0 (no badge) until the tagging feature supplies it in phase 5.
int _clipsToTag() => 0;

/// The tab scaffold: the current tab's navigator behind the floating nav pill.
class AppShell extends StatelessWidget {
  const new({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final index = navigationShell.currentIndex;
    final toTagCount = _clipsToTag();
    // The device's bottom inset. The Scaffold below adds the pill's height to
    // the body's padding (extendBody); the tabs reserve that room themselves
    // with TtNavPill.reservedHeight, so the body gets the plain inset back.
    final safePadding = MediaQuery.paddingOf(context);
    return PopScope(
      canPop: index == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          navigationShell.goBranch(0);
        }
      },
      child: Scaffold(
        extendBody: true,
        body: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: MediaQuery.paddingOf(context)
                  .copyWith(bottom: safePadding.bottom),
            ),
            child: navigationShell,
          ),
        ),
        bottomNavigationBar: TtNavPill(
          currentIndex: index,
          onSelected: (target) => navigationShell.goBranch(
            target,
            initialLocation: target == index,
          ),
          items: [
            TtNavItem(
              icon: Symbols.video_library_rounded,
              label: l10n.navReels,
            ),
            TtNavItem(
              icon: Symbols.sell_rounded,
              label: l10n.navToTag,
              badgeCount: toTagCount,
              badgeSemanticLabel: l10n.toTagBadgeSemantics(toTagCount),
            ),
            TtNavItem(icon: Symbols.settings_rounded, label: l10n.navSettings),
          ],
        ),
      ),
    );
  }
}
