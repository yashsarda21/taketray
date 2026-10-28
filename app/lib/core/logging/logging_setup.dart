import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart'
    show
        CouldNotRollBackException,
        DriftWrappedException,
        InvalidDataException,
        VerificationMeta;
import 'package:drift/isolate.dart' show DriftRemoteException;
import 'package:drift/native.dart' show SqliteException;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:taketray/core/logging/log_file_sink.dart';

/// Upper bound on records held in memory while the log directory resolves.
const int _maxEarlyRecords = 200;

/// Upper bound on one formatted record, in UTF-8 bytes.
const int _maxRecordBytes = 8 * 1024;

const String _truncationMarker = '…[truncated]';

const String _redacted = '<path>';

// Order matters: quoted values first (they may contain spaces), then URIs,
// Windows paths and finally absolute POSIX paths with at least two slashes.
final RegExp _quotedPath = RegExp(
  r'''(['"])(?:/|[A-Za-z][A-Za-z0-9+.\-]*://)[^'"]*\1''',
);
final RegExp _uri = RegExp(r'[A-Za-z][A-Za-z0-9+.\-]*://\S+');
final RegExp _windowsPath = RegExp(r'[A-Za-z]:\\\S+');
final RegExp _absolutePath = RegExp(r'(?<![\w/:.])/[^\s/]+(?:/[^\s]*)+');

final RegExp _trailingReplacement = RegExp(r'\uFFFD+$');

String _redact(String text) => text
    .replaceAll(_quotedPath, _redacted)
    .replaceAll(_uri, _redacted)
    .replaceAll(_windowsPath, _redacted)
    .replaceAll(_absolutePath, _redacted);

/// Where `SqliteException.toString()` starts printing the SQL statement and
/// every value bound to it: reel names, labels, links, file names.
const String _statementMarker = 'Causing statement';

/// [text] without a SQLite statement and its values, and everything after
/// them (a value may span lines), for error text that embeds a
/// `SqliteException` some other way.
String _withoutStatement(String text) {
  final at = text.indexOf(_statementMarker);
  if (at < 0) return text;
  return '${text.substring(0, at).trimRight()} <statement removed>';
}

/// [error] as one log line: its type and what went wrong, never a path or a
/// value the user typed (D-10).
///
/// Database errors are rebuilt from their fields instead of `toString()`,
/// which prints the failing statement with its values (`SqliteException`) or
/// the whole row (`InvalidDataException`). SQLite's own message names only
/// tables and columns.
String _describeError(Object? error) => switch (error) {
  FileSystemException() => _describeFileError(error),
  SqliteException(:final extendedResultCode, :final message) =>
    'SqliteException($extendedResultCode): ${_redact(message)}',
  // The phone's database runs on a background isolate, so its errors arrive
  // wrapped; the cause is the `SqliteException` (or, when drift had to
  // serialise it, its text).
  DriftRemoteException(:final remoteCause) => _describeError(remoteCause),
  // Its message prints the whole row; the failing columns are enough.
  InvalidDataException(:final errors) =>
    'InvalidDataException(${errors.keys.map(_column).join(', ')})',
  CouldNotRollBackException(:final exception, :final cause) =>
    'CouldNotRollBackException: ${_describeError(exception)}; '
        'rolled back because of ${_describeError(cause)}',
  DriftWrappedException(:final cause, :final message) =>
    'DriftWrappedException: ${_describeError(cause)} (${_redact(message)})',
  _ => _redact(_withoutStatement(error.toString())),
};

String _column(VerificationMeta meta) => meta.dartGetterName;

/// Never prints `path`: it is a video or folder location.
String _describeFileError(FileSystemException error) {
  final os = error.osError;
  final osText = os == null
      ? ''
      : ' (OS error: ${_redact(os.message)}, errno = ${os.errorCode})';
  return '${error.runtimeType}: ${_redact(error.message)}$osText';
}

String _truncate(String text) {
  final bytes = utf8.encode(text);
  if (bytes.length <= _maxRecordBytes) return text;
  final cut = utf8
      .decode(bytes.sublist(0, _maxRecordBytes), allowMalformed: true)
      .replaceFirst(_trailingReplacement, '');
  return '$cut$_truncationMarker';
}

/// One log line: `2026-10-24T09:12:03.120Z LEVEL logger: message`, followed by
/// indented `error:` and `stack:` lines when the record carries them.
///
/// Path-like and URI-like tokens in the message and error text are replaced
/// with `<path>`, and a `FileSystemException` is rendered without its path, so
/// video names and locations never reach the log (D-10). Database errors are
/// rendered by their result code and SQLite's message, without the statement
/// and the values bound to it, and any other text that embeds a statement
/// loses it (`<statement removed>`). Stack traces are kept as they are. A
/// record longer than 8 KiB is truncated.
String formatRecord(LogRecord r) {
  final buffer = StringBuffer(
    '${r.time.toUtc().toIso8601String()} ${r.level.name} ${r.loggerName}: '
    '${_redact(_withoutStatement(r.message))}',
  );
  final error = r.error;
  if (error != null) buffer.write('\n  error: ${_describeError(error)}');
  if (r.stackTrace != null) {
    final stack = r.stackTrace.toString().trimRight().replaceAll(
      '\n',
      '\n    ',
    );
    buffer.write('\n  stack: $stack');
  }
  return _truncate(buffer.toString());
}

const String _unprintableError = '<unprintable error>';

