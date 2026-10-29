import 'dart:async';

import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/core/guarded.dart';
import 'package:taketray/data/media/media_scanner.dart';
import 'package:taketray/data/media/media_verifier.dart';
import 'package:taketray/data/repositories/clips_repository.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/models/enums.dart';

part 'to_tag_controller.g.dart';

// Error types only, never a message (D-10).
final Logger _log = Logger('toTag');

/// The clips waiting in To tag, oldest first (D-75).
///
/// The state is the database's own list (`watchInbox(pending)`), so it shows
/// at once and follows every change: a scan that adds clips, a verify that
/// removes the ones whose video is gone, a tag or a skip.
///
/// Each time the state is built (the screen opens it, or it is opened again
/// after being closed) it also scans for new videos and then checks the
/// waiting clips still exist, once; [onResume] does both again. Neither
/// blocks the list and neither can fail it: an error is logged by type and
/// the list stays as the database has it. The scan and the verify each run
/// even if the other failed. Both go through the shared media queue (D-72),
/// so three triggers at once cost one more scan.
@Riverpod(retry: noRetry)
class ToTagController extends _$ToTagController {
  @override
  Stream<List<Clip>> build() {
    final clips = ref.watch(clipsRepositoryProvider);
    unawaited(_refresh());
    return clips.watchInbox(InboxState.pending);
  }

  /// To tag came back to the front (the app resumed while it is open): scans
  /// and verifies again.
  Future<void> onResume() => _refresh();

  /// The reads of `ref` are inside the guarded steps: after the provider was
  /// disposed (the screen closed, then a late resume) `ref.read` throws, and
  /// that must be logged like any other error, not leak out of an unawaited
  /// call.
  Future<void> _refresh() async {
    await guarded(
      _log,
      'The scan',
      () => ref.read(mediaScannerProvider).scan(),
    );
    await guarded(_log, 'The verify', () async {
      final clips = ref.read(clipsRepositoryProvider);
      final verifier = ref.read(mediaVerifierProvider);
      final waiting = await clips.watchInbox(InboxState.pending).first;
      return await verifier.verify(waiting);
    });
  }
}
