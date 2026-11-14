import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/core/guarded.dart';
import 'package:taketray/data/editors/edit_session_service.dart';
import 'package:taketray/data/media/clip_time.dart';
import 'package:taketray/data/media/media_verifier.dart';
import 'package:taketray/data/repositories/clips_repository.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/models/reel.dart';
import 'package:taketray/domain/models/reel_clip.dart';
import 'package:taketray/domain/models/undo_record.dart';
import 'package:taketray/domain/rules/shooting_days.dart';

part 'reel_detail_controller.g.dart';

// Ids, counts and error types only, never a reel name or a path (D-10).
final Logger _log = Logger('reelDetail');

/// What taking a missing clip out of a reel did: `record` is what Undo needs
/// (empty when nothing was removed) and `copiesDeleted` is how many of its
/// copies in the editing folder were deleted first (R8; 0 with no session).
typedef MissingRemoval = ({RemoveUndo record, int copiesDeleted});

/// What a reel's page shows (D-87).
@immutable
class ReelDetailState {
  const new({
    required this.reel,
    required this.days,
    required this.clipCount,
    required this.missingCount,
    required this.liveDurationMs,
    required this.times,
  });

  final Reel reel;

  /// The clips by the local day they were shot, earliest day first, each with
  /// its Day number (D-83). Empty for a reel with no clips.
  final List<ShootingDay<ReelClip>> days;

  /// Every clip of the reel, missing ones included.
  final int clipCount;

  /// How many of them are gone from the phone.
  final int missingCount;

  /// The length of the clips that are not missing, in milliseconds.
  final int liveDurationMs;

  /// The time where each clip was shot, by clip id (D-83). A clip that is not
  /// here yet shows the phone's time.
  final Map<int, ClipLocalTime> times;
}

/// Reel [reelId] now and after every change; null once it is gone.
@riverpod
Stream<Reel?> reelById(Ref ref, int reelId) =>
    ref.watch(reelsRepositoryProvider).watchById(reelId);

/// The clips of reel [reelId], oldest first, again after every change.
@riverpod
Stream<List<ReelClip>> reelClips(Ref ref, int reelId) =>
    ref.watch(clipsRepositoryProvider).watchReelClips(reelId);

/// The time where each clip of reel [reelId] was shot, by clip id (D-83).
///
/// It follows the reel's clips: each new list asks
/// `ClipTimeService.localTimes`, whose cache answers the clips it has seen,
/// so only new ones cost a bridge entry. The service never throws.
@riverpod
Future<Map<int, ClipLocalTime>> reelClipTimes(Ref ref, int reelId) async {
  final service = ref.watch(clipTimeServiceProvider);
  final clips = await ref.watch(reelClipsProvider(reelId).future);
  return await service.localTimes([for (final c in clips) c.clip]);
}

/// The page of one reel (D-87): the reel, its clips by shooting day, and the
/// counts of its header.
///
/// - **The state is the database's own** (`watchById`, `watchReelClips`), so
///   it shows at once and follows every change: a rename, a status change, a
///   clip added or removed, a verify that finds a video gone.
/// - **`null` once the reel is gone** (deleted here or elsewhere, or an id
///   that never existed); the screen then goes to Reels. While the first read
///   runs the state is loading.
/// - **The times never hold the clips back.** The days are grouped, and the
///   tiles drawn, with the phone's own time zone until
///   `ClipTimeService.localTimes` answers (`reelClipTimes`); then the state
///   is built again, regrouped by the day where each clip was shot, and
///   [ReelDetailState.times] has the times. A clip whose time is not known
///   yet (a new one while the list's times are read) uses the phone's.
/// - **Opening the reel verifies its clips** (spec §8.3, "verified when a
///   reel is shown"): once per open, through `MediaVerifier` on the shared
///   media queue (D-72), so full access only, and an error never means
///   missing. It never blocks the list and cannot fail it: an error is logged
///   by type. A clip whose video is gone is flagged, the list emits again,
///   and the tile turns into the missing tile. A later change of the list
///   (or of the times) does not verify again; opening the reel again does.
/// - **Opening the reel checks its copies** (D-128): once per open,
///   `EditSessionService.verifyCopies` forgets the copies of the reel's
///   editing session whose files were deleted outside TakeTray, so their
///   clips show under "New since you started editing" again. A reel with no
///   session asks the phone nothing. Like the verify, it never blocks or
///   fails the page: an error is logged by type and the copies stay as they
///   were.
@Riverpod(retry: noRetry)
class ReelDetailController extends _$ReelDetailController {
  /// Whether this open has started its verify.
  bool _verifyStarted = false;

