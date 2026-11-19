import 'dart:async' as async;

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/data/repositories/references_repository.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/domain/models/reel_reference.dart';
import 'package:taketray/domain/models/reel_summary.dart';
import 'package:taketray/features/reels/view_models/home_controller.dart';

part 'shooting_references.g.dart';

/// One reel and its references, as the Shooting mode References sheet groups
/// them (D-160).
class ReferenceGroup {
  /// The group of [reel] and its [references].
  const new({required this.reel, required this.references});

  /// The reel, as Home's cards have it (its name, status and cover).
  final ReelSummary reel;

  /// The reel's references, newest first. Never empty.
  final List<ReelReference> references;
}

/// The statuses the Shooting mode sheet lists, in the order it lists them:
/// the reels being filmed for, then the ones waiting for an edit. A Published
/// reel is done filming, so it is never there.
const List<ReelStatus> _listed = [ReelStatus.collecting, ReelStatus.ready];

/// Groups [references] by reel for the Shooting mode sheet.
///
/// [summaries] are Home's reels in Home's order (newest first). The groups are
/// the Collecting reels, then the Ready to edit ones, each status in the order
/// of [summaries]; a reel with no reference and a reel in any other status is
/// left out. A reference whose reel is not in [summaries] is left out too.
/// Each group keeps the order of [references] (newest first). A new list;
/// neither argument is changed.
List<ReferenceGroup> groupShootingReferences(
  List<ReelSummary> summaries,
  List<ReelReference> references,
) {
  final byReel = <int, List<ReelReference>>{};
  for (final reference in references) {
    (byReel[reference.reelId] ??= []).add(reference);
  }
  return [
    for (final status in _listed)
      for (final summary in summaries)
        if (summary.reel.status == status &&
            (byReel[summary.reel.id]?.isNotEmpty ?? false))
          ReferenceGroup(reel: summary, references: byReel[summary.reel.id]!),
  ];
}

/// How many references the [groups] hold in all.
int shootingReferenceCount(List<ReferenceGroup> groups) =>
    groups.fold(0, (sum, group) => sum + group.references.length);

/// Every reference of every reel, newest first, again after every change
/// (`ReferencesRepository.watchAll`).
@riverpod
Stream<List<ReelReference>> allReferences(Ref ref) =>
    ref.watch(referencesRepositoryProvider).watchAll();

/// The References of the Collecting and Ready to edit reels, grouped by reel
/// (D-160), again after every change to reels, clips or references.
///
/// The reels come from `reelSummariesProvider`, Home's own stream, so the
/// order within a status is Home's. The Shooting mode card's row and the sheet
/// both read it.
@riverpod
Stream<List<ReferenceGroup>> shootingReferences(Ref ref) async* {
  // Both are watched before either is awaited, so both streams run. Both are
  // awaited together, so neither failure goes unhandled.
  final List<ReelSummary> summaries;
  final List<ReelReference> references;
  try {
    (summaries, references) = await (
      ref.watch(reelSummariesProvider.future),
      ref.watch(allReferencesProvider.future),
    ).wait;
  } on Object catch (error) {
    // Shooting mode went off again while they loaded: this provider is
    // disposed, so both futures end with an error nobody wants. A real
    // failure of the streams is still the provider's error: the first one,
    // not the wrapper `.wait` puts around it.
    if (!ref.mounted) return;
    if (error is! ParallelWaitError<Object?, Object?>) rethrow;
    final (reelsError, referencesError) =
        error.errors! as (async.AsyncError?, async.AsyncError?);
    final cause = reelsError ?? referencesError!;
    Error.throwWithStackTrace(cause.error, cause.stackTrace);
  }
  yield groupShootingReferences(summaries, references);
}
