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
/// generation read before the query, and [seen] every row the query
/// returned (pending ones included).
///
/// A pending row (a video still being recorded) holds the baseline just
/// before the oldest one, so the next scan sees it again once it is
/// finished. Otherwise the baseline moves to the highest of [captured] and
/// the rows' generations. It never moves below [from].
int advanceBaseline({
  required int from,
  required int captured,
  required List<MediaVideo> seen,
}) {
  final pending = [
    for (final v in seen)
      if (v.isPending) v.generationAdded,
  ];
  if (pending.isNotEmpty) {
    return max(from, pending.reduce(min) - 1);
  }
  return seen.fold(
    max(from, captured),
    (best, v) => max(best, v.generationAdded),
  );
}
