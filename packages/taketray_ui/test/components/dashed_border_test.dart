import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray_ui/src/components/internal/dashed_border.dart';

DashedBorderPainter _painter({
  Color color = const Color(0xFF000000),
  double radius = 12,
  double width = 1.5,
  double dash = 4,
  double gap = 3,
}) => DashedBorderPainter(
  color: color,
  radius: radius,
  width: width,
  dash: dash,
  gap: gap,
);

void main() {
  group('DashedBorderPainter.shouldRepaint', () {
    test('is false when every value is the same', () {
      expect(_painter().shouldRepaint(_painter()), isFalse);
    });

    test('is true when any one value changes', () {
      final base = _painter();
      expect(
        _painter(color: const Color(0xFFFFFFFF)).shouldRepaint(base),
        isTrue,
        reason: 'color',
      );
      expect(_painter(radius: 8).shouldRepaint(base), isTrue, reason: 'radius');
      expect(_painter(width: 2).shouldRepaint(base), isTrue, reason: 'width');
      expect(_painter(dash: 5).shouldRepaint(base), isTrue, reason: 'dash');
      expect(_painter(gap: 4).shouldRepaint(base), isTrue, reason: 'gap');
    });
  });
}
