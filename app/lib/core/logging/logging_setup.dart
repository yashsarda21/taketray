import 'dart:async';
import 'dart:convert';
import 'dart:io';

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

String _describeError(Object error) {
  if (error is FileSystemException) {
    // Never print `path`: it is a video or folder location (D-10).
    final os = error.osError;
    final osText = os == null
        ? ''
        : ' (OS error: ${_redact(os.message)}, errno = ${os.errorCode})';
    return '${error.runtimeType}: ${_redact(error.message)}$osText';
  }
  return _redact(error.toString());
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
/// video names and locations never reach the log (D-10). Stack traces are kept
/// as they are. A record longer than 8 KiB is truncated.
String formatRecord(LogRecord r) {
  final buffer = StringBuffer(
    '${r.time.toUtc().toIso8601String()} ${r.level.name} ${r.loggerName}: '
    '${_redact(r.message)}',
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
    final live = state.sink;
    if (live != null) {
      unawaited(_safeWrite(live, formatRecord(record)));
    } else if (!state.disabled && state.early.length < _maxEarlyRecords) {
      state.early.add(formatRecord(record));
    }
  });

  final crash = Logger('crash');
  FlutterError.onError = (details) {
    if (kDebugMode) FlutterError.presentError(details);
    crash.severe('Flutter framework error', details.exception, details.stack);
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
