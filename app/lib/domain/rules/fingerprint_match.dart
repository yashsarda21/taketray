import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/models/clip_fingerprint.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/domain/rules/clip_date.dart';
import 'package:taketray/domain/rules/media_clip.dart';

/// Whether the media row [v] has the same fingerprint as [f] (D-69): the
/// same size, the same duration (unknown counts as `0`) and the same
/// shooting date ([shotAt]).
///
/// The display name is ignored, because a renamed video is still the same
/// video. A size of `0` never matches: it means Android did not know the
/// size, which says nothing about the video.
bool sameVideo(ClipFingerprint f, MediaVideo v, {required DateTime now}) =>
    v.sizeBytes > 0 &&
    f.sizeBytes == v.sizeBytes &&
    f.durationMs == (v.durationMs ?? 0) &&
    f.dateTakenUtc.isAtSameMomentAs(shotAt(v, now: now));

/// Which stored clips were found again after Android rebuilt its media
/// library, and which were not.
///
/// [remap] maps a clip id to the clip's new MediaStore id (on the clip's own
/// volume). [lost] holds the ids of the clips that were not found, or not
/// found for certain. Every clip passed in is in exactly one of the two.
class RebuildMatch {
  const RebuildMatch({required this.remap, required this.lost});

  final Map<int, int> remap;
  final Set<int> lost;
}

/// Finds each of the [stored] clips among the [current] rows by fingerprint
/// (D-69). When unsure, a clip is lost, never matched: a missing clip is
/// better than a wrong video.
///
/// 1. A clip's candidates are the usable rows ([isUsable]) on the clip's
///    volume that are [sameVideo].
/// 2. With more than one, only those with the clip's display name stay.
/// 3. A clip left with exactly one candidate claims it.
/// 4. A row claimed by two or more clips goes to none of them.
/// 5. Every other clip is lost.
///
/// [stored] should be the MediaStore clips of the rebuilt volume: a clip
/// without a volume (a picked clip) has no candidates and is lost.
RebuildMatch matchAfterRebuild(
  List<Clip> stored,
  List<MediaVideo> current, {
  required DateTime now,
}) {
  final usable = current.where(isUsable).toList();
  final claims = <int, (String, int)>{};
  final claimCount = <(String, int), int>{};

  for (final clip in stored) {
    var candidates = [
      for (final v in usable)
        if (v.volumeName == clip.volumeName &&
            sameVideo(clip.fingerprint, v, now: now))
          v,
    ];
    if (candidates.length > 1) {
      candidates = [
        for (final v in candidates)
          if (v.displayName == clip.fingerprint.displayName) v,
      ];
    }
    if (candidates.length == 1) {
      final video = (
        candidates.single.volumeName,
        candidates.single.mediaStoreId,
      );
      claims[clip.id] = video;
      claimCount[video] = (claimCount[video] ?? 0) + 1;
    }
  }

  final remap = <int, int>{
    for (final MapEntry(key: clipId, value: video) in claims.entries)
      if (claimCount[video] == 1) clipId: video.$2,
  };
  final lost = {
    for (final clip in stored)
      if (!remap.containsKey(clip.id)) clip.id,
  };
  return RebuildMatch(remap: remap, lost: lost);
}
