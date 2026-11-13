import 'package:taketray/domain/models/editor_app.dart';
import 'package:taketray/domain/rules/byte_size.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';

/// [editor]'s name as the editor sheet, the snacks and the dialogs say it
/// (R8): "CapCut", "Instagram Edits", "VN".
String editorName(AppLocalizations l10n, EditorApp editor) => switch (editor) {
  EditorApp.capcut => l10n.editorNameCapcut,
  EditorApp.edits => l10n.editorNameEdits,
  EditorApp.vn => l10n.editorNameVn,
};

/// [bytes] as decimal MB or GB, such as "900 MB" or "1.2 GB" (D-119).
String byteSizeText(AppLocalizations l10n, int bytes) {
  final size = byteSize(bytes);
  return switch (size.unit) {
    ByteUnit.mb => l10n.sizeMegabytes(size.number),
    ByteUnit.gb => l10n.sizeGigabytes(size.number),
  };
}
