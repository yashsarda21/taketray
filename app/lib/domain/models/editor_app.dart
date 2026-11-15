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
