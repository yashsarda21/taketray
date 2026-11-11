import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:taketray/data/media/thumbnail_cache.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/models/clip_fingerprint.dart';
import 'package:taketray/domain/models/enums.dart';

import '../../support/fake_media_bridge.dart';
import '../../support/fixed_clock.dart';

/// A [FakeMediaBridge] that records the size of every thumbnail request.
class SizeRecordingBridge extends FakeMediaBridge {
  final List<(String, int, int, int)> requests = [];

  @override
  Future<Uint8List?> thumbnail(
    String volumeName,
    int mediaStoreId,
    int widthPx,
    int heightPx,
  ) {
    requests.add((volumeName, mediaStoreId, widthPx, heightPx));
    return super.thumbnail(volumeName, mediaStoreId, widthPx, heightPx);
  }

  /// Every `thumbnailOfUri` request: the address and both sides.
  final List<(String, int, int)> uriRequests = [];

  @override
  Future<Uint8List?> thumbnailOfUri(String uri, int widthPx, int heightPx) {
    uriRequests.add((uri, widthPx, heightPx));
    return super.thumbnailOfUri(uri, widthPx, heightPx);
  }
}

/// A bridge whose thumbnail call throws something that is not a
/// `PlatformException`.
class ThrowingBridge extends FakeMediaBridge {
  @override
  Future<Uint8List?> thumbnail(
    String volumeName,
    int mediaStoreId,
    int widthPx,
    int heightPx,
  ) async {
    calls.add('thumbnail');
    throw MissingPluginException('no plugin at /storage/emulated/0/secret.mp4');
  }
}

Clip clipOf({
  int id = 1,
  int mediaStoreId = 42,
  String volume = 'external_primary',
  int sizeBytes = 1000000,
  DateTime? dateTaken,
}) => Clip(
  id: id,
  source: ClipSource.mediaStore,
  mediaStoreId: mediaStoreId,
  volumeName: volume,
  fingerprint: ClipFingerprint(
    sizeBytes: sizeBytes,
    durationMs: 5000,
    dateTakenUtc: dateTaken ?? DateTime.utc(2026, 5, 1, 12),
    displayName: 'VID_$id.mp4',
  ),
  width: 1920,
  height: 1080,
  mimeType: 'video/mp4',
  firstSeenAt: DateTime.utc(2026, 5, 2),
  missing: false,
);

/// A picked clip (D-111): a picker address and no MediaStore identity.
Clip pickedOf({
  int id = 7,
  String uri = pickedUri,
  int sizeBytes = 2000000,
  DateTime? dateTaken,
}) => Clip(
  id: id,
  source: ClipSource.picker,
  pickerUri: uri,
  fingerprint: ClipFingerprint(
    sizeBytes: sizeBytes,
    durationMs: 8000,
    dateTakenUtc: dateTaken ?? DateTime.utc(2026, 5, 3, 8),
    displayName: 'picked_$id.mp4',
  ),
  width: 1080,
  height: 1920,
  mimeType: 'video/mp4',
  firstSeenAt: DateTime.utc(2026, 5, 4),
  missing: false,
);

/// A photo-picker address as Android gives one.
const String pickedUri =
    'content://media/picker/0/com.android.providers.media.photopicker/'
    'media/1000017';

/// What a picked thumbnail's file name looks like: `picked-`, 16 hex digits
/// of the address's hash, then the fingerprint and the size.
final RegExp pickedName = RegExp(r'^picked-[0-9a-f]{16}_\d+_-?\d+_\d+\.jpg$');

/// No part of [uri] that could name a video, a folder or an app.
void expectNoAddressIn(String text, [String uri = pickedUri]) {
  expect(text, isNot(contains(uri)));
  expect(text, isNot(contains('content')));
  expect(text, isNot(contains('/')));
  expect(text, isNot(contains('://')));
  expect(text, isNot(contains('photopicker')));
  expect(text, isNot(contains('1000017')));
}

/// The file name of `clipOf()` at 300 px.
final String baseFile =
    'external_primary_42_1000000_'
    '${DateTime.utc(2026, 5, 1, 12).millisecondsSinceEpoch}_300.jpg';

/// [length] bytes that start like a JPEG (FF D8), then [fill].
Uint8List bytesOf(int length, [int fill = 7]) => Uint8List.fromList([
  for (var i = 0; i < length; i++)
    if (i == 0) 0xFF else if (i == 1) 0xD8 else fill,
]);

