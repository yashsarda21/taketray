import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:taketray/core/guarded.dart';
import 'package:taketray/data/media/media_scanner.dart';
import 'package:taketray/data/media/thumbnail_cache.dart';
import 'package:taketray/data/media/zone_sync.dart';
import 'package:taketray/features/media_access/view_models/media_access_controller.dart';

// Error types only, never a message, a path or a name (D-10).
final Logger _log = Logger('mediaLifecycle');

/// Starts the media work when the app starts and when it comes back to the
/// front (D-75). It sits in `TakeTrayApp` above the router and shows its
/// [child] unchanged.
///
/// On the first frame, and on every resume, in this order:
/// 1. `ZoneSync.sync`: the time zone changes the phone saw meanwhile;
/// 2. `MediaAccessController.refresh`: the access may have changed in the
///    phone's settings;
/// 3. `MediaScanner.scan`: new videos, when Shooting mode is on.
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
      'The scan',
      () => ref.read(mediaScannerProvider).scan(),
    );
  }

  Future<void> _prune() => guarded(_log, 'Pruning the thumbnails', () async {
    final cache = await ref.read(thumbnailCacheProvider.future);
    await cache.prune();
  });

  @override
  Widget build(BuildContext context) => widget.child;
}
