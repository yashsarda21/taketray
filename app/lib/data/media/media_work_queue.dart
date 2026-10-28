import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'media_work_queue.g.dart';

/// Runs the jobs that read the media library and write what they found, one
/// at a time, in the order they were queued (D-72).
///
/// The scan, "Add earlier videos" (counting and adding) and the verifier all
/// go through the one queue from [mediaWorkQueueProvider]. Run side by side,
/// they could undo each other: a verify that read a clip's old MediaStore
/// number while a scan was remapping it after a rebuild would detach a clip
/// that had just been found again; an "Add earlier videos" next to a scan
/// could count a video the scan was adding.
///
/// A job that throws fails only its own [run] future; the jobs after it
/// still run.
class MediaWorkQueue {
  Future<void> _tail = Future<void>.value();

  /// Runs [job] after every job queued before it has finished (or failed),
  /// and completes with its result or its error.
  Future<T> run<T>(Future<T> Function() job) {
    final result = _tail.then((_) => job());
    // The next job waits for this one, whatever its outcome; the error itself
    // reaches only the caller, through `result`.
    _tail = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }
}

/// The one queue every media job shares. Kept alive: a second queue would
/// let jobs overlap.
@Riverpod(keepAlive: true)
MediaWorkQueue mediaWorkQueue(Ref ref) => MediaWorkQueue();
