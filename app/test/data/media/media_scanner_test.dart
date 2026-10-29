import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:taketray/data/database/connection.dart';
import 'package:taketray/data/media/media_scanner.dart';
import 'package:taketray/data/repositories/clips_repository.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/app_settings.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/domain/models/zone_entry.dart';
import 'package:taketray/domain/rules/fingerprint_match.dart';
import 'package:taketray/platform/media_bridge.dart';

import '../../support/fake_media_bridge.dart';
import '../../support/test_database.dart';
import 'media_harness.dart';

/// A video on [volume] with MediaStore id [id], added at [generation], with a
/// size that is unique per id (so fingerprints differ).
MediaVideo video(
  int id,
  int generation, {
  String volume = phone,
  String folder = 'DCIM/Camera/',
  bool pending = false,
  int? durationMs = 5000,
  int? sizeBytes,
  int dateTakenMs = 1780000000000,
  int? dateAddedSec = 1780000000,
  String? name,
}) => fakeVideo(
  id: id,
  generation: generation,
  volume: volume,
  folder: folder,
  pending: pending,
  durationMs: durationMs,
  sizeBytes: sizeBytes ?? 1000000 + id,
  dateTakenMs: dateTakenMs,
  dateAddedSec: dateAddedSec,
  name: name,
);

/// [count] videos with ids from [firstId], one generation each from
/// [firstGeneration], or all at [sameGeneration].
List<MediaVideo> videos(
  int count, {
  required int firstId,
  int firstGeneration = 1,
  int? sameGeneration,
  String volume = phone,
}) => [
  for (var i = 0; i < count; i++)
    video(firstId + i, sameGeneration ?? firstGeneration + i, volume: volume),
];

const _v1 = 'v1';

VolumeBaseline at(int generation, [String version = _v1]) =>
    VolumeBaseline(version: version, generation: generation);

/// A clips repository whose `addDetectedClips` fails like a full disk.
class _FailingClips extends ClipsRepository {
  _FailingClips(super._db, super._clock);

  @override
  Future<DetectedClips> addCheckedClips(
    List<NewClip> clips, {
    required bool Function(Clip stored, NewClip incoming) sameVideo,
  }) async => throw StateError('database is full');
}

/// A bridge whose `videosAddedAfter` fails with an error that is not a
/// `PlatformException` for one volume (a bug, or a database surprise).
class _BrokenVolume extends RecordingBridge {
  _BrokenVolume(this.volume);

  final String volume;

  @override
  Future<List<MediaVideo>> videosAddedAfter(
    String volumeName,
    int afterGeneration,
    List<String> folders,
    int limit,
  ) async {
    if (volumeName == volume) throw StateError('unexpected');
    return await super.videosAddedAfter(
      volumeName,
      afterGeneration,
      folders,
      limit,
    );
  }
}

Matcher scanDone({
  required int added,
  Set<String> resynced = const {},
  Set<String> failed = const {},
}) => isA<ScanDone>()
    .having((d) => d.added, 'added', added)
    .having((d) => d.resynced, 'resynced', resynced)
    .having((d) => d.failedVolumes, 'failedVolumes', failed);

MediaHarness? _built;

/// Built on first use, so a test that opens its own database never has two
/// open.
MediaHarness get h => _built ??= MediaHarness();

RecordingBridge get bridge => h.bridge;

