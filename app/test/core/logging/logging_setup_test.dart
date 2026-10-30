import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:drift/drift.dart'
    show
        CouldNotRollBackException,
        DriftWrappedException,
        InvalidDataException,
        Value,
        driftRuntimeOptions;
import 'package:drift/isolate.dart' show DriftRemoteException;
import 'package:drift/native.dart' show NativeDatabase, SqliteException;
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:taketray/core/logging/log_file_sink.dart';
import 'package:taketray/core/logging/logging_setup.dart';
import 'package:taketray/data/database/app_database.dart';
import 'package:taketray/data/repositories/reels_repository.dart';

import '../../support/fixed_clock.dart';

/// Text a database error may carry that must never reach the log (D-10).
const List<String> _secrets = ['Secret', 'instagram', 'INSERT', 'parameters'];

/// [error] as `formatRecord` writes it.
String _logged(Object error) =>
    formatRecord(LogRecord(Level.SEVERE, 'x', 'crash', error));

/// A SQLite error like a full phone, with the statement and values SQLite's
/// own `toString()` prints.
SqliteException _diskFull() => SqliteException(
  extendedResultCode: 13,
  message: 'database or disk is full',
  causingStatement: 'INSERT INTO "reels" ("name", "description") VALUES (?, ?)',
  parametersToStatement: ['Secret Goa', 'https://instagram.com/x'],
);

/// Inserts a reel named "Secret Goa" into [db] after a trigger that refuses
/// every reel, and returns what the insert threw.
Future<Object> _failedInsert(AppDatabase db) async {
  await db.customStatement(
    'CREATE TRIGGER refuse_reels BEFORE INSERT ON reels '
    "BEGIN SELECT RAISE(ABORT, 'refused'); END",
  );
  try {
    await ReelsRepository(
      db,
      FixedClock(DateTime.utc(2026, 10, 27)),
    ).create('Secret Goa', description: 'https://instagram.com/reel/x');
  } on Object catch (e) {
    return e;
  }
  fail('the insert was not refused');
}

void _expectNoSecrets(String line) {
  for (final secret in _secrets) {
    expect(line, isNot(contains(secret)), reason: line);
  }
}

