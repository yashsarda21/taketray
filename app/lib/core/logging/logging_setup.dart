import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:taketray/core/logging/log_file_sink.dart';

/// Upper bound on records held in memory while the log directory resolves.
const _maxEarlyRecords = 200;

StreamSubscription<LogRecord>? _subscription;

/// One log line: `2026-10-24T09:12:03.120Z LEVEL logger: message`, followed by
/// indented `error:` and `stack:` lines when the record carries them.
String formatRecord(LogRecord r) {
  final buffer = StringBuffer(
    '${r.time.toUtc().toIso8601String()} ${r.level.name} ${r.loggerName}: '
    '${r.message}',
  );
  if (r.error != null) buffer.write('\n  error: ${r.error}');
  if (r.stackTrace != null) {
    final stack = r.stackTrace.toString().trimRight().replaceAll(
      '\n',
      '\n    ',
    );
    buffer.write('\n  stack: $stack');
  }
  return buffer.toString();
}

/// Runs [body] with the local error log wired up.
///
/// Records and uncaught errors (Flutter framework, platform dispatcher and the
/// guarded zone) go to a rotating file sink in the directory from [logDir].
/// Everything logged before that directory is known is buffered and flushed
/// in order once the sink exists. Nothing leaves the device.
///
/// [onSinkReady] is called with the sink as soon as it exists (tests use it to
/// read the log back).
Future<void> runAppWithLogging(
  FutureOr<void> Function() body, {
  required Future<Directory> Function() logDir,
  void Function(LogFileSink sink)? onSinkReady,
}) async {
  Logger.root.level = Level.INFO;

  LogFileSink? sink;
  final early = <String>[];
  unawaited(_subscription?.cancel());
  _subscription = Logger.root.onRecord.listen((record) {
    final line = formatRecord(record);
    final live = sink;
    if (live != null) {
      unawaited(_safeWrite(live, line));
    } else if (early.length < _maxEarlyRecords) {
      early.add(line);
    }
  });

  final crash = Logger('crash');
  FlutterError.onError = (details) {
    crash.severe(details.exceptionAsString(), details.exception, details.stack);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    crash.severe('Uncaught platform error', error, stack);
    return true;
  };

  try {
    final ready = LogFileSink(await logDir());
    // Flush synchronously after the await so no record can slip between the
    // buffer and the live path.
    for (final line in early) {
      unawaited(_safeWrite(ready, line));
    }
    early.clear();
    sink = ready;
    onSinkReady?.call(ready);
  } on Object catch (error) {
    // No place to write: keep running; records are dropped, not fatal.
    early.clear();
    debugPrint('Local error log unavailable: ${error.runtimeType}');
  }

  runZonedGuarded(body, (error, stack) {
    crash.severe('Uncaught zone error', error, stack);
  });
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
