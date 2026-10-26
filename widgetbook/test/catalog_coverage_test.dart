import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every widget in `packages/taketray_ui/lib/src/components/<name>.dart` needs
/// a catalogue file `widgetbook/lib/components/<name>.dart` that
/// `lib/catalog.dart` imports (D-42). Passes while the package folder is
/// missing or empty. Run from `widgetbook/`, as `flutter test` does.
void main() {
  test('every package component has a registered catalogue file', () {
    final packageComponents = Directory(
      '../packages/taketray_ui/lib/src/components',
    );
    final names = <String>{
      if (packageComponents.existsSync())
        for (final entity in packageComponents.listSync())
          if (entity is File && entity.path.endsWith('.dart'))
            entity.uri.pathSegments.last,
    }.toList()..sort();

    final catalog = File('lib/catalog.dart').readAsStringSync();
    final problems = <String>[];
    for (final name in names) {
      if (!File('lib/components/$name').existsSync()) {
        problems.add('missing file: widgetbook/lib/components/$name');
      }
      if (!_imports(catalog, name)) {
        problems.add('not imported by lib/catalog.dart: components/$name');
      }
    }

    expect(
      problems,
      isEmpty,
      reason:
          'Add a catalogue file for each component and register it in '
          'lib/catalog.dart.',
    );
  });
}

/// Whether [source] has an import of `components/<name>`, relative or via
/// `package:taketray_widgetbook/`.
bool _imports(String source, String name) {
  final escaped = RegExp.escape(name);
  return RegExp(
    '^import\\s+[\'"](?:package:taketray_widgetbook/|\\./)?'
    'components/$escaped[\'"]',
    multiLine: true,
  ).hasMatch(source);
}
