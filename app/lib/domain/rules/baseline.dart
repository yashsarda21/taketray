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

/// The generation to store as the new baseline after a scan.
///
/// [from] is the baseline the scan started from, [captured] the volume's
/// generation read before the query, and [seen] every row the scan returned
/// (pending ones included, all pages together). [truncated] is true when the
/// scan stopped before the end: its last page was full and was not followed.
///
/// A pending row (a video still being recorded) holds the baseline just
/// before the oldest one, so the next scan sees it again once it is
/// finished. A truncated scan ignores [captured] and holds one below the
/// highest generation seen: rows written in one transaction share a
/// generation, so a full page can end in the middle of one. Otherwise the
/// baseline moves to the highest of [captured] and the rows' generations.
/// It never moves below [from].
int advanceBaseline({
  required int from,
  required int captured,
  required List<MediaVideo> seen,
  bool truncated = false,
}) {
  final pending = [
    for (final v in seen)
      if (v.isPending) v.generationAdded,
  ];
  final pendingHold = pending.isEmpty ? null : pending.reduce(min) - 1;
  if (truncated) {
    if (seen.isEmpty) return from;
    final cut = seen.map((v) => v.generationAdded).reduce(max) - 1;
    return max(from, pendingHold == null ? cut : min(pendingHold, cut));
  }
  if (pendingHold != null) return max(from, pendingHold);
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
