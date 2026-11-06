import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/data/media/media_scanner.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/platform/background_bridge.dart';

import '../../support/fake_media_bridge.dart';
import 'media_harness.dart';

// M-8 (D-108): a volume with no baseline while Shooting mode is on (its read
// failed at switch-on, or an SD card was inserted later) adds the clips shot
// since the session started, instead of starting from now.

/// The clock of every test (the harness default) is also the session start.
final DateTime _start = DateTime.utc(2026, 6, 1, 9);

/// A video on the card shot [afterStart] after the session began (negative:
/// before). Its dates are all its shooting time.
MediaVideo shotOnCard(
  int id,
  int generation,
  Duration afterStart, {
  String volume = card,
  String folder = 'DCIM/Camera/',
  int? durationMs = 5000,
  bool pending = false,
}) {
  final shot = _start.add(afterStart);
  return fakeVideo(
    id: id,
    generation: generation,
    volume: volume,
    folder: folder,
    pending: pending,
    durationMs: durationMs,
    sizeBytes: 1000000 + id,
    dateTakenMs: shot.millisecondsSinceEpoch,
    dateAddedSec: shot.millisecondsSinceEpoch ~/ 1000,
    dateModifiedSec: shot.millisecondsSinceEpoch ~/ 1000,
  );
}

const Duration _hour = Duration(hours: 1);

VolumeBaseline at(int generation, [String version = 'c1']) =>
    VolumeBaseline(version: version, generation: generation);

Matcher scanDone({required int added, Set<String> failed = const {}}) =>
    isA<ScanDone>()
        .having((d) => d.added, 'added', added)
        .having((d) => d.resynced, 'resynced', isEmpty)
        .having((d) => d.failedVolumes, 'failedVolumes', failed);

/// A bridge whose `videosShotSince` also returns pending rows. The phone's
/// query leaves them out (the contract in `pigeons/media_api.dart`), so this
/// proves nothing about the phone: it pins that a pending row that did show
/// up would not be added and would not hold the baseline either.
class _PendingVisible extends RecordingBridge {
  @override
  Future<List<MediaVideo>> videosShotSince(
    String volumeName,
    List<String> folders,
    int sinceMs,
  ) async {
    calls.add('videosShotSince');
    return List.of(videosByVolume[volumeName] ?? const []);
  }
}

MediaHarness? _built;
MediaHarness Function() _make = MediaHarness.new;
MediaHarness get h => _built ??= _make();
RecordingBridge get bridge => h.bridge;

Future<Set<int>> _onCard() async => {
  for (final c in await h.toTag())
    if (c.volumeName == card) c.mediaStoreId!,
};

