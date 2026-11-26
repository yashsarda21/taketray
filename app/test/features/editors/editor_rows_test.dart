import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/data/editors/edit_session_service.dart';
import 'package:taketray/domain/models/editor_app.dart';
import 'package:taketray/features/editors/view_models/editor_choices.dart';

/// The three editors, each installed unless [missing] has it.
List<EditorChoice> _choices({Set<EditorApp> missing = const {}}) => [
  for (final e in EditorApp.values)
    EditorChoice(editor: e, installed: !missing.contains(e)),
];

void main() {
  const normal = [
    EditorPick.capcut,
    EditorPick.edits,
    EditorPick.vn,
    EditorPick.other,
  ];

  test('no last editor: capcut, edits, vn, other; no lastUsed', () {
    final rows = editorRows(null, _choices());

    expect(rows.rows, normal);
    expect(rows.lastUsed, isNull);
  });

  test('no last editor, an editor missing: the order does not change', () {
    final rows = editorRows(null, _choices(missing: {EditorApp.capcut}));

    expect(rows.rows, normal);
    expect(rows.lastUsed, isNull);
  });

  test('last used edits: edits first, the rest in order', () {
    final rows = editorRows(EditorPick.edits, _choices());

    expect(rows.rows, [
      EditorPick.edits,
      EditorPick.capcut,
      EditorPick.vn,
      EditorPick.other,
    ]);
    expect(rows.lastUsed, EditorPick.edits);
  });

  test('last used capcut: it stays first, with the pill', () {
    final rows = editorRows(EditorPick.capcut, _choices());

    expect(rows.rows, normal);
    expect(rows.lastUsed, EditorPick.capcut);
  });

  test('last used other: other first', () {
    final rows = editorRows(EditorPick.other, _choices());

    expect(rows.rows, [
      EditorPick.other,
      EditorPick.capcut,
      EditorPick.edits,
      EditorPick.vn,
    ]);
    expect(rows.lastUsed, EditorPick.other);
  });

  test('last used other still leads while every editor is missing', () {
    final rows = editorRows(
      EditorPick.other,
      _choices(missing: {...EditorApp.values}),
    );

    expect(rows.rows.first, EditorPick.other);
    expect(rows.lastUsed, EditorPick.other);
  });

  for (final missing in EditorApp.values) {
    test('last used ${missing.name}, now not installed: default order, '
        'no pill', () {
      final rows = editorRows(
        editorPickOf(missing),
        _choices(missing: {missing}),
      );

      expect(rows.rows, normal);
      expect(rows.lastUsed, isNull);
    });
  }

  test('last used VN while asking the phone failed (all installed): vn '
      'first', () {
    // A failed ask is "all installed" (the provider's fallback).
    final rows = editorRows(EditorPick.vn, _choices());

    expect(rows.rows, [
      EditorPick.vn,
      EditorPick.capcut,
      EditorPick.edits,
      EditorPick.other,
    ]);
    expect(rows.lastUsed, EditorPick.vn);
  });

  test('another editor missing does not move the last used one', () {
    final rows = editorRows(
      EditorPick.vn,
      _choices(missing: {EditorApp.capcut}),
    );

    expect(rows.rows.first, EditorPick.vn);
    expect(rows.lastUsed, EditorPick.vn);
    expect(rows.rows, hasLength(4));
    expect(rows.rows.toSet(), normal.toSet());
  });
}
