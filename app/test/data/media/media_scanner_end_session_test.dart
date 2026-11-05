import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/data/media/media_scanner.dart';
import 'package:taketray/domain/models/media.dart';

import '../../support/fake_media_bridge.dart';
import 'media_harness.dart';

// `MediaScanner.endSessionAt` (D-106): a shade Turn off, applied by Dart. It
// scans each volume the tap named up to the generation it had at the tap, then
// turns Shooting mode off, in one job on the media queue.

/// A finished video on [volume] with MediaStore id [id] at [generation].
MediaVideo _video(
  int id,
  int generation, {
  String volume = phone,
  bool pending = false,
}) => fakeVideo(
  id: id,
  generation: generation,
  volume: volume,
  pending: pending,
  sizeBytes: 1000000 + id,
);

late MediaHarness h;

RecordingBridge get bridge => h.bridge;

Matcher _done({
  required int added,
  Set<String> resynced = const {},
  Set<String> failed = const {},
}) => isA<ScanDone>()
    .having((d) => d.added, 'added', added)
    .having((d) => d.resynced, 'resynced', resynced)
    .having((d) => d.failedVolumes, 'failedVolumes', failed);

Future<Set<int>> _toTagIds() async => {
  for (final c in await h.toTag()) c.mediaStoreId!,
};

