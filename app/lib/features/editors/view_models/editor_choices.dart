import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/data/editors/edit_session_service.dart';
import 'package:taketray/data/repositories/phone_state_repository.dart';
import 'package:taketray/domain/models/editor_app.dart';

part 'editor_choices.g.dart';

// The error type only (D-10).
final Logger _log = Logger('editorChoices');

/// The editors for the editor sheet, in [EditorApp] order, installed or not
/// (`EditSessionService.editorChoices`).
///
/// When asking the phone fails, all three are shown as installed and with no
/// icon, so the sheet is never stuck: a tap on one that is missing ends in
/// the share's own "not installed" answer. Refresh it with `ref.invalidate`
/// (after such an answer). Auto-disposes with the sheet.
@riverpod
Future<List<EditorChoice>> editorChoices(Ref ref) async {
  final service = ref.watch(editSessionServiceProvider);
  try {
    return await service.editorChoices();
  } on Object catch (error) {
    _log.warning(
      'Asking the phone for the editors failed: ${error.runtimeType}',
    );
    return [
      for (final editor in EditorApp.values)
        EditorChoice(editor: editor, installed: true),
    ];
  }
}

/// The row of the editor sheet used last on this phone (`lastEditor`, D-189),
/// or null when none was, or when it cannot be read: a failed read is logged
/// by the error's type and the sheet shows its default order. The sheet is
/// opened only after this is read (`showEditorSheet`), so its first frame has
/// the order; the provider auto-disposes, so each opening reads it again.
@riverpod
Future<EditorPick?> lastEditor(Ref ref) async {
  final phone = ref.watch(phoneStateRepositoryProvider);
  try {
    return await phone.lastEditor();
  } on Object catch (error) {
    _log.warning('Reading the last editor failed: ${error.runtimeType}');
    return null;
  }
}

/// The rows of the editor sheet, top to bottom, and the one that gets the
/// "Last used" pill.
typedef EditorRows = ({List<EditorPick> rows, EditorPick? lastUsed});

/// The sheet's rows: [last] first when it is `other` or an editor that is
/// installed, then the rest in the default order, CapCut, Instagram Edits,
/// VN, Other app…. `lastUsed` is [last] then, and null when [last]
/// is none or lost its place (its editor is not installed any more), so the
/// order and the pill follow each other.
EditorRows editorRows(EditorPick? last, List<EditorChoice> choices) {
  const defaults = EditorPick.values;
  final installed =
      last != null &&
      (last == EditorPick.other ||
          choices.any((c) => c.editor == last.app && c.installed));
  if (!installed) return (rows: defaults, lastUsed: null);
  return (
    rows: [last, ...defaults.where((pick) => pick != last)],
    lastUsed: last,
  );
}
