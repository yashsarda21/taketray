import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/data/database/app_database.dart';
import 'package:taketray/data/database/connection.dart';
import 'package:taketray/data/media/add_videos_service.dart';
import 'package:taketray/data/media/media_scanner.dart';
import 'package:taketray/data/repositories/clips_repository.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/domain/models/zone_entry.dart';
import 'package:taketray/domain/rules/clip_date.dart';
import 'package:taketray/platform/media_bridge.dart';

import '../../support/clip_setup.dart';
import '../../support/fake_media_bridge.dart';
import '../../support/statement_log.dart';
import '../../support/test_database.dart';
import 'media_harness.dart';

/// A friend's WhatsApp folder: never watched, only added by hand.
const whatsApp = 'Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Video/';

/// When the test videos were shot: two days before the harness's now.
final DateTime shotTime = DateTime.utc(2026, 5, 30, 18);

/// A finished video in [folder] (default: [whatsApp]) with MediaStore id and
/// generation [id], shot at [shot] (default [shotTime]); a size unique to
/// [id] unless [size] is given.
MediaVideo friend(
  int id, {
  DateTime? shot,
  String volume = phone,
  String folder = whatsApp,
  int? size,
  int? durationMs = 5000,
  bool pending = false,
  String? name,
}) {
  final when = shot ?? shotTime;
  return fakeVideo(
    id: id,
    generation: id,
    volume: volume,
    folder: folder,
    sizeBytes: size ?? 1000000 + id,
    durationMs: durationMs,
    pending: pending,
    name: name,
    dateTakenMs: when.millisecondsSinceEpoch,
    dateAddedSec: when.millisecondsSinceEpoch ~/ 1000,
    dateModifiedSec: when.millisecondsSinceEpoch ~/ 1000,
  );
}

/// A video the photo picker returned.
PickedVideo pick(
  String uri, {
  bool persisted = true,
  int sizeBytes = 2000000,
  String displayName = 'picked.mp4',
  int? durationMs = 8000,
  int? dateTakenMs,
  bool noDate = false,
  int? width = 1080,
  int? height = 1920,
  String? mimeType = 'video/mp4',
}) => PickedVideo(
  uri: uri,
  sizeBytes: sizeBytes,
  displayName: displayName,
  persisted: persisted,
  durationMs: durationMs,
  dateTakenMs: noDate ? null : (dateTakenMs ?? shotTime.millisecondsSinceEpoch),
  width: width,
  height: height,
  mimeType: mimeType,
);

const AddTarget toTag = AddToToTag();

late MediaHarness h;
late AddVideosService service;
late ReelsRepository reels;

AddVideosService serviceOn(MediaHarness h) => AddVideosService(
  h.bridge,
  h.clips,
  h.phoneState,
  h.zones,
  h.zoneSync,
  h.queue,
  h.clock,
);

