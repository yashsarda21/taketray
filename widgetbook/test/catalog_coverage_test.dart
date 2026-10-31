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
      _unregisteredClasses(classesByFile, registered, _notInCatalogue.keys),
      isEmpty,
      reason:
          'These public classes are not the name of a WidgetbookComponent in '
          'ttCatalog. Add a component named after the class (or `A / B` for '
          'several) to the catalogue entry of its file, or, if it is '
          'deliberately left out, add it to _notInCatalogue with the reason.',
    );
  });

  test('the allow-list holds only classes that exist and are not shown', () {
    final classes = {
      for (final name in names)
        ..._publicClasses(
          File('${packageComponents.path}/$name').readAsStringSync(),
        ),
    };
    final registered = _registeredNames(ttCatalog);
    expect(
      [
        for (final name in _notInCatalogue.keys)
          if (!classes.contains(name) || registered.contains(name)) name,
      ],
      isEmpty,
      reason:
          'Remove these from _notInCatalogue: gone, or now in the catalogue.',
    );
  });

  test('second class in a registered file is caught', () {
    final registered = {'TtButton'};
    expect(
      _unregisteredClasses(
        {
          'buttons.dart': ['TtButton', 'TtFab'],
          'banners.dart': ['TtBanner'],
          'empty.dart': [],
        },
        registered,
        const [],
      ),
      ['buttons.dart: TtFab', 'banners.dart: TtBanner'],
    );
  });

  test('a class on the allow-list is not reported', () {
    expect(
      _unregisteredClasses(
        {
          'buttons.dart': ['TtButton', 'TtFab'],
        },
        {'TtButton'},
        const ['TtFab'],
      ),
      isEmpty,
    );
  });
}

/// Public classes that the catalogue deliberately does not show, and why.
const Map<String, String> _notInCatalogue = {
  'TtClipMark': 'data for TtClipTile.mark; shown in the TtClipTile use cases',
  'TtDateRangeCalendarLabels':
      'words for TtDateRangeCalendar; set in its use cases',
  'TtDateRangeCalendarController':
      'state holder of TtDateRangeCalendar, not a widget',
  'TtDateRangePickerLabels':
      'words for TtDateRangePicker; set in its use cases',
  'TtDialogAction':
      'data for TtDialog.actions; shown in the TtDialog use cases',
  'TtMenuItem': 'data for TtMenuButton.items; shown in its use cases',
  'TtNavItem': 'data for TtNavPill.items; shown in its use cases',
  'TtViewerAction': 'data for TtViewerActions.actions; shown in its use case',
  'TtPillTab': 'data for TtPillTabs.tabs; shown in its use cases',
};

/// The classes in [classesByFile] that are neither in [registered] nor in
/// [allowed], as `file: Class`. Checked per class, so a second widget added to
/// a file whose first widget is registered is still reported.
List<String> _unregisteredClasses(
  Map<String, List<String>> classesByFile,
  Set<String> registered,
  Iterable<String> allowed,
) => [
  for (final MapEntry(:key, :value) in classesByFile.entries)
    for (final name in value)
      if (!registered.contains(name) && !allowed.contains(name)) '$key: $name',
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
