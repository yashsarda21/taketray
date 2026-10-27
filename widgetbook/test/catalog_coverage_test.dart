import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:taketray_widgetbook/catalog.dart';
import 'package:widgetbook/widgetbook.dart';

/// Every widget in `packages/taketray_ui/lib/src/components/<name>.dart` needs
/// a catalogue file `widgetbook/lib/components/<name>.dart` that
/// `lib/catalog.dart` imports and registers in `ttCatalog` under the name of a
/// class from that package file (D-42). Passes while the package folder is
/// missing or empty. Run from `widgetbook/`, as `flutter test` does.
void main() {
  final packageComponents = Directory(
    '../packages/taketray_ui/lib/src/components',
  );
  final names = <String>{
    if (packageComponents.existsSync())
      for (final entity in packageComponents.listSync())
        if (entity is File && entity.path.endsWith('.dart'))
          entity.uri.pathSegments.last,
  }.toList()..sort();

  test('every package component has a catalogue file that is imported', () {
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
          'Add a catalogue file for each component and import it in '
          'lib/catalog.dart.',
    );
  });

  test('every package component file is registered in ttCatalog', () {
    final registered = _registeredNames(ttCatalog);
    expect(registered, isNotEmpty);
    final classesByFile = {
      for (final name in names)
        name: _publicClasses(
          File('${packageComponents.path}/$name').readAsStringSync(),
        ),
    };

    expect(
      _unregisteredFiles(classesByFile, registered),
      isEmpty,
      reason:
          'None of the classes in these package files is the name of a '
          'WidgetbookComponent in ttCatalog. Add a component named after one '
          "of its classes to the file's catalogue entry.",
    );
  });

  test('the registration check fails for a file with no registered class', () {
    final registered = {'TtButton'};
    expect(
      _unregisteredFiles({
        'buttons.dart': ['TtButton', 'TtFab'],
        'banners.dart': ['TtBanner'],
        'empty.dart': [],
      }, registered),
      ['banners.dart', 'empty.dart'],
    );
  });
}

/// Names of the files in [classesByFile] none of whose classes is in
/// [registered].
List<String> _unregisteredFiles(
  Map<String, List<String>> classesByFile,
  Set<String> registered,
) => [
  for (final MapEntry(:key, :value) in classesByFile.entries)
    if (!value.any(registered.contains)) key,
];

/// The `WidgetbookComponent` names under [nodes] at any depth. A name may list
/// several classes, like `TtCheckMark / TtRadioMark`.
Set<String> _registeredNames(List<WidgetbookNode> nodes) => {
  for (final node in nodes)
    ...switch (node) {
      WidgetbookFolder(:final children) => _registeredNames(
        children ?? const [],
      ),
      WidgetbookComponent(:final name) => [
        for (final part in name.split('/')) part.trim(),
      ],
      _ => const <String>[],
    },
};

/// The public `Tt...` classes declared in [source] (generics stripped).
List<String> _publicClasses(String source) => [
  for (final match in RegExp(
    r'^(?:(?:final|abstract|base|sealed)\s+)*class\s+(Tt\w+)',
    multiLine: true,
  ).allMatches(source))
    match.group(1)!,
];

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
