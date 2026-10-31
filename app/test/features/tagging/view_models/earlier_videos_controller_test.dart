import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/data/media/media_scanner.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/domain/rules/earlier_window.dart';
import 'package:taketray/features/tagging/view_models/earlier_videos_controller.dart';

import '../../../support/fake_media_bridge.dart';
import '../../../support/vm_harness.dart';

// 15:00 local time on 2026-06-10, as in add_earlier_test.dart: the dates are
// built in local time, so the tests hold in any time zone.
final DateTime _nowLocal = DateTime(2026, 6, 10, 15);

MediaVideo shot(int id, DateTime when) => fakeVideo(
  id: id,
  generation: id,
  sizeBytes: 1000000 + id,
  dateTakenMs: when.millisecondsSinceEpoch,
  dateAddedSec: when.millisecondsSinceEpoch ~/ 1000,
  dateModifiedSec: when.millisecondsSinceEpoch ~/ 1000,
);

const EarlierRange today = EarlierToday();

/// The days [from] to [to] of June 2026 (day numbers), both included.
EarlierRange june(int from, int to) =>
    EarlierCustom(DateTime(2026, 6, from), DateTime(2026, 6, to));

/// A bridge whose `accessReport` fails from its [failFrom]th call on.
class _FailsLater extends RecordingBridge {
  int failFrom = 1 << 30;
  int _calls = 0;

  @override
  Future<MediaAccess> accessReport() {
    if (++_calls >= failFrom) {
      throw PlatformException(code: 'later', message: '/storage/secret');
    }
    return super.accessReport();
  }
}