void main() {
  setUp(() {
    h = MediaHarness();
    service = serviceOn(h);
    reels = ReelsRepository(h.db, h.clock);
  });

  Future<List<InboxRow>> inbox() => h.db.select(h.db.inbox).get();

  Future<List<ClipReelRow>> links() => h.db.select(h.db.clipReels).get();

  Future<Set<int>> reelIdsOf(int clipId) async => {
    for (final l in await links())
      if (l.clipId == clipId) l.reelId,
  };

  Future<InboxRow?> inboxOf(int clipId) async {
    for (final r in await inbox()) {
      if (r.clipId == clipId) return r;
    }
    return null;
  }

  /// The one stored clip holding [v]'s number on its volume.
  Future<Clip> clipOf(MediaVideo v) async => (await h.allClips()).singleWhere(
    (c) => c.volumeName == v.volumeName && c.mediaStoreId == v.mediaStoreId,
  );

  Future<Clip> pickedClip(String uri) async =>
      (await h.allClips()).singleWhere((c) => c.pickerUri == uri);

  /// Every row of the clips, inbox, links and reels tables, as text.
  Future<List<String>> snapshot() async => [
    for (final r in await h.db.select(h.db.clips).get()) '$r',
    for (final r in await inbox()) '$r',
    for (final r in await links()) '$r',
    for (final r in await h.db.select(h.db.reels).get()) '$r',
  ];

  /// Saves [v] as a scan would (in To tag) and returns its clip id.
  Future<int> stored(MediaVideo v) async =>
      (await h.store([v], zoneId: 'UTC')).single;

  Future<int> reel(String name) async => (await reels.create(name)).id;

  void expectCounts(
    AddResult r, {
    int added = 0,
    int alreadyThere = 0,
    int notKept = 0,
  }) {
    expect(
      (r.added, r.alreadyThere, r.notKept),
      (added, alreadyThere, notKept),
      reason: '(added, alreadyThere, notKept)',
    );
  }

  group('a new video from a folder', () {
    test('to To tag: one MediaStore clip, pending, with the zone from the '
        'timeline', () async {
      final v = friend(7);
      h.bridge.put([v]);
      h.bridge.currentZone = 'Europe/London';
      await h.zones.recordAll([
        ZoneEntry(at: DateTime.utc(2026, 5, 2), zoneId: 'Asia/Kolkata'),
        ZoneEntry(at: DateTime.utc(2026, 5, 31), zoneId: 'Europe/London'),
      ]);

      final r = await service.addFromFolder([v], toTag);

      expectCounts(r, added: 1);
      final clip = await clipOf(v);
      expect(clip.source, ClipSource.mediaStore);
      expect(clip.pickerUri, isNull);
      expect(clip.timeZoneId, 'Asia/Kolkata', reason: 'where it was shot');
      expect(clip.missing, isFalse);
      final row = (await inbox()).single;
      expect((row.clipId, row.state), (clip.id, InboxState.pending));
      expect(row.addedAt, h.clock.storedNow());
      expect(await links(), isEmpty);
    });

    test(
      'the clip is exactly the one a scan would save (clipFromVideo)',
      () async {
        // DATE_TAKEN two days ahead is not plausible: the scan's rule falls
        // back to DATE_ADDED.
        final now = h.clock.now();
        final v = friend(7).copyWith(
          dateTakenMs: now.add(const Duration(days: 2)).millisecondsSinceEpoch,
          width: null,
          height: null,
          mimeType: 'video/3gpp',
        );
        h.bridge.put([v]);
        await h.zones.recordAll([
          ZoneEntry(at: DateTime.utc(2026, 5, 2), zoneId: 'Asia/Kolkata'),
        ]);

        await service.addFromFolder([v], toTag);

        final clip = await clipOf(v);
        final scan = clipFromVideo(v, await h.zones.all(), 'UTC', now);
        expect(clip.fingerprint, scan.fingerprint);
        expect(clip.fingerprint.dateTakenUtc, shotAt(v, now: now));
        expect(clip.fingerprint.dateTakenUtc, shotTime);
        expect(
          (clip.width, clip.height, clip.mimeType, clip.generationAdded),
          (scan.width, scan.height, scan.mimeType, scan.generationAdded),
        );
        expect((clip.width, clip.height), (0, 0));
        expect(clip.timeZoneId, scan.timeZoneId);
      },
    );

    test('shot before the timeline starts: the phone zone now', () async {
      final v = friend(7);
      h.bridge.put([v]);
      h.bridge.currentZone = 'Europe/London';
      await h.zones.recordAll([
        ZoneEntry(at: DateTime.utc(2026, 5, 31), zoneId: 'Asia/Kolkata'),
      ]);

      await service.addFromFolder([v], toTag);

      expect((await clipOf(v)).timeZoneId, 'Europe/London');
    });

    test("the phone's pending zone changes are synced before the timeline is "
        'read', () async {
      final v = friend(7);
      h.bridge
        ..put([v])
        ..currentZone = 'UTC'
        ..zoneChanges = [
          ZoneEntry(at: DateTime.utc(2026, 5, 2), zoneId: 'Asia/Kolkata'),
        ];

      await service.addFromFolder([v], toTag);

      expect((await clipOf(v)).timeZoneId, 'Asia/Kolkata');
    });

    test('a failed zone sync does not stop the add', () async {
      final v = friend(7);
      h.bridge
        ..put([v])
        ..failNext('pendingZoneChanges');

      expectCounts(await service.addFromFolder([v], toTag), added: 1);
    });

    test(
      'to a reel: one clip, one link, no inbox row; the reel is touched',
      () async {
        final goa = await reel('Goa');
        h.clock.advance(const Duration(minutes: 5));
        final v = friend(7);
        h.bridge.put([v]);

        final r = await service.addFromFolder([v], AddToReel(goa));

        expectCounts(r, added: 1);
        final clip = await clipOf(v);
        expect(clip.source, ClipSource.mediaStore);
        expect(await reelIdsOf(clip.id), {goa});
        expect(await inbox(), isEmpty, reason: 'a reel clip is in no list');
        expect((await reels.getById(goa))!.updatedAt, h.clock.storedNow());
      },
    );

    test('the same video twice in one list is added once', () async {
      final v = friend(7);
      h.bridge.put([v]);

      final r = await service.addFromFolder([v, v], toTag);

      expectCounts(r, added: 1);
      expect(await h.allClips(), hasLength(1));
    });

    test('the first add records the volume version, so a later rebuild is '
        'seen', () async {
      final v = friend(7);
      h.bridge.put([v], version: 'v9');

      await service.addFromFolder([v], toTag);

      expect(await h.phoneState.volumeVersions(), {phone: 'v9'});
    });

    test('a volume rebuilt since it was last seen is matched again first: '
        'no duplicate', () async {
      final old = friend(5);
      final id = await stored(old);
      await h.phoneState.recordVolumeVersion(phone, 'v1');
      // Rebuilt: the same video now has number 50.
      final again = friend(50, size: old.sizeBytes);
      h.bridge.put([again], version: 'v2');

      final r = await service.addFromFolder([again], toTag);

      expectCounts(r, alreadyThere: 1);
      final [clip] = await h.allClips();
      expect((clip.id, clip.mediaStoreId), (id, 50));
      expect(await h.phoneState.volumeVersions(), {phone: 'v2'});
    });
  });

  group('videos that are not added (notKept)', () {
    test('a pending video, one with no length and one with no size', () async {
      final videos = [
        friend(1, pending: true),
        friend(2, durationMs: null),
        friend(3, durationMs: 0),
        friend(4, size: 0),
        friend(5),
      ];
      h.bridge.put(videos);

      final r = await service.addFromFolder(videos, toTag);

      expectCounts(r, added: 1, notKept: 4);
      expect([for (final c in await h.allClips()) c.mediaStoreId], [5]);
    });

    test('a video on a volume that is gone or not mounted', () async {
      final onCard = friend(1, volume: card);
      final onUsb = friend(2, volume: 'usb');
      final here = friend(3);
      h.bridge
        ..put([here])
        ..put([onUsb], volume: 'usb')
        ..setVolume('usb', version: null);

      final r = await service.addFromFolder([onCard, onUsb, here], toTag);

      expectCounts(r, added: 1, notKept: 2);
      expect([for (final c in await h.allClips()) c.mediaStoreId], [3]);
    });
  });

  group('nothing to add', () {
    test('every picked video not kept: counted, nothing read or written, '
        'and Undo does nothing', () async {
      final before = await snapshot();
      h.bridge.calls.clear();

      final r = await service.addPicked([
        pick('content://a', persisted: false),
        pick('content://b', persisted: false),
      ], toTag);

      expectCounts(r, notKept: 2);
      await service.undo(r);
      expect(await snapshot(), before);
      expect(h.bridge.calls, isNot(contains('currentZoneId')));
    });

    test('every folder video unusable: counted, nothing written', () async {
      final videos = [friend(1, size: 0), friend(2, pending: true)];
      h.bridge.put(videos);
      final before = await snapshot();

      final r = await service.addFromFolder(videos, toTag);

      expectCounts(r, notKept: 2);
      expect(await snapshot(), before);
    });

    test('an empty list adds nothing', () async {
      h.bridge.put([friend(1)]);

      expectCounts(await service.addFromFolder(const [], toTag));
      expectCounts(await service.addPicked(const [], toTag));
      expect(await h.allClips(), isEmpty);
    });
  });

  group('the same video by two routes', () {
    test('added twice in a row: one clip, one place; the second is '
        'alreadyThere', () async {
      final v = friend(7);
      h.bridge.put([v]);

      expectCounts(await service.addFromFolder([v], toTag), added: 1);
      final before = await snapshot();
      expectCounts(await service.addFromFolder([v], toTag), alreadyThere: 1);

      expect(await snapshot(), before);
    });

    test('added twice to a reel: one clip, one link', () async {
      final goa = await reel('Goa');
      final v = friend(7);
      h.bridge.put([v]);

      await service.addFromFolder([v], AddToReel(goa));
      final before = await snapshot();
      expectCounts(
        await service.addFromFolder([v], AddToReel(goa)),
        alreadyThere: 1,
      );

      expect(await snapshot(), before);
    });

    test('two calls at once (a double tap): one clip, one place', () async {
      final v = friend(7);
      h.bridge.put([v]);

      final [a, b] = await Future.wait([
        service.addFromFolder([v], toTag),
        service.addFromFolder([v], toTag),
      ]);

      expectCounts(a, added: 1);
      expectCounts(b, alreadyThere: 1);
      expect(await h.allClips(), hasLength(1));
      expect(await inbox(), hasLength(1));
    });

    test(
      'to To tag and to a reel at once: the first wins, one place',
      () async {
        final goa = await reel('Goa');
        final v = friend(7);
        h.bridge.put([v]);

        final [a, b] = await Future.wait([
          service.addFromFolder([v], toTag),
          service.addFromFolder([v], AddToReel(goa)),
        ]);

        expectCounts(a, added: 1);
        expectCounts(b, alreadyThere: 1);
        final clip = await clipOf(v);
        expect((await inboxOf(clip.id))!.state, InboxState.pending);
        expect(await links(), isEmpty);
      },
    );

    group('with Shooting mode on and the video in the watched folder', () {
      late MediaVideo v;

      setUp(() async {
        h.bridge.setVolume(phone, version: 'v1', generation: 0);
        await h.turnOnNow();
        v = friend(7, folder: 'DCIM/Camera/');
        h.bridge.put([v]);
      });

      test(
        'added to To tag, then the scan sees it: one clip, one place',
        () async {
          await service.addFromFolder([v], toTag);
          final outcome = await h.scanner.scan();

          expect(outcome, isA<ScanDone>());
          expect((outcome as ScanDone).added, 0);
          expect(await h.allClips(), hasLength(1));
          expect(await inbox(), hasLength(1));
        },
      );

      test('added to a reel, then the scan sees it: not in To tag', () async {
        final goa = await reel('Goa');
        await service.addFromFolder([v], AddToReel(goa));
        await h.scanner.scan();

        final clip = await clipOf(v);
        expect(await h.allClips(), hasLength(1));
        expect(await reelIdsOf(clip.id), {goa});
        expect(await h.toTag(), isEmpty);
        expect(await inbox(), isEmpty);
      });

      test('an add racing a scan: one clip, one place, either order', () async {
        final goa = await reel('Goa');

        final results = await Future.wait<Object>([
          h.scanner.scan(),
          service.addFromFolder([v], AddToReel(goa)),
        ]);

        // The scan went first and put it in To tag: it is marked there, so
        // the add leaves it.
        expectCounts(results[1] as AddResult, alreadyThere: 1);
        expect(await h.allClips(), hasLength(1));
        expect(await inbox(), hasLength(1));
        expect(await links(), isEmpty);
      });

      test('an add racing a scan, add first: one clip, in the reel', () async {
        final goa = await reel('Goa');

        await Future.wait<Object>([
          service.addFromFolder([v], AddToReel(goa)),
          h.scanner.scan(),
        ]);

        final clip = await clipOf(v);
        expect(await h.allClips(), hasLength(1));
        expect(await reelIdsOf(clip.id), {goa});
        expect(await inbox(), isEmpty);
      });
    });
  });

  group('a video TakeTray already has', () {
    test('in To tag, added to To tag or to a reel: left as it is', () async {
      final goa = await reel('Goa');
      final v = friend(7);
      h.bridge.put([v]);
      await stored(v);
      final before = await snapshot();

      expectCounts(await service.addFromFolder([v], toTag), alreadyThere: 1);
      expectCounts(
        await service.addFromFolder([v], AddToReel(goa)),
        alreadyThere: 1,
      );

      expect(await snapshot(), before);
    });

    test('in a reel, added to To tag: left in its reel', () async {
      final goa = await reel('Goa');
      final v = friend(7);
      h.bridge.put([v]);
      final id = await stored(v);
      await h.clips.tagClip(id, {goa});
      final before = await snapshot();

      expectCounts(await service.addFromFolder([v], toTag), alreadyThere: 1);

      expect(await snapshot(), before);
    });

    test('in another reel, added to this one: linked here too, and Undo '
        'takes only that link away', () async {
      final goa = await reel('Goa');
      final paris = await reel('Paris');
      final v = friend(7);
      h.bridge.put([v]);
      final id = await stored(v);
      await h.clips.tagClip(id, {paris});

      final r = await service.addFromFolder([v], AddToReel(goa));

      expectCounts(r, added: 1);
      expect(await reelIdsOf(id), {goa, paris});
      await service.undo(r);
      expect(await reelIdsOf(id), {paris});
      expect(await inbox(), isEmpty);
    });

    test('in Skipped, added to To tag: pending again, with its addedAt; '
        'Undo puts it back in Skipped', () async {
      final v = friend(7);
      h.bridge.put([v]);
      final id = await stored(v);
      final arrived = (await inboxOf(id))!.addedAt;
      await h.clips.skipClips([id]);
      h.clock.advance(const Duration(hours: 1));

      final r = await service.addFromFolder([v], toTag);

      expectCounts(r, added: 1);
      final row = (await inboxOf(id))!;
      expect((row.state, row.addedAt), (InboxState.pending, arrived));

      await service.undo(r);
      final back = (await inboxOf(id))!;
      expect((back.state, back.addedAt), (InboxState.skipped, arrived));
      expect(await h.allClips(), hasLength(1));
    });

    test('in Skipped, added to a reel: linked and out of Skipped; Undo '
        'restores both, and the reel time', () async {
      final goa = await reel('Goa');
      final goaBefore = (await reels.getById(goa))!.updatedAt;
      final v = friend(7);
      h.bridge.put([v]);
      final id = await stored(v);
      final arrived = (await inboxOf(id))!.addedAt;
      await h.clips.skipClips([id]);
      h.clock.advance(const Duration(hours: 1));

      final r = await service.addFromFolder([v], AddToReel(goa));

      expectCounts(r, added: 1);
      expect(await reelIdsOf(id), {goa});
      expect(await inboxOf(id), isNull);

      await service.undo(r);
      expect(await reelIdsOf(id), isEmpty);
      final back = (await inboxOf(id))!;
      expect((back.state, back.addedAt), (InboxState.skipped, arrived));
      expect((await reels.getById(goa))!.updatedAt, goaBefore);
    });

    test('a mixed list counts each: new, already there, from Skipped, '
        'unusable', () async {
      final v1 = friend(1);
      final v2 = friend(2);
      final v3 = friend(3);
      final v4 = friend(4, size: 0);
      h.bridge.put([v1, v2, v3, v4]);
      await stored(v2);
      final skipped = await stored(v3);
      await h.clips.skipClips([skipped]);

      final r = await service.addFromFolder([v1, v2, v3, v4, v1], toTag);

      expectCounts(r, added: 2, alreadyThere: 1, notKept: 1);
    });
  });

  group('a stored clip at this number that is another video (sameVideo)', () {
    test('missing, in a reel: it detaches and stays there flagged; the video '
        'comes in as a new clip', () async {
      final goa = await reel('Goa');
      final old = friend(5, size: 111);
      final oldId = await stored(old);
      await h.clips.tagClip(oldId, {goa});
      await flagClips(h.db, {oldId}, missing: true, at: h.clock.now());
      final now = friend(5, size: 222);
      h.bridge.put([now]);

      final r = await service.addFromFolder([now], toTag);

      expectCounts(r, added: 1);
      final detached = await h.clip(oldId);
      expect((detached.mediaStoreId, detached.missing), (-oldId, true));
      expect(await reelIdsOf(oldId), {goa});
      final fresh = await clipOf(now);
      expect(fresh.id, isNot(oldId));
      expect(fresh.fingerprint.sizeBytes, 222);
      expect((await inboxOf(fresh.id))!.state, InboxState.pending);
    });

    test('in To tag (an imported clip): it detaches and leaves To tag; the '
        'video comes in, to the reel', () async {
      final goa = await reel('Goa');
      final oldId = await stored(friend(5, size: 111));
      final now = friend(5, size: 222);
      h.bridge.put([now]);

      final r = await service.addFromFolder([now], AddToReel(goa));

      expectCounts(r, added: 1);
      expect(
        (await h.allClips()).map((c) => c.id),
        isNot(contains(oldId)),
        reason: 'detached and in no place: swept (Ruling Y)',
      );
      final fresh = await clipOf(now);
      expect(await reelIdsOf(fresh.id), {goa});
      expect(await inbox(), isEmpty);
    });

    test('missing but the same video: it is found, not added again', () async {
      final goa = await reel('Goa');
      final v = friend(5);
      final id = await stored(v);
      await h.clips.tagClip(id, {goa});
      await flagClips(h.db, {id}, missing: true, at: h.clock.now());
      h.bridge.put([v]);

      final r = await service.addFromFolder([v], AddToReel(goa));

      expectCounts(r, alreadyThere: 1);
      expect(await h.allClips(), hasLength(1));
    });
  });

  group('Undo', () {
    test('removes only what this add created', () async {
      final older = friend(1);
      final known = friend(2);
      final fresh1 = friend(3);
      final fresh2 = friend(4);
      h.bridge.put([older, known, fresh1, fresh2]);
      final olderId = await stored(older);
      final knownId = await stored(known);

      final r = await service.addFromFolder([known, fresh1, fresh2], toTag);
      expectCounts(r, added: 2, alreadyThere: 1);
      await service.undo(r);

      expect((await h.allClips()).map((c) => c.id), [olderId, knownId]);
      expect(
        {for (final row in await inbox()) row.clipId: row.state},
        {olderId: InboxState.pending, knownId: InboxState.pending},
      );
    });

    test('from a reel: the new clips go, the reel time comes back', () async {
      final goa = await reel('Goa');
      final goaBefore = (await reels.getById(goa))!.updatedAt;
      final there = friend(1);
      final v = friend(2);
      h.bridge.put([there, v]);
      h.clock.advance(const Duration(minutes: 1));
      await service.addFromFolder([there], AddToReel(goa));
      final thereId = (await clipOf(there)).id;
      final afterFirst = (await reels.getById(goa))!.updatedAt;
      h.clock.advance(const Duration(minutes: 3));

      final r = await service.addFromFolder([there, v], AddToReel(goa));
      await service.undo(r);

      expect((await h.allClips()).map((c) => c.id), [thereId]);
      expect(await reelIdsOf(thereId), {goa});
      expect((await reels.getById(goa))!.updatedAt, afterFirst);
      expect(afterFirst, isNot(goaBefore));
    });

    test('from a reel: a clip the user put in the reel at the same moment '
        'keeps its link', () async {
      final goa = await reel('Goa');
      final mine = friend(1);
      final v = friend(2);
      h.bridge.put([mine, v]);
      final mineId = await stored(mine);
      // The user tags it into Goa in the same millisecond as the add.
      await h.clips.tagClip(mineId, {goa});
      final r = await service.addFromFolder([v], AddToReel(goa));

      await service.undo(r);

      expect(await reelIdsOf(mineId), {goa});
      expect((await h.allClips()).map((c) => c.id), [mineId]);
    });

    test('keeps a clip tagged meanwhile (added to To tag)', () async {
      final goa = await reel('Goa');
      final v1 = friend(1);
      final v2 = friend(2);
      h.bridge.put([v1, v2]);
      final r = await service.addFromFolder([v1, v2], toTag);
      final tagged = (await clipOf(v1)).id;
      await h.clips.tagClip(tagged, {goa});

      await service.undo(r);

      expect((await h.allClips()).map((c) => c.id), [tagged]);
      expect(await reelIdsOf(tagged), {goa});
      expect(await inbox(), isEmpty);
    });

    test('keeps a clip skipped meanwhile (added to To tag)', () async {
      final v = friend(1);
      h.bridge.put([v]);
      final r = await service.addFromFolder([v], toTag);
      final id = (await clipOf(v)).id;
      await h.clips.skipClips([id]);

      await service.undo(r);

      expect((await inboxOf(id))!.state, InboxState.skipped);
    });

    test(
      'keeps a clip put in another reel meanwhile (added to a reel)',
      () async {
        final goa = await reel('Goa');
        final paris = await reel('Paris');
        final v = friend(1);
        h.bridge.put([v]);
        final r = await service.addFromFolder([v], AddToReel(goa));
        final id = (await clipOf(v)).id;
        await h.clips.addClipsToReel(paris, [id]);

        await service.undo(r);

        expect(await reelIdsOf(id), {paris});
      },
    );

    test('a second Undo changes nothing, even after the user moved the clip '
        'back', () async {
      final v = friend(1);
      h.bridge.put([v]);
      final id = await stored(v);
      await h.clips.skipClips([id]);
      final r = await service.addFromFolder([v], toTag);

      await service.undo(r);
      expect((await inboxOf(id))!.state, InboxState.skipped);
      // The user restores it from Skipped by hand: the same row as the add
      // left it (pending, same addedAt).
      await h.clips.restoreClips([id]);
      final before = await snapshot();

      await service.undo(r);

      expect(await snapshot(), before);
    });

    test('a second Undo of new clips changes nothing', () async {
      final v = friend(1);
      h.bridge.put([v]);
      final r = await service.addFromFolder([v], toTag);
      await service.undo(r);
      final before = await snapshot();

      await service.undo(r);

      expect(await snapshot(), before);
      expect(await h.allClips(), isEmpty);
    });

    test('Undo of an add that changed nothing changes nothing', () async {
      final v = friend(1);
      h.bridge.put([v]);
      await stored(v);
      final r = await service.addFromFolder([v], toTag);
      final before = await snapshot();

      await service.undo(r);

      expect(await snapshot(), before);
    });

    test('Undo after the reel was deleted does not throw', () async {
      final goa = await reel('Goa');
      final v = friend(1);
      h.bridge.put([v]);
      final r = await service.addFromFolder([v], AddToReel(goa));
      await reels.delete(goa);

      await service.undo(r);

      expect(await h.allClips(), isEmpty);
    });

    test('a clip the add detached is not attached again', () async {
      final oldId = await stored(friend(5, size: 111));
      final goa = await reel('Goa');
      await h.clips.tagClip(oldId, {goa});
      final now = friend(5, size: 222);
      h.bridge.put([now]);

      final r = await service.addFromFolder([now], toTag);
      await service.undo(r);

      final old = await h.clip(oldId);
      expect(old.mediaStoreId, -oldId);
      expect(await h.allClips(), hasLength(1), reason: 'the new clip went');
    });

    test(
      'works without full access (it reads nothing from the phone)',
      () async {
        final v = friend(1);
        h.bridge.put([v]);
        final r = await service.addFromFolder([v], toTag);
        h.bridge.access = const MediaAccess(
          level: MediaAccessLevel.denied,
          canAskAgain: true,
          sdkInt: 34,
        );

        await service.undo(r);

        expect(await h.allClips(), isEmpty);
      },
    );
  });

  group('marks', () {
    late int goa;
    late int paris;
    late Map<String, int> ids;

    setUp(() async {
      goa = await reel('Goa');
      paris = await reel('Paris');
      ids = {};
      Future<int> keep(int n) async => ids['$n'] = await stored(friend(n));
      await keep(1); // To tag
      await h.clips.skipClips([await keep(2)]); // Skipped
      await h.clips.tagClip(await keep(3), {goa}); // in Goa
      await h.clips.tagClip(await keep(4), {paris}); // in Paris only
      final missing = await keep(5); // in Goa, flagged missing
      await h.clips.tagClip(missing, {goa});
      await flagClips(h.db, {missing}, missing: true, at: h.clock.now());
      final detached = await keep(6); // in Goa, detached (number -id)
      await h.clips.tagClip(detached, {goa});
      await detachClips(h.db, {detached}, at: h.clock.now());
      await h.clips.tagClip(await keep(8), {goa, paris}); // in both
      // To tag, on the SD card.
      await h.store([friend(1, volume: card)], zoneId: 'UTC');
    });

    final asked = [1, 2, 3, 4, 5, 6, 8, 9, 99];

    test('target a reel: In this reel and In To tag', () async {
      expect(await service.marks(phone, asked, AddToReel(goa)), {
        1: AddMark.inToTag,
        3: AddMark.inThisReel,
        8: AddMark.inThisReel,
      });
      expect(await service.marks(phone, asked, AddToReel(paris)), {
        1: AddMark.inToTag,
        4: AddMark.inThisReel,
        8: AddMark.inThisReel,
      });
    });

    test('target To tag: In To tag and In a reel', () async {
      expect(await service.marks(phone, asked, toTag), {
        1: AddMark.inToTag,
        3: AddMark.inAReel,
        4: AddMark.inAReel,
        8: AddMark.inAReel,
      });
    });

    test('a skipped, missing, detached or unknown video has no mark', () async {
      final marks = await service.marks(phone, [2, 5, 6, 99], toTag);
      expect(marks, isEmpty);
    });

    test('only the asked volume counts', () async {
      expect(await service.marks(card, [1, 3], toTag), {1: AddMark.inToTag});
    });

    test('a picked clip is never a folder video', () async {
      await service.addPicked([pick('content://media/picker/0/42')], toTag);
      expect(await service.marks(phone, [42], toTag), isEmpty);
    });

    test(
      'a marked video is what the add leaves alone (alreadyThere)',
      () async {
        final videos = [for (final n in asked) friend(n)];
        h.bridge.put(videos);
        for (final target in [toTag, AddToReel(goa), AddToReel(paris)]) {
          final marks = await service.marks(phone, asked, target);
          for (final v in videos) {
            final before = await snapshot();
            final r = await service.addFromFolder([v], target);
            if (marks.containsKey(v.mediaStoreId)) {
              expectCounts(r, alreadyThere: 1);
              expect(await snapshot(), before, reason: '${v.mediaStoreId}');
            } else if (v.mediaStoreId != 5) {
              // 5 is a missing clip: no mark (the app cannot see it), yet the
              // add finds it by fingerprint and leaves it (D-113).
              expect(r.alreadyThere, 0, reason: '${v.mediaStoreId} $target');
            }
            await service.undo(r);
          }
        }
      },
    );

    test('no ids: no marks', () async {
      expect(await service.marks(phone, const [], toTag), isEmpty);
    });

    test('does not wait for the media queue (a long scan keeps the grid '
        'responsive)', () async {
      final hold = Completer<void>();
      unawaited(h.queue.run(() => hold.future));

      expect(await service.marks(phone, [1], toTag), {1: AddMark.inToTag});
      hold.complete();
    });
  });

  group('a picked video (photo picker)', () {
    const uri = 'content://media/picker/0/com.android.providers.media/7';

    test('a picker clip with its URI, pending in To tag', () async {
      h.bridge.currentZone = 'Europe/London';
      await h.zones.recordAll([
        ZoneEntry(at: DateTime.utc(2026, 5, 2), zoneId: 'Asia/Kolkata'),
      ]);

      final r = await service.addPicked([pick(uri)], toTag);

      expectCounts(r, added: 1);
      final clip = await pickedClip(uri);
      expect(clip.source, ClipSource.picker);
      expect((clip.volumeName, clip.mediaStoreId), (null, null));
      expect(clip.fingerprint.sizeBytes, 2000000);
      expect(clip.fingerprint.durationMs, 8000);
      expect(clip.fingerprint.dateTakenUtc, shotTime);
      expect(clip.fingerprint.displayName, 'picked.mp4');
      expect(
        (clip.width, clip.height, clip.mimeType),
        (1080, 1920, 'video/mp4'),
      );
      expect(clip.timeZoneId, 'Asia/Kolkata');
      expect(clip.generationAdded, isNull);
      expect((await inboxOf(clip.id))!.state, InboxState.pending);
    });

    test('to a reel: linked, no inbox row', () async {
      final goa = await reel('Goa');

      expectCounts(
        await service.addPicked([pick(uri)], AddToReel(goa)),
        added: 1,
      );

      expect(await reelIdsOf((await pickedClip(uri)).id), {goa});
      expect(await inbox(), isEmpty);
    });

    test('persisted = false is notKept and adds nothing', () async {
      final r = await service.addPicked([
        pick('content://a', persisted: false),
        pick('content://b'),
      ], toTag);

      expectCounts(r, added: 1, notKept: 1);
      expect(
        [for (final c in await h.allClips()) c.pickerUri],
        ['content://b'],
      );
    });

    test('no date: the time of the add, as the scan rule falls back', () async {
      await service.addPicked([pick(uri, noDate: true)], toTag);
      expect((await pickedClip(uri)).fingerprint.dateTakenUtc, h.clock.now());
    });

    test(
      'an implausible date (far ahead, or before 1970): the time of the add',
      () async {
        final ahead = h.clock
            .now()
            .add(const Duration(days: 30))
            .millisecondsSinceEpoch;
        await service.addPicked([
          pick('content://ahead', dateTakenMs: ahead),
          pick('content://before', dateTakenMs: -5),
        ], toTag);

        expect(
          (await pickedClip('content://ahead')).fingerprint.dateTakenUtc,
          h.clock.now(),
        );
        expect(
          (await pickedClip('content://before')).fingerprint.dateTakenUtc,
          h.clock.now(),
        );
      },
    );

    test(
      'a missing name, size, length, size in pixels or type never throws',
      () async {
        final r = await service.addPicked([
          pick(
            uri,
            displayName: '',
            sizeBytes: 0,
            durationMs: null,
            width: null,
            height: null,
            mimeType: null,
          ),
        ], toTag);

        expectCounts(r, added: 1);
        final clip = await pickedClip(uri);
        expect(clip.fingerprint.displayName, '');
        expect(clip.fingerprint.sizeBytes, 0);
        expect(clip.fingerprint.durationMs, 0);
        expect((clip.width, clip.height), (0, 0));
        expect(clip.mimeType, defaultVideoMimeType);
      },
    );

    test(
      'the same URI twice (and at once): one clip, the second alreadyThere',
      () async {
        expectCounts(await service.addPicked([pick(uri)], toTag), added: 1);
        expectCounts(
          await service.addPicked([pick(uri)], toTag),
          alreadyThere: 1,
        );
        final [a, b] = await Future.wait([
          service.addPicked([pick('content://x')], toTag),
          service.addPicked([pick('content://x')], toTag),
        ]);
        expectCounts(a, added: 1);
        expectCounts(b, alreadyThere: 1);
        expect(await h.allClips(), hasLength(2));
      },
    );

    test('Undo removes the picked clip', () async {
      await service.addPicked([pick('content://keep')], toTag);
      final r = await service.addPicked([pick(uri)], toTag);

      await service.undo(r);

      expect(
        [for (final c in await h.allClips()) c.pickerUri],
        ['content://keep'],
      );
    });
  });

  group('access', () {
    for (final level in [MediaAccessLevel.limited, MediaAccessLevel.denied]) {
      test(
        '${level.name}: a folder add throws StateError and writes nothing',
        () async {
          final v = friend(7);
          h.bridge
            ..put([v])
            ..access = MediaAccess(level: level, canAskAgain: true, sdkInt: 34);

          await expectLater(
            service.addFromFolder([v], toTag),
            throwsA(isA<StateError>()),
          );
          expect(await h.allClips(), isEmpty);
        },
      );

      test('${level.name}: the picker route still works', () async {
        h.bridge.access = MediaAccess(
          level: level,
          canAskAgain: true,
          sdkInt: 34,
        );

        expectCounts(
          await service.addPicked([pick('content://p')], toTag),
          added: 1,
        );
      });
    }

    test(
      'a failed access read fails the folder add, writing nothing',
      () async {
        final v = friend(7);
        h.bridge
          ..put([v])
          ..failNext('accessReport');

        await expectLater(service.addFromFolder([v], toTag), throwsA(anything));
        expect(await h.allClips(), isEmpty);
      },
    );
  });

  group('failures', () {
    test('a reel that is gone throws StateError and writes nothing', () async {
      final v = friend(7);
      h.bridge.put([v]);

      await expectLater(
        service.addFromFolder([v], const AddToReel(999)),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        service.addPicked([pick('content://p')], const AddToReel(999)),
        throwsA(isA<StateError>()),
      );
      expect(await h.allClips(), isEmpty);
    });

    test('a write that fails half way rolls the whole add back, and the queue '
        'goes on', () async {
      final log = StatementLog();
      final h = MediaHarness(database: loggedTestDatabase(log));
      final service = serviceOn(h);
      final videos = [friend(1), friend(2), friend(3)];
      h.bridge.put(videos);
      var inserts = 0;
      log.failWhen = (sql) =>
          sql.startsWith('INSERT INTO "inbox"') && ++inserts == 3;

      await expectLater(
        service.addFromFolder(videos, toTag),
        throwsA(isA<StateError>()),
      );
      expect(await h.allClips(), isEmpty);
      expect(await h.db.select(h.db.inbox).get(), isEmpty);

      expectCounts(await service.addFromFolder(videos, toTag), added: 3);
    });

    test('a write that fails during Undo leaves the add whole, and Undo can '
        'run again', () async {
      final log = StatementLog();
      final h = MediaHarness(database: loggedTestDatabase(log));
      final service = serviceOn(h);
      final v1 = friend(1);
      final v2 = friend(2);
      h.bridge.put([v1, v2]);
      final keep = (await h.store([v2], zoneId: 'UTC')).single;
      await h.clips.skipClips([keep]);
      final r = await service.addFromFolder([v1, v2], toTag);
      log.failWhen = (sql) => sql.startsWith('DELETE FROM "clips"');

      await expectLater(service.undo(r), throwsA(isA<StateError>()));
      expect(await h.allClips(), hasLength(2));
      expect(
        {for (final row in await h.db.select(h.db.inbox).get()) row.state},
        {InboxState.pending},
        reason: 'the restore from Skipped was rolled back too',
      );

      await service.undo(r);
      expect((await h.allClips()).map((c) => c.id), [keep]);
      expect(
        (await h.db.select(h.db.inbox).get()).single.state,
        InboxState.skipped,
      );
    });
  });

  group('the media queue', () {
    test('an add waits for the job ahead of it', () async {
      final v = friend(7);
      h.bridge.put([v]);
      final hold = Completer<void>();
      unawaited(h.queue.run(() => hold.future));

      var done = false;
      final adding = service
          .addFromFolder([v], toTag)
          .whenComplete(() => done = true);
      final picking = service.addPicked([pick('content://p')], toTag);
      await settle();
      expect(done, isFalse);
      expect(await h.allClips(), isEmpty);

      hold.complete();
      await adding;
      await picking;
      expect(await h.allClips(), hasLength(2));
    });

    test('an Undo waits for the job ahead of it', () async {
      final v = friend(7);
      h.bridge.put([v]);
      final r = await service.addFromFolder([v], toTag);
      final hold = Completer<void>();
      unawaited(h.queue.run(() => hold.future));

      final undoing = service.undo(r);
      await settle();
      expect(await h.allClips(), hasLength(1));

      hold.complete();
      await undoing;
      expect(await h.allClips(), isEmpty);
    });
  });

  group('a big batch', () {
    const n = ClipsRepository.idBatch * 2 + 1;

    test('$n videos in one transaction, every IN list at most idBatch, the '
        'reads batched', () async {
      final log = StatementLog();
      final h = MediaHarness(database: loggedTestDatabase(log));
      final service = serviceOn(h);
      final videos = [for (var i = 1; i <= n; i++) friend(i)];
      h.bridge.put(videos);
      // A few of them already known, one skipped, so every path runs.
      final known = await h.store(videos.take(3).toList(), zoneId: 'UTC');
      await h.clips.skipClips([known.first]);
      log.clear();

      final r = await service.addFromFolder(videos, toTag);

      expectCounts(r, added: n - 2, alreadyThere: 2);
      expect(await h.toTag(), hasLength(n));
      int vars(String sql) => '?'.allMatches(sql).length;
      for (final sql in [...log.selects, ...log.writes]) {
        expect(
          vars(sql),
          lessThanOrEqualTo(ClipsRepository.idBatch + 8),
          reason: sql.length > 60 ? sql.substring(0, 60) : sql,
        );
      }
      expect(
        log.selects.length,
        lessThan(60),
        reason: 'reads are batched, not one per video',
      );

      // One transaction: a failure at the last write keeps nothing.
      final h2 = MediaHarness(database: loggedTestDatabase(log));
      final service2 = serviceOn(h2);
      h2.bridge.put(videos);
      var inbox = 0;
      log.failWhen = (sql) =>
          sql.startsWith('INSERT INTO "inbox"') && ++inbox == n;
      await expectLater(
        service2.addFromFolder(videos, toTag),
        throwsA(isA<StateError>()),
      );
      expect(await h2.allClips(), isEmpty);

      log.clear();
      await service.undo(r);
      for (final sql in [...log.selects, ...log.writes]) {
        expect(vars(sql), lessThanOrEqualTo(ClipsRepository.idBatch + 8));
      }
      expect(await h.allClips(), hasLength(3));
      expect(
        {for (final c in await h.skipped()) c.id},
        {known.first},
        reason: 'the skipped one went back',
      );
    });

    test('marks for $n ids', () async {
      final log = StatementLog();
      final h = MediaHarness(database: loggedTestDatabase(log));
      final service = serviceOn(h);
      final videos = [for (var i = 1; i <= n; i++) friend(i)];
      await h.store(videos, zoneId: 'UTC');
      log.clear();

      final marks = await service.marks(phone, [
        for (final v in videos) v.mediaStoreId,
      ], toTag);

      expect(marks, hasLength(n));
      expect(marks.values.toSet(), {AddMark.inToTag});
      for (final sql in log.selects) {
        expect(
          '?'.allMatches(sql).length,
          lessThanOrEqualTo(ClipsRepository.idBatch + 8),
        );
      }
    });
  });

  test('logs counts only: no name, folder, URI or reel name (D-10)', () async {
    final logs = captureLogs();
    final goa = (await reels.create('SECRET-REEL')).id;
    final v = friend(7, name: 'SECRET-NAME.mp4', folder: 'SECRET-FOLDER/');
    final skipped = friend(
      8,
      name: 'SECRET-NAME-2.mp4',
      folder: 'SECRET-FOLDER/',
    );
    h.bridge.put([v, skipped]);
    await h.clips.skipClips([await stored(skipped)]);

    final a = await service.addFromFolder([
      v,
      skipped,
      friend(9, size: 0),
    ], AddToReel(goa));
    final b = await service.addPicked([
      pick('content://SECRET-URI/1', displayName: 'SECRET-PICK.mp4'),
      pick('content://SECRET-URI/2', persisted: false),
    ], toTag);
    await service.marks(phone, [7, 8], toTag);
    await service.undo(a);
    await service.undo(b);
    h.bridge.access = const MediaAccess(
      level: MediaAccessLevel.limited,
      canAskAgain: true,
      sdkInt: 34,
    );
    await expectLater(service.addFromFolder([v], toTag), throwsStateError);

    final text = logText(logs);
    expect(text, isNot(contains('SECRET')));
    expect(text, isNot(contains('content:')));
    expect(text, isNot(contains('WhatsApp')));
    expect(logs.where((r) => r.loggerName == 'addVideos'), isNotEmpty);
  });

  test('targets compare by value, and a result prints its counts', () async {
    expect(const AddToToTag(), const AddToToTag());
    expect(const AddToToTag().hashCode, const AddToToTag().hashCode);
    expect(const AddToReel(3), const AddToReel(3));
    expect(const AddToReel(3).hashCode, const AddToReel(3).hashCode);
    expect(const AddToReel(3), isNot(const AddToReel(4)));
    expect(const AddToReel(3), isNot(const AddToToTag()));
    final r = await service.addPicked([
      pick('content://a', persisted: false),
    ], toTag);
    expect('$r', 'AddResult(0 added, 0 already there, 1 not kept)');
  });

  test('addVideosServiceProvider builds one service', () {
    final db = testDatabase();
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        mediaBridgeProvider.overrideWithValue(FakeMediaBridge()),
      ],
    );
    addTearDown(container.dispose);
    final service = container.read(addVideosServiceProvider);
    expect(container.read(addVideosServiceProvider), same(service));
  });
}
