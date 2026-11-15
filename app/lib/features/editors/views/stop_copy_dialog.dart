import 'package:flutter/widgets.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray_ui/taketray_ui.dart';

/// "Stop copying?" (`screens.js`: `dialogs.stopCopy`): asks whether to stop a
/// copy and delete the [copies] made so far. Returns true for **Stop**, false
/// for **Keep copying**, and false when the dialog is dismissed (a tap
/// outside, the system back), so a stray tap never stops a copy.
Future<bool> showStopCopyDialog(
  BuildContext context, {
  required int copies,
}) async {
  final l10n = AppLocalizations.of(context);
  final stop = await showTtDialog<bool>(
    context,
    title: l10n.copyStopTitle,
    body: l10n.copyStopBody(copies),
    actions: [
      TtDialogAction(false, l10n.copyKeepCopying),
      TtDialogAction(true, l10n.copyStop, destructive: true),
    ],
  );
  return stop ?? false;
}