void main() {
  setUp(() => _built = null);

  group('when it does nothing', () {
    test('off → ScanShootingOff, no bridge media calls', () async {
      bridge.put([video(1, 11)]);

      expect(await h.scanner.scan(), isA<ScanShootingOff>());

      expect(bridge.calls, isEmpty);
      expect(await h.allClips(), isEmpty);
    });

    for (final level in [MediaAccessLevel.limited, MediaAccessLevel.denied]) {
      test('scan does nothing without full access (${level.name})', () async {
        bridge.put([video(1, 10)]);
        await h.turnOn({phone: at(10)});
        bridge
          ..put([video(2, 11)])
          ..access = MediaAccess(level: level, canAskAgain: true, sdkInt: 34);

        expect(await h.scanner.scan(), isA<ScanNoAccess>());

        expect(bridge.calls, ['accessReport']);
        expect(await h.baselineOf(phone), at(10));
        expect(await h.allClips(), isEmpty);
        expect(await h.phoneState.accessWasFull(), isFalse);
      });
    }
  });

  group('new videos', () {
    test('first scan after turning on starts from now', () async {
      bridge.put(videos(5, firstId: 1));
      await h.turnOnNow();

      expect(await h.scanner.scan(), scanDone(added: 0));
      expect(await h.allClips(), isEmpty);
      expect(await h.baselineOf(phone), at(5));

      bridge.put([video(6, 6)]);
      expect(await h.scanner.scan(), scanDone(added: 1));
      expect([for (final c in await h.toTag()) c.mediaStoreId], [6]);
    });

    test('new camera video lands in To tag with its zone', () async {
      bridge.put([video(1, 10)]);
      await h.turnOnNow();
      bridge
        ..currentZone = 'Asia/Kolkata'
        ..put([video(77, 11)]);

      expect(await h.scanner.scan(), scanDone(added: 1));

      final clip = (await h.toTag()).single;
      final v = video(77, 11);
      expect(clip.volumeName, phone);
      expect(clip.mediaStoreId, 77);
      expect(clip.generationAdded, 11);
      expect(clip.timeZoneId, 'Asia/Kolkata');
      expect(sameVideo(clip.fingerprint, v, now: h.clock.now()), isTrue);
      expect(await h.baselineOf(phone), at(11));
      expect(await h.phoneState.accessWasFull(), isTrue);
    });

    test(
      'a video shot in another time zone gets the zone from the timeline',
      () async {
        final paris = DateTime.utc(2026, 5, 20);
        final london = DateTime.utc(2026, 5, 30);
        await h.zones.recordAll([
          ZoneEntry(at: paris, zoneId: 'Europe/Paris'),
          ZoneEntry(at: london, zoneId: 'Europe/London'),
        ]);
        bridge.put([video(1, 10)]);
        await h.turnOnNow();
        bridge
          ..currentZone = 'Asia/Tokyo'
          ..put([
            // In Paris (between the two entries).
            video(
              2,
              11,
              dateTakenMs: DateTime.utc(2026, 5, 25).millisecondsSinceEpoch,
            ),
            // In London (after the last entry).
            video(
              3,
              12,
              dateTakenMs: DateTime.utc(2026, 5, 31).millisecondsSinceEpoch,
            ),
            // Before the timeline starts: the phone's zone now.
            video(
              4,
              13,
              dateTakenMs: DateTime.utc(2026, 5, 2).millisecondsSinceEpoch,
            ),
          ]);

        await h.scanner.scan();

        final zones = {
          for (final c in await h.toTag()) c.mediaStoreId: c.timeZoneId,
        };
        expect(zones, {2: 'Europe/Paris', 3: 'Europe/London', 4: 'Asia/Tokyo'});
      },
    );

    test(
      'video outside watched folders is ignored but baseline passes it',
      () async {
        await h.settings.save(
          const AppSettings(watchedFolders: ['DCIM/Camera', 'Movies/Vlog']),
        );
        bridge.put([video(1, 10)]);
        await h.turnOnNow();
        bridge.put([
          video(2, 11, folder: 'Download/'),
          video(3, 12, folder: 'Movies/Vlog/'),
          video(4, 13, folder: 'DCIM/Camera/Sub/'),
        ]);

        expect(await h.scanner.scan(), scanDone(added: 1));

        expect([for (final c in await h.toTag()) c.mediaStoreId], [3]);
        expect(await h.baselineOf(phone), at(13));
      },
    );

    test(
      'empty watched folders: no rows, the baseline still advances',
      () async {
        await h.settings.save(const AppSettings(watchedFolders: []));
        bridge.put([video(1, 10)]);
        await h.turnOnNow();
        bridge.put([video(2, 11), video(3, 12)]);

        expect(await h.scanner.scan(), scanDone(added: 0));

        expect(await h.allClips(), isEmpty);
        expect(await h.baselineOf(phone), at(12));
      },
    );

    test('pending video appears on the next scan', () async {
      bridge.put([video(1, 10)]);
      await h.turnOnNow();
      bridge.put([video(5, 11, pending: true), video(6, 12)]);

      expect(await h.scanner.scan(), scanDone(added: 1));
      expect([for (final c in await h.toTag()) c.mediaStoreId], [6]);
      expect(await h.baselineOf(phone), at(10), reason: 'held before 11');

      // The camera finishes the recording: same row, same GENERATION_ADDED,
      // and the volume's generation moves on.
      bridge.videosByVolume[phone]!
        ..removeWhere((v) => v.mediaStoreId == 5)
        ..add(video(5, 11));
      bridge.setVolume(phone, version: _v1, generation: 13);

      expect(await h.scanner.scan(), scanDone(added: 1));
      expect([for (final c in await h.toTag()) c.mediaStoreId]..sort(), [5, 6]);
      expect(await h.baselineOf(phone), at(13));

      expect(await h.scanner.scan(), scanDone(added: 0));
      expect(await h.toTag(), hasLength(2));
    });

    test(
      'an old zero-duration video is never added; the baseline passes it',
      () async {
        // Added on 2026-05-28, days before the scan: its length is not coming.
        bridge.put([video(1, 10)]);
        await h.turnOnNow();
        bridge.put([
          video(2, 11, durationMs: 0),
          video(3, 12, durationMs: null),
        ]);

        expect(await h.scanner.scan(), scanDone(added: 0));

        expect(await h.allClips(), isEmpty);
        expect(await h.baselineOf(phone), at(12));
      },
    );

    test('a zero-length video whose length arrives later is added once '
        '(Ruling W)', () async {
      final justNow = h.clock.now().millisecondsSinceEpoch ~/ 1000 - 60;
      bridge.put([video(1, 10)]);
      await h.turnOnNow();
      bridge.put([
        video(2, 11, durationMs: 0, dateAddedSec: justNow),
        video(3, 12),
      ]);

      expect(await h.scanner.scan(), scanDone(added: 1));
      expect(await h.baselineOf(phone), at(10), reason: 'held before 11');

      // Android fills in the length; the row keeps its GENERATION_ADDED.
      bridge.videosByVolume[phone]!
        ..removeWhere((v) => v.mediaStoreId == 2)
        ..add(video(2, 11, dateAddedSec: justNow));
      bridge.setVolume(phone, version: _v1, generation: 13);

      expect(await h.scanner.scan(), scanDone(added: 1));
      expect([for (final c in await h.toTag()) c.mediaStoreId]..sort(), [2, 3]);
      expect(await h.baselineOf(phone), at(13));
      expect(await h.scanner.scan(), scanDone(added: 0));
    });

    test(
      'a zero-length video stops holding ten minutes after it was added',
      () async {
        final justNow = h.clock.now().millisecondsSinceEpoch ~/ 1000;
        bridge.put([video(1, 10)]);
        await h.turnOnNow();
        bridge.put([video(2, 11, durationMs: 0, dateAddedSec: justNow)]);

        await h.scanner.scan();
        expect(await h.baselineOf(phone), at(10));

        h.clock.advance(const Duration(minutes: 10, seconds: 1));
        await h.scanner.scan();
        expect(await h.baselineOf(phone), at(11));
        expect(await h.allClips(), isEmpty);
      },
    );

    test('a stored clip holding a number the phone gives a different video: '
        'the video lands in To tag, the old clip is detached and stays in '
        'its reel (Ruling U)', () async {
      // Clip 5 came from a backup of another phone; this phone has not yet
      // reached number 5.
      final [oldClip] = await h.store([video(5, 3, sizeBytes: 42)]);
      final reel = await ReelsRepository(h.db, h.clock).create('Goa');
      await h.clips.tagClip(oldClip, {reel.id});
      bridge.put([video(1, 10)]);
      await h.turnOnNow();
      bridge.put([video(5, 11)]);

      expect(await h.scanner.scan(), scanDone(added: 1));

      final inToTag = (await h.toTag()).single;
      expect(inToTag.mediaStoreId, 5);
      expect(inToTag.id, isNot(oldClip));
      expect(
        sameVideo(inToTag.fingerprint, video(5, 11), now: h.clock.now()),
        isTrue,
      );
      final old = await h.clip(oldClip);
      expect((old.mediaStoreId, old.missing), (-oldClip, true));
      expect(await h.clips.watchReelIdsOf(oldClip).first, {reel.id});
      expect(await h.baselineOf(phone), at(11));
    });

    test('a stored clip holding the same number and the same video: nothing '
        'changes', () async {
      final [stored] = await h.store([video(5, 11)]);
      bridge.put([video(1, 10)]);
      await h.turnOnNow();
      bridge.put([video(5, 11)]);

      expect(await h.scanner.scan(), scanDone(added: 0));

      final clip = await h.clip(stored);
      expect((clip.mediaStoreId, clip.missing), (5, false));
      expect(await h.allClips(), hasLength(1));
      expect(await h.baselineOf(phone), at(11));
    });

    test('after an import (no baseline) scan starts from now', () async {
      // An import leaves clips but no baselines; Shooting mode then starts
      // with none (as if the volume list could not be read).
      bridge.put(videos(3, firstId: 1, firstGeneration: 8));
      await h.store([video(1, 8)]);
      await h.turnOn({});

      expect(await h.scanner.scan(), scanDone(added: 0));

      expect(bridge.calls, isNot(contains('videosAddedAfter')));
      expect(await h.allClips(), hasLength(1));
      expect(await h.baselineOf(phone), at(10));
    });

    test('an SD card seen for the first time starts from now, alone', () async {
      bridge.put([video(1, 10)]);
      await h.turnOnNow();
      bridge
        ..put([video(2, 11)])
        ..put(
          videos(40, firstId: 1, volume: card),
          volume: card,
          version: 'c1',
        );

      expect(await h.scanner.scan(), scanDone(added: 1));

      expect([for (final c in await h.toTag()) c.mediaStoreId], [2]);
      expect(await h.baselineOf(phone), at(11));
      expect(await h.baselineOf(card), at(40, 'c1'));

      bridge.put(
        [video(41, 41, volume: card)],
        volume: card,
        version: 'c1',
      );
      expect(await h.scanner.scan(), scanDone(added: 1));
      final onCard = [
        for (final c in await h.toTag())
          if (c.volumeName == card) c.mediaStoreId,
      ];
      expect(onCard, [41]);
    });

    test(
      'an SD card removed mid-session is skipped and keeps its baseline',
      () async {
        bridge
          ..put([video(1, 10)])
          ..put(
            [video(1, 7, volume: card)],
            volume: card,
            version: 'c1',
          );
        await h.turnOnNow();
        await h.store([video(1, 7, volume: card)]);
        bridge
          ..put([video(2, 11)])
          // Android lists a removed card without a version, or not at all.
          ..setVolume(card, version: null);

        expect(await h.scanner.scan(), scanDone(added: 1));
        expect(await h.baselineOf(card), at(7, 'c1'));

        bridge.removeVolume(card);
        expect(await h.scanner.scan(), scanDone(added: 0));
        expect(await h.baselineOf(card), at(7, 'c1'));

        expect(bridge.addedAfter.map((q) => q.$1), everyElement(phone));
        expect(bridge.calls, isNot(contains('allVideos')));
        final cardClip = (await h.allClips()).singleWhere(
          (c) => c.volumeName == card,
        );
        expect(cardClip.missing, isFalse);
        expect(cardClip.mediaStoreId, 1);
      },
    );
  });

  group('paging (D-70)', () {
    test('1200 new videos → all added, baseline at the last', () async {
      bridge.put([video(1, 100)]);
      await h.turnOnNow();
      bridge.put(videos(1200, firstId: 1001, firstGeneration: 101));

      expect(await h.scanner.scan(), scanDone(added: 1200));

      expect(await h.toTag(), hasLength(1200));
      expect(await h.baselineOf(phone), at(1300));
      expect(bridge.addedAfter, [
        (phone, 100, 500),
        (phone, 599, 500),
        (phone, 1098, 500),
      ]);
    });

    test('a page cut inside a shared generation loses none of it', () async {
      bridge.put([video(1, 100)]);
      await h.turnOnNow();
      bridge.put([
        ...videos(450, firstId: 1001, firstGeneration: 101),
        ...videos(600, firstId: 2001, sameGeneration: 600),
      ]);

      expect(await h.scanner.scan(), scanDone(added: 1050));

      final ids = [for (final c in await h.toTag()) c.mediaStoreId];
      expect(ids, hasLength(1050));
      expect(ids.toSet(), hasLength(1050));
      expect(await h.baselineOf(phone), at(600));
      expect(bridge.addedAfter, [
        (phone, 100, 500),
        (phone, 599, 500),
        (phone, 599, 1000),
      ]);
    });

    test('a stuck pending row does not hide the 1200 rows after it', () async {
      bridge.put([video(1, 100)]);
      await h.turnOnNow();
      bridge.put([
        video(5, 101, pending: true),
        ...videos(1200, firstId: 1001, firstGeneration: 102),
      ]);

      expect(await h.scanner.scan(), scanDone(added: 1200));

      expect(await h.toTag(), hasLength(1200));
      expect(await h.baselineOf(phone), at(100), reason: 'held before 101');

      // Still pending at the next scan: nothing new, nothing doubled.
      expect(await h.scanner.scan(), scanDone(added: 0));
      expect(await h.toTag(), hasLength(1200));
    });

    test(
      'a generation too big for the largest page stops the scan there',
      () async {
        bridge.put([video(1, 97)]);
        await h.turnOnNow();
        bridge.put([
          ...videos(3, firstId: 101, firstGeneration: 98),
          ...videos(16001, firstId: 1001, sameGeneration: 101),
        ], generation: 105);
        final logs = captureLogs();

        final outcome = await h.scanner.scan();

        expect(outcome, scanDone(added: 16003));
        expect(bridge.addedAfter, [
          (phone, 97, 500),
          (phone, 100, 500),
          (phone, 100, 1000),
          (phone, 100, 2000),
          (phone, 100, 4000),
          (phone, 100, 8000),
          (phone, 100, 16000),
        ]);
        // Past the three rows below 101, never past 101 itself.
        expect(await h.baselineOf(phone), at(100));
        expect(
          logs.where((r) => r.level >= Level.WARNING).map((r) => r.message),
          contains(allOf(contains(phone), contains('16003'))),
        );
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });

  group('rebuilt media library (Review Focus 3)', () {
    /// Stores [old] as clips, turns Shooting mode on at generation 10 of
    /// version v1, then replaces the library with [rebuilt] under version v2.
    Future<List<Clip>> rebuild(
      List<MediaVideo> old,
      List<MediaVideo> rebuilt,
    ) async {
      bridge.put(old, generation: 10);
      await h.store(old);
      await h.turnOnNow();
      bridge
        ..videosByVolume[phone] = []
        ..put(rebuilt, version: 'v2');
      return await h.allClips();
    }

    test('version change resyncs, adds nothing', () async {
      final old = videos(5, firstId: 1);
      // The five old videos under new numbers, among 45 others.
      final rebuilt = [
        for (final (i, v) in old.indexed)
          v.copyWith(mediaStoreId: 101 + i, generationAdded: i + 1),
        ...videos(45, firstId: 201, firstGeneration: 6),
      ];
      bridge.put(
        [video(9, 3, volume: card)],
        volume: card,
        version: 'c1',
      );
      await h.store([video(9, 3, volume: card)]);
      final before = await rebuild(old, rebuilt);

      expect(await h.scanner.scan(), scanDone(added: 0, resynced: {phone}));

      expect(bridge.calls, contains('allVideos'));
      expect(bridge.addedAfter.where((q) => q.$1 == phone), isEmpty);
      expect(await h.toTag(), hasLength(before.length));
      expect(await h.baselineOf(phone), at(50, 'v2'));
      final library = {for (final v in rebuilt) v.mediaStoreId: v};
      for (final was in before.where((c) => c.volumeName == phone)) {
        final now = await h.clip(was.id);
        final id = now.mediaStoreId!;
        // Every attached clip of the volume is either remapped to its own
        // video, or lost (detached and missing).
        final remapped =
            id > 0 &&
            !now.missing &&
            sameVideo(now.fingerprint, library[id]!, now: h.clock.now());
        final lost = id == -was.id && now.missing;
        expect(remapped || lost, isTrue, reason: 'clip ${was.id}');
        expect(remapped, isTrue, reason: 'all five were found');
      }
      final onCard = (await h.allClips()).singleWhere(
        (c) => c.volumeName == card,
      );
      expect(onCard.mediaStoreId, 9);
      expect(onCard.missing, isFalse);
    });

    test('found, lost and swapped clips in one resync', () async {
      final a = video(1, 1);
      final b = video(2, 2);
      final c = video(3, 3);
      final d = video(4, 4);
      final before = await rebuild(
        [a, b, c, d],
        [
          a.copyWith(mediaStoreId: 11, generationAdded: 1),
          // b is gone. c and d swap numbers.
          c.copyWith(mediaStoreId: 4, generationAdded: 2),
          d.copyWith(mediaStoreId: 3, generationAdded: 3),
        ],
      );
      final idOf = {for (final clip in before) clip.mediaStoreId!: clip.id};

      expect(await h.scanner.scan(), scanDone(added: 0, resynced: {phone}));

      Future<(int?, bool)> state(int oldId) async {
        final clip = await h.clip(idOf[oldId]!);
        return (clip.mediaStoreId, clip.missing);
      }

      expect(await state(1), (11, false));
      expect(await state(2), (-idOf[2]!, true));
      expect(await state(3), (4, false));
      expect(await state(4), (3, false));
    });

    test(
      'a resync whose baseline write loses to an off/on keeps the remap',
      () async {
        final old = [video(1, 1)];
        await rebuild(old, [old.single.copyWith(mediaStoreId: 21)]);
        final gate = bridge.gate('allVideos');
        final scan = h.scanner.scan();
        await until(() => bridge.calls.contains('allVideos'));

        await h.phoneState.turnShootingOff();
        h.clock.advance(const Duration(minutes: 1));
        final session = await h.turnOn({phone: at(30, 'v2')});
        gate.complete();

        expect(await scan, scanDone(added: 0, resynced: {phone}));
        expect((await h.allClips()).single.mediaStoreId, 21);
        expect(await h.phoneState.loadShooting(), session);
      },
    );

    test('a failing allVideos leaves the clips and the baseline', () async {
      final old = [video(1, 1)];
      await rebuild(old, [old.single.copyWith(mediaStoreId: 21)]);
      bridge.failNext('allVideos');

      expect(await h.scanner.scan(), scanDone(added: 0, failed: {phone}));

      expect((await h.allClips()).single.mediaStoreId, 1);
      expect(await h.baselineOf(phone), at(10));

      expect(await h.scanner.scan(), scanDone(added: 0, resynced: {phone}));
      expect((await h.allClips()).single.mediaStoreId, 21);
    });

    test(
      'a scan records the version of every mounted volume it plans',
      () async {
        bridge
          ..put([video(1, 10)])
          ..put(
            [video(1, 5, volume: card)],
            volume: card,
            version: 'c1',
          );
        await h.turnOnNow();

        await h.scanner.scan();

        expect(await h.phoneState.volumeVersions(), {phone: _v1, card: 'c1'});
        bridge.setVolume(card, version: null);
        await h.scanner.scan();
        expect(await h.phoneState.volumeVersions(), {phone: _v1, card: 'c1'});
      },
    );

    test('a rebuild while Shooting mode was off is caught up by the next scan '
        '(Ruling V)', () async {
      final old = video(1, 1);
      bridge.put([old], generation: 10);
      final [clipId] = await h.store([old]);
      await h.phoneState.recordVolumeVersion(phone, _v1);
      // Rebuilt while Shooting mode was off; it is then switched on at v2.
      bridge
        ..videosByVolume[phone] = []
        ..put([
          old.copyWith(mediaStoreId: 21),
          video(1, 2, sizeBytes: 9),
        ], version: 'v2');
      await h.turnOnNow();

      expect(await h.scanner.scan(), scanDone(added: 0, resynced: {phone}));

      final clip = await h.clip(clipId);
      expect((clip.mediaStoreId, clip.missing), (21, false));
      expect(await h.phoneState.volumeVersions(), {phone: 'v2'});
      expect(await h.baselineOf(phone), at(2, 'v2'));
    });

    test('a generation that went backwards resyncs too', () async {
      final old = [video(1, 1)];
      bridge.put(old, generation: 10);
      await h.store(old);
      await h.turnOnNow();
      bridge
        ..videosByVolume[phone] = [old.single.copyWith(mediaStoreId: 31)]
        ..setVolume(phone, version: _v1, generation: 4);

      expect(await h.scanner.scan(), scanDone(added: 0, resynced: {phone}));
      expect((await h.allClips()).single.mediaStoreId, 31);
      expect(await h.baselineOf(phone), at(4));
    });
  });

  group('failures', () {
    test('a failing volume keeps its baseline, others proceed', () async {
      bridge
        ..put([video(1, 10)])
        ..put(
          [video(1, 5, volume: card)],
          volume: card,
          version: 'c1',
        );
      await h.turnOnNow();
      bridge
        ..put([video(2, 11)])
        ..put(
          [video(2, 6, volume: card)],
          volume: card,
          version: 'c1',
        )
        ..failNext('videosAddedAfter');

      expect(await h.scanner.scan(), scanDone(added: 1, failed: {phone}));

      expect(await h.baselineOf(phone), at(10));
      expect(await h.baselineOf(card), at(6, 'c1'));
      expect([for (final c in await h.toTag()) c.volumeName], [card]);

      expect(await h.scanner.scan(), scanDone(added: 1));
      expect(await h.baselineOf(phone), at(11));
    });

    test('addDetectedClips failure leaves baseline unmoved', () async {
      bridge.put([video(1, 10)]);
      await h.turnOnNow();
      bridge.put([video(2, 11)]);
      final failing = h.scannerWith(_FailingClips(h.db, h.clock));
      final logs = captureLogs();

      // Caught for that volume only (Ruling X): logged by type, never moved.
      expect(await failing.scan(), scanDone(added: 0, failed: {phone}));

      expect(logText(logs), contains('StateError'));
      expect(await h.baselineOf(phone), at(10));
      expect(await h.allClips(), isEmpty);

      expect(await h.scanner.scan(), scanDone(added: 1));
      expect(await h.baselineOf(phone), at(11));
    });

    test('one volume failing unexpectedly does not stop the others', () async {
      final h = MediaHarness(bridge: _BrokenVolume(phone));
      h.bridge
        ..put([video(1, 10)])
        ..put(
          [video(1, 5, volume: card)],
          volume: card,
          version: 'c1',
        );
      await h.turnOnNow();
      h.bridge
        ..put([video(2, 11)])
        ..put(
          [video(2, 6, volume: card)],
          volume: card,
          version: 'c1',
        );
      final logs = captureLogs();

      expect(await h.scanner.scan(), scanDone(added: 1, failed: {phone}));

      expect(await h.baselineOf(phone), at(10));
      expect(await h.baselineOf(card), at(6, 'c1'));
      expect(logText(logs), allOf(contains('StateError'), contains(phone)));
      expect(logText(logs), isNot(contains('unexpected')));
    });

    test('volumes() throws → no baseline or clip is written, the code is '
        'logged', () async {
      bridge.put([video(1, 10)]);
      final session = await h.turnOnNow();
      bridge
        ..put([video(2, 11)])
        ..failNext('volumes');
      final logs = captureLogs();

      await expectLater(h.scanner.scan(), throwsA(isA<PlatformException>()));

      expect(await h.phoneState.loadShooting(), session);
      expect(await h.allClips(), isEmpty);
      final text = logText(logs);
      expect(text, contains('fake-failure'));
      expect(text, isNot(contains('failed on purpose')));
    });
  });

  group('races (Review Focus 4)', () {
    test('concurrent scans coalesce', () async {
      bridge.put([video(1, 10)]);
      await h.turnOnNow();
      bridge.put([video(2, 11)]);
      final gate = bridge.gate('volumes');

      final first = h.scanner.scan();
      await until(() => bridge.calls.contains('volumes'));
      // While the first run is paused, a video arrives and three triggers
      // fire (app start, resume, opening To tag).
      bridge.put([video(3, 12)]);
      final second = h.scanner.scan();
      final third = h.scanner.scan();
      final fourth = h.scanner.scan();
      expect(identical(second, third), isTrue);
      expect(identical(third, fourth), isTrue);
      gate.complete();

      expect(await first, scanDone(added: 1));
      expect(await second, scanDone(added: 1));
      expect(await third, scanDone(added: 1));
      const run = [
        'accessReport',
        'currentZoneId',
        'volumes',
        'videosAddedAfter',
      ];
      expect(bridge.calls, [...run, ...run]);
      expect([for (final c in await h.toTag()) c.mediaStoreId]..sort(), [2, 3]);
      expect(await h.baselineOf(phone), at(12));

      // Idle again: the next call starts a new run.
      expect(await h.scanner.scan(), scanDone(added: 0));
      expect(bridge.count('volumes'), 3);
    });

    test('Shooting mode toggled while the volumes are read: the scan stops '
        'without writing (M6)', () async {
      bridge.put([video(1, 10)]);
      await h.turnOnNow();
      bridge.put([video(2, 11)]);
      final gate = bridge.gate('volumes');

      final stale = h.scanner.scan();
      await until(() => bridge.calls.contains('volumes'));
      await h.phoneState.turnShootingOff();
      h.clock.advance(const Duration(minutes: 1));
      final session = await h.turnOn({phone: at(10)});
      gate.complete();

      expect(await stale, isA<ScanShootingOff>());
      expect(bridge.calls, isNot(contains('videosAddedAfter')));
      expect(await h.phoneState.loadShooting(), session);
      expect(await h.allClips(), isEmpty);
      expect(await h.phoneState.volumeVersions(), isEmpty);
    });

    test(
      "scan started before off/on cannot write the new session's baseline",
      () async {
        bridge.put([video(1, 10)]);
        await h.turnOnNow();
        bridge.put([video(2, 11)]);
        final gate = bridge.gate('videosAddedAfter');

        final stale = h.scanner.scan();
        await until(() => bridge.calls.contains('videosAddedAfter'));
        await h.phoneState.turnShootingOff();
        bridge.put([video(3, 12)]); // shot while Shooting mode was off
        h.clock.advance(const Duration(minutes: 1));
        final session = await h.turnOnNow();
        bridge.put([video(4, 13)]); // shot in the new session
        gate.complete();

        expect(await stale, scanDone(added: 1));
        expect(await h.phoneState.loadShooting(), session);
        expect(await h.baselineOf(phone), at(12));

        expect(await h.scanner.scan(), scanDone(added: 1));
        expect([for (final c in await h.toTag()) c.mediaStoreId]..sort(), [
          2,
          4,
        ], reason: 'video 3 was shot while Shooting mode was off');
      },
    );

    test(
      'a stale scan cannot write a new session with the same baseline',
      () async {
        bridge.put([video(1, 10)]);
        await h.turnOnNow();
        bridge.put([video(2, 11)]);
        final gate = bridge.gate('videosAddedAfter');

        final stale = h.scanner.scan();
        await until(() => bridge.calls.contains('videosAddedAfter'));
        await h.phoneState.turnShootingOff();
        h.clock.advance(const Duration(minutes: 1));
        final session = await h.turnOn({phone: at(10)});
        gate.complete();

        await stale;
        expect(await h.phoneState.loadShooting(), session);
      },
    );

    test(
      "a stale scan's later page cannot pick up an off-period video",
      () async {
        bridge.put([video(1, 10)]);
        await h.turnOnNow();
        bridge.put(videos(500, firstId: 1001, firstGeneration: 11));
        final gate = bridge.gate('videosAddedAfter');

        final stale = h.scanner.scan();
        await until(() => bridge.calls.contains('videosAddedAfter'));
        await h.phoneState.turnShootingOff();
        bridge.put([video(3, 511)]); // shot while Shooting mode was off
        h.clock.advance(const Duration(minutes: 1));
        await h.turnOnNow();
        gate.complete();

        expect(await stale, scanDone(added: 500));
        expect(bridge.addedAfter, hasLength(2), reason: 'it read a 2nd page');
        final ids = {for (final c in await h.allClips()) c.mediaStoreId};
        expect(ids, isNot(contains(3)));
        expect(await h.baselineOf(phone), at(511));
      },
    );
  });

  test('log lines carry no display name, folder or version', () async {
    final logs = captureLogs();
    await h.settings.save(
      const AppSettings(watchedFolders: ['DCIM/SecretFolder']),
    );
    bridge.put([
      video(1, 10, folder: 'DCIM/SecretFolder/', name: 'Secret_take.mp4'),
    ], version: 'version-secret-1');
    await h.store([
      video(1, 10, folder: 'DCIM/SecretFolder/', name: 'Secret_take.mp4'),
    ]);
    await h.turnOnNow();
    bridge.put([
      video(2, 11, folder: 'DCIM/SecretFolder/', name: 'Secret_new.mp4'),
      video(3, 12, folder: 'DCIM/SecretFolder/', pending: true),
    ], version: 'version-secret-1');
    await h.scanner.scan();
    // A rebuild, a failure and a first-seen card log too.
    bridge
      ..put([], version: 'version-secret-2')
      ..put(
        [video(1, 1, volume: card)],
        volume: card,
        version: 'card-secret',
      );
    await h.scanner.scan();
    bridge
      ..put([
        video(4, 30, folder: 'DCIM/SecretFolder/'),
      ], version: 'version-secret-2')
      ..failNext('videosAddedAfter');
    await h.scanner.scan();

    final text = logText(logs);
    expect(logs, isNotEmpty);
    for (final secret in ['Secret', 'secret', 'DCIM', '.mp4']) {
      expect(text, isNot(contains(secret)));
    }
  });

  test('mediaScannerProvider builds one scanner', () {
    final db = testDatabase();
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        mediaBridgeProvider.overrideWithValue(FakeMediaBridge()),
      ],
    );
    addTearDown(container.dispose);
    final scanner = container.read(mediaScannerProvider);
    expect(container.read(mediaScannerProvider), same(scanner));
  });
}
