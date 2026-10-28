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

/// Whether [v] can be a clip: it is finished (not pending) and has a length.
///
/// A video still being recorded, or one whose duration is unknown or zero,
/// is not offered, not matched and not counted as shot.
bool isUsable(MediaVideo v) => !v.isPending && (v.durationMs ?? 0) > 0;
