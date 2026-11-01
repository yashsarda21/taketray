import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray_ui/src/components/internal/scrim.dart';

const _black = Color(0xCC000000);

Future<LinearGradient> _gradientOf(WidgetTester tester, Scrim scrim) async {
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(width: 100, height: 100, child: scrim),
    ),
  );
  final box = tester.widget<DecoratedBox>(
    find.descendant(
      of: find.byType(Scrim),
      matching: find.byType(DecoratedBox),
    ),
  );
  return (box.decoration as BoxDecoration).gradient! as LinearGradient;
}

void main() {
  group('Scrim', () {
    testWidgets('a plain top fade goes from the colour at the top to clear', (
      tester,
    ) async {
      final g = await _gradientOf(
        tester,
        const Scrim(color: _black, top: true),
      );
      expect(g.begin, Alignment.topCenter);
      expect(g.end, Alignment.bottomCenter);
      expect(g.colors, [_black, _black.withValues(alpha: 0)]);
      expect(g.stops, isNull);
    });

    testWidgets('a plain bottom fade is clear at the top, the colour at the '
        'bottom', (tester) async {
      final g = await _gradientOf(
        tester,
        const Scrim(color: _black, top: false),
      );
      expect(g.begin, Alignment.topCenter);
      expect(g.end, Alignment.bottomCenter);
      expect(g.colors, [_black.withValues(alpha: 0), _black]);
      expect(g.stops, isNull);
    });

    testWidgets('a solid part keeps the colour from the edge to the stop', (
      tester,
    ) async {
      final g = await _gradientOf(
        tester,
        const Scrim(color: _black, top: false, solid: 0.7),
      );
      expect(g.begin, Alignment.bottomCenter);
      expect(g.end, Alignment.topCenter);
      expect(g.colors, [_black, _black, _black.withValues(alpha: 0)]);
      expect(g.stops, [0.0, 0.7, 1.0]);
    });

    testWidgets('takes no touches and is not announced', (tester) async {
      await _gradientOf(tester, const Scrim(color: _black, top: true));
      expect(
        find.descendant(
          of: find.byType(Scrim),
          matching: find.byType(IgnorePointer),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(Scrim),
          matching: find.byType(ExcludeSemantics),
        ),
        findsOneWidget,
      );
    });

    test('solid must be a share of the height', () {
      expect(
        () => Scrim(color: _black, top: true, solid: _share(1)),
        throwsAssertionError,
      );
      expect(
        () => Scrim(color: _black, top: true, solid: _share(-0.1)),
        throwsAssertionError,
      );
      expect(
        Scrim(color: _black, top: true, solid: _share(0.99)),
        isA<Scrim>(),
      );
    });
  });
}

/// Keeps the value out of a const constructor, so the assert runs at run time.
double _share(double value) => value;
