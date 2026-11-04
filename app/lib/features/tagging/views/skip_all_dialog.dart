import 'package:flutter/widgets.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray_ui/taketray_ui.dart';

/// Asks "Skip all {n} clips?" before every waiting clip moves to Skipped
/// (`screens.js`: `dialogs.skipAll`, D-98): "They move to Skipped, and you can
/// restore them any time.", the green "Your videos stay in your gallery.",
/// **Cancel** and **Skip all**.
///
/// Returns true only for **Skip all**; **Cancel**, a tap outside and Back
/// return false or null, and nothing changes. Skip all is a plain button, not a
/// red one: nothing is deleted, and Undo follows.
Future<bool?> showSkipAllDialog(BuildContext context, {required int count}) {
  final l10n = AppLocalizations.of(context);
  return showTtDialog<bool>(
    context,
    title: l10n.skipAllTitle(count),
    body: l10n.skipAllBody,
    content: TtDialogNote(text: l10n.skipAllSafe),
    actions: [
      TtDialogAction(false, l10n.cancel),
      TtDialogAction(true, l10n.skipAllConfirm),
    ],
  );
}
