import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/domain/models/editor_app.dart';
import 'package:taketray/features/editors/views/editor_text.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';

/// The text and the weight of each span of [span].
List<(String, int?)> parts(InlineSpan span) {
  final out = <(String, int?)>[];
  span.visitChildren((child) {
    if (child is TextSpan && (child.text ?? '').isNotEmpty) {
      out.add((child.text!, child.style?.fontWeight?.value));
    }
    return true;
  });
  return out;
}

void main() {
  testWidgets('the short editor names (R8): Edits, CapCut, VN', (tester) async {
    late AppLocalizations l10n;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            l10n = AppLocalizations.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(
      [for (final e in EditorApp.values) editorShortName(l10n, e)],
      ['CapCut', 'Edits', 'VN'],
    );
    expect(editorName(l10n, EditorApp.edits), 'Instagram Edits');
  });

  group('boldMark and boldSpans', () {
    test('a marked part is bold, the rest is plain', () {
      final text =
          'In VN, tap ${boldMark('New project')} and open '
          'the ${boldMark('Goa')} folder.';

      expect(parts(boldSpans(text)), [
        ('In VN, tap ', null),
        ('New project', 700),
        (' and open the ', null),
        ('Goa', 700),
        (' folder.', null),
      ]);
    });

    test('text with no mark is one plain span', () {
      expect(parts(boldSpans('Nothing bold here')), [
        ('Nothing bold here', null),
      ]);
    });

    test('a mark at the very start or the very end', () {
      expect(parts(boldSpans('${boldMark('A')} then B')), [
        ('A', 700),
        (' then B', null),
      ]);
      expect(parts(boldSpans('A then ${boldMark('B')}')), [
        ('A then ', null),
        ('B', 700),
      ]);
    });

    test('an empty marked part leaves no span, an empty text none at all', () {
      expect(parts(boldSpans('a${boldMark('')}b')), [('a', null), ('b', null)]);
      expect(parts(boldSpans('')), isEmpty);
    });

    test('a mark that is never closed is bold to the end', () {
      expect(parts(boldSpans('plain \u0001bold to the end')), [
        ('plain ', null),
        ('bold to the end', 700),
      ]);
    });

    test('a folder name with punctuation or a number in it is kept whole', () {
      expect(parts(boldSpans('open ${boldMark('Goa (2) · Day 1/2')} now')), [
        ('open ', null),
        ('Goa (2) · Day 1/2', 700),
        (' now', null),
      ]);
    });
  });
}
