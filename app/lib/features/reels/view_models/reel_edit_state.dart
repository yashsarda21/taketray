import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/data/editors/edit_session_service.dart';
import 'package:taketray/data/repositories/edit_sessions_repository.dart';
import 'package:taketray/domain/models/clip_local_time.dart';
import 'package:taketray/domain/models/edit_session.dart';
import 'package:taketray/domain/models/editor_app.dart';
import 'package:taketray/domain/models/reel_clip.dart';
import 'package:taketray/domain/rules/edit_split.dart';
import 'package:taketray/domain/rules/shooting_days.dart';
import 'package:taketray/features/reels/view_models/reel_detail_controller.dart';
import 'package:taketray/platform/copy_bridge.dart';

part 'reel_edit_state.g.dart';

/// Reel [reelId]'s editing session with its copies and sent clips, now and
/// after every change; null while the reel has none (D-120). No value until
/// the database has answered.
@riverpod
Stream<EditState?> reelEditSession(Ref ref, int reelId) =>
    ref.watch(editSessionsRepositoryProvider).watchEditState(reelId);

/// The editor of every reel that is being edited (reel id to editor), for
/// the pills of Home's cards.
@riverpod
Stream<Map<int, EditorApp>> reelEditors(Ref ref) =>
    ref.watch(editSessionsRepositoryProvider).watchEditors();

/// The editor of copy job [jobId], from its saved plan (the same source the
/// copy progress screen reads); null once the plan is gone. The running-job
/// banner names it, so a job never shows another editor's name while the
/// reel's session is not read yet or has ended (D-129).
@riverpod
Future<EditorApp?> copyJobEditor(Ref ref, String jobId) async =>
    (await ref.read(editSessionServiceProvider).jobContext(jobId))?.editor;

/// A reel's page while it is being edited (D-128): its session and its clips
/// in two parts, by what the editor already has (`splitForEditing`, D-119).
@immutable
class ReelEditState {
  ReelEditState({
    required this.session,
    required this.copyCount,
    required this.copyBytes,
    required List<ShootingDay<ReelClip>> newDays,
    required List<ShootingDay<ReelClip>> inEditDays,
    required this.newCount,
    required this.inEditCount,
    required this.newLiveCount,
  }) : newDays = List.unmodifiable(newDays),
       inEditDays = List.unmodifiable(inEditDays);

  final EditSession session;

  /// The session's editor.
  EditorApp get editor => session.editor;

  /// How many copies are recorded in the session's folder, and their size.
  final int copyCount;
  final int copyBytes;

  /// "New since you started editing": clips neither sent nor with a live
  /// copy, by the day they were shot, each day with **the reel's** Day
  /// number (a part never renumbers its days). Days with no such clip are
  /// left out. Missing clips stay here.
  final List<ShootingDay<ReelClip>> newDays;

  /// "In your edit": clips sent to the editor or with a live copy, by day,
  /// as [newDays].
  final List<ShootingDay<ReelClip>> inEditDays;

  /// How many clips each part holds, missing ones included.
  final int newCount;
  final int inEditCount;

  /// How many of the new clips are on the phone (not missing): what there is
  /// to copy. The copy itself picks and orders its clips (Task 10).
  final int newLiveCount;
}

/// Reel [reelId]'s page while it is being edited; null while it has no
/// session (D-128).
///
/// It follows the session (a copy recorded, a copy the copy check found gone,
/// Done editing), the reel's clips (a clip tagged in meanwhile is new at
/// once) and their times, like the page itself (`ReelDetailController`).
/// The split is `splitForEditing` over every clip of the reel, with the sent
/// clips and the clips whose copy is recorded: the copy check that runs when
/// the page opens removes the records of copies deleted outside TakeTray, so
/// a recorded copy is a live one.
@riverpod
Future<ReelEditState?> reelEditState(Ref ref, int reelId) async {
  final clipsFuture = ref.watch(reelClipsProvider(reelId).future);
  final times =
      ref.watch(reelClipTimesProvider(reelId)).value ??
      const <int, ClipLocalTime>{};
  final edit = await ref.watch(reelEditSessionProvider(reelId).future);
  if (edit == null) return null;
  final clips = await clipsFuture;
  final split = splitForEditing<ReelClip>(
    clips,
    (c) => c.clip.id,
    sentIds: edit.sentIds,
    liveCopyIds: {for (final c in edit.copies) c.clipId},
  );
  final days = groupByShootingDay<ReelClip>(clips, (c) => c.clip, times);
  return ReelEditState(
    session: edit.session,
    copyCount: edit.copies.length,
    copyBytes: edit.copies.fold(0, (sum, c) => sum + c.sizeBytes),
    newDays: _daysOf(days, split.newClips),
    inEditDays: _daysOf(days, split.inEdit),
    newCount: split.newClips.length,
    inEditCount: split.inEdit.length,
    newLiveCount: split.newClips.where((c) => !c.clip.missing).length,
  );
}

/// [days] cut down to the clips of [part], keeping each day's number and
/// dropping the days left empty.
List<ShootingDay<ReelClip>> _daysOf(
  List<ShootingDay<ReelClip>> days,
  List<ReelClip> part,
) {
  final ids = {for (final c in part) c.clip.id};
  return [
    for (final day in days)
      if (day.clips.any((c) => ids.contains(c.clip.id)))
        ShootingDay(
          date: day.date,
          number: day.number,
          clips: [
            for (final c in day.clips)
              if (ids.contains(c.clip.id)) c,
          ],
        ),
  ];
}

/// [job] when it is a copy job of reel [reelId] that is running; otherwise
/// null. While it runs, the reel's banner shows its progress and Done editing
/// is not offered (`doneEditing` refuses a running job, D-123).
CopyJob? runningCopyJobOf(CopyJob? job, int reelId) =>
    job != null && job.reelId == reelId && job.state == CopyState.running
    ? job
    : null;
