import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/tt_accessibility.dart';
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

    testWidgets('scrim uses the prototype stops', (tester) async {
      await tester.pumpWidget(
        ttTestApp(
          const Align(
            child: SizedBox(
              width: 200,
              height: 600,
              child: TtVideoSurface(scrims: true, child: SizedBox.expand()),
            ),
          ),
        ),
      );
      final gradients = find
          .descendant(
            of: find.byType(TtVideoSurface),
            matching: find.byWidgetPredicate(_isGradient),
          )
          .evaluate()
          .map(
            (e) =>
                ((e.widget as DecoratedBox).decoration as BoxDecoration)
                        .gradient!
                    as LinearGradient,
          )
          .toList();
      expect(gradients, hasLength(2));

      // proto.css .viewer .vtop: linear-gradient(rgba(0,0,0,.6), transparent)
      final top = gradients.first;
      expect(top.begin, Alignment.topCenter);
      expect(top.end, Alignment.bottomCenter);
      expect(top.colors, hasLength(2));
      expect(top.colors.first.a, closeTo(0.6, 1 / 255));
      expect(top.colors.last.a, 0);
      expect(top.stops, isNull);

      // proto.css .viewer .vbot: linear-gradient(transparent, rgba(0,0,0,.78)
      // 30%): clear at the inner end, solid .78 from 30 % on, to the edge.
      final bottom = gradients.last;
      expect(bottom.begin, Alignment.bottomCenter);
      expect(bottom.end, Alignment.topCenter);
      expect(bottom.colors, hasLength(3));
      expect(bottom.colors[0].a, closeTo(0.78, 1 / 255));
      expect(bottom.colors[1].a, closeTo(0.78, 1 / 255));
      expect(bottom.colors[2].a, 0);
      expect(bottom.stops, [0.0, 0.7, 1.0]);

      // The scrim heights come from the same CSS paddings.
      final boxes = find
          .descendant(
            of: find.byType(TtVideoSurface),
            matching: find.byWidgetPredicate(_isGradient),
          )
          .evaluate()
          .map((e) => tester.getSize(find.byWidget(e.widget)))
          .toList();
      expect(boxes.first.height, 112);
      expect(boxes.last.height, 168);
    });

    testWidgets('video surface is accessible', (tester) async {
      await tester.pumpWidget(
        ttTestApp(
          TtVideoSurface(
            scrims: true,
            child: Builder(
              builder: (context) => Column(
                children: [
                  TtIconButton(
                    icon: Symbols.close_rounded,
                    semanticLabel: 'Close',
                    style: TtIconButtonStyle.onVideo,
                    onPressed: () {},
                  ),
                  Text(
                    'On video',
                    style: context.tt.text.material.bodyMedium!.copyWith(
                      color: context.tt.colors.onVideo,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await expectTtAccessible(tester);
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

    for (final brightness in Brightness.values) {
      testWidgets('asks for light system bar icons (${brightness.name})', (
        tester,
      ) async {
        await tester.pumpWidget(
          ttTestApp(
            const TtVideoSurface(child: SizedBox.expand()),
            brightness: brightness,
          ),
        );
        final style = tester
            .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
              find.descendant(
                of: find.byType(TtVideoSurface),
                matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
              ),
            )
            .value;
        expect(style.statusBarIconBrightness, Brightness.light);
        expect(style.systemNavigationBarIconBrightness, Brightness.light);
        expect(style.statusBarColor!.a, 0);
        expect(style.systemNavigationBarColor!.a, 0);
      });
    }
  });
}
