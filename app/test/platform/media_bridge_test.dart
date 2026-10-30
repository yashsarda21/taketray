import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/domain/models/zone_entry.dart';
import 'package:taketray/platform/media_api.g.dart';
import 'package:taketray/platform/media_bridge.dart';

/// A [MediaHostApi] whose answers a test sets, and which remembers the
/// arguments it was called with.
class _StubApi extends MediaHostApi {
  AccessReportMsg access = AccessReportMsg(
    level: MediaAccessLevelMsg.full,
    canAskAgain: true,
    sdkInt: 34,
  );
  List<VolumeMsg> volumeList = [];
  List<VideoRowMsg> rows = [];
  List<VideoFolderMsg> folderList = [];
  Uint8List? thumbnailBytes;
  String zoneId = 'UTC';
  List<int?> zoneOffsets = [];
  List<ZoneChangeMsg> zoneChanges = [];
  bool cameraResult = true;
  Exception? error;

  final List<String> calls = [];
  List<Object?> args = [];

  void _record(String name, [List<Object?> arguments = const []]) {
    calls.add(name);
    args = arguments;
    final e = error;
    if (e != null) throw e;
  }

  @override
  Future<AccessReportMsg> accessReport() async {
    _record('accessReport');
    return access;
  }

  @override
  Future<AccessReportMsg> requestAccess() async {
    _record('requestAccess');
    return access;
  }

  @override
  Future<void> openAppSettings() async => _record('openAppSettings');

  @override
  Future<List<VolumeMsg>> volumes() async {
    _record('volumes');
    return volumeList;
  }

  @override
  Future<List<VideoRowMsg>> videosAddedAfter(
    String volumeName,
    int afterGeneration,
    List<String> folders,
    int limit,
  ) async {
    _record('videosAddedAfter', [volumeName, afterGeneration, folders, limit]);
    return rows;
  }

  @override
  Future<List<VideoRowMsg>> videosByIds(
    String volumeName,
    List<int> ids,
  ) async {
    _record('videosByIds', [volumeName, ids]);
    return rows;
  }

  @override
  Future<List<VideoRowMsg>> allVideos(String volumeName) async {
    _record('allVideos', [volumeName]);
    return rows;
  }

  @override
  Future<List<VideoRowMsg>> videosShotSince(
    String volumeName,
    List<String> folders,
    int sinceMs,
  ) async {
    _record('videosShotSince', [volumeName, folders, sinceMs]);
    return rows;
  }

  @override
  Future<List<VideoFolderMsg>> videoFolders() async {
    _record('videoFolders');
    return folderList;
  }

  @override
  Future<Uint8List?> thumbnail(
    String volumeName,
    int mediaStoreId,
    int widthPx,
    int heightPx,
  ) async {
    _record('thumbnail', [volumeName, mediaStoreId, widthPx, heightPx]);
    return thumbnailBytes;
  }

  @override
  Future<String> currentZoneId() async {
    _record('currentZoneId');
    return zoneId;
  }

  @override
  Future<List<int?>> zoneOffsetsMs(
    List<String> zoneIds,
    List<int> instantsMs,
  ) async {
    _record('zoneOffsetsMs', [zoneIds, instantsMs]);
    return zoneOffsets;
  }

  @override
  Future<List<ZoneChangeMsg>> pendingZoneChanges() async {
    _record('pendingZoneChanges');
    return zoneChanges;
  }

  @override
  Future<void> clearZoneChangesUpTo(int atMs) async =>
      _record('clearZoneChangesUpTo', [atMs]);

  @override
  Future<bool> openVideoCamera() async {
    _record('openVideoCamera');
    return cameraResult;
  }
}

VideoRowMsg _fullRow() => VideoRowMsg(
  volumeName: 'external_primary',
  mediaStoreId: 4821,
  generationAdded: 90210,
  sizeBytes: 123456789,
  durationMs: 9500,
  dateTakenMs: 1760000000123,
  dateAddedSec: 1760000001,
  dateModifiedSec: 1760000002,
  displayName: 'VID_20261028_101500.mp4',
  relativePath: 'DCIM/Camera/',
  width: 1920,
  height: 1080,
  mimeType: 'video/mp4',
  isPending: true,
);

