import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'copy_screens.g.dart';

/// The copy jobs that have a progress screen open right now, so the app does
/// not open a second one when it comes to the front (D-127). A screen adds
/// its job id when it is built and removes it when it goes. Nothing watches
/// it: it is a plain set, not state.
class OpenCopyScreens {
  final Map<String, int> _counts = {};

  /// Notes one more screen for [jobId].
  void add(String jobId) => _counts[jobId] = (_counts[jobId] ?? 0) + 1;

  /// Notes that one screen for [jobId] is gone.
  void remove(String jobId) {
    final left = (_counts[jobId] ?? 0) - 1;
    if (left <= 0) {
      _counts.remove(jobId);
    } else {
      _counts[jobId] = left;
    }
  }

  /// Whether a progress screen for [jobId] is open.
  bool isOpen(String jobId) => _counts.containsKey(jobId);
}

@Riverpod(keepAlive: true)
OpenCopyScreens openCopyScreens(Ref ref) => OpenCopyScreens();
