import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taketray/domain/rules/phone_brand.dart';
import 'package:taketray/features/notifications/view_models/notifications_help.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray/router/routes.dart';
import 'package:taketray_ui/taketray_ui.dart';

/// The help screen "Notifications not arriving?" (D-107; `Routes
/// .notificationsHelp`, from the Help row in Settings; `screens.js`:
/// `routes['notif-help']`): for phones that stop apps in the background.
///
/// From the top: an app bar with **Back**; the intro; "Your clips are never
/// lost" (a success callout); one expandable card per brand, in the
/// prototype's order (Samsung; Xiaomi, Redmi, POCO; Oppo, Realme; Vivo, iQOO;
/// OnePlus); and a note that menu names differ.
///
/// - **The user's brand is open** and carries the badge "Your phone", once the
///   phone's maker is known (`phoneBrand`). A maker with no steps opens no
///   card, and nothing says "Your phone". A card the user opened before the
///   maker arrived stays; the maker then only adds the badge.
/// - **One card is open at a time:** opening one closes the other; a tap on
///   the open card closes it.
/// - A card's body is its numbered steps and a tonal button: **Open battery
///   settings** (Samsung, Vivo) or **Open app info** (the others). When the
///   settings page cannot be opened: "Couldn't open settings on this phone."
class NotificationsHelpScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<NotificationsHelpScreen> createState() =>
      _NotificationsHelpScreenState();
}

class _NotificationsHelpScreenState
    extends ConsumerState<NotificationsHelpScreen> {
  /// The card the user chose, once they have chosen (null: they closed it).
  PhoneBrand? _chosen;
  bool _touched = false;

  /// Opens the settings page of [brand]'s card, and says so if it cannot.
  Future<void> _openSettings(PhoneBrand brand) async {
    final l10n = AppLocalizations.of(context);
    final opened = await ref.read(notificationsHelpActionsProvider).open(brand);
    if (opened || !mounted) return;
    showTtSnack(context, message: l10n.notificationsHelpOpenFailed);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tt = context.tt;
    final scheme = context.scheme;
    final text = tt.text.material;
    final mine = ref.watch(phoneBrandProvider).value;
    final open = _touched ? _chosen : mine;
    // The bar is the first child of the body, not the Scaffold's `appBar`:
    // that slot has a fixed height, and this title wraps at large text and
    // grows the bar (`wrapTitle`, as in the date range picker).
    final bar = TtAppBar(
      title: l10n.notificationsHelpTitle,
      // The title is the question: read in full at large text.
      wrapTitle: true,
      leading: TtIconButton(
        icon: Symbols.arrow_back_rounded,
        semanticLabel: l10n.navBack,
        style: TtIconButtonStyle.circle,
        onPressed: () =>
            context.canPop() ? context.pop() : context.go(Routes.settings),
      ),
    );
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          bar,
          Expanded(
            child: ListView(
              padding: EdgeInsets.only(bottom: tt.spacing.xl),
              children: [
                // proto.css: p.t-bm.v { margin: 0 16px 12px }
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    tt.spacing.gutter,
                    tt.spacing.none,
                    tt.spacing.gutter,
                    tt.spacing.s,
                  ),
                  child: Text(
                    l10n.notificationsHelpIntro,
                    style: text.bodyMedium!.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    tt.spacing.gutter,
                    tt.spacing.none,
                    tt.spacing.gutter,
                    tt.spacing.m,
                  ),
                  child: TtCallout(
                    success: true,
                    icon: Symbols.verified_rounded,
                    title: l10n.notificationsHelpSafeTitle,
                    body: l10n.notificationsHelpSafeBody,
                  ),
                ),
                for (final brand in PhoneBrand.values)
                  // proto.css: .acc { margin: 0 16px 8px }
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      tt.spacing.gutter,
                      tt.spacing.none,
                      tt.spacing.gutter,
                      tt.spacing.xs,
                    ),
                    child: TtExpandCard(
                      key: ValueKey(brand),
                      title: _title(l10n, brand),
                      badge: brand == mine
                          ? l10n.notificationsHelpYourPhone
                          : null,
                      expanded: brand == open,
                      onToggle: () => setState(() {
                        _chosen = brand == open ? null : brand;
                        _touched = true;
                      }),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TtStepList(_steps(l10n, brand)),
                          // proto.css: .acc .ab ol { margin: 0 0 12px }
                          SizedBox(height: tt.spacing.s),
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: TtButton(
                              label: brand.opensBatterySettings
                                  ? l10n.notificationsHelpOpenBattery
                                  : l10n.notificationsHelpOpenAppInfo,
                              icon: Symbols.open_in_new_rounded,
                              kind: TtButtonKind.tonal,
                              onPressed: () => _openSettings(brand),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // proto.css: p.t-bs.v { margin: 8px 16px 24px }
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    tt.spacing.gutter,
                    tt.spacing.xs,
                    tt.spacing.gutter,
                    tt.spacing.none,
                  ),
                  child: Text(
                    l10n.notificationsHelpFooter,
                    style: text.bodySmall!.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _title(AppLocalizations l10n, PhoneBrand brand) => switch (brand) {
  PhoneBrand.samsung => l10n.notificationsHelpBrandSamsung,
  PhoneBrand.xiaomi => l10n.notificationsHelpBrandXiaomi,
  PhoneBrand.oppo => l10n.notificationsHelpBrandOppo,
  PhoneBrand.vivo => l10n.notificationsHelpBrandVivo,
  PhoneBrand.oneplus => l10n.notificationsHelpBrandOneplus,
};

List<String> _steps(AppLocalizations l10n, PhoneBrand brand) => switch (brand) {
  PhoneBrand.samsung => [
    l10n.notificationsHelpSamsungStep1,
    l10n.notificationsHelpSamsungStep2,
    l10n.notificationsHelpSamsungStep3,
  ],
  PhoneBrand.xiaomi => [
    l10n.notificationsHelpXiaomiStep1,
    l10n.notificationsHelpXiaomiStep2,
    l10n.notificationsHelpXiaomiStep3,
  ],
  PhoneBrand.oppo => [
    l10n.notificationsHelpOppoStep1,
    l10n.notificationsHelpOppoStep2,
    l10n.notificationsHelpOppoStep3,
  ],
  PhoneBrand.vivo => [
    l10n.notificationsHelpVivoStep1,
    l10n.notificationsHelpVivoStep2,
  ],
  PhoneBrand.oneplus => [
    l10n.notificationsHelpOneplusStep1,
    l10n.notificationsHelpOneplusStep2,
  ],
};
