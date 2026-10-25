import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:taketray/core/logging/log_file_sink.dart';
import 'package:taketray/core/logging/logging_setup.dart';

void main() {
  late Directory dir;
  late FlutterExceptionHandler? originalFlutterOnError;
  late ErrorCallback? originalPlatformOnError;
  final subscriptions = <StreamSubscription<LogRecord>>[];

  StreamSubscription<LogRecord> listen(void Function(LogRecord) onData) {
    final sub = Logger.root.onRecord.listen(onData);
    subscriptions.add(sub);
    return sub;
  }

  setUp(() {
    dir = Directory.systemTemp.createTempSync('taketray_setup_test');
    originalFlutterOnError = FlutterError.onError;
    originalPlatformOnError = PlatformDispatcher.instance.onError;
  });

  tearDown(() async {
    for (final sub in subscriptions) {
      await sub.cancel();
    }
    subscriptions.clear();
    await disposeLogging();
    FlutterError.onError = originalFlutterOnError;
    PlatformDispatcher.instance.onError = originalPlatformOnError;
    Logger.root.level = Level.INFO;
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  group('formatRecord', () {
    test('renders time, level, logger and message', () {
      final record = LogRecord(Level.WARNING, 'something happened', 'scan');
      final line = formatRecord(record);
      final time = record.time.toUtc().toIso8601String();
      expect(line, '$time WARNING scan: something happened');
      expect(
        line,
        matches(RegExp(r'^\d{4}-\d\d-\d\dT[\d:.]+Z WARNING scan: ')),
      );
    });

    test('appends error and stack when present', () {
      final line = formatRecord(
        LogRecord(
          Level.SEVERE,
          'failed',
          'crash',
          StateError('boom'),
          StackTrace.fromString('frame1\nframe2'),
        ),
      );
      expect(
        line,
        contains(' SEVERE crash: failed\n  error: Bad state: boom\n'),
      );
      expect(line, contains('  stack: frame1'));
      expect(line, contains('frame2'));
    });

    test('renders a FileSystemException without its path', () {
      final line = formatRecord(
        LogRecord(
          Level.SEVERE,
          'copy failed',
          'crash',
          const FileSystemException(
            'Cannot open file',
            '/storage/emulated/0/DCIM/clip.mp4',
            OSError('No such file or directory', 2),
          ),
        ),
      );
      expect(line, isNot(contains('/storage')));
      expect(line, isNot(contains('clip.mp4')));
      expect(line, contains('FileSystemException: Cannot open file'));
      expect(line, contains('errno = 2'));
    });

    test('redacts a path inside a FileSystemException message', () {
      final line = formatRecord(
        LogRecord(
          Level.SEVERE,
          'x',
          'crash',
          const FileSystemException(
            "Cannot open '/storage/emulated/0/DCIM/My Clip 1.mp4' now",
          ),
        ),
      );
      expect(line, isNot(contains('DCIM')));
      expect(line, isNot(contains('Clip')));
      expect(line, contains('<path>'));
    });

    test('redacts URIs and paths in the message', () {
      String format(String message) =>
          formatRecord(LogRecord(Level.INFO, message, 'x'));
      expect(
        format('failed content://media/external/video/media/42'),
        endsWith('x: failed <path>'),
      );
      expect(
        format('open file:///sdcard/a.mp4 failed'),
        endsWith('open <path> failed'),
      );
      expect(
        format(r'bad C:\Users\me\clip.mp4 here'),
        endsWith('bad <path> here'),
      );
      expect(
        format('at /storage/emulated/0/clip.mp4 and more'),
        endsWith('at <path> and more'),
      );
      expect(
        format('"/storage/emulated/0/My Clip.mp4" failed'),
        endsWith('<path> failed'),
      );
    });

    test('leaves ordinary text unchanged', () {
      final record = LogRecord(
        Level.INFO,
        'scanned 12/30 clips and/or tags in 3 s (a/b)',
        'scan',
      );
      expect(
        formatRecord(record),
        endsWith('scan: scanned 12/30 clips and/or tags in 3 s (a/b)'),
      );
    });

    test('keeps stack traces as they are', () {
      final line = formatRecord(
        LogRecord(
          Level.SEVERE,
          'x',
          'crash',
          null,
          StackTrace.fromString('#0 main (package:taketray/main.dart:1:1)'),
        ),
      );
      expect(line, contains('package:taketray/main.dart:1:1'));
    });

    test('truncates a record to 8 KiB', () {
      final line = formatRecord(LogRecord(Level.INFO, 'é' * 20000, 'big'));
      expect(line, endsWith('…[truncated]'));
      expect(line.codeUnits.length, lessThan(8 * 1024));
    });
  });

  test('an uncaught async error ends up in the log as SEVERE crash', () async {
    final crashLogged = Completer<void>();
    final sinkReady = Completer<LogFileSink>();

    await runAppWithLogging(
      () {
        late StreamSubscription<LogRecord> sub;
        sub = listen((r) {
          if (r.loggerName != 'crash') return;
          unawaited(sub.cancel());
          crashLogged.complete();
        });
        unawaited(Future<void>(() => throw StateError('boom')));
      },
      logDir: () async => dir,
      onSinkReady: sinkReady.complete,
    );

    await crashLogged.future;
    final sink = await sinkReady.future;
    final content = await sink.readAll();
    expect(content, contains('SEVERE crash'));
    expect(content, contains('boom'));
  });

  test('FlutterError and platform errors are logged as crash', () async {
    final seen = <String>[];
    final sinkReady = Completer<LogFileSink>();
    await runAppWithLogging(
      () {},
      logDir: () async => dir,
      onSinkReady: sinkReady.complete,
    );
    listen((r) => seen.add(r.loggerName));

    FlutterError.onError!(
      FlutterErrorDetails(exception: StateError('framework boom')),
    );
    final handled = PlatformDispatcher.instance.onError!(
      StateError('platform boom'),
      StackTrace.current,
    );

    expect(handled, isTrue);
    expect(seen, ['crash', 'crash']);
    final content = await (await sinkReady.future).readAll();
    expect(content, contains('framework boom'));
    expect(content, contains('platform boom'));
  });

  test(
    'records logged before the sink is ready are flushed in order',
    () async {
      final logDirGate = Completer<Directory>();
      final sinkReady = Completer<LogFileSink>();

      final running = runAppWithLogging(
        () {},
        logDir: () => logDirGate.future,
        onSinkReady: sinkReady.complete,
      );
      Logger('early')
        ..info('first early')
        ..severe('second early');
      expect(sinkReady.isCompleted, isFalse);
      expect(bufferedRecordCount, 2);

      logDirGate.complete(dir);
      await running;
      final content = await (await sinkReady.future).readAll();
      expect(bufferedRecordCount, 0);
      expect(content.indexOf('first early'), greaterThanOrEqualTo(0));
      expect(
        content.indexOf('second early'),
        greaterThan(content.indexOf('first early')),
      );
    },
  );

  test(
    'an error thrown at the start of body is kept once the sink is ready',
    () async {
      final logDirGate = Completer<Directory>();
      final sinkReady = Completer<LogFileSink>();

      final running = runAppWithLogging(
        () => throw StateError('start-up boom'),
        logDir: () => logDirGate.future,
        onSinkReady: sinkReady.complete,
      );
      expect(sinkReady.isCompleted, isFalse);
      expect(bufferedRecordCount, 1);

      logDirGate.complete(dir);
      await running;
      final content = await (await sinkReady.future).readAll();
      expect(content, contains('SEVERE crash'));
      expect(content, contains('start-up boom'));
    },
  );

  test('a logDir that never completes does not block body', () async {
    var bodyRan = false;
    await runAppWithLogging(
      () => bodyRan = true,
      logDir: () => Completer<Directory>().future,
      logDirTimeout: const Duration(milliseconds: 20),
    );
    expect(bodyRan, isTrue);
    Logger('late').info('after timeout');
    expect(bufferedRecordCount, 0);
  });

  test('after logDir fails nothing is buffered and body still runs', () async {
    final sinkReady = Completer<LogFileSink>();
    var bodyRan = false;
    final running = runAppWithLogging(
      () => bodyRan = true,
      logDir: () async => throw const FileSystemException('no dir'),
      onSinkReady: sinkReady.complete,
    );
    expect(bodyRan, isTrue);
    await running;
    Logger('late').severe('after failure');
    expect(bufferedRecordCount, 0);
    expect(sinkReady.isCompleted, isFalse);
  });

  test('a throwing onSinkReady does not disable logging', () async {
    LogFileSink? sink;
    await runAppWithLogging(
      () {},
      logDir: () async => dir,
      onSinkReady: (ready) {
        sink = ready;
        throw StateError('callback');
      },
    );
    Logger('after').info('still logged');
    expect(bufferedRecordCount, 0);
    expect(await sink!.readAll(), contains('still logged'));
  });
}
