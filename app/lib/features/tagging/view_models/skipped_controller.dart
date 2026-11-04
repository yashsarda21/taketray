import 'dart:async';

import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/core/guarded.dart';
import 'package:taketray/data/media/clip_time.dart';
import 'package:taketray/data/media/media_verifier.dart';
import 'package:taketray/data/repositories/clips_repository.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/domain/models/undo_record.dart';
import 'package:taketray/domain/rules/skipped_days.dart';

part 'skipped_controller.g.dart';

// Error types only, never a message (D-10).
final Logger _log = Logger('skipped');

/// The clips in Skipped, **newest first** (D-99).
///
/// The state is the database's own list (`watchInbox(skipped)`, reversed), so
/// it shows at once and follows every change: a restore, a clip tagged
/// elsewhere, a verify that removes a clip whose video is gone.
///
/// Each time the state is built (the screen opens it) it also checks, once,
/// that the skipped clips still exist (D-72): a clip that is only in Skipped
/// and whose video is gone leaves the list. The check never blocks the list
/// and cannot fail it; an error is logged by type and the list stays as the
/// database has it. It runs on the shared media queue, so it never overlaps a
/// scan. (Unlike To tag it does not scan: a scan adds to To tag, and this
/// screen has nothing to do with new videos.)
@Riverpod(retry: noRetry)
class SkippedController extends _$SkippedController {
  @override
  Stream<List<Clip>> build() {
    final clips = ref.watch(clipsRepositoryProvider);
    unawaited(_verify());
    return clips
        .watchInbox(InboxState.skipped)
        .map((oldestFirst) => oldestFirst.reversed.toList(growable: false));
  }

  /// **Try again** on the error state: reads the list again, and verifies
  /// again, as opening the screen does.
  void retry() => ref.invalidateSelf();

  /// Moves [clipIds] back to To tag in one transaction (D-94). Returns what
  /// the snack's **Undo** needs: the rows that really moved (a clip that is
  /// no longer skipped is left alone; none moved is an empty record).
  ///
  /// The repository is read when this is called, not after the write, so the
  /// write and its record outlive a screen that closes meanwhile.
  Future<InboxUndo> restore(Iterable<int> clipIds) =>
      ref.read(clipsRepositoryProvider).restoreClips(clipIds);

  /// The reads of `ref` are inside the guarded step: after the provider was
  /// disposed (the screen closed at once) `ref.read` throws, and that must
  /// be logged like any other error, not leak out of an unawaited call.
  Future<void> _verify() async {
    await guarded(_log, 'The verify', () async {
      final clips = ref.read(clipsRepositoryProvider);
      final verifier = ref.read(mediaVerifierProvider);
      final skipped = await clips.watchInbox(InboxState.skipped).first;
      return await verifier.verify(skipped);
    });
  }
}

/// The time where each skipped clip was shot, by clip id (D-83): the day
/// headers and the tiles' times. Follows the list; the service's cache
/// answers the clips it has seen. A clip missing from the map (a list that
/// arrived while its times are still being read) uses the phone's time.
@riverpod
Future<Map<int, ClipLocalTime>> skippedTimes(Ref ref) async {
  final service = ref.watch(clipTimeServiceProvider);
  final clips = await ref.watch(skippedControllerProvider.future);
  return await service.localTimes(clips);
}

/// The skipped clips cut into days, newest day first (`groupIntoDays`): null
/// until the list has been read (loading, or it could not be). Like To tag's
/// scenes it **never waits for the times**: a clip whose time is not known
/// yet uses the phone's, and the days regroup in place when the answer
/// arrives.
@riverpod
List<SkippedDay>? skippedDays(Ref ref) {
  final clips = ref.watch(skippedControllerProvider).value;
  if (clips == null) return null;
  final times = ref.watch(skippedTimesProvider).value ?? const {};
  return groupIntoDays(clips, times);
}