  /// Whether this open has started its copy check.
  bool _copiesChecked = false;

  /// The removals that are running, by clip id.
  final Map<int, Future<MissingRemoval>> _removing = {};

  @override
  Future<ReelDetailState?> build(int reelId) async {
    final reelFuture = ref.watch(reelByIdProvider(reelId).future);
    final clipsFuture = ref.watch(reelClipsProvider(reelId).future);
    // Never awaited: the page shows without the times.
    final times =
        ref.watch(reelClipTimesProvider(reelId)).value ??
        const <int, ClipLocalTime>{};

    final reel = await reelFuture;
    if (reel == null) return null;
    if (!_copiesChecked) {
      _copiesChecked = true;
      unawaited(_checkCopies());
    }
    final clips = await clipsFuture;
    if (!_verifyStarted && clips.isNotEmpty) {
      _verifyStarted = true;
      unawaited(_verify([for (final c in clips) c.clip]));
    }
    final live = clips.where((c) => !c.clip.missing);
    return ReelDetailState(
      reel: reel,
      days: groupByShootingDay<ReelClip>(clips, (c) => c.clip, times),
      clipCount: clips.length,
      missingCount: clips.length - live.length,
      liveDurationMs: live.fold(
        0,
        (sum, c) => sum + c.clip.fingerprint.durationMs,
      ),
      times: times,
    );
  }

  /// Checks that [clips] are still on the phone. Never throws: the reads of
  /// `ref` are inside the guarded step, because after the provider was
  /// disposed (the page closed) `ref.read` throws.
  Future<void> _verify(List<Clip> clips) => guarded<void>(
    _log,
    'The verify',
    () async {
      final outcome = await ref.read(mediaVerifierProvider).verify(clips);
      _log.info(
        'Opened reel $reelId: ${outcome.found.length} found, '
        '${outcome.missing.length} missing, ${outcome.skipped.length} skipped',
      );
    },
  );

  /// Forgets the copies of this reel whose files are gone. Never throws,
  /// for the same reason as [_verify].
  Future<void> _checkCopies() => guarded<void>(
    _log,
    'The copy check',
    () => ref.read(editSessionServiceProvider).verifyCopies(reelId),
  );

  /// Takes the missing clip [clipId] out of this reel and returns what Undo
  /// needs (D-84): the link, with its `addedAt`, and the clip itself if no
  /// other reel and not To tag held it, with how many copies were deleted
  /// for it during an editing session (0 or 1) for the snack.
  ///
  /// Only a clip that is flagged missing and is in this reel is removed: if
  /// the verify found its video again, or the clip is not here, nothing
  /// changes and the record is empty (the view then says nothing). During an
  /// editing session its copy is deleted first (R8); when it cannot be,
  /// `CopiesNotDeleted` is thrown and nothing is removed.
  ///
  /// Single-flight per clip: a second tap while the first runs gets the same
  /// future, so the link is removed once and there is one record. Throws when
  /// the write failed (after logging the error's type); the view tells the
  /// user.
  Future<MissingRemoval> removeMissing(int clipId) {
    final running = _removing[clipId];
    if (running != null) return running;
    final repository = ref.read(clipsRepositoryProvider);
    final editing = ref.read(editSessionServiceProvider);
    final run = _remove(repository, editing, clipId);
    _removing[clipId] = run;
    unawaited(
      run.then<void>((_) {}, onError: (_) {}).then<void>((_) {
        _removing.removeWhere((_, running) => identical(running, run));
      }),
    );
    return run;
  }

  Future<MissingRemoval> _remove(
    ClipsRepository clips,
    EditSessionService editing,
    int clipId,
  ) async {
    final id = reelId;
    try {
      final inReel = await clips.watchReelClips(id).first;
      final here = inReel.where((c) => c.clip.id == clipId);
      if (here.isEmpty || !here.single.clip.missing) {
        return (
          record: RemoveUndo(
            reelId: id,
            removedLinks: const [],
            sweptClips: const [],
            touch: null,
          ),
          copiesDeleted: 0,
        );
      }
      // Its copy goes first (R8); if it cannot, nothing is removed.
      final copies = await editing.beforeClipsLeaveReel(id, {clipId});
      return (
        record: await clips.removeClipsFromReel(id, [clipId]),
        copiesDeleted: copies,
      );
    } on Object catch (error) {
      _log.warning(
        'Removing clip $clipId from reel $id failed: ${error.runtimeType}',
      );
      rethrow;
    }
  }
}
