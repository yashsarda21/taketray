import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/domain/models/editor_app.dart';

void main() {
  test('the three editors, in this order', () {
    expect(EditorApp.values, [EditorApp.capcut, EditorApp.edits, EditorApp.vn]);
  });

  test('package names are exact', () {
    expect(EditorApp.capcut.packageName, 'com.lemon.lvoverseas');
    expect(EditorApp.edits.packageName, 'com.instagram.basel');
    expect(EditorApp.vn.packageName, 'com.frontrow.vlog');
  });

  test('only VN does not take shares', () {
    expect(EditorApp.capcut.takesShares, isTrue);
    expect(EditorApp.edits.takesShares, isTrue);
    expect(EditorApp.vn.takesShares, isFalse);
  });

  test('the stored names are the database contract', () {
    expect(EditorApp.capcut.name, 'capcut');
    expect(EditorApp.edits.name, 'edits');
    expect(EditorApp.vn.name, 'vn');
  });

  test('EditorPick names are capcut, edits, vn, other', () {
    expect(EditorPick.values, [
      EditorPick.capcut,
      EditorPick.edits,
      EditorPick.vn,
      EditorPick.other,
    ]);
    // `lastEditor` stores the name: a rename would forget every phone's habit.
    expect(
      [for (final p in EditorPick.values) p.name],
      ['capcut', 'edits', 'vn', 'other'],
    );
  });

  test('editorPickOf and app round-trip', () {
    for (final editor in EditorApp.values) {
      expect(editorPickOf(editor).name, editor.name);
      expect(editorPickOf(editor).app, editor);
    }
    expect(editorPickOf(null), EditorPick.other);
    expect(EditorPick.other.app, isNull);
  });
}
