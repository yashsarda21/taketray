import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/features/tagging/view_models/pending_clips.dart';

import '../../../support/clips.dart';
import '../../../support/fake_media_bridge.dart';
import '../../../support/vm_harness.dart';

void main() {
  group('inShootingOrder', () {
    test('oldest date taken first, then the lower id', () {
      final ordered = inShootingOrder([
        testClip(9, shot: DateTime(2026, 10, 28, 11)),
        testClip(4, shot: DateTime(2026, 10, 28, 10)),
        testClip(7, shot: DateTime(2026, 10, 28, 10)),
        testClip(2, shot: DateTime(2026, 10, 27, 23)),
      ]);

      expect([for (final c in ordered) c.id], [2, 4, 7, 9]);
    });

    test('does not change the list it is given, and handles none', () {
      final given = [testClip(2), testClip(1)];

      inShootingOrder(given);

      expect([for (final c in given) c.id], [2, 1]);
      expect(inShootingOrder(const []), isEmpty);
    });

    test('a sub-second difference still orders', () {
      final ordered = inShootingOrder([
        testClip(1, shot: DateTime.utc(2026, 10, 28, 9, 0, 0, 500)),
        testClip(2, shot: DateTime.utc(2026, 10, 28, 9, 0, 0, 100)),
      ]);

      expect([for (final c in ordered) c.id], [2, 1]);
    });
  });

  group('latestPending', () {
    test('is the last in shooting order, or null for none', () {
      expect(latestPending(const []), isNull);
      expect(
        latestPending([
          testClip(3, shot: DateTime(2026, 10, 28, 11)),
          testClip(9, shot: DateTime(2026, 10, 28, 11)),
          testClip(5, shot: DateTime(2026, 10, 28, 12)),
          testClip(8, shot: DateTime(2026, 10, 28, 10)),
        ])!.id,
        5,
      );
    });
  });

  group('pendingClipsProvider', () {
    test('follows the To tag list without scanning or verifying', () async {
      final h = VmHarness();
      h.container.listen(pendingClipsProvider, (_, _) {});

      expect(await h.container.read(pendingClipsProvider.future), isEmpty);
      await h.media.store([fakeVideo(id: 1)]);
      await settle();

      expect(h.container.read(pendingClipsProvider).value, hasLength(1));
      // Showing the card must not look at the phone: opening To tag does.
      expect(h.bridge.calls, isEmpty);
    });
  });
}
