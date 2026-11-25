/// A video editor TakeTray can hand a reel to (D-119).
///
/// Stored in the database by [name] (`capcut`, `edits`, `vn`): renaming a
/// value would orphan the rows of every editing session (D-120), so a test
/// pins the spelling.
enum EditorApp { capcut, edits, vn }

/// What TakeTray knows about each editor.
extension EditorAppFacts on EditorApp {
  /// The Android package name, used to find out whether the editor is
  /// installed (it is also listed in the manifest's `<queries>`).
  String get packageName => switch (this) {
    EditorApp.capcut => 'com.lemon.lvoverseas',
    EditorApp.edits => 'com.instagram.basel',
    EditorApp.vn => 'com.frontrow.vlog',
  };

  /// Whether the editor accepts several clips in one share. VN does not
  /// (the owner tested it), so it gets copies in a folder instead (D-118).
  bool get takesShares => this != EditorApp.vn;
}

/// A row of the editor sheet, stored by [name] in `lastEditor` (D-189):
/// the three editors, and **Other app…**, which counts as an editor too.
///
/// A test pins the spelling: a rename would make every phone forget which
/// editor it used last.
enum EditorPick { capcut, edits, vn, other }

/// The editor behind a row of the sheet.
extension EditorPickApp on EditorPick {
  /// The editor, or null for **Other app…**.
  EditorApp? get app => switch (this) {
    EditorPick.capcut => EditorApp.capcut,
    EditorPick.edits => EditorApp.edits,
    EditorPick.vn => EditorApp.vn,
    EditorPick.other => null,
  };
}

/// The row of the sheet for [app]; null (**Other app…**) is
/// [EditorPick.other].
EditorPick editorPickOf(EditorApp? app) => switch (app) {
  EditorApp.capcut => EditorPick.capcut,
  EditorApp.edits => EditorPick.edits,
  EditorApp.vn => EditorPick.vn,
  null => EditorPick.other,
};
