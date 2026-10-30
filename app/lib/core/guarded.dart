import 'package:logging/logging.dart';

/// Runs [job] and returns its result; when it throws anything, logs one line
/// on [log] and returns null.
///
/// Only the error's type is logged, never its message or stack trace: a
/// message from the media library, the file system or the database may hold a
/// path, a file name or a URI (D-10). [what] names the step, without data.
///
/// For work that must never reach the UI as an uncaught error: the media
/// triggers on app start, resume and opening To tag (D-75). An [Error] is
/// caught too (a bug in a step must not stop the steps after it).
Future<T?> guarded<T>(Logger log, String what, Future<T> Function() job) async {
  try {
    return await job();
  } on Object catch (error) {
    log.warning('$what failed: ${error.runtimeType}');
    return null;
  }
}

/// A Riverpod `retry` that never retries. Riverpod 3 retries a provider whose
/// build threw, with a growing delay; the view models that read the media
/// library show the error instead (the next open of the screen tries again).
Duration? noRetry(int retryCount, Object error) => null;
