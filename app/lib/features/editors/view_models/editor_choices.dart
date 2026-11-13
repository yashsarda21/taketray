import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/data/editors/edit_session_service.dart';
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
