import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/domain/rules/tag_queue.dart';

void main() {
  // Clip ids 10..14 sit at indexes 0..4.
  final queue = TagQueue(const [10, 11, 12, 13, 14]);

  group('TagQueue', () {
    test('next skips clips no longer pending', () {
      expect(queue.next(0, {10, 13, 14}), 3);
      expect(queue.next(3, {10, 13, 14}), 4);
    });

    test('next is null after the last pending clip', () {
      expect(queue.next(4, {10, 11, 12, 13, 14}), isNull);
      expect(queue.next(1, {10, 11}), isNull);
    });

    test('previous skips too', () {
      expect(queue.previous(4, {10, 11, 14}), 1);
      expect(queue.previous(1, {10, 11, 14}), 0);
    });

    test('previous is null before the first pending clip', () {
      expect(queue.previous(0, {10, 11, 12, 13, 14}), isNull);
      expect(queue.previous(3, {13, 14}), isNull);
    });

    test('afterAction goes to the next pending clip', () {
      expect(queue.afterAction(1, {10, 13}), 3);
    });

    test('afterAction wraps to the first pending before the current', () {
      expect(queue.afterAction(4, {10, 12}), 0);
      expect(queue.afterAction(3, {12}), 2);
    });

    test('afterAction is null when none pending', () {
      expect(queue.afterAction(2, <int>{}), isNull);
      // Ids that are not in the session are not pending clips of it.
      expect(queue.afterAction(2, {99}), isNull);
    });

    test('empty session', () {
      final empty = TagQueue(const []);

      expect(empty.next(0, {1}), isNull);
      expect(empty.previous(0, {1}), isNull);
      expect(empty.afterAction(0, {1}), isNull);
      expect(empty.afterAction(-1, <int>{}), isNull);
    });

    test('a position outside the session still finds the nearest', () {
      expect(queue.next(-1, {10, 14}), 0);
      expect(queue.previous(9, {10, 14}), 4);
      expect(queue.next(9, {10, 14}), isNull);
    });
  });
}
