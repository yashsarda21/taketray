import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/core/logging/log_file_sink.dart';

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('taketray_sink_test');
  });

  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  test('write then readAll returns the line', () async {
    final sink = LogFileSink(dir);
    await sink.write('hello');
    expect(await sink.readAll(), contains('hello'));
  });

  test('readAll on an empty log is empty', () async {
    expect(await LogFileSink(dir).readAll(), isEmpty);
  });

  test('rotation keeps exactly two files within 2 * maxBytes', () async {
    final sink = LogFileSink(dir, maxBytes: 100);
    // 9 characters + newline = 10 bytes per line.
    final lines = [
      for (var i = 0; i < 30; i++) 'line-${i.toString().padLeft(4, '0')}',
    ];
    for (final line in lines) {
      await sink.write(line);
    }

    final files = dir.listSync().whereType<File>().toList();
    expect(files.map((f) => f.uri.pathSegments.last).toList()..sort(), [
      'taketray-0.log',
      'taketray-1.log',
    ]);
    final total = files.fold<int>(0, (sum, f) => sum + f.lengthSync());
    expect(total, lessThanOrEqualTo(200));
    expect((await sink.readAll()).trimRight(), endsWith(lines.last));
  });

  test('readAll lists the previous file before the current one', () async {
    final sink = LogFileSink(dir, maxBytes: 20);
    await sink.write('aaaaaaaaa'); // 10 bytes
    await sink.write('bbbbbbbbb'); // 20 bytes, fits
    await sink.write('ccccccccc'); // would exceed, rotates
    final all = await sink.readAll();
    expect(all, 'aaaaaaaaa\nbbbbbbbbb\nccccccccc\n');
    expect(
      File('${dir.path}/taketray-1.log').readAsStringSync(),
      'aaaaaaaaa\nbbbbbbbbb\n',
    );
    expect(
      File('${dir.path}/taketray-0.log').readAsStringSync(),
      'ccccccccc\n',
    );
  });

  test('concurrent writes do not interleave or get lost', () async {
    final sink = LogFileSink(dir);
    await Future.wait([for (var i = 0; i < 50; i++) sink.write('entry-$i')]);
    final lines = (await sink.readAll()).trimRight().split('\n');
    expect(lines, [for (var i = 0; i < 50; i++) 'entry-$i']);
  });

  test('a new sink on the same directory continues the current file', () async {
    await LogFileSink(dir).write('first');
    final second = LogFileSink(dir);
    await second.write('second');
    expect(await second.readAll(), 'first\nsecond\n');
  });

  group('the file prefix', () {
    List<String> names() => [
      for (final f in dir.listSync().whereType<File>()) f.uri.pathSegments.last,
    ]..sort();

    test('the default prefix is taketray', () async {
      final sink = LogFileSink(dir);
      expect(sink.prefix, 'taketray');
      expect(sink.maxBytes, 512 * 1024);
      expect(sink.maxFiles, 2);

      await sink.write('a');

      expect(names(), ['taketray-0.log']);
    });

    test("prefix 'share' writes share-0.log", () async {
      final sink = LogFileSink(dir, prefix: 'share');

      await sink.write('hello');

      expect(names(), ['share-0.log']);
      expect(File('${dir.path}/share-0.log').readAsStringSync(), 'hello\n');
    });

    test("prefix 'share' rotates to share-1.log and keeps two files", () async {
      final sink = LogFileSink(dir, prefix: 'share', maxBytes: 20);
      await sink.write('aaaaaaaaa'); // 10 bytes
      await sink.write('bbbbbbbbb'); // 20 bytes, fits
      await sink.write('ccccccccc'); // would exceed, rotates
      await sink.write('ddddddddd'); // 20 bytes, fits
      await sink.write('eeeeeeeee'); // rotates again: the a and b lines go

      expect(names(), ['share-0.log', 'share-1.log']);
      expect(
        File('${dir.path}/share-1.log').readAsStringSync(),
        'ccccccccc\nddddddddd\n',
      );
      expect(File('${dir.path}/share-0.log').readAsStringSync(), 'eeeeeeeee\n');
      expect(await sink.readAll(), 'ccccccccc\nddddddddd\neeeeeeeee\n');
    });

    test('two sinks with their own prefix in one folder never touch '
        "each other's files", () async {
      final app = LogFileSink(dir, maxBytes: 20);
      final share = LogFileSink(dir, prefix: 'share', maxBytes: 20);
      for (var i = 0; i < 5; i++) {
        await app.write('app-$i-xxx'); // 10 bytes
        await share.write('shr-$i-xxx');
      }

      expect(names(), [
        'share-0.log',
        'share-1.log',
        'taketray-0.log',
        'taketray-1.log',
      ]);
      expect(await app.readAll(), isNot(contains('shr-')));
      expect(await share.readAll(), isNot(contains('app-')));
      expect(await app.readAll(), endsWith('app-4-xxx\n'));
      expect(await share.readAll(), endsWith('shr-4-xxx\n'));
    });

    test('the share log keeps its own size: 128 KiB each', () async {
      final sink = LogFileSink(dir, prefix: 'share', maxBytes: 128 * 1024);
      final line = 'x' * 1023; // 1 KiB with its newline
      for (var i = 0; i < 129; i++) {
        await sink.write(line);
      }

      expect(names(), ['share-0.log', 'share-1.log']);
      expect(File('${dir.path}/share-1.log').lengthSync(), 128 * 1024);
      expect(File('${dir.path}/share-0.log').lengthSync(), 1024);
    });
  });

  group('two sinks on the same files (two share engines, D-163)', () {
    test('a file never grows past maxBytes, whoever wrote last', () async {
      final a = LogFileSink(dir, maxBytes: 100);
      final b = LogFileSink(dir, maxBytes: 100);
      // 29 characters + newline = 30 bytes per line.
      final line = List.filled(29, 'x').join();
      // Each sink's own count of the file is behind the other's writes.
      await a.write(line);
      await b.write(line);
      await a.write(line);
      await b.write(line);
      await a.write(line);
      await b.write(line);

      final files = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.log'))
          .toList();
      expect(files, isNotEmpty);
      expect(files.length, lessThanOrEqualTo(2));
      for (final file in files) {
        expect(file.lengthSync(), lessThanOrEqualTo(100), reason: file.path);
      }
    });

    test('the second sink rotates when the first filled the file', () async {
      final a = LogFileSink(dir, maxBytes: 100);
      final b = LogFileSink(dir, maxBytes: 100);
      final line = List.filled(29, 'x').join();
      await b.write(line); // b counts 30
      await a.write(line);
      await a.write(line); // the file holds 90 bytes

      await b.write(line); // 120 would pass the limit

      expect(File('${dir.path}/taketray-1.log').lengthSync(), 90);
      expect(File('${dir.path}/taketray-0.log').lengthSync(), 30);
    });

    test('a file deleted under a sink starts again from zero', () async {
      final a = LogFileSink(dir, maxBytes: 100);
      await a.write('hello');
      File('${dir.path}/taketray-0.log').deleteSync();

      await a.write('again');

      expect(await a.readAll(), 'again\n');
    });
  });

  test('the two prefixes are named once', () {
    expect(appLogPrefix, 'taketray');
    expect(shareLogPrefix, 'share');
  });
}
