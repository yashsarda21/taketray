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

  setUp(() {
    dir = Directory.systemTemp.createTempSync('taketray_setup_test');
    originalFlutterOnError = FlutterError.onError;
    originalPlatformOnError = PlatformDispatcher.instance.onError;
  });

  tearDown(() async {
    await disposeLogging();
    FlutterError.onError = originalFlutterOnError;
    PlatformDispatcher.instance.onError = originalPlatformOnError;
    Logger.root.level = Level.INFO;
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  test('formatRecord renders time, level, logger and message', () {
    final record = LogRecord(Level.WARNING, 'something happened', 'scan');
    final line = formatRecord(record);
    final time = record.time.toUtc().toIso8601String();
    expect(line, '$time WARNING scan: something happened');
    expect(line, matches(RegExp(r'^\d{4}-\d\d-\d\dT[\d:.]+Z WARNING scan: ')));
  });

  test('formatRecord appends error and stack when present', () {
    final line = formatRecord(
      LogRecord(
        Level.SEVERE,
        'failed',
        'crash',
        StateError('boom'),
        StackTrace.fromString('frame1\nframe2'),
      ),
    );
    expect(line, contains(' SEVERE crash: failed\n  error: Bad state: boom\n'));
    expect(line, contains('  stack: frame1'));
    expect(line, contains('frame2'));
  });

  test('an uncaught async error ends up in the log as SEVERE crash', () async {
    final crashLogged = Completer<void>();
    final sinkReady = Completer<LogFileSink>();

    await runAppWithLogging(
      () {
        late StreamSubscription<LogRecord> sub;
        sub = Logger.root.onRecord.where((r) => r.loggerName == 'crash').listen(
          (_) {
            unawaited(sub.cancel());
            crashLogged.complete();
          },
        );
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
    Logger.root.onRecord.listen((r) => seen.add(r.loggerName));

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

  test('errors logged before the sink is ready are flushed in order', () async {
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

    logDirGate.complete(dir);
    await running;
    final content = await (await sinkReady.future).readAll();
    expect(content.indexOf('first early'), greaterThanOrEqualTo(0));
    expect(
      content.indexOf('second early'),
      greaterThan(content.indexOf('first early')),
    );
  });
}
