import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/core/guarded.dart';
import 'package:taketray/data/media/clip_time.dart';
import 'package:taketray/data/repositories/clips_repository.dart';
import 'package:taketray/data/repositories/edit_sessions_repository.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/models/edit_copy.dart';
import 'package:taketray/domain/models/edit_session.dart';
import 'package:taketray/domain/rules/shooting_order.dart';
import 'package:taketray/features/reels/view_models/reel_detail_controller.dart';

part 'copy_ready_controller.g.dart';

/// Reel [reelId]'s editing session with its copies, now and after every
/// change; null while it has none.
@riverpod
Stream<EditState?> editStateOf(Ref ref, int reelId) =>
    ref.watch(editSessionsRepositoryProvider).watchEditState(reelId);

/// What the "Ready for VN" screen shows (D-127).
@immutable
class CopyReadyState {
  const CopyReadyState({
    required this.reelGone,
    required this.session,
    required this.clips,
  });

  /// The reel was deleted (or never existed).
  final bool reelGone;

  /// The reel's editing session now (its folder keeps the name it was
  /// started with, also after a rename); null when there is none.
  final EditSession? session;

  /// The clips that have a copy and are still on the phone, in shooting
  /// order: the pictures of step 3.
  final List<Clip> clips;
}

/// The data of the ready screen for reel [reelId]. Auto-disposes with it.
@Riverpod(retry: noRetry)
class CopyReadyController extends _$CopyReadyController {
  @override
  Future<CopyReadyState> build(int reelId) async {
    final reelFuture = ref.watch(reelByIdProvider(reelId).future);
    final stateFuture = ref.watch(editStateOfProvider(reelId).future);
    final clipsFuture = ref.watch(reelClipsProvider(reelId).future);
    final reel = await reelFuture;
    final edit = await stateFuture;
    if (reel == null) {
      return const CopyReadyState(reelGone: true, session: null, clips: []);
    }
    final copied = {
      for (final c in edit?.copies ?? const <EditCopy>[]) c.clipId,
    };
    final clips = inShootingOrder([
      for (final c in await clipsFuture)
        if (!c.clip.missing && copied.contains(c.clip.id)) c.clip,
    ]);
    return CopyReadyState(
      reelGone: false,
      session: edit?.session,
      clips: clips,
    );
  }
}

/// The wall-clock time where clip [clipId] was shot (`ClipLocalTime`, D-83;
/// the fields of a UTC DateTime), or null when there is no such clip. For
/// the line "The clip from {time} may have been deleted or moved."
@riverpod
Future<DateTime?> failedClipTime(Ref ref, int clipId) async {
  final clips = await ref.read(clipsRepositoryProvider).clipsByIds([clipId]);
  if (clips.isEmpty) return null;
  final times = await ref.read(clipTimeServiceProvider).localTimes(clips);
  return times[clips.first.id]?.wallClock ??
      clips.first.fingerprint.dateTakenUtc.toLocal();
}
