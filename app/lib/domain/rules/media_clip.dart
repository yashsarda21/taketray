import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/models/clip_fingerprint.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/domain/rules/clip_date.dart';

/// The clip to save for a video detected in Android's media library.
///
/// Its identity is the video's volume and MediaStore id. The fingerprint is
/// the size, the duration (`0` when unknown), the shooting date from
/// [shotAt] and the display name. An unknown width or height is `0`.
/// [zoneId] is stored as given, null included.
NewClip newClipFrom(
  MediaVideo v, {
  required DateTime now,
  required String? zoneId,
}) => NewClip.mediaStore(
  mediaStoreId: v.mediaStoreId,
  volumeName: v.volumeName,
  fingerprint: ClipFingerprint(
    sizeBytes: v.sizeBytes,
    durationMs: v.durationMs ?? 0,
    dateTakenUtc: shotAt(v, now: now),
    displayName: v.displayName,
  ),
  width: v.width ?? 0,
  height: v.height ?? 0,
  mimeType: v.mimeType,
  timeZoneId: zoneId,
  generationAdded: v.generationAdded,
);

/// Whether [v] can be a clip: it is finished (not pending) and has a length
/// and a size.
///
/// A video still being recorded, or one whose duration or size is unknown or
/// zero, is not offered, not matched and not counted as shot. A size of 0
/// matters because it never matches a fingerprint (`sameVideo`): a clip
/// saved with it would be removed by the next verify while its video is
/// still on the phone. The baseline holds for such a row, so it is picked up
/// once Android fills the size in (`holdsBaseline`).
bool isUsable(MediaVideo v) =>
    !v.isPending && (v.durationMs ?? 0) > 0 && v.sizeBytes > 0;
