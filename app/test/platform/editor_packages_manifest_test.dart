import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/domain/models/editor_app.dart';
import 'package:taketray/features/references/view_models/source_icons.dart';

/// Android 11+ hides other apps unless the manifest names them in
/// `<queries>`: an editor missing from it always reads as "not installed"
/// (D-121). The package names live in Dart ([EditorAppFacts.packageName]), so
/// this test reads the source manifest and checks them there. The source
/// apps of the reference links (D-155) are named too, to show their own icon.
void main() {
  test('the queries name every editor and source app package, only', () {
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
      [
        for (final app in EditorApp.values) app.packageName,
        for (final names in sourceAppPackages.values) ...names,
      ]..sort(),
    );
  });
}
