import 'dart:math';

import 'package:meta/meta.dart';
import 'package:taketray/domain/models/media.dart';

/// What a scan does with one volume of the media library (D-70).
@immutable
sealed class VolumePlan {
  const VolumePlan();
}

/// The volume has no baseline (Shooting mode was switched on before it was
/// mounted, or after an import): take its current generation as the
/// baseline and treat nothing on it as new.
final class StartFromNow extends VolumePlan {
  const StartFromNow();
}

/// The volume is not mounted (a removed SD card): leave it and its clips
/// alone.
final class SkipVolume extends VolumePlan {
  const SkipVolume();
}

/// Android rebuilt the volume's media library (its version changed, or its
/// generation went backwards): the generations no longer compare, so the
/// stored clips must be found again by fingerprint.
final class Resync extends VolumePlan {
  const Resync();
}

/// Look for videos added after [generation].
final class ScanAfter extends VolumePlan {
  const ScanAfter(this.generation);

  final int generation;

  @override
  bool operator ==(Object other) =>
      other is ScanAfter && other.generation == generation;

  @override
  int get hashCode => generation.hashCode;

  @override
  String toString() => 'ScanAfter($generation)';
}

/// The plan for [current], given the [baseline] stored for it (if any).
///
/// The checks run in this order, and the first that applies wins: not
/// mounted, no baseline, a different version (compared for equality only),
/// a generation below the baseline's.
VolumePlan planVolume(VolumeBaseline? baseline, MediaVolume current) {
  if (!current.isMounted) return const SkipVolume();
  if (baseline == null) return const StartFromNow();
  if (current.version != baseline.version) return const Resync();
  // Within one version the generation only grows; if it did not, trust
  // nothing about it.
  if (current.generation < baseline.generation) return const Resync();
  return ScanAfter(baseline.generation);
}

/// How long a finished video without a length keeps holding the baseline
/// after it was added (D-72, Ruling W).
const lateMetadataWindow = Duration(minutes: 10);

/// Whether row [v] must hold the baseline before it, so the next scan sees
/// it again:
///
/// - a pending row (a video still being recorded) always holds;
/// - a finished row whose duration is unknown or 0 holds while its
///   DATE_ADDED is at most [lateMetadataWindow] before [now] (exactly ten
///   minutes still holds) and not more than one day after it (the bound of
///   a plausible date, D-69). Android can fill in the length a moment after
///   the row is finished; an older row without a length is broken and is
///   passed.
///
/// DATE_ADDED is compared in seconds before it is multiplied, so a huge
/// value cannot overflow into a plausible one.
bool holdsBaseline(MediaVideo v, {required DateTime now}) {
  if (v.isPending) return true;
  if ((v.durationMs ?? 0) > 0) return false;
  final addedSec = v.dateAddedSec;
  if (addedSec == null || addedSec < 0) return false;
  final nowMs = now.millisecondsSinceEpoch;
  final latestSec = (nowMs + const Duration(days: 1).inMilliseconds) ~/ 1000;
  if (addedSec > latestSec) return false;
  return nowMs - addedSec * 1000 <= lateMetadataWindow.inMilliseconds;
}

/// The generation to store as the new baseline after a scan.
///
/// [from] is the baseline the scan started from, [captured] the volume's
/// generation read before the query, and [seen] every row the scan returned
/// (pending ones included, all pages together). [truncated] is true when the
/// scan stopped before the end: its last page was full and was not followed.
/// [now] is the scan's time, for [holdsBaseline].
///
/// A row that holds the baseline ([holdsBaseline]: a video still being
/// recorded, or a just-finished one whose length Android has not filled in
/// yet) holds it just before the oldest such row, so the next scan sees it
/// again. A truncated scan ignores [captured] and holds one below the
/// highest generation seen: rows written in one transaction share a
/// generation, so a full page can end in the middle of one. Otherwise the
/// baseline moves to the highest of [captured] and the rows' generations.
/// It never moves below [from].
int advanceBaseline({
  required int from,
  required int captured,
  required List<MediaVideo> seen,
  required DateTime now,
  bool truncated = false,
}) {
  final holding = [
    for (final v in seen)
      if (holdsBaseline(v, now: now)) v.generationAdded,
  ];
  final hold = holding.isEmpty ? null : holding.reduce(min) - 1;
  if (truncated) {
    if (seen.isEmpty) return from;
    final cut = seen.map((v) => v.generationAdded).reduce(max) - 1;
    return max(from, hold == null ? cut : min(hold, cut));
  }
  if (hold != null) return max(from, hold);
  return seen.fold(
    max(from, captured),
    (best, v) => max(best, v.generationAdded),
  );
}

/// The cursor for the next page of a scan that asked for rows added after
/// [cursor] and got the full [page] back (D-70).
///
/// The answer is one below the page's highest generation, because the page
/// may end in the middle of that generation. It is null when the page is
/// empty, when every row on it shares one generation (the next page would be
/// the same rows again), or when the answer would not move past [cursor].
/// Null means the scan has stalled: ask again with a bigger limit.
int? nextPageCursor({required int cursor, required List<MediaVideo> page}) {
  if (page.isEmpty) return null;
  final generations = page.map((v) => v.generationAdded);
  final highest = generations.reduce(max);
  if (generations.reduce(min) == highest) return null;
  final next = highest - 1;
  return next > cursor ? next : null;
}
