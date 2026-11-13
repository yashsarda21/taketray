import 'package:flutter/widgets.dart';
import 'package:taketray/domain/models/editor_app.dart';
import 'package:taketray/domain/rules/byte_size.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray_ui/taketray_ui.dart';

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

/// Marks [text] to be shown in bold by [boldSpans]: put it around a part of
/// a sentence that is passed to a string as an argument.
String boldMark(String text) => '\u0001$text\u0001';

/// [text] as spans, where the parts made with [boldMark] are bold and the
/// rest follows the parent's style. A mark that is not closed bolds to the
/// end. Anything without a mark is one plain span.
InlineSpan boldSpans(String text) {
  final parts = text.split('\u0001');
  return TextSpan(
    children: [
      for (final (i, part) in parts.indexed)
        if (part.isNotEmpty)
          TextSpan(
            text: part,
            style: i.isOdd ? TtTextStyles.weight(FontWeight.w700) : null,
          ),
    ],
  );
}