void main() {
  late Directory dir;
  late FlutterExceptionHandler? originalFlutterOnError;
  late ErrorCallback? originalPlatformOnError;
  late bool originalDontWarn;
  final subscriptions = <StreamSubscription<LogRecord>>[];

  StreamSubscription<LogRecord> listen(void Function(LogRecord) onData) {
    final sub = Logger.root.onRecord.listen(onData);
    subscriptions.add(sub);
    return sub;
  }

  setUp(() {
    dir = Directory.systemTemp.createTempSync('taketray_setup_test');
    originalDontWarn = driftRuntimeOptions.dontWarnAboutMultipleDatabases;
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
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = originalDontWarn;
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

  group('database errors never carry user text (D-10)', () {
    test('renders a SqliteException without its statement or values', () {
      final line = _logged(_diskFull());

      expect(line, contains('error: SqliteException(13): database or disk'));
      _expectNoSecrets(line);
    });

    test('renders a DriftRemoteException by its SqliteException', () async {
      // The phone runs the database on a background isolate, so its errors
      // arrive wrapped (drift_flutter); the wrapper's text is the cause's.
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      final db = AppDatabase(
        NativeDatabase.createInBackground(File('${dir.path}/t.sqlite')),
      );
      addTearDown(db.close);

      final error = await _failedInsert(db);

      expect(error, isA<DriftRemoteException>());
      expect('$error', contains('Secret Goa'), reason: 'what the fix hides');
      final line = _logged(error);
      expect(line, contains('error: SqliteException(1811): refused'));
      _expectNoSecrets(line);
    });

    test('renders a real failed insert without its values', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      final error = await _failedInsert(db);

      expect(error, isA<SqliteException>());
      expect('$error', contains('Secret Goa'), reason: 'what the fix hides');
      final line = _logged(error);
      expect(line, contains('error: SqliteException(1811): refused'));
      _expectNoSecrets(line);
    });

    test('renders an InvalidDataException by its columns only', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      Object? error;
      try {
        // No name: drift refuses the row before SQLite sees it, and its
        // message prints the whole row.
        await db
            .into(db.reels)
            .insert(const ReelsCompanion(description: Value('Secret Goa')));
      } on Object catch (e) {
        error = e;
      }

      expect(error, isA<InvalidDataException>());
      expect('$error', contains('Secret Goa'), reason: 'what the fix hides');
      final line = _logged(error!);
      expect(line, contains('error: InvalidDataException(name)'));
      _expectNoSecrets(line);
    });

    test('renders drift wrappers by their causes', () {
      final rollBack = _logged(
        CouldNotRollBackException(
          _diskFull(),
          StackTrace.empty,
          SqliteException(extendedResultCode: 10, message: 'disk I/O error'),
        ),
      );
      expect(
        rollBack,
        contains(
          'error: CouldNotRollBackException: SqliteException(10): disk I/O '
          'error; rolled back because of SqliteException(13): database or '
          'disk is full',
        ),
      );
      _expectNoSecrets(rollBack);

      final wrapped = _logged(
        DriftWrappedException(message: 'a hint', cause: _diskFull()),
      );
      expect(
        wrapped,
        contains(
          'error: DriftWrappedException: SqliteException(13): database or '
          'disk is full (a hint)',
        ),
      );
      _expectNoSecrets(wrapped);
    });

    test('cuts the statement out of any other text that carries it', () {
      final inError = _logged(StateError('save failed: ${_diskFull()}'));
      expect(inError, contains('save failed: SqliteException(13)'));
      expect(inError, contains('<statement removed>'));
      _expectNoSecrets(inError);

      final inMessage = formatRecord(
        LogRecord(Level.WARNING, 'save failed: ${_diskFull()}', 'reels'),
      );
      expect(inMessage, contains('reels: save failed: SqliteException(13)'));
      _expectNoSecrets(inMessage);
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

  group('debug console echo', () {
    late List<String> printed;
    late DebugPrintCallback originalDebugPrint;

    setUp(() {
      printed = [];
      originalDebugPrint = debugPrint;
      debugPrint = (message, {wrapWidth}) {
        if (message != null) printed.add(message);
      };
    });

    tearDown(() => debugPrint = originalDebugPrint);

    test('an uncaught zone error is printed with its stack', () async {
      final crashLogged = Completer<void>();
      await runAppWithLogging(() {
        late StreamSubscription<LogRecord> sub;
        sub = listen((r) {
          if (r.loggerName != 'crash') return;
          unawaited(sub.cancel());
          crashLogged.complete();
        });
        unawaited(Future<void>(() => throw StateError('zone boom')));
      }, logDir: () async => dir);
      await crashLogged.future;

      final line = printed.singleWhere((p) => p.contains('zone boom'));
      expect(line, contains('SEVERE crash: Uncaught zone error'));
      expect(line, contains('  stack: '));
    });

    test('a platform error is printed even when the log is disabled', () async {
      await runAppWithLogging(
        () {},
        logDir: () async => throw const FileSystemException('no dir'),
      );

      PlatformDispatcher.instance.onError!(
        StateError('platform boom'),
        StackTrace.fromString('frame-a'),
      );

      final line = printed.singleWhere((p) => p.contains('platform boom'));
      expect(line, contains('SEVERE crash: Uncaught platform error'));
      expect(line, contains('frame-a'));
    });

    test('a framework error is not printed twice', () async {
      await runAppWithLogging(() {}, logDir: () async => dir);
      final presented = <FlutterErrorDetails>[];
      final originalPresent = FlutterError.presentError;
      FlutterError.presentError = presented.add;
      addTearDown(() => FlutterError.presentError = originalPresent);

      FlutterError.onError!(
        FlutterErrorDetails(exception: StateError('framework boom')),
      );

      expect(presented, hasLength(1));
      expect(printed.where((p) => p.contains('framework boom')), isEmpty);
    });

    test('ordinary records are printed too', () async {
      await runAppWithLogging(() {}, logDir: () async => dir);

      Logger('router').warning('Unknown location; showing Reels');

      expect(
        printed,
        contains(endsWith('WARNING router: Unknown location; showing Reels')),
      );
    });
  });

  test('an error whose toString throws does not escape the listener', () async {
    final sinkReady = Completer<LogFileSink>();
    await runAppWithLogging(
      () {},
      logDir: () async => dir,
      onSinkReady: sinkReady.complete,
    );

    // `Logger.log` runs the listener synchronously, inside the logging
    // package's stream. A throw there does not reach this call: the zone gets
    // it as an uncaught error, which fails this test (and in the app goes to
    // the error handler, which logs again), and the line is lost.
    Logger('scan').severe('scan failed', _ThrowingToString());

    final content = await (await sinkReady.future).readAll();
    expect(content, contains('SEVERE scan: scan failed'));
    expect(content, contains('<unprintable error>'));
  });

  test('a stack trace whose toString throws still writes the line', () async {
    final sinkReady = Completer<LogFileSink>();
    await runAppWithLogging(
      () {},
      logDir: () async => dir,
      onSinkReady: sinkReady.complete,
    );

    Logger('scan').severe('scan failed', StateError('fine'), _ThrowingStack());

    final content = await (await sinkReady.future).readAll();
    expect(content, contains('SEVERE scan: scan failed'));
    // The error still prints; only the stack is dropped.
    expect(content, contains('error: Bad state: fine'));
    expect(content, isNot(contains('stack:')));
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

/// An error that cannot be printed, like a broken platform exception.
class _ThrowingToString {
  @override
  String toString() => throw StateError('toString broke');
}

/// A stack trace that cannot be printed.
class _ThrowingStack implements StackTrace {
  @override
  String toString() => throw StateError('stack toString broke');
}