void main() {
  late VmHarness h;

  setUp(() {
    h = VmHarness(now: _nowLocal.toUtc());
    h.bridge.put([
      shot(1, DateTime(2026, 6, 10, 10)), // today
      shot(2, DateTime(2026, 6, 9, 10)), // yesterday
      shot(3, DateTime(2026, 6, 5, 10)), // five days ago
    ]);
  });

  /// Listens like a sheet would, so the auto-dispose provider stays alive.
  ProviderSubscription<AsyncValue<int>> open() =>
      h.container.listen(earlierVideosControllerProvider, (_, _) {});

  int? shown() => h.container.read(earlierVideosControllerProvider).value;

  EarlierVideosController notifier() =>
      h.container.read(earlierVideosControllerProvider.notifier);

  group('counts', () {
    test('load when the sheet opens, with Shooting mode off', () async {
      open();

      expect(await h.container.read(earlierVideosControllerProvider.future), 1);
      expect((await h.media.phoneState.loadShooting()).on, isFalse);
    });

    test('are zeros without full access', () async {
      h.bridge.access = const MediaAccess(
        level: MediaAccessLevel.limited,
        canAskAgain: true,
        sdkInt: 34,
      );
      open();

      expect(await h.container.read(earlierVideosControllerProvider.future), 0);
    });

    test('a failure is an error state, and only its type is logged', () async {
      final records = captureLogs();
      h.bridge.failNext('accessReport');
      open();

      await expectLater(
        h.container.read(earlierVideosControllerProvider.future),
        throwsA(isA<PlatformException>()),
      );

      expect(
        h.container.read(earlierVideosControllerProvider),
        isA<AsyncError<int>>(),
      );
      expect(logText(records), contains('PlatformException'));
      expect(logText(records), isNot(contains('failed on purpose')));
    });

    test('a failed count is not retried by itself', () async {
      h.bridge.failNext('accessReport');
      open();
      await expectLater(
        h.container.read(earlierVideosControllerProvider.future),
        throwsA(anything),
      );

      await settle();

      expect(h.bridge.count('accessReport'), 1);
    });
  });

  group('countIn', () {
    test('counts a chosen range and leaves the shown count alone', () async {
      open();
      await h.container.read(earlierVideosControllerProvider.future);

      expect(await notifier().countIn(june(5, 9)), 2);
      expect(await notifier().countIn(june(9, 9)), 1);
      expect(await notifier().countIn(june(3, 4)), 0);

      expect(shown(), 1, reason: "Today's count is what the state holds");
      expect(await h.media.allClips(), isEmpty, reason: 'nothing is written');
    });

    test('is 0 without full access', () async {
      open();
      await h.container.read(earlierVideosControllerProvider.future);
      h.bridge.access = const MediaAccess(
        level: MediaAccessLevel.limited,
        canAskAgain: true,
        sdkInt: 34,
      );

      expect(await notifier().countIn(june(2, 10)), 0);
    });

    test('a failure is rethrown, and only its type is logged', () async {
      final records = captureLogs();
      open();
      await h.container.read(earlierVideosControllerProvider.future);
      h.bridge.failNext('accessReport');

      await expectLater(
        notifier().countIn(june(2, 10)),
        throwsA(isA<PlatformException>()),
      );

      expect(logText(records), contains('PlatformException'));
      expect(logText(records), isNot(contains('failed on purpose')));
      expect(
        h.container.read(earlierVideosControllerProvider),
        isA<AsyncData<int>>(),
        reason: 'a failed count of a range does not turn the sheet to error',
      );
    });

    test('an impossible range is rethrown as an ArgumentError', () async {
      open();
      await h.container.read(earlierVideosControllerProvider.future);

      await expectLater(notifier().countIn(june(9, 5)), throwsArgumentError);
    });
  });

  group('add', () {
    test('a past range leaves Today count alone', () async {
      open();
      await h.container.read(earlierVideosControllerProvider.future);

      final ids = await notifier().add(june(5, 9));

      expect(ids, hasLength(2));
      expect(shown(), 1);
    });

    test('returns the new ids, puts them in To tag and recounts', () async {
      open();
      await h.container.read(earlierVideosControllerProvider.future);

      final ids = await notifier().add(june(9, 10));

      expect(ids, hasLength(2));
      expect({for (final c in await h.media.toTag()) c.id}, ids.toSet());
      // Today's video is known now.
      expect(shown(), 0);
    });

    test('with nothing to add returns no ids', () async {
      open();
      await h.container.read(earlierVideosControllerProvider.future);
      await notifier().add(june(2, 10));

      expect(await notifier().add(june(2, 10)), isEmpty);
    });

    test('without full access it throws, and says so to the caller', () async {
      final records = captureLogs();
      open();
      await h.container.read(earlierVideosControllerProvider.future);
      h.bridge.access = const MediaAccess(
        level: MediaAccessLevel.denied,
        canAskAgain: false,
        sdkInt: 34,
      );

      await expectLater(notifier().add(today), throwsA(isA<StateError>()));

      expect(await h.media.toTag(), isEmpty);
      expect(shown(), 1, reason: 'the shown count is kept');
      expect(logText(records), contains('StateError'));
    });

    test('a bridge error is rethrown and nothing is added', () async {
      open();
      await h.container.read(earlierVideosControllerProvider.future);
      h.bridge.failNext('accessReport');

      await expectLater(
        notifier().add(today),
        throwsA(isA<PlatformException>()),
      );

      expect(await h.media.toTag(), isEmpty);
    });

    test('a failing recount after a good add keeps the ids', () async {
      final bridge = _FailsLater();
      final local = VmHarness(now: _nowLocal.toUtc(), bridge: bridge);
      bridge.put([shot(1, DateTime(2026, 6, 10, 10))]);
      local.container.listen(earlierVideosControllerProvider, (_, _) {});
      await local.container.read(earlierVideosControllerProvider.future);
      bridge.failFrom = bridge._calls + 2; // add reads once, the recount fails

      final ids = await local.container
          .read(earlierVideosControllerProvider.notifier)
          .add(today);

      expect(ids, hasLength(1));
      expect(
        local.container.read(earlierVideosControllerProvider).value,
        1,
        reason: 'the old counts stay',
      );
    });

    test('closing the sheet while it adds does not crash', () async {
      final sub = open();
      await h.container.read(earlierVideosControllerProvider.future);
      final gate = h.bridge.gate('videosShotSince');

      final adding = notifier().add(today);
      await settle();
      sub.close(); // the auto-dispose provider goes away
      await settle();
      gate.complete();

      expect(await adding, hasLength(1));
      expect(await h.media.toTag(), hasLength(1));
    });
  });

  group('undo', () {
    test(
      'removes exactly the added clips and keeps older To tag clips',
      () async {
        // Two clips that were already in To tag (a scan found them).
        await h.media.store([
          fakeVideo(id: 90, generation: 90, sizeBytes: 5),
          fakeVideo(
            id: 91,
            generation: 91,
            sizeBytes: 6,
            dateTakenMs: 1780000100000,
          ),
        ]);
        final older = {for (final c in await h.media.toTag()) c.id};
        open();
        await h.container.read(earlierVideosControllerProvider.future);
        final ids = await notifier().add(june(2, 10));
        expect(ids, hasLength(3));

        await notifier().undo(ids);

        expect({for (final c in await h.media.toTag()) c.id}, older);
        expect((await h.media.allClips()).map((c) => c.id).toSet(), older);
      },
    );

    test('counts those videos again afterwards', () async {
      open();
      await h.container.read(earlierVideosControllerProvider.future);
      final ids = await notifier().add(june(2, 10));
      expect(shown(), 0);

      await notifier().undo(ids);

      expect(shown(), 1);
    });

    test('a clip tagged in between survives with its reel', () async {
      open();
      await h.container.read(earlierVideosControllerProvider.future);
      final ids = await notifier().add(today);
      final goa = (await ReelsRepository(
        h.media.db,
        h.media.clock,
      ).create('Goa')).id;
      await h.media.clips.tagClip(ids.single, {goa});

      await notifier().undo(ids);

      expect((await h.media.allClips()).map((c) => c.id), ids);
      expect(
        (await h.media.clips.watchReelClips(goa).first).map((c) => c.clip.id),
        ids,
      );
    });

    test('a clip skipped in between survives', () async {
      open();
      await h.container.read(earlierVideosControllerProvider.future);
      final ids = await notifier().add(today);
      await h.media.clips.skipClips(ids);

      await notifier().undo(ids);

      expect((await h.media.skipped()).map((c) => c.id), ids);
    });

    test('undo with no ids does nothing', () async {
      await h.media.store([fakeVideo(id: 90, generation: 90)]);
      open();
      await h.container.read(earlierVideosControllerProvider.future);

      await notifier().undo(const []);

      expect(await h.media.toTag(), hasLength(1));
    });

    test('undo twice is harmless', () async {
      open();
      await h.container.read(earlierVideosControllerProvider.future);
      final ids = await notifier().add(today);

      await notifier().undo(ids);
      await notifier().undo(ids);

      expect(await h.media.toTag(), isEmpty);
    });

    test('waits for a scan that is running', () async {
      await h.media.turnOnNow();
      open();
      await h.container.read(earlierVideosControllerProvider.future);
      final ids = await notifier().add(today);
      h.bridge.put([fakeVideo(id: 50, generation: 50)]);
      final gate = h.bridge.gate('videosAddedAfter');
      final scan = h.container.read(mediaScannerProvider).scan();
      await settle();

      var undone = false;
      final undoing = notifier().undo(ids).then((_) => undone = true);
      await settle();
      expect(undone, isFalse, reason: 'the scan holds the queue');
      expect(
        {for (final c in await h.media.toTag()) c.id},
        ids.toSet(),
        reason: 'the undo has not deleted anything while the scan runs',
      );

      gate.complete();
      await scan;
      await undoing;
      expect(undone, isTrue);
      expect({
        for (final c in await h.media.toTag()) c.id,
      }, isNot(contains(ids.single)));
    });

    test('a database error is rethrown to the caller', () async {
      final records = captureLogs();
      open();
      await h.container.read(earlierVideosControllerProvider.future);
      final ids = await notifier().add(today);
      await h.media.db.close();

      await expectLater(notifier().undo(ids), throwsA(anything));

      expect(logText(records), contains('Undoing the earlier videos failed'));
    });
  });
}
