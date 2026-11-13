import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/domain/models/editor_app.dart';

/// Android 11+ hides other apps unless the manifest names them in
/// `<queries>`: an editor missing from it always reads as "not installed"
/// (D-121). The package names live in Dart ([EditorAppFacts.packageName]), so
/// this test reads the source manifest and checks them there.
void main() {
  test('every editor package is in the manifest queries, and nothing else', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    final queries = RegExp(
      '<queries>(.*?)</queries>',
      dotAll: true,
    ).allMatches(manifest).map((m) => m.group(1)!).join();
    final packages = RegExp(r'<package\s+android:name="([^"]+)"\s*/>')
        .allMatches(queries)
        .map((m) => m.group(1)!)
        .toList();

    expect(
      packages..sort(),
      [for (final app in EditorApp.values) app.packageName]..sort(),
    );
  });
}
