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

/// Whether two stored fingerprints are the same video, by the D-69 rule of
/// [sameVideo]: a size above 0 and equal, the same duration and the same
/// shooting instant. The display name is ignored.
///
/// Undo uses it before it links a clip that holds a swept clip's identity
/// now (D-84): after a rebuild, the same number can belong to another video.
bool sameFingerprint(ClipFingerprint a, ClipFingerprint b) =>
    a.sizeBytes > 0 &&
    a.sizeBytes == b.sizeBytes &&
    a.durationMs == b.durationMs &&
    a.dateTakenUtc.isAtSameMomentAs(b.dateTakenUtc);

/// Which stored clips were found again after Android rebuilt its media
/// library, and which were not.
///
/// [remap] maps a clip id to the clip's new MediaStore id (on the rebuilt
/// volume). [lost] holds the ids of the clips that were not found, or not
/// found for certain. Every clip passed in is in exactly one of the two.
class RebuildMatch {
  const RebuildMatch({required this.remap, required this.lost});

  final Map<int, int> remap;
  final Set<int> lost;
}

/// Finds each of the [stored] clips among the [current] rows of the rebuilt
/// volume [volumeName] by fingerprint (D-69). When unsure, a clip is lost,
/// never matched: a missing clip is better than a wrong video.
///
/// 1. A clip's candidates are the usable rows ([isUsable]) on [volumeName]
///    that are [sameVideo]; rows on other volumes are ignored.
/// 2. With more than one, only those with the clip's display name stay.
/// 3. A clip left with exactly one candidate claims it.
/// 4. A row claimed by two or more clips goes to none of them.
/// 5. Every other clip is lost.
///
/// Every clip in [stored] must be on [volumeName]. A clip on another volume,
/// or without one (a picked clip), throws an [ArgumentError] before anything
/// is matched: losing it silently would mark a good clip missing.
RebuildMatch matchAfterRebuild(
  List<Clip> stored,
  List<MediaVideo> current, {
  required String volumeName,
  required DateTime now,
}) {
  for (final clip in stored) {
    if (clip.volumeName != volumeName) {
      throw ArgumentError.value(
        clip.id,
        'stored',
        'clip is not on the volume being matched, $volumeName',
      );
    }
  }
  final usable = [
    for (final v in current)
      if (v.volumeName == volumeName && isUsable(v)) v,
  ];
  final claims = <int, int>{};
  final claimCount = <int, int>{};

  for (final clip in stored) {
    var candidates = [
      for (final v in usable)
        if (sameVideo(clip.fingerprint, v, now: now)) v,
    ];
    if (candidates.length > 1) {
      candidates = [
        for (final v in candidates)
          if (v.displayName == clip.fingerprint.displayName) v,
      ];
    }
    if (candidates.length == 1) {
      final video = candidates.single.mediaStoreId;
      claims[clip.id] = video;
      claimCount[video] = (claimCount[video] ?? 0) + 1;
    }
  }

  final remap = <int, int>{
    for (final MapEntry(key: clipId, value: video) in claims.entries)
      if (claimCount[video] == 1) clipId: video,
  };
  final lost = {
    for (final clip in stored)
      if (!remap.containsKey(clip.id)) clip.id,
  };
  return RebuildMatch(remap: remap, lost: lost);
}
