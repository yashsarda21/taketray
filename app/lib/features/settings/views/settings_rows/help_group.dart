import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:taketray/features/reels/views/open_once.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray/router/routes.dart';
import 'package:taketray_ui/taketray_ui.dart';

/// The Help group: "Notifications not arriving?" (opens the help screen,
/// `Routes.notificationsHelp`, D-107) and "Send error log".
///
/// "Send error log" shows its title and subtitle; its action is Phase 10B's
/// Task 8, and the tap does nothing until then.
class HelpGroup extends StatefulWidget {
  const new({super.key});

  @override
  State<HelpGroup> createState() => _HelpGroupState();
}

class _HelpGroupState extends State<HelpGroup> {
  /// Opens the help page once however fast the taps.
  final OpenOnce _help = OpenOnce();

  @override
  void dispose() {
    _help.dispose();
    super.dispose();
  }

  /// Task 8 sends the error log from here.
  void _sendErrorLog() {}

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
            TtListRow(
              leading: const TtRowIcon(
                icon: Symbols.bug_report_rounded,
                boxed: false,
              ),
              title: l10n.settingsErrorLogTitle,
              subtitle: l10n.settingsErrorLogSubtitle,
              onTap: _sendErrorLog,
            ),
          ],
        ),
      ],
    );
  }
}
