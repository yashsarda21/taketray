import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/features/editors/view_models/copy_screens.dart';

void main() {
  group('OpenCopyScreens', () {
    test('a job is open from the first add to the last remove', () {
      final open = OpenCopyScreens();
      expect(open.isOpen('1-2000'), isFalse);

      open.add('1-2000');
      expect(open.isOpen('1-2000'), isTrue);
      expect(open.isOpen('1-3000'), isFalse, reason: 'another job');

      open.remove('1-2000');
      expect(open.isOpen('1-2000'), isFalse);
    });

    test('two screens for one job: still open until both are gone', () {
      final open = OpenCopyScreens()
        ..add('1-2000')
        ..add('1-2000')
        ..remove('1-2000');
      expect(open.isOpen('1-2000'), isTrue);

      open.remove('1-2000');
      expect(open.isOpen('1-2000'), isFalse);
    });

    test('removing a job that was never added changes nothing, and does not '
        'count below zero', () {
      final open = OpenCopyScreens()..remove('9-9');
      expect(open.isOpen('9-9'), isFalse);

      open.add('9-9');
      expect(open.isOpen('9-9'), isTrue, reason: 'an early remove is no debt');
    });
  });
}