void main() {
  late DateTime since;

  setUp(() async {
    h = MediaHarness();
    // Shooting mode on at generation 10 of the phone's storage.
    bridge.put([_video(1, 10)]);
    since = (await h.turnOnNow()).since!;
  });

  test('clips shot before the tap are added', () async {
    bridge.put([_video(11, 11), _video(12, 12)]);

    final outcome = await h.scanner.endSessionAt(
      since: since,
      generations: {phone: 12},
    );

    expect(outcome, _done(added: 2));
    expect(await _toTagIds(), {11, 12});
    expect(await h.phoneState.loadShooting(), ShootingState.off);
  });

  test('clips shot after the tap are not added', () async {
    // 11 and 12 before the tap (generation 12 at the tap), 13 and 14 after.
    bridge.put([
      _video(11, 11),
      _video(12, 12),
      _video(13, 13),
      _video(14, 14),
    ]);

    final outcome = await h.scanner.endSessionAt(
      since: since,
      generations: {phone: 12},
    );

    expect(outcome, _done(added: 2));
    expect(await _toTagIds(), {11, 12});
    expect(await h.phoneState.loadShooting(), ShootingState.off);
    // A later scan (Shooting mode off) adds nothing either.
    expect(await h.scanner.scan(), isA<ScanShootingOff>());
    expect(await _toTagIds(), {11, 12});
  });

  test('clips after the tap stay out across pages', () async {
    // More rows than a page, every one after the tap but the first.
    bridge.put([
      _video(11, 11),
      for (var i = 0; i < MediaScanner.pageSize + 5; i++)
        _video(100 + i, 12 + i),
    ]);

    final outcome = await h.scanner.endSessionAt(
      since: since,
      generations: {phone: 11},
    );

    expect(outcome, _done(added: 1));
    expect(await _toTagIds(), {11});
  });

  test('a session that changed is left alone', () async {
    bridge.put([_video(11, 11)]);

    final outcome = await h.scanner.endSessionAt(
      since: since.subtract(const Duration(minutes: 1)),
      generations: {phone: 11},
    );

    expect(outcome, isA<ScanShootingOff>());
    expect(await h.allClips(), isEmpty);
    final state = await h.phoneState.loadShooting();
    expect(state.on, isTrue);
    expect(state.since, since);
    expect(bridge.count('videosAddedAfter'), 0);
  });

  test('with Shooting mode already off it changes nothing', () async {
    await h.phoneState.turnShootingOff();
    bridge.put([_video(11, 11)]);

    final outcome = await h.scanner.endSessionAt(
      since: since,
      generations: {phone: 11},
    );

    expect(outcome, isA<ScanShootingOff>());
    expect(await h.allClips(), isEmpty);
  });

  test('a session stored with microseconds matches the tap', () async {
    await h.phoneState.turnShootingOff();
    h.clock.advance(const Duration(microseconds: 789));
    since = (await h.turnOnNow()).since!;
    bridge.put([_video(11, 11)]);

    final outcome = await h.scanner.endSessionAt(
      since: DateTime.fromMillisecondsSinceEpoch(
        since.millisecondsSinceEpoch,
        isUtc: true,
      ),
      generations: {phone: 11},
    );

    expect(outcome, _done(added: 1));
    expect(await h.phoneState.loadShooting(), ShootingState.off);
  });

  test('volumes not in generations are skipped', () async {
    // An SD card baselined in the session, left out of the tap's map (the
    // phone could not read it then).
    await h.phoneState.turnShootingOff();
    bridge.put(
      [_video(50, 3, volume: card)],
      volume: card,
      version: 'c1',
    );
    since = (await h.turnOnNow()).since!;
    bridge
      ..put([_video(11, 11)])
      ..put(
        [_video(51, 4, volume: card)],
        volume: card,
        version: 'c1',
      );
    final records = captureLogs();

    final outcome = await h.scanner.endSessionAt(
      since: since,
      generations: {phone: 11},
    );

    expect(outcome, _done(added: 1));
    expect(await _toTagIds(), {11});
    expect(bridge.addedAfter.where((a) => a.$1 == card), isEmpty);
    expect(logText(records), contains('Volume $card: not in the tap'));
  });

  test('an empty generations map adds nothing and turns off', () async {
    bridge.put([_video(11, 11)]);

    final outcome = await h.scanner.endSessionAt(
      since: since,
      generations: const {},
    );

    expect(outcome, _done(added: 0));
    expect(await h.allClips(), isEmpty);
    expect(bridge.count('videosAddedAfter'), 0);
    expect(await h.phoneState.loadShooting(), ShootingState.off);
  });

  test('a volume rebuilt between the tap and the apply is resynced, not '
      'scanned', () async {
    // A clip from the session, then Android rebuilds the library: a new
    // version whose generations start again.
    bridge.put([_video(11, 11)]);
    await h.scanner.scan();
    bridge.videosByVolume[phone] = [
      _video(201, 2).copyWith(sizeBytes: 1000011),
      _video(202, 3),
    ];
    bridge.setVolume(phone, version: 'v2', generation: 3);

    final outcome = await h.scanner.endSessionAt(
      since: since,
      generations: {phone: 11},
    );

    expect(outcome, _done(added: 0, resynced: {phone}));
    // The stored clip was found again under its new number; nothing new.
    expect(await _toTagIds(), {201});
    expect(await h.phoneState.loadShooting(), ShootingState.off);
  });

  test('a volume that is no longer mounted is skipped', () async {
    bridge
      ..put([_video(11, 11)])
      ..setVolume(phone, version: null);

    final outcome = await h.scanner.endSessionAt(
      since: since,
      generations: {phone: 11},
    );

    expect(outcome, _done(added: 0));
    expect(bridge.count('videosAddedAfter'), 0);
    expect(await h.phoneState.loadShooting(), ShootingState.off);
  });

  test('a held pending row below the cap is not added; the clips around it '
      'are', () async {
    bridge.put([_video(11, 11, pending: true), _video(12, 12), _video(13, 13)]);

    final outcome = await h.scanner.endSessionAt(
      since: since,
      generations: {phone: 13},
    );

    expect(outcome, _done(added: 2));
    expect(await _toTagIds(), {12, 13});
    expect(await h.phoneState.loadShooting(), ShootingState.off);
  });

  test('a volume that does not answer is logged, and the session still '
      'ends', () async {
    bridge
      ..put([_video(11, 11)])
      ..failNext('videosAddedAfter');

    final outcome = await h.scanner.endSessionAt(
      since: since,
      generations: {phone: 11},
    );

    expect(outcome, _done(added: 0, failed: {phone}));
    expect(await h.phoneState.loadShooting(), ShootingState.off);
  });

  test('without full access it turns off and reads nothing', () async {
    bridge
      ..put([_video(11, 11)])
      ..access = const MediaAccess(
        level: MediaAccessLevel.limited,
        canAskAgain: true,
        sdkInt: 34,
      );

    final outcome = await h.scanner.endSessionAt(
      since: since,
      generations: {phone: 11},
    );

    expect(outcome, isA<ScanNoAccess>());
    expect(await h.allClips(), isEmpty);
    expect(await h.phoneState.loadShooting(), ShootingState.off);
  });

  test('when the phone does not answer at all it changes nothing and '
      'throws', () async {
    bridge
      ..put([_video(11, 11)])
      ..failNext('volumes');

    await expectLater(
      h.scanner.endSessionAt(since: since, generations: {phone: 11}),
      throwsA(isA<Exception>()),
    );

    expect(await h.allClips(), isEmpty);
    expect((await h.phoneState.loadShooting()).since, since);
  });

  test('never shares a run with scan()', () async {
    bridge.put([_video(11, 11), _video(12, 12)]);
    final gate = bridge.gate('videosAddedAfter');

    final scan = h.scanner.scan();
    await until(() => bridge.count('videosAddedAfter') == 1);
    final end = h.scanner.endSessionAt(since: since, generations: {phone: 11});
    final scanAgain = h.scanner.scan();
    await settle();
    // The end waits for the running scan: one at a time.
    expect(bridge.count('volumes'), 1);

    gate.complete();
    expect(await scan, _done(added: 2));
    expect(await end, _done(added: 0));
    // The scan queued after the end is its own run, and finds Shooting mode
    // off.
    expect(await scanAgain, isA<ScanShootingOff>());
    expect(bridge.count('volumes'), 2);
  });

  test(
    'turned off and on again while it runs, the new session stays',
    () async {
      bridge.put([_video(11, 11)]);
      final gate = bridge.gate('videosAddedAfter');

      final end = h.scanner.endSessionAt(
        since: since,
        generations: {phone: 11},
      );
      await until(() => bridge.count('videosAddedAfter') == 1);
      await h.phoneState.turnShootingOff();
      h.clock.advance(const Duration(minutes: 1));
      final next = await h.turnOnNow();
      gate.complete();
      await end;

      final state = await h.phoneState.loadShooting();
      expect(state.on, isTrue);
      expect(state.since, next.since);
    },
  );

  test('logs no folder, version or time', () async {
    final records = captureLogs();
    bridge.put([_video(11, 11)]);

    await h.scanner.endSessionAt(since: since, generations: {phone: 11});

    final text = logText(records);
    expect(text, contains('Ended the session'));
    expect(text, isNot(contains('DCIM')));
    expect(text, isNot(contains('v1')));
    expect(text, isNot(contains('2026')));
  });
}
