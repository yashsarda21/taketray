import 'package:taketray/domain/models/media.dart';

/// The type stored for a picked photo whose provider gave no image type
/// (R13-3): the picker was asked for images only, so the pick is a photo.
const String defaultPhotoMimeType = 'image/*';

/// True when [mimeType] starts with `image/`, ignoring ASCII case.
///
/// This is the one test of "is this clip a photo": `Clip.isPhoto` and
/// `ClipRef.isPhoto` both use it, and a video type (`video/mp4`, `video/*`),
/// an empty type and a near miss (`imagex/y`) are not photos.
bool isPhotoMimeType(String mimeType) =>
    mimeType.toLowerCase().startsWith('image/');

/// The type to store for a picked photo: [reported] when it is an image type,
/// else [defaultPhotoMimeType] (R13-3).
///
/// A null, empty or non-image type (`application/octet-stream`, `video/mp4`)
/// becomes `image/*`, so a photo pick is always a photo.
String photoMimeTypeOf(String? reported) =>
    reported != null && isPhotoMimeType(reported)
    ? reported
    : defaultPhotoMimeType;

/// When the picked photo [p] was shot: the first plausible of its taken date
/// ([PickedVideo.dateTakenMs]) and its last-modified date
/// ([PickedVideo.dateModifiedMs]), else [now] (R13-3).
///
/// Both are milliseconds, and the plausibility is the `shotAtFrom` rule: not
/// before 0 and not after [now] plus 24 hours (that exact instant is still
/// plausible). The result is a UTC instant.
DateTime pickedPhotoShotAt(PickedVideo p, {required DateTime now}) {
  final nowUtc = now.toUtc();
  final latestMs = nowUtc.add(const Duration(days: 1)).millisecondsSinceEpoch;
  for (final ms in [p.dateTakenMs, p.dateModifiedMs]) {
    if (ms != null && ms >= 0 && ms <= latestMs) {
      return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
    }
  }
  return nowUtc;
}
