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

  test('exportFile content equals readAll', () async {
    final sink = LogFileSink(dir, maxBytes: 50);
    for (var i = 0; i < 10; i++) {
      await sink.write('record $i');
    }
    final file = await sink.exportFile();
    expect(file.uri.pathSegments.last, 'taketray-log.txt');
    expect(await file.readAsString(), await sink.readAll());
  });
}
