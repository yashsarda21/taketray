import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray_ui/src/components/internal/fit_height.dart';

const _child = Key('child');

Widget _boxed(Widget child, {required double width, required double height}) =>
    Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: width, height: height, child: child),
      ),
    );

Widget _block(double width, double height, {VoidCallback? onTap}) =>
    GestureDetector(
      key: _child,
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(width: width, height: height),
    );

void main() {
  group('FitHeight', () {
    testWidgets('shrinks a child that is taller than the box', (tester) async {
      await tester.pumpWidget(
        _boxed(FitHeight(child: _block(100, 100)), width: 100, height: 50),
      );
      final rect = tester.getRect(find.byKey(_child));
      expect(rect.size, const Size(50, 50));
      // Centred in the box.
      expect(rect.left, 25);
      expect(rect.top, 0);
    });

    testWidgets('never scales a child up', (tester) async {
      await tester.pumpWidget(
        _boxed(FitHeight(child: _block(60, 40)), width: 200, height: 400),
      );
      expect(tester.getRect(find.byKey(_child)).size, const Size(60, 40));
    });

    testWidgets('a tap lands in the shrunk child, not outside it', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _boxed(
          FitHeight(child: _block(100, 100, onTap: () => taps++)),
          width: 100,
          height: 50,
        ),
      );
      // The child is drawn 50 x 50 at x 25..75. Its own coordinates run to
      // 100, so without the transform a tap at x 90 would hit it.
      await tester.tapAt(const Offset(90, 25));
      expect(taps, 0);
      await tester.tapAt(const Offset(50, 25));
      expect(taps, 1);
      await tester.tapAt(const Offset(30, 10));
      expect(taps, 2);
    });

    testWidgets('answers intrinsic height queries', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 100,
              child: IntrinsicHeight(child: FitHeight(child: _block(100, 70))),
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(FitHeight)).height, 70);
      expect(tester.takeException(), isNull);
    });

    testWidgets('reports its child baseline, scaled', (tester) async {
      TextStyle style(double size) =>
          TextStyle(inherit: false, fontSize: size, fontFamily: 'Ahem');
      double baseline(double size) => (TextPainter(
        text: TextSpan(text: 'Hamburg', style: style(size)),
        textDirection: TextDirection.ltr,
      )..layout()).computeDistanceToActualBaseline(TextBaseline.alphabetic);
      final bigHeight = (TextPainter(
        text: TextSpan(text: 'Hamburg', style: style(40)),
        textDirection: TextDirection.ltr,
      )..layout()).height;
      // A Row aligns children by baseline: the small text sits so that its
      // baseline is the baseline of the big text, drawn at half size.
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 300,
                  height: bigHeight / 2,
                  child: FitHeight(
                    child: Text('Hamburg', key: _child, style: style(40)),
                  ),
                ),
                Text('Hamburg', key: const Key('small'), style: style(10)),
              ],
            ),
          ),
        ),
      );
      final big = tester.getRect(find.byType(FitHeight));
      final small = tester.getTopLeft(find.byKey(const Key('small')));
      expect(
        small.dy + baseline(10),
        closeTo(big.top + baseline(40) / 2, 0.01),
      );
    });

    testWidgets('a word wider than the box is shrunk, not broken', (
      tester,
    ) async {
      await tester.pumpWidget(
        _boxed(
          const FitHeight(
            child: Text('Wonderful day', style: TextStyle(fontSize: 30)),
          ),
          width: 60,
          height: 400,
        ),
      );
      final paragraph = tester.renderObject<RenderParagraph>(
        find.text('Wonderful day'),
      );
      // The paragraph is laid out wide enough for its longest word...
      expect(
        paragraph.getMinIntrinsicWidth(double.infinity),
        lessThanOrEqualTo(paragraph.size.width + 0.01),
      );
      // ...and drawn inside the 60 dp box.
      final rect = tester.getRect(find.text('Wonderful day'));
      expect(rect.width, lessThanOrEqualTo(60.01));
      expect(rect.height, lessThan(paragraph.size.height));
    });
  });
}