/// [formatRecord], for the log listener, which must never throw: it runs
/// inside `Logger.log`, so a throw would come out of the caller's own log
/// call (or out of the app's error handler).
///
/// An error whose `toString` throws is written as `<unprintable error>`; the
/// message is kept. The stack is dropped in that case, because it may be
/// unprintable too.
String _formatRecordSafely(LogRecord record) {
  try {
    return formatRecord(record);
  } on Object {
    // Only the error and the stack are printed by user-supplied code; the
    // message is a String.
    return formatRecord(
      LogRecord(
        record.level,
        record.message,
        record.loggerName,
        record.error == null ? null : _unprintableError,
      ),
    );
  }
}

/// Message object of framework error records; its `toString` is the logged
/// message, its identity tells the console echo to skip the record.
const _FrameworkErrorTag _frameworkErrorTag = _FrameworkErrorTag();

class _FrameworkErrorTag {
  const new();

  @override
  String toString() => 'Flutter framework error';
}

/// Where records go: a buffer until the sink exists, then the sink, or
/// nowhere once logging has been disabled.
class _LogState {
  LogFileSink? sink;
  bool disabled = false;
  final List<String> early = [];
}

_LogState _state = _LogState();
StreamSubscription<LogRecord>? _subscription;

/// Number of records held in memory waiting for the sink. For tests.
@visibleForTesting
int get bufferedRecordCount => _state.early.length;

/// Runs [body] with the local error log wired up.
///
/// The log hooks (`Logger.root.onRecord`, `FlutterError.onError`,
/// `PlatformDispatcher.onError`) are installed first, then [body] runs
/// immediately inside a guarded zone (after `WidgetsFlutterBinding`
/// initialisation in that same zone, so `runApp` inside [body] matches it).
/// Meanwhile [logDir] is resolved concurrently, waiting at most
/// [logDirTimeout].
/// Records and uncaught errors produced in the meantime, including start-up
/// errors thrown by [body], are buffered in memory (200 records at most) and
/// written in order once the sink exists. If [logDir] throws or times out,
/// logging is disabled: the buffer is dropped, nothing more is buffered and the
/// app carries on. Nothing leaves the device.
///
/// In debug builds every formatted record is also printed with `debugPrint`
/// (framework errors once, through `FlutterError.presentError`); release
/// builds print nothing.
///
/// The returned future completes once the sink is ready or logging has been
/// disabled; do not wait for it before starting the app.
///
/// [onSinkReady] receives the live sink as soon as it exists. Phase 10's
/// Settings "share log" action uses it to keep a handle for
/// [LogFileSink.exportFile]; tests use it to read the log back.
Future<void> runAppWithLogging(
  FutureOr<void> Function() body, {
  required Future<Directory> Function() logDir,
  void Function(LogFileSink sink)? onSinkReady,
  Duration logDirTimeout = const Duration(seconds: 5),
}) async {
  Logger.root.level = Level.INFO;

  final state = _state = _LogState();
  unawaited(_subscription?.cancel());
  _subscription = Logger.root.onRecord.listen((record) {
    final line = _formatRecordSafely(record);
    // Debug builds also show every record on the console (uncaught async
    // errors would otherwise only reach the device file). Framework errors
    // are skipped: `presentError` below already printed them. Release builds
    // print nothing.
    if (kDebugMode && !identical(record.object, _frameworkErrorTag)) {
      debugPrint(line);
    }
    final live = state.sink;
    if (live != null) {
      unawaited(_safeWrite(live, line));
    } else if (!state.disabled && state.early.length < _maxEarlyRecords) {
      state.early.add(line);
    }
  });

  final crash = Logger('crash');
  FlutterError.onError = (details) {
    if (kDebugMode) FlutterError.presentError(details);
    crash.severe(_frameworkErrorTag, details.exception, details.stack);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    crash.severe('Uncaught platform error', error, stack);
    return true;
  };

  final settled = Completer<void>();
  // The zone handler logs; the returned future is only `settled`.
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    unawaited(
      _attachSink(
        state,
        logDir,
        logDirTimeout,
        onSinkReady,
      ).whenComplete(settled.complete),
    );
    return body();
  }, (error, stack) => crash.severe('Uncaught zone error', error, stack));
  await settled.future;
}

Future<void> _attachSink(
  _LogState state,
  Future<Directory> Function() logDir,
  Duration timeout,
  void Function(LogFileSink sink)? onSinkReady,
) async {
  final LogFileSink sink;
  try {
    sink = LogFileSink(await logDir().timeout(timeout));
  } on Object catch (error) {
    state
      ..disabled = true
      ..early.clear();
    debugPrint('Local error log unavailable: ${error.runtimeType}');
    return;
  }
  // No await between the flush and publishing the sink, so no record can slip
  // between the buffer and the live path.
  for (final line in state.early) {
    unawaited(_safeWrite(sink, line));
  }
  state
    ..early.clear()
    ..sink = sink;
  try {
    onSinkReady?.call(sink);
  } on Object catch (error) {
    debugPrint('Log sink callback failed: ${error.runtimeType}');
  }
}

Future<void> _safeWrite(LogFileSink sink, String line) async {
  try {
    await sink.write(line);
  } on Object catch (error) {
    debugPrint('Local error log write failed: ${error.runtimeType}');
  }
}

/// Stops forwarding log records to the sink. For tests.
@visibleForTesting
Future<void> disposeLogging() async {
  await _subscription?.cancel();
  _subscription = null;
}
