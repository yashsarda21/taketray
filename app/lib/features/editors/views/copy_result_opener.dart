import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:taketray/features/editors/view_models/copy_job_controller.dart';
import 'package:taketray/features/editors/view_models/copy_screens.dart';
import 'package:taketray/platform/copy_bridge.dart';
import 'package:taketray/router/app_router.dart';
import 'package:taketray/router/routes.dart';

// Job ids and error types only (D-10).
final Logger _log = Logger('copyResultOpener');

/// Opens the copy screen for a copy job nobody is looking at (D-127), for as
/// long as the app lives. It sits above the navigator, in the app's
/// `builder`, next to `LaunchActionsListener`, and shows [child] unchanged.
///
/// - **A result that nobody has seen** (`CopyJobController.takeUnseenResult`:
///   once per job id and end state): Phone storage is full, TakeTray was
///   closed mid-copy (also the job `recoverAtStart` built after a restart),
///   a finished copy, or one with clips that could not be copied. It is
///   checked whenever the controller's job changes, so the result a recovery
///   finds a moment after the start opens at once, and when the app comes to
///   the front. If a progress screen for that job is open it is not opened
///   again.
/// - **A job that still runs** when the app starts or comes to the front
///   (the activity was re-created while the copy went on, so no screen is
///   left): its progress screen opens, once, and asks for the screen to stay
///   on. A job whose screen is open is left alone, and the engine's events
///   alone never open it (the copy screens start it themselves).
///
/// Each opening pushes the progress route over what is showing; the screen
/// takes it from there.
class CopyResultOpener extends ConsumerStatefulWidget {
  const new({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<CopyResultOpener> createState() => _CopyResultOpenerState();
}

class _CopyResultOpenerState extends ConsumerState<CopyResultOpener> {
  late final AppLifecycleListener _lifecycle;

  /// The running jobs a screen was opened for already.
  final Set<String> _openedRunning = {};

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: () => unawaited(_atFront()));
    ref.listenManual(copyJobControllerProvider, (_, _) => _check());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_atFront());
    });
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  /// The app is at the front (its start, or a resume): read the engine's job
  /// again (its events were dropped while nobody listened), then look.
  Future<void> _atFront() async {
    try {
      await ref.read(copyJobControllerProvider.notifier).onResume();
    } on Object catch (error) {
      _log.warning('Reading the copy job failed: ${error.runtimeType}');
    }
    if (mounted) _check(openRunning: true);
  }

  void _check({bool openRunning = false}) {
    if (!mounted) return;
    final job = ref.read(copyJobControllerProvider);
    if (job == null) return;
    final open = ref.read(openCopyScreensProvider);
    if (job.state == CopyState.running) {
      if (!openRunning || open.isOpen(job.jobId)) return;
      if (!_openedRunning.add(job.jobId)) return;
    } else {
      if (!ref.read(copyJobControllerProvider.notifier).takeUnseenResult()) {
        return;
      }
      if (open.isOpen(job.jobId)) return;
    }
    final location = Routes.copyProgressOf(job.jobId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(ref.read(appRouterProvider).push<void>(location));
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
