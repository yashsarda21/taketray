import 'package:flutter_test/flutter_test.dart';

import '../../patrol_test/support/tap_guard.dart';
import '../../patrol_test/support/test_background.dart';

/// The two refusals in front of the shade tap on "Turn off": only Still
/// shooting? may be showing from TakeTray (two notifications from one app are
/// grouped and the older one is folded away), and the tap must come before the
/// real job's 5 s delay is over (the job would post the new-clips
/// notification).
void main() {
  const still = TestBackground.stillShootingId;
  const soon = Duration(seconds: 1);

  group('stillTapRefusal', () {
    test('only Still shooting?, soon after the insert: no refusal', () {
      expect(
        stillTapRefusal(ownIds: [still], sinceInsert: soon, stillId: still),
        isNull,
      );
    });

    test('the new-clips notification is showing too: refused, named', () {
      final why = stillTapRefusal(
        ownIds: [TestBackground.newClipsId, still],
        sinceInsert: soon,
        stillId: still,
      );
      expect(why, contains('a second TakeTray notification is showing'));
    });

    test('the evening reminder is showing too: refused', () {
      expect(
        stillTapRefusal(
          ownIds: [TestBackground.eveningId, still],
          sinceInsert: soon,
          stillId: still,
        ),
        contains('a second TakeTray notification is showing'),
      );
    });

    test('any other id with it (the system group summary, id 0): refused', () {
      expect(
        stillTapRefusal(ownIds: [0, still], sinceInsert: soon, stillId: still),
        contains('a second TakeTray notification is showing'),
      );
    });

    test('the order of the ids does not matter', () {
      expect(
        stillTapRefusal(
          ownIds: [still, TestBackground.newClipsId],
          sinceInsert: soon,
          stillId: still,
        ),
        contains('a second TakeTray notification is showing'),
      );
    });

    test(
      'Still shooting? is not showing at all: refused, a different cause',
      () {
        final none = stillTapRefusal(
          ownIds: const [],
          sinceInsert: soon,
          stillId: still,
        );
        final other = stillTapRefusal(
          ownIds: [TestBackground.newClipsId],
          sinceInsert: soon,
          stillId: still,
        );
        expect(none, contains('Still shooting? is not showing'));
        expect(other, contains('Still shooting? is not showing'));
        expect(none, isNot(contains('a second TakeTray notification')));
      },
    );

    test('just under 4.5 s: no refusal; 4.5 s and over: too slow', () {
      expect(
        stillTapRefusal(
          ownIds: [still],
          sinceInsert: const Duration(milliseconds: 4499),
          stillId: still,
        ),
        isNull,
      );
      for (final ms in [4500, 4501, 5000, 60000]) {
        expect(
          stillTapRefusal(
            ownIds: [still],
            sinceInsert: Duration(milliseconds: ms),
            stillId: still,
          ),
          contains('too slow: the job may post'),
          reason: '$ms ms',
        );
      }
    });

    test('no time at all since the insert is fine', () {
      expect(
        stillTapRefusal(
          ownIds: [still],
          sinceInsert: Duration.zero,
          stillId: still,
        ),
        isNull,
      );
    });

    test('a negative time (a clock that went back) is refused', () {
      expect(
        stillTapRefusal(
          ownIds: [still],
          sinceInsert: const Duration(milliseconds: -1),
          stillId: still,
        ),
        contains('too slow: the job may post'),
      );
    });

    test('a second notification and too slow: the notification is named', () {
      final why = stillTapRefusal(
        ownIds: [TestBackground.newClipsId, still],
        sinceInsert: const Duration(seconds: 10),
        stillId: still,
      );
      expect(why, contains('a second TakeTray notification is showing'));
    });

    test('the limit is under the job update delay of 5 s', () {
      expect(maxTapAge, const Duration(milliseconds: 4500));
      expect(maxTapAge, lessThan(const Duration(seconds: 5)));
    });
  });
}
