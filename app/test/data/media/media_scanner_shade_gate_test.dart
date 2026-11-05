import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/data/background/background_sync.dart';
import 'package:taketray/data/background/shade_actions.dart';
import 'package:taketray/data/media/media_scanner.dart';
import 'package:taketray/data/repositories/phone_state_repository.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/features/tagging/view_models/to_tag_controller.dart';
import 'package:taketray/platform/background_bridge.dart';

import '../../support/fake_media_bridge.dart';
import '../../support/vm_harness.dart';

// The shade gate (D-106, fix round 1): every scan, whoever triggers it,
// first looks for a shade action inside its own queued job. A Turn off for
// the current session replaces the scan with the end capped at the tap.

MediaVideo _video(int id, int generation) =>
    fakeVideo(id: id, generation: generation, sizeBytes: 1000000 + id);

final DateTime _tap = DateTime.utc(2026, 6, 1, 18);

/// A phone state whose `markStillAnswered` fails like a full disk.
class _FailingMark extends PhoneStateRepository {
  _FailingMark(super._db, super._clock);

  @override
  Future<bool> markStillAnswered(DateTime since) async =>
      throw StateError('database is full');
}

late VmHarness h;
late DateTime since;

MediaScanner get scanner => h.container.read(mediaScannerProvider);

Matcher _done({required int added, Set<String> failed = const {}}) =>
    isA<ScanDone>()
        .having((d) => d.added, 'added', added)
        .having((d) => d.failedVolumes, 'failedVolumes', failed);

Future<Set<int>> _toTagIds() async => {
  for (final c in await h.media.toTag()) c.mediaStoreId!,
};

/// A Turn off tapped in the shade at generation 12 for the current session.
void _tapTurnOff({DateTime? forSession}) =>
    h.background.shadeAction = ShadeAction(
      kind: ShadeActionKind.turnOff,
      since: forSession ?? since,
      at: _tap,
      generations: const {'external_primary': 12},
    );

