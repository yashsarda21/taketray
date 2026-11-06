import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taketray/features/notifications/view_models/notification_access_controller.dart';
import 'package:taketray/features/reels/views/open_once.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray/router/routes.dart';
import 'package:taketray_ui/taketray_ui.dart';

/// Settings, the third tab (`screens.js`: `routes.settings`). Until Phase 10
/// builds the rest around them, it holds two groups (D-107):
///
/// - **Help:** "Notifications not arriving?" with a chevron, which opens the
///   help screen (`Routes.notificationsHelp`);
/// - **Permissions:** "Notifications", "Allowed" with a check, or "Not
///   allowed" with a tonal **Allow** button. **Allow** asks when Android will
///   show its dialog and opens the phone's notification settings otherwise
///   (`NotificationAccessController.allow`); if that page cannot be opened,
///   "Couldn't open settings on this phone." The row follows the state, which
///   is read again on every resume, so it is right after the user comes back
///   from the phone's settings. While the first read is running the group is
///   left out. If it failed, the row says "Not allowed" with **Allow**: the
///   permission is unknown, and the button reads it again (and opens the
///   phone's notification settings if it still cannot be read).
class SettingsScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  /// Opens the help page once however fast the taps.
  final OpenOnce _help = OpenOnce();

  @override
  void dispose() {
    _help.dispose();
    super.dispose();
  }

  Future<void> _allow() async {
    final l10n = AppLocalizations.of(context);
    final worked = await ref
        .read(notificationAccessControllerProvider.notifier)
        .allow();
    if (worked || !mounted) return;
    showTtSnack(context, message: l10n.notificationsHelpOpenFailed);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final access = ref.watch(notificationAccessControllerProvider);
    // Running the first read: unknown, nothing to show yet. A failed first
    // read is shown as not allowed, so the user can still reach Allow.
    final granted = access.value?.granted ?? false;
    final showPermissions = access.hasValue || access.hasError;
    return Scaffold(
      appBar: TtAppBar(large: true, title: l10n.navSettings),
      body: ListView(
        padding: EdgeInsets.only(bottom: TtNavPill.reservedHeight(context)),
        children: [
          TtGroupLabel(l10n.settingsGroupHelp),
          TtGroupedRows(
            children: [
              TtListRow(
                leading: const TtRowIcon(
                  icon: Symbols.notifications_off_rounded,
                  boxed: false,
                ),
                title: l10n.notificationsHelpTitle,
                subtitle: l10n.notificationsHelpRowSubtitle,
                trailing: const Icon(Symbols.chevron_right_rounded),
                onTap: () => _help.open(
                  () => context.push<void>(Routes.notificationsHelp),
                ),
              ),
            ],
          ),
          if (showPermissions) ...[
            TtGroupLabel(l10n.settingsGroupPermissions),
            TtGroupedRows(
              children: [_notificationsRow(l10n, granted: granted)],
            ),
          ],
        ],
      ),
    );
  }

  Widget _notificationsRow(AppLocalizations l10n, {required bool granted}) {
    return TtListRow(
      leading: const TtRowIcon(
        icon: Symbols.notifications_rounded,
        boxed: false,
      ),
      title: l10n.settingsNotificationsTitle,
      subtitle: granted
          ? l10n.settingsNotificationsAllowed
          : l10n.settingsNotificationsNotAllowed,
      stackTrailingAtLargeText: true,
      trailing: granted
          ? Icon(
              Symbols.check_circle_rounded,
              fill: 1,
              color: context.scheme.primary,
            )
          : TtButton(
              label: l10n.settingsNotificationsAllow,
              semanticLabel: l10n.settingsNotificationsAllowSemantics,
              kind: TtButtonKind.tonal,
              size: TtButtonSize.small,
              onPressed: _allow,
            ),
    );
  }
}
