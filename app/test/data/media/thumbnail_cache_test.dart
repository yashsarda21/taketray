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

/// The file name of `clipOf()` at 300 px.
final String baseFile =
    'external_primary_42_1000000_'
    '${DateTime.utc(2026, 5, 1, 12).millisecondsSinceEpoch}_300.jpg';

Uint8List bytesOf(int length, [int fill = 7]) =>
    Uint8List.fromList(List.filled(length, fill));

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
  }) => ThumbnailCache(
    using ?? bridge,
    dir,
    maxBytes: maxBytes,
    clock: clock,
    renameFile: renameFile,
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

    test(
      'detached and picker clips give null without asking the bridge',
      () async {
        final cache = cacheWith();
        final detached = clipOf(mediaStoreId: -5);
        final zero = clipOf(mediaStoreId: 0);
        final picker = clipOf().copyWith(
          source: ClipSource.picker,
          mediaStoreId: null,
          volumeName: null,
          pickerUri: 'content://x',
        );
        final noVolume = clipOf().copyWith(volumeName: null);
        final blankVolume = clipOf(volume: '');

        for (final clip in [detached, zero, picker, noVolume, blankVolume]) {
          expect(await cache.load(clip, 300), isNull);
        }

        expect(bridge.calls, isEmpty);
        expect(names(), isEmpty);
      },
    );

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
      final cache = cacheWith(
        maxBytes: 1,
        renameFile: (temp, finalPath) async {
          await renameGate.future;
          await temp.rename(finalPath);
        },
      );

      final loading = cache.load(clipOf(), 300);
      await Future<void>.delayed(const Duration(milliseconds: 50));
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