void main() {
  setUp(() {
    _built = null;
    _make = MediaHarness.new;
  });

  /// The phone has a video, Shooting mode goes on, and the card is not there.
  Future<void> shootingWithPhoneOnly() async {
    bridge.put([fakeVideo(id: 1)]);
    await h.turnOnNow();
  }

  group('a volume with no baseline', () {
    test('new volume adds clips shot since the session start', () async {
      await shootingWithPhoneOnly();
      bridge.put(
        [shotOnCard(1, 1, _hour), shotOnCard(2, 2, _hour * 2)],
        volume: card,
        version: 'c1',
      );

      final outcome = await h.scanner.scan();

      expect(outcome, scanDone(added: 2));
      expect(await _onCard(), {1, 2});
      expect(await h.baselineOf(card), at(2));
      // Asked once, for the session's start; the paged query is not used.
      expect(bridge.count('videosShotSince'), 1);
      expect(
        bridge.addedAfter.where((q) => q.$1 == card),
        isEmpty,
        reason: 'no paging from generation 0',
      );
    });

    test('new volume skips clips shot before', () async {
      await shootingWithPhoneOnly();
      bridge.put(
        [shotOnCard(1, 1, -_hour * 48), shotOnCard(2, 2, -_hour)],
        volume: card,
        version: 'c1',
      );

      final outcome = await h.scanner.scan();

      expect(outcome, scanDone(added: 0));
      expect(await _onCard(), isEmpty);
      expect(await h.baselineOf(card), at(2));

      // Later clips are new in the ordinary way.
      bridge.put([shotOnCard(3, 3, _hour)], volume: card, version: 'c1');
      expect(await h.scanner.scan(), scanDone(added: 1));
      expect(await _onCard(), {3});
    });

    test('an old clip copied onto the card during the session is not new, '
        'though the phone lists it', () async {
      await shootingWithPhoneOnly();
      // The query is a superset: DATE_ADDED after the start lists it, but it
      // was shot two days before the session (`shotAt` says so).
      final copied = fakeVideo(
        id: 1,
        volume: card,
        sizeBytes: 5001,
        dateTakenMs: _start
            .subtract(const Duration(days: 2))
            .millisecondsSinceEpoch,
        dateAddedSec: _start.add(_hour).millisecondsSinceEpoch ~/ 1000,
      );
      bridge.put([copied], volume: card, version: 'c1');

      expect(await h.scanner.scan(), scanDone(added: 0));

      expect(bridge.count('videosShotSince'), 1);
      expect(await _onCard(), isEmpty);
      expect(await h.baselineOf(card), at(1));
    });

    test('a clip shot exactly at the session start is added, one a '
        'millisecond before is not', () async {
      await shootingWithPhoneOnly();
      bridge.put(
        [
          shotOnCard(1, 1, Duration.zero),
          shotOnCard(2, 2, const Duration(milliseconds: -1)),
        ],
        volume: card,
        version: 'c1',
      );

      expect(await h.scanner.scan(), scanDone(added: 1));

      expect(await _onCard(), {1});
    });

    test('new volume skips existing clips', () async {
      await shootingWithPhoneOnly();
      final known = shotOnCard(1, 1, _hour);
      final second = shotOnCard(2, 2, _hour);
      final skipped = shotOnCard(3, 3, _hour);
      final fresh = shotOnCard(4, 4, _hour);
      bridge.put([known, second, skipped, fresh], volume: card, version: 'c1');
      final ids = await h.store([known, second, skipped]);
      await h.clips.skipClips([ids[2]]);

      final outcome = await h.scanner.scan();

      expect(outcome, scanDone(added: 1));
      expect(await _onCard(), {1, 2, 4}, reason: 'skipped stays skipped');
      expect({for (final c in await h.skipped()) c.mediaStoreId}, {3});
      expect(await h.allClips(), hasLength(4));
      // The clips that were there keep their first-seen time and place.
      expect((await h.clip(ids[0])).firstSeenAt, h.clock.now());
    });

    test('a held row on a new card never lets older card videos in on the '
        'next scan', () async {
      await shootingWithPhoneOnly();
      h.clock.advance(_hour * 3);
      // A card indexes in no order: videos shot long before the session can
      // get higher generations than one shot during it. Row 3 was shot an
      // hour ago and has no length yet (it would hold a baseline).
      bridge.put(
        [
          shotOnCard(1, 1, -_hour * 48),
          shotOnCard(2, 2, _hour),
          shotOnCard(3, 3, _hour * 2, durationMs: 0),
          shotOnCard(4, 4, -_hour * 72),
          shotOnCard(5, 5, -_hour * 24),
        ],
        volume: card,
        version: 'c1',
      );

      expect(await h.scanner.scan(), scanDone(added: 1));
      expect(await _onCard(), {2});
      expect(await h.baselineOf(card), at(5), reason: 'never held');

      // Its length arrives. The next scan is a plain `ScanAfter`, with no
      // date filter: had the baseline held at 2, rows 4 and 5 would come in.
      bridge.videosByVolume[card] = [
        for (final v in bridge.videosByVolume[card]!)
          if (v.mediaStoreId == 3) v.copyWith(durationMs: 5000) else v,
      ];
      expect(await h.scanner.scan(), scanDone(added: 0));
      expect(await _onCard(), {2}, reason: 'nothing shot before the session');
    });

    test('a zero-length video at the first card scan is not added and the '
        'baseline moves to captured', () async {
      await shootingWithPhoneOnly();
      h.clock.advance(_hour * 4);
      bridge.put(
        [
          shotOnCard(1, 5, _hour),
          shotOnCard(2, 6, _hour * 2, durationMs: 0),
          shotOnCard(3, 7, _hour * 3),
        ],
        volume: card,
        version: 'c1',
      );

      expect(await h.scanner.scan(), scanDone(added: 2));
      expect(await _onCard(), {1, 3});
      expect(await h.baselineOf(card), at(7));

      // Its length arrives, but the baseline is past it: the gap (D-108).
      // "Add earlier videos" brings it in.
      bridge.videosByVolume[card] = [
        shotOnCard(1, 5, _hour),
        shotOnCard(2, 6, _hour * 2),
        shotOnCard(3, 7, _hour * 3),
      ];
      expect(await h.scanner.scan(), scanDone(added: 0));
      expect(await _onCard(), {1, 3});
      expect(await h.baselineOf(card), at(7));
    });

    test('a pending row at the first card scan is left out by the bridge, so '
        'it is not added (a pin of the bridge contract: the production rule '
        'is `shotSinceSession` and the next test)', () async {
      await shootingWithPhoneOnly();
      h.clock.advance(_hour * 4);
      bridge.put(
        [
          shotOnCard(1, 5, _hour),
          shotOnCard(2, 6, _hour * 2, pending: true),
          shotOnCard(3, 7, _hour * 3),
        ],
        volume: card,
        version: 'c1',
      );

      // The phone's `videosShotSince` leaves pending rows out (the fake
      // does the same), so the scanner never sees this one; no production
      // code here could make this fail. The test pins the contract the gap
      // in D-108 relies on.
      expect(await h.scanner.scan(), scanDone(added: 2));
      expect(await _onCard(), {1, 3});
      expect(await h.baselineOf(card), at(7));

      // The recording ends; the baseline is past it: the gap (D-108).
      bridge.videosByVolume[card] = [
        shotOnCard(1, 5, _hour),
        shotOnCard(2, 6, _hour * 2),
        shotOnCard(3, 7, _hour * 3),
      ];
      expect(await h.scanner.scan(), scanDone(added: 0));
      expect(await _onCard(), {1, 3});
    });

    test('a pending row from a bridge that lists one (the phone never '
        'does) is not added and holds nothing', () async {
      _make = () => MediaHarness(bridge: _PendingVisible());
      await shootingWithPhoneOnly();
      h.clock.advance(_hour * 4);
      bridge.put(
        [
          shotOnCard(1, 5, _hour),
          shotOnCard(2, 6, _hour * 2, pending: true),
          shotOnCard(3, 7, _hour * 3),
        ],
        volume: card,
        version: 'c1',
      );

      final outcome = await h.scanner.scan();

      expect(outcome, scanDone(added: 2));
      expect(await _onCard(), {1, 3});
      expect(await h.baselineOf(card), at(7));
    });

    test('a clip outside the watched folders is not added', () async {
      await shootingWithPhoneOnly();
      bridge.put(
        [
          shotOnCard(1, 1, _hour),
          shotOnCard(2, 2, _hour, folder: 'Movies/Other/'),
        ],
        volume: card,
        version: 'c1',
      );

      expect(await h.scanner.scan(), scanDone(added: 1));

      expect(await _onCard(), {1});
    });

    test('after a switch-on that could not read the volumes, the first scan '
        'adds the clips shot since', () async {
      bridge.put([
        shotOnCard(1, 1, -_hour, volume: phone),
        shotOnCard(2, 2, _hour, volume: phone),
      ]);
      await h.turnOn({});

      expect(await h.scanner.scan(), scanDone(added: 1));

      expect([for (final c in await h.toTag()) c.mediaStoreId], [2]);
      expect(await h.baselineOf(phone), at(2, 'v1'));
    });

    test('1200 clips since the start are added from one query', () async {
      await shootingWithPhoneOnly();
      bridge.put(
        [
          for (var i = 1; i <= 1200; i++)
            shotOnCard(i, i, Duration(minutes: i)),
        ],
        volume: card,
        version: 'c1',
      );

      expect(await h.scanner.scan(), scanDone(added: 1200));

      expect(bridge.count('videosShotSince'), 1);
      expect(await h.baselineOf(card), at(1200));
    });

    test('a stored clip holding a number of another video is detached and '
        'the video added (Ruling U)', () async {
      await shootingWithPhoneOnly();
      // Clip 1 on the card is a video of another day that held number 5.
      final other = shotOnCard(5, 1, -_hour * 40);
      final stale = (await h.store([other])).single;
      // In a reel, so the detached clip stays to be looked at (Ruling Y).
      final reel = await ReelsRepository(h.db, h.clock).create('Goa');
      await h.clips.addClipsToReel(reel.id, [stale]);
      bridge.put(
        [shotOnCard(5, 2, _hour).copyWith(sizeBytes: 5)],
        volume: card,
        version: 'c1',
      );

      expect(await h.scanner.scan(), scanDone(added: 1));

      expect((await h.clip(stale)).missing, isTrue);
      expect((await h.clip(stale)).mediaStoreId, -stale);
      expect(await _onCard(), {5});
    });

    test('the log has the volume name and counts, never a name or a '
        'folder', () async {
      await shootingWithPhoneOnly();
      bridge.put(
        [
          fakeVideo(
            id: 1,
            volume: card,
            name: 'Secret_take.mp4',
            dateTakenMs: _start.add(_hour).millisecondsSinceEpoch,
            sizeBytes: 77,
          ),
        ],
        volume: card,
        version: 'secret-version',
      );
      final records = captureLogs();

      await h.scanner.scan();

      final text = logText(records);
      expect(text, contains(card));
      for (final secret in ['Secret', 'secret', '.mp4', 'DCIM']) {
        expect(text, isNot(contains(secret)));
      }
    });
  });

  group('failures', () {
    test('a failing videosShotSince keeps the volume without a baseline; '
        'the next scan adds the clips', () async {
      await shootingWithPhoneOnly();
      bridge
        ..put([shotOnCard(1, 1, _hour)], volume: card, version: 'c1')
        ..failNext('videosShotSince');

      final outcome = await h.scanner.scan();

      expect(outcome, scanDone(added: 0, failed: {card}));
      expect(
        await h.baselineOf(card),
        isNull,
        reason:
            'the baseline must '
            'not move',
      );
      expect(await _onCard(), isEmpty);

      expect(await h.scanner.scan(), scanDone(added: 1));
      expect(await _onCard(), {1});
      expect(await h.baselineOf(card), at(1));
    });

    test('a failing database write leaves no baseline either', () async {
      await shootingWithPhoneOnly();
      bridge.put([shotOnCard(1, 1, _hour)], volume: card, version: 'c1');
      await h.db.customStatement(
        'CREATE TRIGGER no_inserts BEFORE INSERT ON clips '
        "BEGIN SELECT RAISE(ABORT, 'disk full'); END",
      );

      final outcome = await h.scanner.scan();

      expect(outcome, scanDone(added: 0, failed: {card}));
      expect(await h.baselineOf(card), isNull);
    });

    test('the other volumes still move when the new one fails', () async {
      await shootingWithPhoneOnly();
      bridge
        ..put([fakeVideo(id: 2, generation: 2)])
        ..put([shotOnCard(1, 1, _hour)], volume: card, version: 'c1')
        ..failNext('videosShotSince');

      final outcome = await h.scanner.scan();

      expect(outcome, scanDone(added: 1, failed: {card}));
      expect(await h.baselineOf(phone), at(2, 'v1'));
    });
  });

  group('when the session ends from the shade', () {
    ShadeAction turnOff(DateTime session, Map<String, int> generations) =>
        ShadeAction(
          kind: ShadeActionKind.turnOff,
          since: session,
          at: DateTime.utc(2026, 6, 1, 18),
          generations: generations,
        );

    test(
      'a volume with no baseline is not in the tap and is left alone',
      () async {
        await shootingWithPhoneOnly();
        final session = (await h.phoneState.loadShooting()).since!;
        bridge.put([shotOnCard(1, 1, _hour)], volume: card, version: 'c1');
        h.background.shadeAction = turnOff(session, const {phone: 1});

        final outcome = await h.scanner.scan();

        expect(outcome, scanDone(added: 0));
        expect(bridge.count('videosShotSince'), 0);
        expect(await _onCard(), isEmpty);
        expect((await h.phoneState.loadShooting()).on, isFalse);
      },
    );

    test(
      'a volume named in the tap without a baseline respects the cap',
      () async {
        await shootingWithPhoneOnly();
        final session = (await h.phoneState.loadShooting()).since!;
        bridge.put(
          [
            shotOnCard(1, 5, _hour),
            shotOnCard(2, 6, _hour * 2),
            shotOnCard(3, 7, _hour * 3),
          ],
          volume: card,
          version: 'c1',
        );
        h.background.shadeAction = turnOff(session, const {phone: 1, card: 6});

        final outcome = await h.scanner.scan();

        expect(outcome, scanDone(added: 2));
        expect(await _onCard(), {1, 2}, reason: 'the third came after the tap');
      },
    );
  });
}
