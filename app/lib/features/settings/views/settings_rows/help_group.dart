import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taketray/features/reels/views/open_once.dart';
import 'package:taketray/features/settings/view_models/send_log.dart';
import 'package:taketray/features/shell/views/root_messenger.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray/router/routes.dart';
import 'package:taketray_ui/taketray_ui.dart';

/// The Help group: "Notifications not arriving?" (opens the help screen,
/// `Routes.notificationsHelp`, D-107) and "Send error log".
///
/// "Send error log" joins the log files and opens Android's share sheet on
/// them (`SendLog`, D-151). With no log yet it says "Nothing to send yet"; if
/// the share sheet cannot open, "Couldn't open the share menu on this
/// phone." Cancelling the sheet says nothing. A second tap while the first is
/// being prepared, or just after, does nothing.
class HelpGroup extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<HelpGroup> createState() => _HelpGroupState();
}

class _HelpGroupState extends ConsumerState<HelpGroup> {
  /// Opens the help page once however fast the taps.
  final OpenOnce _help = OpenOnce();

  /// Sends the log once however fast the taps.
  final OpenOnce _log = OpenOnce();

  @override
  void dispose() {
    _help.dispose();
    _log.dispose();
    super.dispose();
  }

  void _sendErrorLog() {
    final l10n = AppLocalizations.of(context);
    final messenger = rootMessengerOf(context);
    final send = ref.read(sendLogProvider);
    _log.openSlow((pushing) async {
      final outcome = await send.send();
      pushing();
      switch (outcome) {
        case SendLogOutcome.shared:
          break;
        case SendLogOutcome.nothing:
          showTtSnackOn(messenger, message: l10n.settingsErrorLogNothing);
        case SendLogOutcome.failed:
          showTtSnackOn(messenger, message: l10n.settingsErrorLogFailed);
      }
    });
  }

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
