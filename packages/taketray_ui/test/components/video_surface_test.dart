import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/tt_test_app.dart';

bool _isGradient(Widget w) =>
    w is DecoratedBox &&
    w.decoration is BoxDecoration &&
    (w.decoration as BoxDecoration).gradient != null;

void main() {
  group('TtVideoSurface', () {
    for (final brightness in Brightness.values) {
      testWidgets('gives its subtree the video theme (${brightness.name})', (
        tester,
      ) async {
        late BuildContext inner;
        await tester.pumpWidget(
          ttTestApp(
            TtVideoSurface(
              child: Builder(
                builder: (context) {
                  inner = context;
                  return const SizedBox.shrink();
                },
              ),
            ),
            brightness: brightness,
          ),
        );
        expect(Theme.of(inner).brightness, Brightness.dark);
        expect(inner.scheme.surface, TakeTrayTheme.video().colorScheme.surface);
        expect(inner.tt.colors.videoBackground, const Color(0xFF000000));
        // The subtree around it keeps the app theme.
        final outer = tester.element(find.byType(TtVideoSurface));
        expect(Theme.of(outer).brightness, brightness);
      });
    }

    testWidgets('is black and fills the space it is given', (tester) async {
      await tester.pumpWidget(
        ttTestApp(
          const Align(
            child: SizedBox(
              width: 200,
              height: 300,
              child: TtVideoSurface(child: SizedBox.expand()),
            ),
          ),
        ),
      );
      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(TtVideoSurface),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.color, const Color(0xFF000000));
      expect(tester.getSize(find.byType(TtVideoSurface)), const Size(200, 300));
    });

    testWidgets('shrinks to its child when not constrained tightly', (
      tester,
    ) async {
      await tester.pumpWidget(
        ttTestApp(
          const Align(
            alignment: Alignment.topLeft,
            child: TtVideoSurface(child: SizedBox(width: 120, height: 40)),
          ),
        ),
      );
      expect(tester.getSize(find.byType(TtVideoSurface)), const Size(120, 40));
    });

    testWidgets('scrims are off by default and add two gradients when on', (
      tester,
    ) async {
      Finder gradients() => find.descendant(
        of: find.byType(TtVideoSurface),
        matching: find.byWidgetPredicate(_isGradient),
      );
      await tester.pumpWidget(
        ttTestApp(const TtVideoSurface(child: SizedBox.expand())),
      );
      expect(gradients(), findsNothing);
      await tester.pumpWidget(
        ttTestApp(const TtVideoSurface(scrims: true, child: SizedBox.expand())),
      );
      expect(gradients(), findsNWidgets(2));
    });

    testWidgets('scrims let taps through to the child', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        ttTestApp(
          TtVideoSurface(
            scrims: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => taps++,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );
      await tester.tapAt(const Offset(400, 20));
      await tester.tapAt(const Offset(400, 580));
      expect(taps, 2);
    });

    testWidgets('the scrims are not announced', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        ttTestApp(const TtVideoSurface(scrims: true, child: SizedBox.expand())),
      );
      expect(find.byType(ExcludeSemantics), findsWidgets);
      handle.dispose();
    });
  });
}
