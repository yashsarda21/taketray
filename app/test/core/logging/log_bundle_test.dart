import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/core/logging/log_bundle.dart';
import 'package:taketray/core/logging/log_file_sink.dart';

void main() {
  late Directory root;
  late Directory logDir;
  late Directory cacheDir;
  final now = DateTime(2026, 11, 17, 14, 30);

  setUp(() {
    root = Directory.systemTemp.createTempSync('taketray_bundle_test');
    logDir = Directory('${root.path}/support')..createSync();
    cacheDir = Directory('${root.path}/cache')..createSync();
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  void writeLog(int index, String text) =>
      File('${logDir.path}/taketray-$index.log').writeAsStringSync(text);

  void writeShareLog(int index, String text) =>
      File('${logDir.path}/share-$index.log').writeAsStringSync(text);

  Directory shared() => Directory('${cacheDir.path}/shared');

  List<String> sharedNames() => shared().existsSync()
      ? [for (final f in shared().listSync()) f.uri.pathSegments.last]
      : <String>[];

  group('no log to send', () {
    test('no log files: null, and nothing is written', () async {
      expect(await bundleLogs(logDir, cacheDir, now), isNull);

      expect(sharedNames(), isEmpty);
    });

    test('a log folder that does not exist: null', () async {
      final missing = Directory('${root.path}/nowhere');

      expect(await bundleLogs(missing, cacheDir, now), isNull);
    });

    test('an empty current file alone: null', () async {
      writeLog(0, '');

      expect(await bundleLogs(logDir, cacheDir, now), isNull);
      expect(sharedNames(), isEmpty);
    });

    test('both files empty: null', () async {
      writeLog(1, '');
      writeLog(0, '');

      expect(await bundleLogs(logDir, cacheDir, now), isNull);
    });

    test('a file with only half a line: null', () async {
      writeLog(0, 'half a li');

      expect(await bundleLogs(logDir, cacheDir, now), isNull);
    });
  });

  group('the bundle', () {
    test('only the current file: its bytes, in cache shared', () async {
      writeLog(0, 'one\ntwo\n');

      final file = await bundleLogs(logDir, cacheDir, now);

      expect(file, isNotNull);
      expect(
        file!.path,
        '${cacheDir.path}/shared/taketray-log-2026-11-17-1430.txt',
      );
      expect(file.readAsStringSync(), 'one\ntwo\n');
    });

    test('only the previous file: its bytes', () async {
      writeLog(1, 'old\n');

      final file = await bundleLogs(logDir, cacheDir, now);

      expect(file!.readAsStringSync(), 'old\n');
    });

    test('both files: the previous one first, then the current one, '
        'byte for byte', () async {
      final previous = utf8.encode('first é ✓\nsecond\n');
      final current = utf8.encode('third\n  stack: a\n    b\nfourth\n');
      File('${logDir.path}/taketray-1.log').writeAsBytesSync(previous);
      File('${logDir.path}/taketray-0.log').writeAsBytesSync(current);

      final file = await bundleLogs(logDir, cacheDir, now);

      expect(file!.readAsBytesSync(), [...previous, ...current]);
    });

    test('the log files themselves are left as they were', () async {
      writeLog(1, 'old\n');
      writeLog(0, 'new\n');

      await bundleLogs(logDir, cacheDir, now);

      expect(File('${logDir.path}/taketray-1.log').readAsStringSync(), 'old\n');
      expect(File('${logDir.path}/taketray-0.log').readAsStringSync(), 'new\n');
    });

    test('other files in the log folder are not included', () async {
      writeLog(0, 'mine\n');
      File('${logDir.path}/taketray-2.log').writeAsStringSync('third\n');
      File('${logDir.path}/taketray-log.txt').writeAsStringSync('export\n');
      File('${logDir.path}/other.txt').writeAsStringSync('other\n');

      final file = await bundleLogs(logDir, cacheDir, now);

      expect(file!.readAsStringSync(), 'mine\n');
    });

    test('a cache folder with no shared folder yet: it is made', () async {
      writeLog(0, 'a\n');
      cacheDir.deleteSync(recursive: true);

      final file = await bundleLogs(logDir, cacheDir, now);

      expect(file!.existsSync(), isTrue);
      expect(file.parent.path, '${cacheDir.path}/shared');
    });
  });

  group('the name follows the time', () {
    for (final (time, name) in [
      (DateTime(2026, 11, 17, 14, 30), 'taketray-log-2026-11-17-1430.txt'),
      (DateTime(2027, 1, 2, 3, 5), 'taketray-log-2027-01-02-0305.txt'),
      (DateTime(2026, 12, 31, 23, 59), 'taketray-log-2026-12-31-2359.txt'),
      (DateTime(2027), 'taketray-log-2027-01-01-0000.txt'),
    ]) {
      test('$time is $name', () async {
        writeLog(0, 'a\n');

        final file = await bundleLogs(logDir, cacheDir, time);

        expect(file!.uri.pathSegments.last, name);
      });
    }

    test('a UTC time is named by the phone clock', () async {
      writeLog(0, 'a\n');
      final utc = DateTime.utc(2026, 6, 30, 23, 30);
      final local = utc.toLocal();
      String two(int n) => n.toString().padLeft(2, '0');

      final file = await bundleLogs(logDir, cacheDir, utc);

      expect(
        file!.uri.pathSegments.last,
        'taketray-log-${local.year}-${two(local.month)}-${two(local.day)}-'
        '${two(local.hour)}${two(local.minute)}.txt',
      );
    });
  });

  group('older bundles', () {
    File oldBundle(String name, [String text = 'old bundle\n']) {
      shared().createSync(recursive: true);
      return File('${shared().path}/$name')..writeAsStringSync(text);
    }

    test('an older bundle is deleted', () async {
      writeLog(0, 'now\n');
      final old = oldBundle('taketray-log-2026-11-16-0900.txt');

      final file = await bundleLogs(logDir, cacheDir, now);

      expect(old.existsSync(), isFalse);
      expect(sharedNames(), [file!.uri.pathSegments.last]);
    });

    test('several older bundles are deleted', () async {
      writeLog(0, 'now\n');
      oldBundle('taketray-log-2026-11-14-0900.txt');
      oldBundle('taketray-log-2026-11-15-0900.txt');
      oldBundle('taketray-log-2026-11-16-0900.txt');

      await bundleLogs(logDir, cacheDir, now);

      expect(sharedNames(), ['taketray-log-2026-11-17-1430.txt']);
    });

    test('with no log to send the older bundle is still deleted', () async {
      final old = oldBundle('taketray-log-2026-11-16-0900.txt');

      expect(await bundleLogs(logDir, cacheDir, now), isNull);

      expect(old.existsSync(), isFalse);
    });

    test('a second bundle in the same minute replaces the first', () async {
      writeLog(0, 'first\n');
      await bundleLogs(logDir, cacheDir, now);
      writeLog(0, 'first\nsecond\n');

      final file = await bundleLogs(logDir, cacheDir, now);

      expect(sharedNames(), ['taketray-log-2026-11-17-1430.txt']);
      expect(file!.readAsStringSync(), 'first\nsecond\n');
    });

    test('a file that is not a bundle is left alone', () async {
      writeLog(0, 'now\n');
      final other = oldBundle('notes.txt', 'keep');

      await bundleLogs(logDir, cacheDir, now);

      expect(other.readAsStringSync(), 'keep');
    });
  });

  group('a file that is being written', () {
    test('half a line at the end of a file is left out', () async {
      writeLog(1, 'a\nb\nhal');
      writeLog(0, 'c\nd\ne par');

      final file = await bundleLogs(logDir, cacheDir, now);

      expect(file!.readAsStringSync(), 'a\nb\nc\nd\n');
    });

    test('a half line is left out of the only file too', () async {
      writeLog(0, 'whole\nhalf');

      final file = await bundleLogs(logDir, cacheDir, now);

      expect(file!.readAsStringSync(), 'whole\n');
    });

    // A smoke test, not a proof: the writes are queued and the join starts at
    // once, so it rarely reads in the middle of a write. What makes a half
    // line impossible is pinned by the two "half line" tests above.
    test('smoke: lines being written while the logs are joined, every line '
        'bundled is whole', () async {
      final sink = LogFileSink(logDir, maxBytes: 600);
      final writes = <Future<void>>[];
      String line(int i) => 'line-${i.toString().padLeft(4, '0')} ${'x' * 40}';
      for (var i = 0; i < 60; i++) {
        writes.add(sink.write(line(i)));
      }

      // Joined while the writes are still running.
      final file = await bundleLogs(logDir, cacheDir, now);
      await Future.wait(writes);

      if (file != null) {
        final text = file.readAsStringSync();
        expect(text, endsWith('\n'));
        final lines = text.trimRight().split('\n');
        for (final l in lines) {
          expect(
            l,
            matches(RegExp(r'^line-\d{4} x{40}$')),
            reason: 'a half line reached the bundle',
          );
        }
      }
    });
  });

  group("the share screen's log (D-163)", () {
    test('both sets: taketray oldest first, then share oldest first', () async {
      writeLog(1, 'app old\n');
      writeLog(0, 'app new\n');
      writeShareLog(1, 'share old\n');
      writeShareLog(0, 'share new\n');

      final file = await bundleLogs(logDir, cacheDir, now);

      expect(
        file!.readAsStringSync(),
        'app old\napp new\nshare old\nshare new\n',
      );
    });

    test('both sets, byte for byte', () async {
      final parts = [
        ('taketray-1.log', utf8.encode('a é\n')),
        ('taketray-0.log', utf8.encode('b ✓\n')),
        ('share-1.log', utf8.encode('c\n  stack: x\n')),
        ('share-0.log', utf8.encode('d\n')),
      ];
      for (final (name, bytes) in parts) {
        File('${logDir.path}/$name').writeAsBytesSync(bytes);
      }

      final file = await bundleLogs(logDir, cacheDir, now);

      expect(file!.readAsBytesSync(), [for (final (_, b) in parts) ...b]);
    });

    test('no share log: only the taketray files', () async {
      writeLog(1, 'app old\n');
      writeLog(0, 'app new\n');

      final file = await bundleLogs(logDir, cacheDir, now);

      expect(file!.readAsStringSync(), 'app old\napp new\n');
    });

    test('only a share log: it is sent', () async {
      writeShareLog(0, 'shared once\n');

      final file = await bundleLogs(logDir, cacheDir, now);

      expect(file!.readAsStringSync(), 'shared once\n');
    });

    test('only the current file of each set', () async {
      writeLog(0, 'app\n');
      writeShareLog(0, 'share\n');

      final file = await bundleLogs(logDir, cacheDir, now);

      expect(file!.readAsStringSync(), 'app\nshare\n');
    });

    test('a half line at the end of a share file is dropped', () async {
      writeLog(0, 'app\n');
      writeShareLog(1, 'share old\nhalf of');
      writeShareLog(0, 'share new\nhal');

      final file = await bundleLogs(logDir, cacheDir, now);

      expect(file!.readAsStringSync(), 'app\nshare old\nshare new\n');
    });

    test('empty share files add nothing, and alone send nothing', () async {
      writeShareLog(1, '');
      writeShareLog(0, '');

      expect(await bundleLogs(logDir, cacheDir, now), isNull);
    });

    test('other share-like files are not included', () async {
      writeShareLog(0, 'mine\n');
      File('${logDir.path}/share-2.log').writeAsStringSync('third\n');
      File('${logDir.path}/share.log').writeAsStringSync('plain\n');
      File('${logDir.path}/shared-0.log').writeAsStringSync('shared\n');

      final file = await bundleLogs(logDir, cacheDir, now);

      expect(file!.readAsStringSync(), 'mine\n');
    });

    test('the share files themselves are left as they were', () async {
      writeShareLog(1, 'old\n');
      writeShareLog(0, 'new\n');

      await bundleLogs(logDir, cacheDir, now);

      expect(File('${logDir.path}/share-1.log').readAsStringSync(), 'old\n');
      expect(File('${logDir.path}/share-0.log').readAsStringSync(), 'new\n');
    });

    test('a share sink and the bundle agree on the file names', () async {
      final sink = LogFileSink(logDir, prefix: shareLogPrefix, maxBytes: 20);
      await sink.write('aaaaaaaaa');
      await sink.write('bbbbbbbbb');
      await sink.write('ccccccccc'); // rotates

      final file = await bundleLogs(logDir, cacheDir, now);

      expect(file!.readAsStringSync(), await sink.readAll());
    });
  });
}
