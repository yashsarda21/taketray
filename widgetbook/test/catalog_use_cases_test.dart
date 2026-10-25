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

void main() {
  testWidgets('every use case in the catalogue opens without an error', (
    tester,
  ) async {
    // A desktop-sized window, so the navigation panel is shown.
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const TakeTrayCatalogue());
    await tester.pumpAndSettle();

    final entries = _entries(ttCatalog);
    expect(entries, isNotEmpty);
    for (final (:folder, :component, :name) in entries) {
      // Open the folder and the component if the tree has them closed.
      if (find.text(component.name).evaluate().isEmpty) {
        await tester.tap(find.text(folder));
        await tester.pumpAndSettle();
      }
      // A component with one use case is listed as that use case.
      if (component.useCases.length == 1) {
        await tester.tap(find.text(component.name));
      } else {
        if (find.text(name).evaluate().isEmpty) {
          await tester.tap(find.text(component.name));
          await tester.pumpAndSettle();
        }
        await tester.tap(find.text(name));
      }
      // Not pumpAndSettle: TtRecDot pulses for ever.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        tester.takeException(),
        isNull,
        reason: '${component.name} / $name threw',
      );
    }
  });
}
