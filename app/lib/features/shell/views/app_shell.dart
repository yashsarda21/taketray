import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taketray/features/reels/views/reel_choosing_dock.dart';
import 'package:taketray/features/shell/view_models/choosing_reel.dart';
import 'package:taketray/features/tagging/view_models/pending_clips.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray_ui/taketray_ui.dart';

/// The tab scaffold: the current tab's navigator behind the floating nav pill.
///
/// The To tag tab's badge is the number of pending clips, from the same
/// read-only [pendingClipsProvider] as the Shooting mode card's strip, so the
/// two always agree (D-76, D-184). While it loads or after an error there is
/// no badge.
///
/// While a reel's page is choosing clips ([choosingReelProvider]) and the
/// Reels tab is the one shown, its dock ([ReelChoosingDock]) takes the nav
/// pill's place, badge and all (D-191): one bar at the bottom at a time, and
/// the floating snacks sit above whichever it is. On another tab the pill
/// stays.
class AppShell extends ConsumerWidget {
  const new({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final index = navigationShell.currentIndex;
    final toTagCount = ref.watch(pendingClipsProvider).value?.length ?? 0;
    // The reel page that is choosing, when it is in the tab on screen. It is
    // watched at index 0 only: the dock replaces the pill on the Reels tab
    // alone. A tab change rebuilds the shell (the index is read above), so
    // the watch is taken up or dropped with it; on another tab a choosing
    // page changes nothing here and costs no rebuild.
    final choosing = index == 0 ? ref.watch(choosingReelProvider) : null;
    // The device's bottom inset. The Scaffold below adds the pill's height to
    // the body's padding (extendBody); the tabs reserve that room themselves
    // with TtNavPill.reservedHeight, so the body gets the plain inset back.
    // The dock's room is left in: the choosing page pads its last row by it.
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
          // Always this MediaQuery, so the tabs keep their state when the
          // dock comes and goes.
          builder: (context) => MediaQuery(
            data: choosing != null
                ? MediaQuery.of(context)
                : MediaQuery.of(context).copyWith(
                    padding: MediaQuery.paddingOf(context)
                        .copyWith(bottom: safePadding.bottom),
                  ),
            child: navigationShell,
          ),
        ),
        bottomNavigationBar: choosing != null
            ? ReelChoosingDock(key: ValueKey<int>(choosing), reelId: choosing)
            : TtNavPill(
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
                  TtNavItem(
                    icon: Symbols.settings_rounded,
                    label: l10n.navSettings,
                  ),
                ],
              ),
      ),
    );
  }
}