void main() {
  late Directory root;
  late Directory dir;
  late SizeRecordingBridge bridge;
  late FixedClock clock;

  setUp(() {
    root = Directory.systemTemp.createTempSync('thumbs_test');
    dir = Directory('${root.path}/thumbs');
    bridge = SizeRecordingBridge();
    clock = FixedClock(DateTime.utc(2026, 6));
  });

  tearDown(() => root.deleteSync(recursive: true));

  ThumbnailCache cacheWith({
    FakeMediaBridge? using,
    int maxBytes = 64 * 1024 * 1024,
    Future<void> Function(File temp, String finalPath)? renameFile,
    Stream<FileSystemEntity> Function(Directory dir)? listDir,
    Duration bridgeTimeout = const Duration(seconds: 15),
  }) => ThumbnailCache(
    using ?? bridge,
    dir,
    maxBytes: maxBytes,
    clock: clock,
    renameFile: renameFile,
    listDir: listDir,
    bridgeTimeout: bridgeTimeout,
  );

  List<String> names() {
    if (!dir.existsSync()) return [];
    return [
      for (final e in dir.listSync()) e.path.substring(dir.path.length + 1),
    ]..sort();
  }

  File jpg(String name, int length, DateTime modified) {
    dir.createSync(recursive: true);
    final file = File('${dir.path}/$name')
      ..writeAsBytesSync(bytesOf(length, 1))
      ..setLastModifiedSync(modified);
    return file;
  }

  group('load', () {
    test(
      'a miss asks the bridge, writes the file and returns the bytes',
      () async {
        bridge.thumbnails[('external_primary', 42)] = bytesOf(10);
        final cache = cacheWith();

        final got = await cache.load(clipOf(), 300);

        expect(got, bytesOf(10));
        expect(bridge.requests, [('external_primary', 42, 300, 300)]);
        expect(names(), [baseFile]);
      },
    );

    test('disk hit avoids the bridge', () async {
      bridge.thumbnails[('external_primary', 42)] = bytesOf(10);
      final cache = cacheWith();
      await cache.load(clipOf(), 300);
      bridge.calls.clear();
      bridge.thumbnails.clear();

      final got = await cache.load(clipOf(), 300);

      expect(got, bytesOf(10));
      expect(bridge.calls, isEmpty);
    });

    test('a disk hit touches the mtime to now', () async {
      bridge.thumbnails[('external_primary', 42)] = bytesOf(10);
      final cache = cacheWith();
      await cache.load(clipOf(), 300);
      final file = dir.listSync().whereType<File>().single
        ..setLastModifiedSync(DateTime.utc(2020));
      clock.advance(const Duration(days: 3));

      await cache.load(clipOf(), 300);

      expect(
        file.lastModifiedSync().toUtc().difference(clock.now()).abs(),
        lessThan(const Duration(seconds: 2)),
      );
    });

    test('cache key changes when the fingerprint changes', () async {
      bridge.thumbnails[('external_primary', 42)] = bytesOf(10);
      bridge.thumbnails[('external_primary', 43)] = bytesOf(11);
      bridge.thumbnails[('1234-5678', 42)] = bytesOf(12);
      final cache = cacheWith();
      final variants = <(String, Clip, int)>[
        ('base', clipOf(), 300),
        ('size bytes', clipOf(sizeBytes: 1000001), 300),
        (
          'date taken',
          clipOf(dateTaken: DateTime.utc(2026, 5, 1, 12, 0, 1)),
          300,
        ),
        ('media store id', clipOf(mediaStoreId: 43), 300),
        ('volume', clipOf(volume: '1234-5678'), 300),
        ('size px', clipOf(), 301),
      ];

      for (final (_, clip, size) in variants) {
        await cache.load(clip, size);
      }

      expect(
        bridge.calls.where((c) => c == 'thumbnail'),
        hasLength(variants.length),
        reason: "no variant may reuse another variant's picture",
      );
      expect(names(), hasLength(variants.length));
    });

    test(
      'the same fingerprint under another clip id shares the picture',
      () async {
        bridge.thumbnails[('external_primary', 42)] = bytesOf(10);
        final cache = cacheWith();
        await cache.load(clipOf(), 300);
        bridge.calls.clear();

        await cache.load(clipOf(id: 99), 300);

        expect(bridge.calls, isEmpty);
      },
    );

    test('null thumbnail is not cached', () async {
      final cache = cacheWith();

      expect(await cache.load(clipOf(), 300), isNull);
      expect(names(), isEmpty);

      bridge.thumbnails[('external_primary', 42)] = bytesOf(10);
      expect(await cache.load(clipOf(), 300), bytesOf(10));
      expect(
        bridge.calls.where((c) => c == 'thumbnail'),
        hasLength(2),
        reason: 'the miss is asked again, not remembered',
      );
    });

    test('an empty answer from the bridge is not cached', () async {
      bridge.thumbnails[('external_primary', 42)] = Uint8List(0);
      final cache = cacheWith();

      expect(await cache.load(clipOf(), 300), isNull);
      expect(names(), isEmpty);
    });

    test(
      'PlatformException → null, nothing cached, log has volume and code only',
      () async {
        bridge.failNext('thumbnail');
        final records = <LogRecord>[];
        final sub = Logger.root.onRecord.listen(records.add);
        addTearDown(sub.cancel);
        final previous = Logger.root.level;
        Logger.root.level = Level.ALL;
        addTearDown(() => Logger.root.level = previous);
        final cache = cacheWith();

        expect(await cache.load(clipOf(volume: '1234-5678'), 300), isNull);

        expect(names(), isEmpty);
        final text = records
            .map((r) => '${r.message} ${r.error ?? ''}')
            .join('\n');
        expect(text, contains('1234-5678'));
        expect(text, contains('fake-failure'));
        expect(text, isNot(contains('on purpose')), reason: 'no error message');
        expect(text, isNot(contains('/')), reason: 'no path');
      },
    );

    test(
      'an unmounted volume (native-error) gives null and caches nothing',
      () async {
        final unmounted = _CodeBridge('native-error');
        final cache = cacheWith(using: unmounted);

        expect(await cache.load(clipOf(volume: '1234-5678'), 300), isNull);

        expect(names(), isEmpty);
        expect(unmounted.calls, ['thumbnail']);
      },
    );

    test(
      'another kind of failure gives null and the log has no message',
      () async {
        final records = <LogRecord>[];
        final sub = Logger.root.onRecord.listen(records.add);
        addTearDown(sub.cancel);
        final previous = Logger.root.level;
        Logger.root.level = Level.ALL;
        addTearDown(() => Logger.root.level = previous);
        final cache = cacheWith(using: ThrowingBridge());

        expect(await cache.load(clipOf(), 300), isNull);

        final text = records
            .map((r) => '${r.message} ${r.error ?? ''}')
            .join('\n');
        expect(text, isNot(contains('secret')));
        expect(text, isNot(contains('/storage')));
      },
    );

    test('detached clips and clips with no volume give null without asking the '
        'bridge', () async {
      // Amended in Phase 7 (D-74): a picked clip now has a picture (group
      // 'picked clips'); it used to be in this list.
      final cache = cacheWith();
      final detached = clipOf(mediaStoreId: -5);
      final zero = clipOf(mediaStoreId: 0);
      final noVolume = clipOf().copyWith(volumeName: null);
      final blankVolume = clipOf(volume: '');

      for (final clip in [detached, zero, noVolume, blankVolume]) {
        expect(await cache.load(clip, 300), isNull);
      }

      expect(bridge.calls, isEmpty);
      expect(names(), isEmpty);
    });

    test('sizePx is clamped to 4096 before the call and the key', () async {
      bridge.thumbnails[('external_primary', 42)] = bytesOf(10);
      final cache = cacheWith();

      await cache.load(clipOf(), 5000);

      expect(bridge.requests, [('external_primary', 42, 4096, 4096)]);
      expect(names().single, endsWith('_4096.jpg'));
      bridge.calls.clear();
      await cache.load(clipOf(), 4096);
      expect(bridge.calls, isEmpty, reason: '5000 and 4096 are one picture');
    });

    test(
      'sizePx of 1 is asked as 1; 0 or less gives null without a call',
      () async {
        bridge.thumbnails[('external_primary', 42)] = bytesOf(10);
        final cache = cacheWith();

        expect(await cache.load(clipOf(), 0), isNull);
        expect(await cache.load(clipOf(), -1), isNull);
        expect(bridge.calls, isEmpty);

        await cache.load(clipOf(), 1);
        expect(bridge.requests, [('external_primary', 42, 1, 1)]);
      },
    );

    test('a volume name cannot escape the folder', () async {
      bridge.thumbnails[('../x', 42)] = bytesOf(10);
      final cache = cacheWith();

      await cache.load(clipOf(volume: '../x'), 300);

      expect(names(), hasLength(1));
      expect(names().single, startsWith('___x_42_'));
      expect(
        root.listSync().map(
          (e) => e.uri.pathSegments.where((s) => s.isNotEmpty).last,
        ),
        ['thumbs'],
        reason: 'nothing was written beside the cache folder',
      );
      expect(
        bridge.requests.single.$1,
        '../x',
        reason: 'the bridge gets the real name',
      );
    });

    test('a 0-byte file on disk is a miss: deleted and reloaded', () async {
      bridge.thumbnails[('external_primary', 42)] = bytesOf(10);
      final cache = cacheWith();
      await cache.load(clipOf(), 300);
      final file = dir.listSync().whereType<File>().single
        ..writeAsBytesSync(const []);
      bridge.calls.clear();

      final got = await cache.load(clipOf(), 300);

      expect(got, bytesOf(10));
      expect(bridge.calls, ['thumbnail']);
      expect(file.readAsBytesSync(), bytesOf(10), reason: 'rewritten whole');
    });

    test('a 0-byte file stays gone when the bridge has nothing', () async {
      final cache = cacheWith();
      dir.createSync(recursive: true);
      final name = baseFile;
      final file = File('${dir.path}/$name')..writeAsBytesSync(const []);

      expect(await cache.load(clipOf(), 300), isNull);
      expect(file.existsSync(), isFalse);
    });

    test(
      'the cache folder gone while running: the next load creates it again',
      () async {
        bridge.thumbnails[('external_primary', 42)] = bytesOf(10);
        final cache = cacheWith();
        await cache.load(clipOf(), 300);
        dir.deleteSync(recursive: true);
        bridge.calls.clear();

        final got = await cache.load(clipOf(), 300);

        expect(got, bytesOf(10));
        expect(bridge.calls, ['thumbnail']);
        expect(names(), hasLength(1));
      },
    );

    test('the cache folder never existed: first load creates it', () async {
      bridge.thumbnails[('external_primary', 42)] = bytesOf(10);
      expect(dir.existsSync(), isFalse);

      await cacheWith().load(clipOf(), 300);

      expect(names(), hasLength(1));
    });
  });

  group('undecodable and foreign files', () {
    test(
      'a file that does not start with FF D8 is a miss: deleted, reloaded',
      () async {
        bridge.thumbnails[('external_primary', 42)] = bytesOf(10);
        dir.createSync(recursive: true);
        final file = File('${dir.path}/$baseFile')
          ..writeAsBytesSync([0x89, 0x50, 0x4E, 0x47, 1, 2, 3]);

        final got = await cacheWith().load(clipOf(), 300);

        expect(got, bytesOf(10));
        expect(bridge.calls, ['thumbnail']);
        expect(file.readAsBytesSync(), bytesOf(10), reason: 'rewritten whole');
      },
    );

    test(
      'a 1-byte file is a miss, and stays gone when the bridge has nothing',
      () async {
        dir.createSync(recursive: true);
        final file = File('${dir.path}/$baseFile')..writeAsBytesSync([0xFF]);

        expect(await cacheWith().load(clipOf(), 300), isNull);
        expect(file.existsSync(), isFalse);
      },
    );

    test('a file that starts with FF D8 is a hit', () async {
      dir.createSync(recursive: true);
      File('${dir.path}/$baseFile').writeAsBytesSync([0xFF, 0xD8]);

      expect(await cacheWith().load(clipOf(), 300), [0xFF, 0xD8]);
      expect(bridge.calls, isEmpty);
    });

    test('discard deletes the file of that key only', () async {
      bridge.thumbnails[('external_primary', 42)] = bytesOf(10);
      final cache = cacheWith();
      await cache.load(clipOf(), 300);
      await cache.load(clipOf(), 200);
      expect(names(), hasLength(2));

      await cache.discard(clipOf(), 300);

      expect(names(), [endsWith('_200.jpg')]);
      bridge.calls.clear();
      await cache.load(clipOf(), 300);
      expect(bridge.calls, ['thumbnail'], reason: 'asked again after discard');
    });

    test('discard is a no-op: no file, no folder, no key', () async {
      final cache = cacheWith();

      await cache.discard(clipOf(), 300);
      await cache.discard(clipOf(mediaStoreId: -1), 300);
      await cache.discard(clipOf(), 0);
      jpg('keep.jpg', 5, DateTime.utc(2026));
      await cache.discard(clipOf(), 300);

      expect(names(), ['keep.jpg']);
    });

    test(
      'discard leaves the file of a load that is running right now',
      () async {
        bridge.thumbnails[('external_primary', 42)] = bytesOf(10);
        final renamed = Completer<void>();
        final finish = Completer<void>();
        final cache = cacheWith(
          renameFile: (temp, finalPath) async {
            await temp.rename(finalPath);
            renamed.complete();
            await finish.future; // written, but the load is still running
          },
        );
        final loading = cache.load(clipOf(), 300);
        await renamed.future;
        expect(names(), [baseFile]);

        await cache.discard(clipOf(), 300);
        finish.complete();
        await loading;

        expect(names(), [baseFile], reason: 'the fresh file was kept');
      },
    );
  });

  group('picked clips (D-74 amended in Phase 7)', () {
    List<LogRecord> captureLogs() {
      final records = <LogRecord>[];
      final sub = Logger.root.onRecord.listen(records.add);
      addTearDown(sub.cancel);
      final previous = Logger.root.level;
      Logger.root.level = Level.ALL;
      addTearDown(() => Logger.root.level = previous);
      return records;
    }

    String textOf(List<LogRecord> records) =>
        records.map((r) => '${r.message} ${r.error ?? ''}').join('\n');

    test('a picked clip gets a key: a hash of the address, the fingerprint '
        'and the size, never the address', () {
      final key = ClipThumbnailKey.of(pickedOf(), 300)!;

      expect(key.fileName, matches(pickedName));
      expect(
        key.fileName,
        endsWith(
          '_2000000_${DateTime.utc(2026, 5, 3, 8).millisecondsSinceEpoch}'
          '_300.jpg',
        ),
      );
      expectNoAddressIn(key.fileName);
      expectNoAddressIn(key.toString());
      expect(key.sizePx, 300);
    });

    test('the hash is FNV-1a 64 of the address, so a name survives a '
        'restart', () {
      // The published FNV-1a 64-bit test vector for "foobar".
      final key = ClipThumbnailKey.of(pickedOf(uri: 'foobar'), 1)!;

      expect(key.fileName, startsWith('picked-85944171f73967e8_'));
      expect(
        ClipThumbnailKey.of(pickedOf(uri: 'a'), 1)!.fileName,
        startsWith('picked-af63dc4c8601ec8c_'),
      );
    });

    test('a miss asks thumbnailOfUri with the address, writes the file and '
        'returns the bytes', () async {
      bridge.uriThumbnails[pickedUri] = bytesOf(10);
      final cache = cacheWith();

      final got = await cache.load(pickedOf(), 300);

      expect(got, bytesOf(10));
      expect(bridge.uriRequests, [(pickedUri, 300, 300)]);
      expect(bridge.requests, isEmpty, reason: 'no MediaStore call');
      expect(names(), [ClipThumbnailKey.of(pickedOf(), 300)!.fileName]);
      expect(names().single, matches(pickedName));
      expectNoAddressIn(names().single);
    });

    test('a disk hit avoids the bridge', () async {
      bridge.uriThumbnails[pickedUri] = bytesOf(10);
      final cache = cacheWith();
      await cache.load(pickedOf(), 300);
      bridge.calls.clear();
      bridge.uriThumbnails.clear();

      expect(await cache.load(pickedOf(), 300), bytesOf(10));
      expect(bridge.calls, isEmpty);
    });

    test(
      'the key changes with the address, the fingerprint and the size',
      () async {
        const other = '${pickedUri}8';
        bridge.uriThumbnails[pickedUri] = bytesOf(10);
        bridge.uriThumbnails[other] = bytesOf(11);
        final cache = cacheWith();
        final variants = <(Clip, int)>[
          (pickedOf(), 300),
          (pickedOf(uri: other), 300),
          (pickedOf(sizeBytes: 2000001), 300),
          (pickedOf(dateTaken: DateTime.utc(2026, 5, 3, 8, 0, 1)), 300),
          (pickedOf(), 301),
        ];

        for (final (clip, size) in variants) {
          await cache.load(clip, size);
        }

        expect(
          bridge.calls.where((c) => c == 'thumbnailOfUri'),
          hasLength(variants.length),
          reason: "no variant may reuse another variant's picture",
        );
        expect(names(), hasLength(variants.length));
        expect({
          for (final (c, size) in variants) ClipThumbnailKey.of(c, size),
        }, hasLength(variants.length));
      },
    );

    test('the same address and fingerprint under another clip id share the '
        'picture', () async {
      bridge.uriThumbnails[pickedUri] = bytesOf(10);
      final cache = cacheWith();
      await cache.load(pickedOf(), 300);
      bridge.calls.clear();

      await cache.load(pickedOf(id: 99), 300);

      expect(bridge.calls, isEmpty);
      expect(
        ClipThumbnailKey.of(pickedOf(), 300),
        ClipThumbnailKey.of(pickedOf(id: 99), 300),
      );
    });

    test('a picked key never equals a MediaStore key, and their files never '
        'share a name', () {
      final picked = ClipThumbnailKey.of(pickedOf(uri: 'foobar'), 300)!;
      // A volume crafted to look like the picked name's start.
      final crafted = ClipThumbnailKey.of(
        clipOf(
          volume: 'picked-85944171f73967e8',
          mediaStoreId: 2000000,
          sizeBytes: DateTime.utc(2026, 5, 3, 8).millisecondsSinceEpoch,
        ),
        300,
      )!;

      expect(picked, isNot(crafted));
      expect(picked.fileName, isNot(crafted.fileName));
    });

    test('a null from the bridge is "no picture": nothing cached, asked '
        'again next time', () async {
      final cache = cacheWith();

      expect(await cache.load(pickedOf(), 300), isNull);
      expect(names(), isEmpty);

      bridge.uriThumbnails[pickedUri] = bytesOf(10);
      expect(await cache.load(pickedOf(), 300), bytesOf(10));
      expect(bridge.calls.where((c) => c == 'thumbnailOfUri'), hasLength(2));
    });

    test('an empty answer is "no picture" too', () async {
      bridge.uriThumbnails[pickedUri] = Uint8List(0);

      expect(await cacheWith().load(pickedOf(), 300), isNull);
      expect(names(), isEmpty);
    });

    test('a PlatformException gives null; the log has the code and never the '
        'address', () async {
      final records = captureLogs();
      bridge.failNext('thumbnailOfUri');

      expect(await cacheWith().load(pickedOf(), 300), isNull);

      expect(names(), isEmpty);
      final text = textOf(records);
      expect(text, contains('fake-failure'));
      expect(text, isNot(contains('on purpose')), reason: 'no error message');
      expectNoAddressIn(text);
    });

    test('another failure gives null; the log has the type only', () async {
      final records = captureLogs();

      expect(
        await cacheWith(using: _ThrowingUriBridge()).load(pickedOf(), 300),
        isNull,
      );

      final text = textOf(records);
      expect(text, contains('MissingPluginException'));
      expectNoAddressIn(text);
    });

    test('a bridge that never answers gives null after the timeout; the log '
        'has no address', () async {
      final records = captureLogs();
      final stuck = _StuckBridge();
      final cache = cacheWith(
        using: stuck,
        bridgeTimeout: const Duration(milliseconds: 30),
      );

      expect(await cache.load(pickedOf(), 300), isNull);

      expect(names(), isEmpty);
      final text = textOf(records);
      expect(text, contains('timeout'));
      expectNoAddressIn(text);
    });

    test('a failed write is logged with the type only', () async {
      final records = captureLogs();
      bridge.uriThumbnails[pickedUri] = bytesOf(10);
      final cache = cacheWith(
        renameFile: (temp, finalPath) async =>
            throw const FileSystemException('disk full', '/data/x'),
      );

      expect(await cache.load(pickedOf(), 300), bytesOf(10));

      final text = textOf(records);
      expect(text, contains('FileSystemException'));
      expectNoAddressIn(text);
    });

    test('no address, an empty address or a size below 1 gives null without '
        'a call', () async {
      final cache = cacheWith();
      final none = pickedOf().copyWith(pickerUri: null);
      final empty = pickedOf(uri: '');

      expect(await cache.load(none, 300), isNull);
      expect(await cache.load(empty, 300), isNull);
      expect(await cache.load(pickedOf(), 0), isNull);
      expect(ClipThumbnailKey.of(none, 300), isNull);
      expect(ClipThumbnailKey.of(empty, 300), isNull);
      expect(bridge.calls, isEmpty);
    });

    test('a size above 4096 is asked and kept as 4096', () async {
      bridge.uriThumbnails[pickedUri] = bytesOf(10);

      await cacheWith().load(pickedOf(), 5000);

      expect(bridge.uriRequests, [(pickedUri, 4096, 4096)]);
      expect(names().single, endsWith('_4096.jpg'));
    });

    test('two loads of one picked key at once share one call', () async {
      bridge.uriThumbnails[pickedUri] = bytesOf(10);
      final gate = bridge.gate('thumbnailOfUri');
      final cache = cacheWith();

      final a = cache.load(pickedOf(), 300);
      final b = cache.load(pickedOf(), 300);
      await Future<void>.delayed(Duration.zero);
      gate.complete();

      expect(await a, bytesOf(10));
      expect(await b, bytesOf(10));
      expect(bridge.calls.where((c) => c == 'thumbnailOfUri'), hasLength(1));
    });

    test('discard deletes a picked file', () async {
      bridge.uriThumbnails[pickedUri] = bytesOf(10);
      final cache = cacheWith();
      await cache.load(pickedOf(), 300);

      await cache.discard(pickedOf(), 300);

      expect(names(), isEmpty);
    });

    test('prune counts and removes picked files like the others', () async {
      final cache = cacheWith(maxBytes: 15);
      bridge.uriThumbnails[pickedUri] = bytesOf(10);
      await cache.load(pickedOf(), 300);
      final picked = File('${dir.path}/${names().single}')
        ..setLastModifiedSync(DateTime.utc(2020));
      jpg('newer.jpg', 10, DateTime.utc(2026));

      await cache.prune();

      expect(picked.existsSync(), isFalse);
      expect(names(), ['newer.jpg']);
    });
  });

  group('bridge timeout', () {
    test('a bridge that never answers gives null after the timeout', () async {
      final records = <LogRecord>[];
      final sub = Logger.root.onRecord.listen(records.add);
      addTearDown(sub.cancel);
      final previous = Logger.root.level;
      Logger.root.level = Level.ALL;
      addTearDown(() => Logger.root.level = previous);
      final stuck = _StuckBridge();
      final cache = cacheWith(
        using: stuck,
        bridgeTimeout: const Duration(milliseconds: 30),
      );

      expect(await cache.load(clipOf(volume: '1234-5678'), 300), isNull);

      expect(names(), isEmpty);
      final text = records
          .map((r) => '${r.message} ${r.error ?? ''}')
          .join('\n');
      expect(text, contains('1234-5678'));
      expect(text, contains('timeout'));
      expect(text, isNot(contains('/')));
    });

    test(
      'shared loads all get null on a timeout, and the next call asks again',
      () async {
        final stuck = _StuckBridge();
        final cache = cacheWith(
          using: stuck,
          bridgeTimeout: const Duration(milliseconds: 30),
        );

        final results = await Future.wait([
          cache.load(clipOf(), 300),
          cache.load(clipOf(), 300),
        ]);

        expect(results, [null, null]);
        expect(stuck.calls, ['thumbnail'], reason: 'one call for both');
        expect(await cache.load(clipOf(), 300), isNull);
        expect(stuck.calls, [
          'thumbnail',
          'thumbnail',
        ], reason: 'not remembered');
      },
    );

    test('an answer that arrives after the timeout is not cached', () async {
      final stuck = _StuckBridge();
      final cache = cacheWith(
        using: stuck,
        bridgeTimeout: const Duration(milliseconds: 30),
      );
      expect(await cache.load(clipOf(), 300), isNull);

      stuck.answer.complete(bytesOf(10));
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(names(), isEmpty);
    });
  });

  group('sharing', () {
    test('two concurrent loads → one bridge call', () async {
      bridge.thumbnails[('external_primary', 42)] = bytesOf(10);
      final gate = bridge.gate('thumbnail');
      final cache = cacheWith();

      final a = cache.load(clipOf(), 300);
      final b = cache.load(clipOf(), 300);
      await Future<void>.delayed(Duration.zero);
      gate.complete();

      expect(await a, bytesOf(10));
      expect(await b, bytesOf(10));
      expect(bridge.calls.where((c) => c == 'thumbnail'), hasLength(1));
    });

    test('loads of different keys do not share a call', () async {
      bridge.thumbnails[('external_primary', 42)] = bytesOf(10);
      final gate = bridge.gate('thumbnail');
      final cache = cacheWith();

      final a = cache.load(clipOf(), 300);
      final b = cache.load(clipOf(), 200);
      await Future<void>.delayed(Duration.zero);
      gate.complete();
      await Future.wait([a, b]);

      expect(bridge.calls.where((c) => c == 'thumbnail'), hasLength(2));
    });

    test(
      'shared loads that fail all get null, and the next call retries',
      () async {
        bridge.thumbnails[('external_primary', 42)] = bytesOf(10);
        bridge.failNext('thumbnail');
        final gate = bridge.gate('thumbnail');
        final cache = cacheWith();

        final a = cache.load(clipOf(), 300);
        final b = cache.load(clipOf(), 300);
        final c = cache.load(clipOf(), 300);
        await Future<void>.delayed(Duration.zero);
        gate.complete();

        expect(await Future.wait([a, b, c]), [null, null, null]);
        expect(bridge.calls.where((c) => c == 'thumbnail'), hasLength(1));
        expect(await cache.load(clipOf(), 300), bytesOf(10));
        expect(bridge.calls.where((c) => c == 'thumbnail'), hasLength(2));
      },
    );

    test('a finished load is not kept: a later load reads the disk', () async {
      bridge.thumbnails[('external_primary', 42)] = bytesOf(10);
      final cache = cacheWith();
      await cache.load(clipOf(), 300);
      dir.listSync().whereType<File>().single.writeAsBytesSync(bytesOf(3));

      expect(await cache.load(clipOf(), 300), bytesOf(3));
    });
  });

  group('prune', () {
    final base = DateTime.utc(2026);

    test('removes oldest first down to the cap', () async {
      jpg('c.jpg', 40, base.add(const Duration(days: 3)));
      jpg('a.jpg', 40, base.add(const Duration(days: 1)));
      jpg('b.jpg', 40, base.add(const Duration(days: 2)));
      jpg('d.jpg', 40, base.add(const Duration(days: 4)));

      await cacheWith(maxBytes: 100).prune();

      expect(names(), ['c.jpg', 'd.jpg']);
    });

    test('exactly at the cap deletes nothing', () async {
      jpg('a.jpg', 50, base);
      jpg('b.jpg', 50, base.add(const Duration(days: 1)));

      await cacheWith(maxBytes: 100).prune();

      expect(names(), ['a.jpg', 'b.jpg']);
    });

    test('one byte over deletes the oldest', () async {
      jpg('a.jpg', 50, base);
      jpg('b.jpg', 51, base.add(const Duration(days: 1)));

      await cacheWith(maxBytes: 100).prune();

      expect(names(), ['b.jpg']);
    });

    test('stops as soon as the total fits', () async {
      jpg('a.jpg', 10, base);
      jpg('b.jpg', 10, base.add(const Duration(days: 1)));
      jpg('c.jpg', 90, base.add(const Duration(days: 2)));

      await cacheWith(maxBytes: 100).prune();

      expect(names(), ['b.jpg', 'c.jpg']);
    });

    test(
      'a file larger than the cap is deleted, the folder is left empty',
      () async {
        jpg('a.jpg', 200, base);

        await cacheWith(maxBytes: 100).prune();

        expect(names(), isEmpty);
      },
    );

    test('a missing folder is fine', () async {
      await cacheWith(maxBytes: 100).prune();

      expect(dir.existsSync(), isFalse);
    });

    test(
      'leftover *.tmp files are deleted and not counted toward the cap',
      () async {
        jpg('a.jpg', 40, base);
        jpg('b.jpg', 40, base.add(const Duration(days: 1)));
        jpg('a.jpg.tmp', 1000, base.add(const Duration(days: 2)));

        await cacheWith(maxBytes: 100).prune();

        expect(names(), [
          'a.jpg',
          'b.jpg',
        ], reason: 'tmp gone, no jpg lost for it');
      },
    );

    test(
      'a file that vanishes while the folder is listed is skipped',
      () async {
        jpg('a.jpg', 50, base);
        jpg('b.jpg', 51, base.add(const Duration(days: 1)));
        final cache = cacheWith(
          maxBytes: 100,
          listDir: (d) async* {
            // Listed, then gone before it is looked at.
            yield File('${d.path}/ghost.jpg');
            yield* d.list();
          },
        );

        await cache.prune();

        expect(names(), ['b.jpg'], reason: 'the ghost counted for nothing');
      },
    );

    test('files that are not thumbnails are left alone', () async {
      jpg('a.jpg', 500, base);
      jpg('notes.txt', 500, base);
      Directory('${dir.path}/sub').createSync();

      await cacheWith(maxBytes: 100).prune();

      expect(names(), ['notes.txt', 'sub']);
    });

    test('a hit makes a file newest, so prune keeps it', () async {
      bridge.thumbnails[('external_primary', 42)] = bytesOf(10);
      bridge.thumbnails[('external_primary', 43)] = bytesOf(10);
      final cache = cacheWith(maxBytes: 10);
      await cache.load(clipOf(), 300);
      await cache.load(clipOf(mediaStoreId: 43), 300);
      for (final f in dir.listSync().whereType<File>()) {
        f.setLastModifiedSync(DateTime.utc(2020));
      }
      clock.advance(const Duration(days: 1));
      await cache.load(clipOf(), 300);

      await cache.prune();

      expect(names().single, contains('_42_'));
    });

    test('a file being written while prune runs is never deleted', () async {
      bridge.thumbnails[('external_primary', 42)] = bytesOf(10);
      jpg('old.jpg', 40, base);
      final renameGate = Completer<void>();
      final atRename = Completer<void>();
      final cache = cacheWith(
        maxBytes: 1,
        renameFile: (temp, finalPath) async {
          atRename.complete();
          await renameGate.future;
          await temp.rename(finalPath);
        },
      );

      final loading = cache.load(clipOf(), 300);
      await atRename.future; // the temp file is complete, the rename waits
      expect(names().where((n) => n.endsWith('.tmp')), hasLength(1));

      await cache.prune();

      expect(names().where((n) => n.endsWith('.tmp')), hasLength(1));
      expect(names().contains('old.jpg'), isFalse);
      renameGate.complete();
      expect(await loading, bytesOf(10));
      expect(names().where((n) => n.endsWith('.jpg')), hasLength(1));
      expect(names().where((n) => n.endsWith('.tmp')), isEmpty);
    });
  });

  group('partial write', () {
    test('partial write never leaves a corrupt file', () async {
      // A kill between the write and the rename: the process is gone, so
      // nothing after the failed step runs (an Error is not caught).
      bridge.thumbnails[('external_primary', 42)] = bytesOf(10);
      final dying = cacheWith(
        renameFile: (temp, finalPath) async => throw _Killed(),
      );

      await expectLater(dying.load(clipOf(), 300), throwsA(isA<_Killed>()));

      expect(
        names().where((n) => n.endsWith('.jpg')),
        isEmpty,
        reason: 'no real name until the rename',
      );

      // The app starts again: a new cache on the same folder.
      bridge.calls.clear();
      final restarted = cacheWith();
      expect(await restarted.load(clipOf(), 300), bytesOf(10));
      expect(bridge.calls, ['thumbnail'], reason: 'nothing was cached');
      expect(names().where((n) => n.endsWith('.jpg')), hasLength(1));
      expect(names().where((n) => n.endsWith('.tmp')), isEmpty);
    });

    test(
      'a rename that fails cleanly still returns the picture and recovers',
      () async {
        bridge.thumbnails[('external_primary', 42)] = bytesOf(10);
        var failing = true;
        final cache = cacheWith(
          renameFile: (temp, finalPath) async {
            if (failing) throw const FileSystemException('disk full');
            await temp.rename(finalPath);
          },
        );

        expect(await cache.load(clipOf(), 300), bytesOf(10));
        expect(names(), isEmpty, reason: 'no final file and no temp file left');

        failing = false;
        bridge.calls.clear();
        expect(await cache.load(clipOf(), 300), bytesOf(10));
        expect(bridge.calls, ['thumbnail']);
        expect(names().where((n) => n.endsWith('.jpg')), hasLength(1));
      },
    );

    test('a temp file left by a real crash is never read as a hit', () async {
      bridge.thumbnails[('external_primary', 42)] = bytesOf(10);
      dir.createSync(recursive: true);
      final name = baseFile;
      File('${dir.path}/$name.tmp').writeAsBytesSync(bytesOf(3));

      final got = await cacheWith().load(clipOf(), 300);

      expect(got, bytesOf(10));
      expect(File('${dir.path}/$name').readAsBytesSync(), bytesOf(10));
    });
  });
}

