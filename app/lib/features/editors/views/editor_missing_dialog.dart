import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:taketray/domain/models/editor_app.dart';
import 'package:taketray/features/editors/views/editor_text.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray/platform/editors_bridge.dart';
import 'package:taketray_ui/taketray_ui.dart';

// The error type only (D-10).
final Logger _log = Logger('editorMissing');

/// "{editor} isn't installed" (`screens.js`: `dialogs.editorMissing`), shown
/// when a share found no such app (the sheet greys out an editor the phone
/// says it lacks, but the answer can be old).
///
/// **Open Play Store** opens the editor's store page and closes the dialog;
/// when no store opens (or it fails) nothing more is shown. **Choose
/// another**, or a tap outside, only closes it.
Future<void> showEditorMissingDialog(
  BuildContext context,
  EditorApp editor,
) async {
  final l10n = AppLocalizations.of(context);
  final bridge = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(editorsBridgeProvider);
  final name = editorName(l10n, editor);
  final openStore = await showTtDialog<bool>(
    context,
    title: l10n.editorMissingTitle(name),
    body: l10n.editorMissingBody(name),
    actions: [
      TtDialogAction(false, l10n.editorMissingChoose),
      TtDialogAction(true, l10n.editorMissingStore),
    ],
  );
  if (openStore != true) return;
  try {
    await bridge.openStoreListing(editor.packageName);
  } on Object catch (error) {
    _log.warning('Opening the store page failed: ${error.runtimeType}');
  }
}
