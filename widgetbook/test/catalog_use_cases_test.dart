import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray_widgetbook/catalog.dart';
import 'package:taketray_widgetbook/main.dart';
import 'package:widgetbook/widgetbook.dart';

/// One use case, with where it sits in the navigation tree.
typedef _Entry = ({String folder, WidgetbookComponent component, String name});

/// Every use case in the catalogue, in the order the tree lists them.
List<_Entry> _entries(List<WidgetbookNode> nodes, [String folder = '']) => [
  for (final node in nodes)
    ...switch (node) {
      WidgetbookFolder(:final name, :final children) => _entries(
        children ?? const [],
        name,
      ),
      WidgetbookComponent(:final useCases) => [
        for (final useCase in useCases)
          (folder: folder, component: node, name: useCase.name),
      ],
      _ => const <_Entry>[],
    },
];

/// Scrolls the navigation tree to the row labelled [label], then taps it.
Future<void> _tapInTree(WidgetTester tester, String label) async {
  final row = find.text(label);
  await tester.ensureVisible(row);
  await tester.pump();
  await tester.tap(row);
}

void main() {
  testWidgets('use case tap selects it, and every use case opens without an '
      'error', (tester) async {
    // A desktop-sized window, so the navigation panel is shown. The tree is
    // longer than the window; each entry is scrolled into view before a tap,
    // so the catalogue can grow without resizing the window.
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const TakeTrayCatalogue());
    await tester.pumpAndSettle();

    final entries = _entries(ttCatalog);
    expect(entries, isNotEmpty);
    for (final (:folder, :component, :name) in entries) {
      // Open the folder and the component if the tree has them closed.
      if (find.text(component.name).evaluate().isEmpty) {
        await _tapInTree(tester, folder);
        await tester.pumpAndSettle();
      }
      // A component with one use case is listed as that use case.
      if (component.useCases.length == 1) {
        await _tapInTree(tester, component.name);
      } else {
        if (find.text(name).evaluate().isEmpty) {
          await _tapInTree(tester, component.name);
          await tester.pumpAndSettle();
        }
        await _tapInTree(tester, name);
      }
      // Not pumpAndSettle: TtRecDot pulses for ever.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      // The tap really opened this use case, not some other one.
      expect(
        WidgetbookState.of(tester.element(find.byType(Scaffold).first))
            .useCase
            ?.name,
        name,
        reason: '${component.name} / $name was not selected by the tap',
      );
      expect(
        tester.takeException(),
        isNull,
        reason: '${component.name} / $name threw',
      );
    }
  });
}