/// A bridge whose thumbnail call waits until [answer] completes.
class _StuckBridge extends FakeMediaBridge {
  final Completer<Uint8List?> answer = Completer();

  @override
  Future<Uint8List?> thumbnail(
    String volumeName,
    int mediaStoreId,
    int widthPx,
    int heightPx,
  ) {
    calls.add('thumbnail');
    return answer.future;
  }

  @override
  Future<Uint8List?> thumbnailOfUri(String uri, int widthPx, int heightPx) {
    calls.add('thumbnailOfUri');
    return answer.future;
  }
}

/// Stands for the process being killed: an [Error], so no `on Exception`
/// clean-up runs.
class _Killed extends Error {
  _Killed();
}

/// A bridge whose thumbnail call fails with one error code.
class _CodeBridge extends FakeMediaBridge {
  _CodeBridge(this.code);

  final String code;

  @override
  Future<Uint8List?> thumbnail(
    String volumeName,
    int mediaStoreId,
    int widthPx,
    int heightPx,
  ) async {
    calls.add('thumbnail');
    throw PlatformException(code: code, message: '/storage/1234-5678/secret');
  }
}

/// A bridge whose `thumbnailOfUri` throws something that is not a
/// `PlatformException`, with an address in its message.
class _ThrowingUriBridge extends FakeMediaBridge {
  @override
  Future<Uint8List?> thumbnailOfUri(
    String uri,
    int widthPx,
    int heightPx,
  ) async {
    calls.add('thumbnailOfUri');
    throw MissingPluginException('no plugin for $uri');
  }
}
