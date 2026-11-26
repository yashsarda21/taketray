import 'package:flutter_test/flutter_test.dart';
import 'package:taketray_ui/src/components/internal/saturation.dart';

// The W3C Filter Effects `saturate(s)` matrix (D-175).

void main() {
  group('ttSaturationMatrix', () {
    test('saturation 1 is the identity', () {
      const identity = [
        1, 0, 0, 0, 0, //
        0, 1, 0, 0, 0,
        0, 0, 1, 0, 0,
        0, 0, 0, 1, 0,
      ];
      final matrix = ttSaturationMatrix(1);
      expect(matrix, hasLength(20));
      for (var i = 0; i < 20; i++) {
        expect(matrix[i], closeTo(identity[i], 1e-9), reason: 'value $i');
      }
    });

    test('saturation 1.4 matches the CSS filter spec', () {
      const expected = [
        1.31496, -0.28608, -0.02888, 0, 0, //
        -0.08504, 1.11392, -0.02888, 0, 0,
        -0.08504, -0.28608, 1.37112, 0, 0,
        0, 0, 0, 1, 0,
      ];
      final matrix = ttSaturationMatrix(1.4);
      expect(matrix, hasLength(20));
      for (var i = 0; i < 20; i++) {
        expect(matrix[i], closeTo(expected[i], 1e-9), reason: 'value $i');
      }
    });

    test('saturation 0 is the luma grey', () {
      final matrix = ttSaturationMatrix(0);
      for (var row = 0; row < 3; row++) {
        expect(matrix[row * 5], closeTo(0.2126, 1e-9));
        expect(matrix[row * 5 + 1], closeTo(0.7152, 1e-9));
        expect(matrix[row * 5 + 2], closeTo(0.0722, 1e-9));
      }
    });

    test('every row of rgb keeps white white (rows sum to 1)', () {
      final matrix = ttSaturationMatrix(1.4);
      for (var row = 0; row < 3; row++) {
        expect(
          matrix[row * 5] + matrix[row * 5 + 1] + matrix[row * 5 + 2],
          closeTo(1, 1e-9),
        );
      }
    });
  });
}
