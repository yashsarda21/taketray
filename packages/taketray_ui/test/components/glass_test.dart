import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/tt_accessibility.dart';
import '../support/tt_test_app.dart';

void main() {
  group('TtGlass', () {
    testWidgets('shows its child inside a backdrop blur', (tester) async {
      await tester.pumpWidget(
        ttTestApp(
          const Center(child: TtGlass(radius: 20, child: Text('Hello'))),
        ),
      );
      expect(find.text('Hello'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(TtGlass),
          matching: find.byType(BackdropFilter),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the shadow is optional', (tester) async {
      Future<int> shadowed({required bool shadow}) async {
        await tester.pumpWidget(
          ttTestApp(
            Center(
              child: TtGlass(
                radius: 20,
                shadow: shadow,
                child: const Text('Hello'),
              ),
            ),
          ),
        );
        return find
            .descendant(
              of: find.byType(TtGlass),
              matching: find.byType(DecoratedBox),
            )
            .evaluate()
            .where((e) {
              final d = (e.widget as DecoratedBox).decoration;
              return d is BoxDecoration && d.boxShadow != null;
            })
            .length;
      }

      expect(await shadowed(shadow: true), 1);
      expect(await shadowed(shadow: false), 0);
    });

    for (final brightness in Brightness.values) {
      testWidgets('passes the accessibility guidelines (${brightness.name})', (
        tester,
      ) async {
        await tester.pumpWidget(
          ttTestApp(
            const Center(child: TtGlass(radius: 20, child: Text('Hello'))),
            brightness: brightness,
          ),
        );
        await expectTtAccessible(tester);
      });
    }
  });

  group('TtGlassPill', () {
    testWidgets('shows the icon and the text', (tester) async {
      await tester.pumpWidget(
        ttTestApp(
          const Center(
            child: TtGlassPill(
              icon: Symbols.link_rounded,
              text: '3',
              semanticLabel: '3 links',
            ),
          ),
        ),
      );
      expect(find.byIcon(Symbols.link_rounded), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('is 24 dp high', (tester) async {
      await tester.pumpWidget(
        ttTestApp(
          const Center(
            child: TtGlassPill(
              icon: Symbols.link_rounded,
              semanticLabel: 'Linked',
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(TtGlassPill)).height, 24);
    });

    testWidgets('an icon-only pill is announced by its semanticLabel', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          ttTestApp(
            const Center(
              child: TtGlassPill(
                icon: Symbols.link_rounded,
                semanticLabel: 'Has references',
              ),
            ),
          ),
        );
        final data = tester
            .getSemantics(find.byType(TtGlassPill))
            .getSemanticsData();
        expect(data.label, 'Has references');
        // One node: the icon adds no label of its own.
        expect(find.bySemanticsLabel('Has references'), findsOneWidget);
      } finally {
        handle.dispose();
      }
    });

    testWidgets('a pill with text is announced by its semanticLabel, not '
        'the text', (tester) async {
      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          ttTestApp(
            const Center(
              child: TtGlassPill(
                icon: Symbols.link_rounded,
                text: '3',
                semanticLabel: '3 references',
              ),
            ),
          ),
        );
        expect(find.bySemanticsLabel('3 references'), findsOneWidget);
        expect(find.bySemanticsLabel('3'), findsNothing);
      } finally {
        handle.dispose();
      }
    });
  });
}