/// Every nullable field left out, which means null.
VideoRowMsg _nullRow() => VideoRowMsg(
  volumeName: '0000-0000',
  mediaStoreId: 1,
  generationAdded: 0,
  sizeBytes: 0,
  displayName: '',
  relativePath: '',
  isPending: false,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _StubApi api;
  late PigeonMediaBridge bridge;

  setUp(() {
    api = _StubApi();
    bridge = PigeonMediaBridge(api);
  });

  test('every message field maps to the domain model and back', () async {
    // AccessReportMsg, for every level.
    for (final (msg, domain) in [
      (MediaAccessLevelMsg.full, MediaAccessLevel.full),
      (MediaAccessLevelMsg.limited, MediaAccessLevel.limited),
      (MediaAccessLevelMsg.denied, MediaAccessLevel.denied),
    ]) {
      api.access = AccessReportMsg(
        level: msg,
        canAskAgain: msg == MediaAccessLevelMsg.limited,
        sdkInt: 30 + msg.index,
      );
      for (final report in [
        await bridge.accessReport(),
        await bridge.requestAccess(),
      ]) {
        expect(report.level, domain);
        expect(report.canAskAgain, msg == MediaAccessLevelMsg.limited);
        expect(report.sdkInt, 30 + msg.index);
      }
    }

    // VolumeMsg, mounted and not mounted.
    api.volumeList = [
      VolumeMsg(volumeName: 'external_primary', version: 'v-9', generation: 77),
      VolumeMsg(volumeName: '0000-0000', generation: 0),
    ];
    final volumes = await bridge.volumes();
    expect(volumes, const [
      MediaVolume(name: 'external_primary', version: 'v-9', generation: 77),
      MediaVolume(name: '0000-0000', generation: 0),
    ]);
    expect(volumes.map((v) => v.isMounted), [true, false]);

    // VideoRowMsg, with every field set and with every nullable one null.
    api.rows = [_fullRow(), _nullRow()];
    final videos = await bridge.videosAddedAfter('external_primary', 5, [
      'DCIM/Camera/',
    ], 100);
    expect(videos, hasLength(2));
    final full = videos[0];
    expect(full.volumeName, 'external_primary');
    expect(full.mediaStoreId, 4821);
    expect(full.generationAdded, 90210);
    expect(full.sizeBytes, 123456789);
    expect(full.durationMs, 9500);
    expect(full.dateTakenMs, 1760000000123);
    expect(full.dateAddedSec, 1760000001);
    expect(full.dateModifiedSec, 1760000002);
    expect(full.displayName, 'VID_20261028_101500.mp4');
    expect(full.relativePath, 'DCIM/Camera/');
    expect(full.width, 1920);
    expect(full.height, 1080);
    expect(full.mimeType, 'video/mp4');
    expect(full.isPending, isTrue);
    final empty = videos[1];
    expect(empty.volumeName, '0000-0000');
    expect(empty.mediaStoreId, 1);
    expect(empty.generationAdded, 0);
    expect(empty.sizeBytes, 0);
    expect(empty.durationMs, isNull);
    expect(empty.dateTakenMs, isNull);
    expect(empty.dateAddedSec, isNull);
    expect(empty.dateModifiedSec, isNull);
    expect(empty.displayName, '');
    expect(empty.relativePath, '');
    expect(empty.width, isNull);
    expect(empty.height, isNull);
    expect(empty.mimeType, 'video/*');
    expect(empty.isPending, isFalse);

    // The same mapping for the other three calls that return videos.
    expect(await bridge.videosByIds('v', [1]), videos);
    expect(await bridge.allVideos('v'), videos);
    expect(await bridge.videosShotSince('v', ['a/'], 1), videos);

    // VideoFolderMsg.
    api.folderList = [
      VideoFolderMsg(
        volumeName: 'external_primary',
        relativePath: 'DCIM/Camera/',
        videoCount: 12,
      ),
    ];
    expect(await bridge.videoFolders(), const [
      VideoFolder(
        volumeName: 'external_primary',
        relativePath: 'DCIM/Camera/',
        videoCount: 12,
      ),
    ]);

    // ZoneChangeMsg.
    api.zoneChanges = [
      ZoneChangeMsg(atMs: 1760000000123, zoneId: 'Asia/Kolkata'),
    ];
    expect(await bridge.pendingZoneChanges(), [
      ZoneEntry(
        at: DateTime.utc(2025, 10, 9, 8, 53, 20, 123),
        zoneId: 'Asia/Kolkata',
      ),
    ]);

    // And back: every argument reaches the host API as given.
    await bridge.videosAddedAfter('vol', 12, ['a/', 'b/'], 34);
    expect(api.args, [
      'vol',
      12,
      ['a/', 'b/'],
      34,
    ]);
    await bridge.videosByIds('vol', [3, 1, 2]);
    expect(api.args, [
      'vol',
      [3, 1, 2],
    ]);
    await bridge.allVideos('vol');
    expect(api.args, ['vol']);
    await bridge.videosShotSince('vol', ['x/'], 99);
    expect(api.args, [
      'vol',
      ['x/'],
      99,
    ]);
    await bridge.thumbnail('vol', 5, 320, 240);
    expect(api.args, ['vol', 5, 320, 240]);
    await bridge.clearZoneChangesUpTo(1760000000123);
    expect(api.args, [1760000000123]);
    api.zoneOffsets = [3600000, null];
    expect(
      await bridge.zoneOffsetsMs(
        ['Europe/London', 'Not/AZone'],
        [1782907200000, 0],
      ),
      [3600000, null],
    );
    expect(api.args, [
      ['Europe/London', 'Not/AZone'],
      [1782907200000, 0],
    ]);

    // Calls with no arguments and plain results.
    api.zoneId = 'Europe/London';
    expect(await bridge.currentZoneId(), 'Europe/London');
    api.cameraResult = false;
    expect(await bridge.openVideoCamera(), isFalse);
    api.cameraResult = true;
    expect(await bridge.openVideoCamera(), isTrue);
    await bridge.openAppSettings();
    expect(api.calls.last, 'openAppSettings');
    api.thumbnailBytes = Uint8List.fromList([0xff, 0xd8, 0xff]);
    expect(await bridge.thumbnail('v', 1, 1, 1), [0xff, 0xd8, 0xff]);
    api.thumbnailBytes = null;
    expect(await bridge.thumbnail('v', 1, 1, 1), isNull);
  });

  test('null mimeType becomes video/*', () async {
    api.rows = [_nullRow()];
    final videos = await bridge.allVideos('v');
    expect(videos.single.mimeType, 'video/*');
    // A mime type that is set is not replaced.
    api.rows = [_fullRow()];
    expect((await bridge.allVideos('v')).single.mimeType, 'video/mp4');
  });

  test('zone changes map to ZoneEntry with UTC instants', () async {
    api.zoneChanges = [
      ZoneChangeMsg(atMs: 0, zoneId: 'UTC'),
      ZoneChangeMsg(atMs: 1760000000123, zoneId: 'Europe/London'),
    ];
    final entries = await bridge.pendingZoneChanges();
    expect(entries, [
      ZoneEntry(
        at: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        zoneId: 'UTC',
      ),
      ZoneEntry(
        at: DateTime.fromMillisecondsSinceEpoch(1760000000123, isUtc: true),
        zoneId: 'Europe/London',
      ),
    ]);
    expect(entries.every((e) => e.at.isUtc), isTrue);
    expect(entries.first.at.millisecondsSinceEpoch, 0);
  });

  test('a PlatformException from the host API passes through unchanged', () {
    final error = PlatformException(code: 'denied', message: 'no access');
    api.error = error;
    expect(bridge.accessReport(), throwsA(same(error)));
    expect(bridge.videosByIds('v', [1]), throwsA(same(error)));
    expect(bridge.thumbnail('v', 1, 1, 1), throwsA(same(error)));
  });

  test('mediaBridgeProvider builds the Pigeon bridge, once', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final bridge = container.read(mediaBridgeProvider);
    expect(bridge, isA<PigeonMediaBridge>());
    expect(container.read(mediaBridgeProvider), same(bridge));
  });

  group('through the generated channels', () {
    const prefix = 'dev.flutter.pigeon.taketray.MediaHostApi';
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const codec = MediaHostApi.pigeonChannelCodec;

    tearDown(() {
      for (final name in ['videosByIds', 'accessReport', 'zoneOffsetsMs']) {
        messenger.setMockMessageHandler('$prefix.$name', null);
      }
    });

    test('a video row with nulls survives the wire and is mapped', () async {
      List<Object?>? received;
      messenger.setMockMessageHandler('$prefix.videosByIds', (message) async {
        received = codec.decodeMessage(message)! as List<Object?>;
        return codec.encodeMessage(<Object?>[
          [_fullRow(), _nullRow()],
        ]);
      });

      final videos = await PigeonMediaBridge().videosByIds('vol', [7, 8]);

      expect(received, [
        'vol',
        [7, 8],
      ]);
      expect(videos.map((v) => v.mediaStoreId), [4821, 1]);
      expect(videos[0].durationMs, 9500);
      expect(videos[1].durationMs, isNull);
      expect(videos[1].mimeType, 'video/*');
    });

    test('zone offsets with an unknown zone survive the wire', () async {
      List<Object?>? received;
      messenger.setMockMessageHandler('$prefix.zoneOffsetsMs', (message) async {
        received = codec.decodeMessage(message)! as List<Object?>;
        return codec.encodeMessage(<Object?>[
          <Object?>[19800000, null],
        ]);
      });

      final offsets = await PigeonMediaBridge().zoneOffsetsMs(
        ['Asia/Kolkata', 'Not/AZone'],
        [1782907200000, 1782907200000],
      );

      expect(received, [
        ['Asia/Kolkata', 'Not/AZone'],
        [1782907200000, 1782907200000],
      ]);
      expect(offsets, [19800000, null]);
    });

    test('a channel nobody answers is a channel-error PlatformException', () {
      // No handler is registered for videoFolders: the case until Task 4
      // registers the Kotlin implementation.
      expect(
        PigeonMediaBridge().videoFolders(),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'channel-error',
          ),
        ),
      );
    });

    test('an error reply becomes a PlatformException, unchanged', () async {
      messenger.setMockMessageHandler('$prefix.accessReport', (message) async {
        return codec.encodeMessage(<Object?>['denied', 'no access', 'details']);
      });

      await expectLater(
        PigeonMediaBridge().accessReport(),
        throwsA(
          isA<PlatformException>()
              .having((e) => e.code, 'code', 'denied')
              .having((e) => e.message, 'message', 'no access')
              .having((e) => e.details, 'details', 'details'),
        ),
      );
    });
  });
}