void main() {
  setUp(() async {
    h = VmHarness();
    h.bridge.put([_video(1, 10)]);
    since = (await h.media.turnOnNow()).since!;
    // 11 and 12 shot before the tap (generation 12 then), 13 and 14 after.
    h.bridge.put([
      _video(11, 11),
      _video(12, 12),
      _video(13, 13),
      _video(14, 14),
    ]);
  });

  group('every trigger', () {
    test("to tag's scan with a pending turn off adds only clips shot before "
        'the tap', () async {
      _tapTurnOff();
      h.container.listen<AsyncValue<List<Clip>>>(
        toTagControllerProvider,
        (_, _) {},
      );

      await settle();

      expect(await _toTagIds(), {11, 12});
      expect(await h.media.phoneState.loadShooting(), ShootingState.off);
      expect(h.background.shadeAction, isNull);
    });

    test('two triggers at once with a pending turn off add only pre-tap '
        'clips', () async {
      _tapTurnOff();

      await Future.wait([
        scanner.scan(),
        h.container.read(shadeActionsProvider).apply(),
        scanner.scan(),
      ]);

      expect(await _toTagIds(), {11, 12});
      expect(await h.media.phoneState.loadShooting(), ShootingState.off);
    });

    test('a cold start from the notification with a pending turn off is '
        'capped', () async {
      _tapTurnOff();
      // To tag is built first (the notification opened it), and its scan
      // joins the queue before the lifecycle's first-frame apply.
      h.container.listen<AsyncValue<List<Clip>>>(
        toTagControllerProvider,
        (_, _) {},
      );
      final apply = h.container.read(shadeActionsProvider).apply();
      final lifecycleScan = scanner.scan();
      await Future.wait([apply, lifecycleScan]);
      await settle();

      expect(await _toTagIds(), {11, 12});
      expect(await h.media.phoneState.loadShooting(), ShootingState.off);
    });
  });

  group('reading the shade action', () {
    test('reading the shade action fails: the scan is deferred and nothing '
        'moves', () async {
      h.background.failNext('pendingShadeAction');

      final outcome = await scanner.scan();

      expect(outcome, isA<ScanDeferred>());
      expect(await h.media.allClips(), isEmpty);
      expect(await h.media.baselineOf('external_primary'), isNotNull);
      expect((await h.media.baselineOf('external_primary'))!.generation, 10);
      expect(h.bridge.count('volumes'), 0);
    });

    test('a deferred scan runs on the next trigger', () async {
      h.background.failNext('pendingShadeAction');
      expect(await scanner.scan(), isA<ScanDeferred>());

      expect(await scanner.scan(), _done(added: 4));
      expect(await _toTagIds(), {11, 12, 13, 14});
    });

    test(
      'keep on pending, then scan: marked answered and the scan runs',
      () async {
        h.background.shadeAction = ShadeAction(
          kind: ShadeActionKind.keepOn,
          since: since,
          at: _tap,
          generations: const {},
        );

        expect(await scanner.scan(), _done(added: 4));

        final state = await h.media.phoneState.loadShooting();
        expect(state.stillAnswered, isTrue);
        expect(state.on, isTrue);
        expect(h.background.shadeAction, isNull);
      },
    );

    test('a stale action is cleared and the scan runs', () async {
      _tapTurnOff(forSession: since.subtract(const Duration(days: 3)));

      expect(await scanner.scan(), _done(added: 4));

      expect((await h.media.phoneState.loadShooting()).on, isTrue);
      expect(h.background.shadeAction, isNull);
      expect(h.background.clearedShadeActions, [_tap]);
    });
  });

  group('a failed stale or keep on step never blocks the scan', () {
    test('a failing clear for a stale action still scans', () async {
      _tapTurnOff(forSession: since.subtract(const Duration(days: 3)));
      h.background.failNext('clearShadeAction');
      final records = captureLogs();

      expect(await scanner.scan(), _done(added: 4));

      expect((await h.media.phoneState.loadShooting()).on, isTrue);
      expect(logText(records), contains('PlatformException'));
      expect(logText(records), isNot(contains('failed on purpose')));
    });

    test('a failing mark answered for keep on still scans', () async {
      final m = h.media;
      final failing = MediaScanner(
        m.bridge,
        m.clips,
        _FailingMark(m.db, m.clock),
        m.settings,
        m.zones,
        m.zoneSync,
        m.queue,
        m.clock,
        m.background,
      );
      h.background.shadeAction = ShadeAction(
        kind: ShadeActionKind.keepOn,
        since: since,
        at: _tap,
        generations: const {},
      );
      final records = captureLogs();

      expect(await failing.scan(), _done(added: 4));

      expect(logText(records), contains('StateError'));
      expect(logText(records), isNot(contains('database is full')));
    });
  });

  group('the end', () {
    test('a volume failing during the end keeps the session and the '
        'action', () async {
      _tapTurnOff();
      h.bridge.failNext('videosAddedAfter');

      final outcome = await scanner.scan();

      expect(outcome, _done(added: 0, failed: {'external_primary'}));
      final state = await h.media.phoneState.loadShooting();
      expect(state.on, isTrue);
      expect(state.since, since);
      expect(h.background.shadeAction, isNotNull);
      // Nothing after the tap came in through a plain scan either.
      expect(await h.media.allClips(), isEmpty);
    });

    test('the end is retried on the next trigger and adds the pre-tap '
        'clips', () async {
      _tapTurnOff();
      h.bridge.failNext('videosAddedAfter');
      await scanner.scan();

      expect(await scanner.scan(), _done(added: 2));

      expect(await _toTagIds(), {11, 12});
      expect(await h.media.phoneState.loadShooting(), ShootingState.off);
      expect(h.background.shadeAction, isNull);
    });

    test('three counted failures end the session', () async {
      _tapTurnOff();
      final records = captureLogs();
      for (var i = 0; i < 3; i++) {
        h.bridge.failNext('videosAddedAfter');
      }

      await scanner.scan();
      h.media.clock.advance(const Duration(minutes: 5));
      await scanner.scan();
      expect((await h.media.phoneState.loadShooting()).on, isTrue);
      h.media.clock.advance(const Duration(minutes: 5));

      final third = await scanner.scan();

      expect(third, _done(added: 0, failed: {'external_primary'}));
      expect(await h.media.phoneState.loadShooting(), ShootingState.off);
      expect(h.background.shadeAction, isNull);
      expect(await h.media.allClips(), isEmpty);
      final text = logText(records);
      expect(text, contains('after 3 attempts'));
      expect(text, isNot(contains('2026')));
    });

    test('failures 5 minutes apart count; closer ones do not', () async {
      _tapTurnOff();
      final records = captureLogs();
      for (var i = 0; i < 6; i++) {
        h.bridge.failNext('videosAddedAfter');
      }
      Future<bool> stillOn() async =>
          (await h.media.phoneState.loadShooting()).on;

      await scanner.scan(); // counted: 1
      h.media.clock.advance(const Duration(minutes: 4, seconds: 59));
      await scanner.scan(); // too soon: not counted
      h.media.clock.advance(const Duration(seconds: 1));
      await scanner.scan(); // 5 minutes after the first: 2
      h.media.clock.advance(const Duration(minutes: 1));
      await scanner.scan(); // too soon
      expect(await stillOn(), isTrue);
      expect(h.background.shadeAction, isNotNull);
      expect(logText(records), contains('not counted'));

      h.media.clock.advance(const Duration(minutes: 4));
      await scanner.scan(); // 5 minutes after the second: 3, ends

      expect(await stillOn(), isFalse);
      expect(h.background.shadeAction, isNull);
    });

    test('no full access at the end: the session ends at once', () async {
      _tapTurnOff();
      h.bridge.access = const MediaAccess(
        level: MediaAccessLevel.denied,
        canAskAgain: true,
        sdkInt: 34,
      );

      expect(await scanner.scan(), isA<ScanNoAccess>());

      expect(await h.media.phoneState.loadShooting(), ShootingState.off);
      expect(h.background.shadeAction, isNull);
      expect(await h.media.allClips(), isEmpty);
    });

    test('no queue job waits on another', () async {
      _tapTurnOff();
      h.bridge.failNext('videosAddedAfter');
      final sync = h.container.read(backgroundSyncProvider)..start();
      var done = 0;

      // Every way into the queue at once, with a Turn off that fails once.
      for (final job in <Future<Object?>>[
        scanner.scan(),
        h.container.read(shadeActionsProvider).apply(),
        h.container.read(shadeActionsProvider).apply(),
        scanner.countEarlier(),
        sync.flush(),
        scanner.scan(),
      ]) {
        job.then((_) => done++, onError: (Object _) => done++).ignore();
      }
      await until(() => done == 6);

      expect(await h.media.phoneState.loadShooting(), ShootingState.off);
    });
  });
}
