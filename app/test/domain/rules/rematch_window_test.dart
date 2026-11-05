import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/domain/rules/rematch_window.dart';

// D-108: a rebuild resync that detaches clips opens a 24 hour window in which
// the scan matches them again, only when the volume's generation changed.

final DateTime _opened = DateTime.utc(2026, 6, 1, 9);

RematchWindow _window({Set<int> clipIds = const {4, 7}, int generation = 12}) =>
    RematchWindow(openedAt: _opened, clipIds: clipIds, generation: generation);

void main() {
  test('a window lasts 24 hours', () {
    expect(rematchWindowLength, const Duration(hours: 24));
  });

  group('isOpenAt', () {
    test('open from the resync on', () {
      expect(_window().isOpenAt(_opened), isTrue);
      expect(_window().isOpenAt(_opened.add(const Duration(hours: 5))), isTrue);
    });

    test('open a millisecond before 24 hours, closed at 24 hours', () {
      final end = _opened.add(rematchWindowLength);
      expect(
        _window().isOpenAt(end.subtract(const Duration(milliseconds: 1))),
        isTrue,
      );
      expect(_window().isOpenAt(end), isFalse);
      expect(_window().isOpenAt(end.add(const Duration(days: 30))), isFalse);
    });

    test('closed before it was opened (the clock went back)', () {
      expect(
        _window().isOpenAt(_opened.subtract(const Duration(milliseconds: 1))),
        isFalse,
      );
    });

    test('compares instants, not wall clocks', () {
      final local = _opened.toLocal();
      expect(_window().isOpenAt(local), isTrue);
    });
  });

  group('equality', () {
    test('equal by time, clips and generation', () {
      expect(_window(), _window());
      expect(_window().hashCode, _window().hashCode);
      expect(_window(clipIds: {7, 4}), _window());
      expect(_window(clipIds: {4}), isNot(_window()));
      expect(_window(generation: 13), isNot(_window()));
      expect(
        RematchWindow(
          openedAt: _opened.add(const Duration(milliseconds: 1)),
          clipIds: const {4, 7},
          generation: 12,
        ),
        isNot(_window()),
      );
    });

    test('the clip ids cannot be changed from outside', () {
      final ids = {1, 2};
      final window = RematchWindow(
        openedAt: _opened,
        clipIds: ids,
        generation: 1,
      );
      ids.add(3);

      expect(window.clipIds, {1, 2});
      expect(() => window.clipIds.add(9), throwsUnsupportedError);
    });

    test('toString names the counts only', () {
      expect(_window().toString(), contains('2 clips'));
    });
  });
}
