import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/domain/models/zone_entry.dart';

import '../support/fake_media_bridge.dart';

void main() {
  late FakeMediaBridge fake;

  setUp(() => fake = FakeMediaBridge());

  group('videosAddedAfter', () {
    test('filters by generation, folder (case-insensitive, exact), and limit, '
        'in generation order', () async {
      fake.videosByVolume['v'] = [
        fakeVideo(id: 1, generation: 30),
        fakeVideo(id: 2, generation: 10),
        fakeVideo(id: 3, generation: 20, folder: 'dcim/camera/'),
        fakeVideo(id: 4, generation: 25, folder: 'DCIM/Camera/Sub/'),
        fakeVideo(id: 5, generation: 26, folder: 'DCIM/Other/'),
        fakeVideo(id: 6, generation: 5),
        fakeVideo(id: 7, generation: 40),
      ];

      final all = await fake.videosAddedAfter('v', 5, ['DCIM/Camera/'], 100);
      // Generation 5 is not > 5; the subfolder and other folder are out.
      expect(all.map((v) => v.mediaStoreId), [2, 3, 1, 7]);
      expect(all.map((v) => v.generationAdded), [10, 20, 30, 40]);

      final limited = await fake.videosAddedAfter('v', 5, ['DCIM/Camera/'], 2);
      expect(limited.map((v) => v.mediaStoreId), [2, 3]);

      // A folder given without its trailing slash, in other case, matches.
      final loose = await fake.videosAddedAfter('v', 0, ['dcim/CAMERA'], 100);
      expect(loose.map((v) => v.mediaStoreId), [6, 2, 3, 1, 7]);

      // No folders match nothing; an unknown volume has no videos.
      expect(await fake.videosAddedAfter('v', 0, [], 100), isEmpty);
      expect(
        await fake.videosAddedAfter('x', 0, ['DCIM/Camera/'], 100),
        isEmpty,
      );
      expect(await fake.videosAddedAfter('v', 0, ['DCIM/Camera/'], 0), isEmpty);
    });

    test(
      'compares the stored path as is: no slash added, ASCII case only',
      () async {
        fake.videosByVolume['v'] = [
          fakeVideo(id: 1, folder: 'DCIM/Camera'),
          fakeVideo(id: 2, folder: 'Vidéos/'),
          fakeVideo(id: 3, folder: 'VIDÉOS/'),
          fakeVideo(id: 4, folder: 'DCIM/CAMERA/'),
        ];
        // The phone adds the slash to the requested folder only, so a stored
        // path without one never matches.
        final plain = await fake.videosAddedAfter('v', 0, ['DCIM/Camera'], 10);
        expect(plain.map((v) => v.mediaStoreId), [4]);
        // SQLite's NOCASE folds only A-Z: 'é' and 'É' are different letters.
        final accented = await fake.videosAddedAfter('v', 0, ['Vidéos/'], 10);
        expect(accented.map((v) => v.mediaStoreId), [2]);
        final shot = await fake.videosShotSince('v', ['Vidéos'], 0);
        expect(shot.map((v) => v.mediaStoreId), [2]);
      },
    );

    test('includes pending rows', () async {
      fake.videosByVolume['v'] = [
        fakeVideo(id: 1, generation: 10, pending: true),
        fakeVideo(id: 2, generation: 11),
      ];
      final rows = await fake.videosAddedAfter('v', 0, ['DCIM/Camera/'], 10);
      expect(rows.map((v) => v.mediaStoreId), [1, 2]);
      expect(rows.first.isPending, isTrue);
    });
  });

  group('videosShotSince', () {
    test(
      'is the superset the contract describes, and excludes pending',
      () async {
        const since = 1000000;
        fake.videosByVolume['v'] = [
          // Included by one of the three dates, or by a null DATE_ADDED.
          fakeVideo(id: 1, dateTakenMs: since),
          fakeVideo(id: 2, dateTakenMs: since - 1, dateAddedSec: 1000),
          fakeVideo(
            id: 3,
            dateTakenMs: since - 1,
            dateAddedSec: 1,
            dateModifiedSec: 1001,
          ),
          fakeVideo(id: 4, dateTakenMs: since - 1, dateAddedSec: null),
          fakeVideo(id: 5, dateTakenMs: null, dateAddedSec: 1000),
          // Everything older.
          fakeVideo(
            id: 6,
            dateTakenMs: since - 1,
            dateAddedSec: 999,
            dateModifiedSec: 999,
          ),
          fakeVideo(
            id: 7,
            dateTakenMs: null,
            dateAddedSec: 1,
            dateModifiedSec: null,
          ),
          // Pending is excluded even when new, and a wrong folder is out.
          fakeVideo(id: 8, dateTakenMs: since, pending: true),
          fakeVideo(id: 9, dateTakenMs: since, folder: 'Pictures/'),
          fakeVideo(id: 10, dateTakenMs: since, folder: 'dcim/CAMERA/'),
        ];
        final rows = await fake.videosShotSince('v', ['DCIM/Camera/'], since);
        expect(rows.map((v) => v.mediaStoreId), [1, 2, 3, 4, 5, 10]);
      },
    );
  });

  test('videosShotSince rounds sinceMs down to whole seconds', () async {
    fake.videosByVolume['v'] = [
      fakeVideo(id: 1, dateTakenMs: 0, dateAddedSec: 1, dateModifiedSec: 0),
      fakeVideo(id: 2, dateTakenMs: 0, dateAddedSec: 0, dateModifiedSec: 1),
      fakeVideo(id: 3, dateTakenMs: 0, dateAddedSec: 0, dateModifiedSec: 0),
    ];
    // 1999 ms is 1 s: the real query compares seconds with sinceMs ~/ 1000,
    // so the fake must not hide a row the phone would return.
    final rows = await fake.videosShotSince('v', ['DCIM/Camera/'], 1999);
    expect(rows.map((v) => v.mediaStoreId), [1, 2]);
  });

  test('videosByIds returns the known ids and ignores the rest', () async {
    fake.videosByVolume['v'] = [
      fakeVideo(id: 1),
      fakeVideo(id: 2),
      fakeVideo(id: 3),
    ];
    fake.videosByVolume['w'] = [fakeVideo(id: 1, volume: 'w')];
    expect(
      (await fake.videosByIds('v', [3, 1, 99])).map((v) => v.mediaStoreId),
      [1, 3],
    );
    expect((await fake.videosByIds('w', [1])).single.volumeName, 'w');
    expect(await fake.videosByIds('v', []), isEmpty);
  });

  test('allVideos returns every non-pending video of the volume', () async {
    fake.videosByVolume['v'] = [
      fakeVideo(id: 1),
      fakeVideo(id: 2, pending: true),
      fakeVideo(id: 3, folder: 'Anywhere/'),
    ];
    expect((await fake.allVideos('v')).map((v) => v.mediaStoreId), [1, 3]);
    expect(await fake.allVideos('nope'), isEmpty);
  });

  group('failNext', () {
    test('throws once', () async {
      fake.failNext('volumes');
      await expectLater(fake.volumes(), throwsA(isA<PlatformException>()));
      expect(await fake.volumes(), isEmpty);
    });

    test('only the named method fails, and the call is still logged', () async {
      fake.failNext('allVideos');
      expect(await fake.volumes(), isEmpty);
      await expectLater(fake.allVideos('v'), throwsA(isA<PlatformException>()));
      expect(fake.calls, ['volumes', 'allVideos']);
    });

    test('a failure also uses up a gate set for the same method', () async {
      fake
        ..failNext('volumes')
        ..gate('volumes');
      await expectLater(fake.volumes(), throwsA(isA<PlatformException>()));
      // The gate went with the failed call: this one does not wait.
      expect(await fake.volumes().timeout(const Duration(seconds: 1)), isEmpty);
    });

    test('two queued failures fail two calls', () async {
      fake
        ..failNext('accessReport')
        ..failNext('accessReport');
      await expectLater(fake.accessReport(), throwsA(isA<PlatformException>()));
      await expectLater(fake.accessReport(), throwsA(isA<PlatformException>()));
      expect((await fake.accessReport()).level, MediaAccessLevel.full);
    });
  });

  group('gate', () {
    test('pauses the next call until the test completes it', () async {
      fake.videosByVolume['v'] = [fakeVideo(id: 1)];
      final gate = fake.gate('allVideos');
      var done = false;
      final pending = fake.allVideos('v').then((rows) {
        done = true;
        return rows;
      });
      await pumpEventQueue();
      expect(fake.calls, ['allVideos']);
      expect(done, isFalse);

      // The answer was read when the call started, not when it was released.
      fake.videosByVolume['v'] = [];
      gate.complete();
      expect((await pending).map((v) => v.mediaStoreId), [1]);
      expect(done, isTrue);

      // The gate was used up: the next call does not wait.
      expect(await fake.allVideos('v'), isEmpty);
    });
  });

  test('calls logs method names in order', () async {
    await fake.accessReport();
    await fake.volumes();
    await fake.openAppSettings();
    await fake.currentZoneId();
    expect(fake.calls, [
      'accessReport',
      'volumes',
      'openAppSettings',
      'currentZoneId',
    ]);
  });

  test(
    'requestAccess returns the programmed result and updates access',
    () async {
      expect(fake.access.level, MediaAccessLevel.full);
      fake
        ..access = const MediaAccess(
          level: MediaAccessLevel.denied,
          canAskAgain: true,
          sdkInt: 34,
        )
        ..onRequestAccess = () => const MediaAccess(
          level: MediaAccessLevel.limited,
          canAskAgain: false,
          sdkInt: 34,
        );
      expect((await fake.requestAccess()).level, MediaAccessLevel.limited);
      expect((await fake.accessReport()).level, MediaAccessLevel.limited);
      expect((await fake.accessReport()).canAskAgain, isFalse);
    },
  );

  test('thumbnails come from the map, null when absent', () async {
    fake.thumbnails[('v', 1)] = Uint8List.fromList([1, 2, 3]);
    expect(await fake.thumbnail('v', 1, 10, 10), [1, 2, 3]);
    expect(await fake.thumbnail('v', 2, 10, 10), isNull);
    expect(await fake.thumbnail('w', 1, 10, 10), isNull);
  });

  test(
    'zone changes are read, then cleared up to and including atMs',
    () async {
      fake
        ..currentZone = 'Asia/Kolkata'
        ..zoneChanges = [
          ZoneEntry(at: DateTime.utc(2026), zoneId: 'UTC'),
          ZoneEntry(at: DateTime.utc(2026, 1, 2), zoneId: 'Europe/London'),
          ZoneEntry(at: DateTime.utc(2026, 1, 3), zoneId: 'Asia/Kolkata'),
        ];
      expect(await fake.currentZoneId(), 'Asia/Kolkata');
      expect(await fake.pendingZoneChanges(), hasLength(3));
      await fake.clearZoneChangesUpTo(
        DateTime.utc(2026, 1, 2).millisecondsSinceEpoch,
      );
      expect((await fake.pendingZoneChanges()).map((e) => e.zoneId), [
        'Asia/Kolkata',
      ]);
      expect(fake.clearedUpTo, [
        DateTime.utc(2026, 1, 2).millisecondsSinceEpoch,
      ]);
    },
  );

  test('volumes, folders and the camera are settable', () async {
    fake
      ..volumeList = const [MediaVolume(name: 'v', version: 'x', generation: 3)]
      ..folders = const [
        VideoFolder(volumeName: 'v', relativePath: 'A/', videoCount: 2),
      ];
    expect(await fake.volumes(), fake.volumeList);
    expect(await fake.videoFolders(), fake.folders);
    expect(await fake.openVideoCamera(), isTrue);
    fake.cameraOpens = false;
    expect(await fake.openVideoCamera(), isFalse);
  });
  group('videosInFolder', () {
    List<int> ids(List<MediaVideo> v) => [for (final x in v) x.mediaStoreId];

    test('keeps finished videos with a duration in exactly that folder, '
        'ignoring ASCII case only', () async {
      fake.videosByVolume['v'] = [
        fakeVideo(id: 1),
        fakeVideo(id: 2, folder: 'dcim/CAMERA/'),
        fakeVideo(id: 3, folder: 'DCIM/Camera/Sub/'),
        fakeVideo(id: 4, folder: 'DCIM/Camera'),
        fakeVideo(id: 5, pending: true),
        fakeVideo(id: 6, durationMs: 0),
        fakeVideo(id: 7, durationMs: null),
        fakeVideo(id: 8, folder: 'DCIM/Other/'),
        fakeVideo(id: 9, folder: 'Vidéos/'),
        fakeVideo(id: 10, folder: 'VIDÉOS/'),
      ];
      expect(ids(await fake.videosInFolder('v', 'DCIM/Camera', 100, 0)), [
        2,
        1,
      ]);
      expect(ids(await fake.videosInFolder('v', '/dcim/camera/', 100, 0)), [
        2,
        1,
      ]);
      expect(ids(await fake.videosInFolder('v', 'Vidéos', 100, 0)), [9]);
      expect(fake.calls, hasLength(3));
    });

    test('a folder of the volume root matches an empty path', () async {
      fake.videosByVolume['v'] = [
        fakeVideo(id: 1, folder: ''),
        fakeVideo(id: 2, folder: 'DCIM/'),
      ];
      expect(ids(await fake.videosInFolder('v', '', 10, 0)), [1]);
      expect(ids(await fake.videosInFolder('v', '/', 10, 0)), [1]);
    });

    test('is newest shot first: date taken, then date added, then date '
        'modified, ties by id, no date last', () async {
      fake.videosByVolume['v'] = [
        fakeVideo(id: 1, dateTakenMs: 5000000, dateAddedSec: 1),
        fakeVideo(
          id: 2,
          dateTakenMs: null,
          dateAddedSec: 6000,
          dateModifiedSec: 1,
        ),
        fakeVideo(
          id: 3,
          dateTakenMs: 0,
          dateAddedSec: 4000,
          dateModifiedSec: 1,
        ),
        fakeVideo(
          id: 4,
          dateTakenMs: null,
          dateAddedSec: null,
          dateModifiedSec: 7000,
        ),
        fakeVideo(
          id: 5,
          dateTakenMs: null,
          dateAddedSec: 0,
          dateModifiedSec: 3000,
        ),
        fakeVideo(id: 6, dateTakenMs: 8000000, dateAddedSec: 1),
        fakeVideo(
          id: 7,
          dateTakenMs: null,
          dateAddedSec: null,
          dateModifiedSec: null,
        ),
        fakeVideo(id: 8, dateTakenMs: 3000000),
        fakeVideo(id: 9, dateTakenMs: 3000000),
      ];
      expect(ids(await fake.videosInFolder('v', 'DCIM/Camera/', 100, 0)), [
        6,
        4,
        2,
        1,
        3,
        9,
        8,
        5,
        7,
      ]);
    });

    test('pages never repeat or skip a video', () async {
      fake.videosByVolume['v'] = [
        for (var i = 1; i <= 11; i++)
          fakeVideo(id: i, dateTakenMs: i <= 5 ? 2000 : 1000 * i),
      ];
      final all = ids(await fake.videosInFolder('v', 'DCIM/Camera/', 100, 0));
      expect(all, hasLength(11));
      for (final size in [1, 2, 3, 4, 5, 10, 11, 12]) {
        final paged = <int>[];
        for (var offset = 0; ; offset += size) {
          final page = ids(
            await fake.videosInFolder('v', 'DCIM/Camera/', size, offset),
          );
          if (page.isEmpty) break;
          expect(page.length, lessThanOrEqualTo(size));
          paged.addAll(page);
        }
        expect(paged, all, reason: 'page size $size');
      }
    });

    test('a limit of 0 or less, an offset past the end, a negative offset and '
        'a volume that is gone', () async {
      fake.videosByVolume['v'] = [fakeVideo(id: 1), fakeVideo(id: 2)];
      expect(await fake.videosInFolder('v', 'DCIM/Camera/', 0, 0), isEmpty);
      expect(await fake.videosInFolder('v', 'DCIM/Camera/', -1, 0), isEmpty);
      expect(await fake.videosInFolder('v', 'DCIM/Camera/', 10, 5), isEmpty);
      expect(
        ids(await fake.videosInFolder('v', 'DCIM/Camera/', 10, -3)),
        hasLength(2),
      );
      expect(await fake.videosInFolder('gone', 'DCIM/Camera/', 10, 0), isEmpty);
    });
  });

  group('the photo picker and saved addresses', () {
    PickedVideo picked(int n, {bool persisted = true}) => PickedVideo(
      uri: 'content://picker/$n',
      sizeBytes: n,
      displayName: 'p$n.mp4',
      persisted: persisted,
    );

    test('pickVideos answers the settable list (empty is a cancel), and the '
        'list it gives is a copy', () async {
      expect(await fake.pickVideos(), isEmpty);
      fake.picked = [picked(1), picked(2, persisted: false)];
      final answer = await fake.pickVideos();
      expect(answer, fake.picked);
      answer.clear();
      expect(fake.picked, hasLength(2));
      expect(fake.calls, ['pickVideos', 'pickVideos']);
    });

    test('pickVideos persists the grants it reports as persisted', () async {
      fake.picked = [picked(1), picked(2, persisted: false)];
      await fake.pickVideos();
      expect(await fake.persistedUris(), ['content://picker/1']);
    });

    test('a busy picker throws the busy PlatformException and still logs the '
        'call', () async {
      fake
        ..picked = [picked(1)]
        ..pickerBusy = true;
      await expectLater(
        fake.pickVideos(),
        throwsA(isA<PlatformException>().having((e) => e.code, 'code', 'busy')),
      );
      expect(fake.calls, ['pickVideos']);
      expect(await fake.persistedUris(), isEmpty);
      fake.pickerBusy = false;
      expect(await fake.pickVideos(), hasLength(1));
    });

    test('readableUris is the subset of the settable set, in order', () async {
      fake.readable = {'a', 'c'};
      expect(await fake.readableUris(['c', 'b', 'a']), ['c', 'a']);
      expect(await fake.readableUris([]), isEmpty);
      fake.failNext('readableUris');
      await expectLater(
        fake.readableUris(['a']),
        throwsA(isA<PlatformException>()),
      );
    });

    test('releaseUris drops only the given grants and logs them', () async {
      fake.persisted = {'a', 'b', 'c'};
      await fake.releaseUris(['b', 'zzz']);
      expect(await fake.persistedUris(), unorderedEquals(['a', 'c']));
      expect(fake.released, [
        ['b', 'zzz'],
      ]);
    });

    test('thumbnailOfUri answers from the settable map', () async {
      fake.uriThumbnails['content://x/1'] = Uint8List.fromList([1, 2]);
      expect(await fake.thumbnailOfUri('content://x/1', 10, 10), [1, 2]);
      expect(await fake.thumbnailOfUri('content://x/2', 10, 10), isNull);
    });
  });
}
