import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/core/guarded.dart';
import 'package:taketray/data/editors/edit_session_service.dart';
import 'package:taketray/domain/models/editor_app.dart';
import 'package:taketray/domain/rules/space_check.dart';
import 'package:taketray/features/reels/view_models/reel_detail_controller.dart';

part 'copy_space_controller.g.dart';

/// Which copy the space screen checks: reel [reelId], for [editor], of
/// [clipIds] in shooting order. Compares by value, so one screen keeps one
/// controller.
@immutable
class CopySpaceArgs {
  CopySpaceArgs(this.reelId, this.editor, Iterable<int> clipIds)
    : clipIds = List.unmodifiable(clipIds);

  final int reelId;
  final EditorApp editor;
  final List<int> clipIds;

  @override
  bool operator ==(Object other) =>
      other is CopySpaceArgs &&
      other.reelId == reelId &&
      other.editor == editor &&
      listEquals(other.clipIds, clipIds);

  @override
  int get hashCode => Object.hash(reelId, editor, Object.hashAll(clipIds));
}

/// What the space screen shows: the plan `EditSessionService.planCopy` made,
/// and the two bar fractions the plan implies (D-127).
@immutable
class CopySpaceState {
  const CopySpaceState(this.plan);

  final CopyPlan plan;

  /// Whether the copies fit and the reserve stays free.
  bool get enough => plan.space.enough;

  /// There is no clip left to copy (all copied, or missing from the phone).
  bool get nothingToCopy => plan.clipIds.isEmpty;

  /// The copies' share of the free space, for the bar when they fit (the
  /// bar's scale is the phone's free space).
  double get needFraction =>
      plan.freeBytes <= 0 ? 1 : plan.needBytes / plan.freeBytes;

  /// For the bar when they do not fit (its scale is what the copies need):
  /// how much of the need the phone has **after the reserve**, from 0 up to
  /// but not including 1. `(free - reserve) / need`; 0 when the free space is
  /// under the reserve, so the solid part is never negative and the bar's
  /// "have" part never claims room TakeTray will not use.
  double get haveFraction {
    final need = plan.needBytes;
    if (need <= 0) return 0;
    final usable = plan.freeBytes - copyReserveBytes;
    if (usable <= 0) return 0;
    final share = usable / need;
    return share >= 1 ? _belowOne : share;
  }

  /// The largest fraction `TtStorageBar.short` takes.
  static const double _belowOne = 0.999999;
}

/// The VN space check (D-127): what copying [CopySpaceArgs.clipIds] would take
/// (`EditSessionService.planCopy`) and the start of the copy.
///
/// - **Data:** `null` once the reel is gone (deleted meanwhile, or an id that
///   names none); the screen then goes to Reels. An error (the phone's free
///   space cannot be read, the reel is in another editor) is shown as
///   "Couldn't start copying. Try again.".
/// - The plan is made again when the reel changes (a clip goes missing), so
///   the numbers are never older than the reel.
///
/// Auto-disposes with the screen.
@Riverpod(retry: noRetry)
class CopySpaceController extends _$CopySpaceController {
  @override
  Future<CopySpaceState?> build(CopySpaceArgs args) async {
    final reel = await ref.watch(reelByIdProvider(args.reelId).future);
    if (reel == null) return null;
    final plan = await ref
        .read(editSessionServiceProvider)
        .planCopy(args.reelId, args.editor, args.clipIds);
    return CopySpaceState(plan);
  }

  /// Starts copying [plan] and returns the job id. `CopyBusy` while another
  /// job runs; anything else the service throws is passed on.
  Future<String> start(CopyPlan plan) =>
      ref.read(editSessionServiceProvider).startCopy(plan);
}
