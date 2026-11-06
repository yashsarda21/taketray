import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:taketray/core/guarded.dart';
import 'package:taketray/data/background/background_sync.dart';
import 'package:taketray/data/media/media_scanner.dart';
import 'package:taketray/data/media/thumbnail_cache.dart';
import 'package:taketray/data/media/zone_sync.dart';
import 'package:taketray/features/media_access/view_models/media_access_controller.dart';
import 'package:taketray/features/notifications/view_models/notification_access_controller.dart';
import 'package:taketray/platform/background_bridge.dart';

// Error types only, never a message, a path or a name (D-10).
final Logger _log = Logger('mediaLifecycle');

/// Starts the media work when the app starts and when it comes back to the
/// front (D-75). It sits in `TakeTrayApp` above the router and shows its
/// [child] unchanged.
///
/// On the first frame, and on every resume, in this order:
/// 1. `ZoneSync.sync`: the time zone changes the phone saw meanwhile. The
///    scan (and Add earlier videos) syncs again inside its own queued job,
///    right before it reads the timeline, so it never depends on this step
///    having finished; a second sync changes nothing that is stored. This one
///    stays because with Shooting mode off the scan does nothing, and the
///    timeline must still learn the zone;
/// 2. `MediaAccessController.refresh`: the access may have changed in the
///    phone's settings;
/// 3. `NotificationAccessController.refresh`: the notification permission
///    may have changed in the phone's settings too (D-107);
/// 4. `MediaScanner.scan`: new videos, when Shooting mode is on. A Still
///    shooting? button tapped in the shade needs no step of its own: every
///    scan applies it first, inside its own job (D-106);
/// 5. after a scan that read every volume (`ScanDone` with no failed volume;
///    an end from the shade counts), `BackgroundSync.flush` and then
///    `BackgroundBridge.clearNewClipsNotification` (D-106): the clips are in
///    To tag now. The new baselines reach the phone's copy first, so the
///    new-clips job never counts again with the old ones and re-posts.
///
/// Each step runs even if the one before it failed. Nothing is waited for by
/// the UI, and no error reaches it: every step is guarded and logs only the
/// error's type. The first frame also prunes the thumbnail cache, once per
/// app start (once per mount of this widget; not on resume).
///
/// Runs never overlap. A trigger that comes while a run is going (a resume
/// during the start) costs exactly one more run after it, however many
/// arrive; the scanner's own coalescing and the media queue (D-72) hold on
/// top of that.
class MediaLifecycle extends ConsumerStatefulWidget {
  const MediaLifecycle({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<MediaLifecycle> createState() => _MediaLifecycleState();
}

class _MediaLifecycleState extends ConsumerState<MediaLifecycle> {
  late final AppLifecycleListener _listener;
  bool _running = false;
  bool _again = false;

  @override
  void initState() {
    super.initState();
    _listener = AppLifecycleListener(onResume: _trigger);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_prune());
      _trigger();
    });
  }

  @override
  void dispose() {
    _listener.dispose();
    super.dispose();
  }

  /// Starts a run, or asks the run that is going for one more.
  void _trigger() {
    if (_running) {
      _again = true;
      return;
    }
    unawaited(_runLoop());
  }

  Future<void> _runLoop() async {
    _running = true;
    try {
      do {
        _again = false;
        await _run();
      } while (_again && mounted);
    } finally {
      _running = false;
    }
  }

  Future<void> _run() async {
    await guarded(
      _log,
      'The zone sync',
      () => ref.read(zoneSyncProvider).sync(),
    );
    await guarded(
      _log,
      'The access check',
      () => ref.read(mediaAccessControllerProvider.notifier).refresh(),
    );
    await guarded(
      _log,
      'The notification permission check',
      () => ref.read(notificationAccessControllerProvider.notifier).refresh(),
    );
    final scanned = await guarded(
      _log,
      'The scan',
      () => ref.read(mediaScannerProvider).scan(),
    );
    // A volume that failed may still hold clips the job counts.
    if (scanned is! ScanDone || scanned.failedVolumes.isNotEmpty || !mounted) {
      return;
    }
    await guarded(
      _log,
      'Writing the background copy',
      () => ref.read(backgroundSyncProvider).flush(),
    );
    if (!mounted) return;
    await guarded(
      _log,
      'Clearing the new clips notification',
      () => ref.read(backgroundBridgeProvider).clearNewClipsNotification(),
    );
  }

  Future<void> _prune() => guarded(_log, 'Pruning the thumbnails', () async {
    final cache = await ref.read(thumbnailCacheProvider.future);
    await cache.prune();
  });

  @override
  Widget build(BuildContext context) => widget.child;
}
