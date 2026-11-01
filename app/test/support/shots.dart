import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/models/clip_fingerprint.dart';

/// A detected clip with MediaStore number [number], shot at [at] (UTC).
///
/// Its size, length, file name and generation all follow from [number], so
/// two shots never share a fingerprint. Shot in India (`Asia/Kolkata`) on
/// the phone's own storage.
NewClip mediaStoreShot(int number, {required DateTime at}) =>
    NewClip.mediaStore(
      mediaStoreId: number,
      volumeName: 'external_primary',
      fingerprint: ClipFingerprint(
        sizeBytes: 1000 + number,
        durationMs: 4000 + number,
        dateTakenUtc: at,
        displayName: 'VID_$number.mp4',
      ),
      width: 1080,
      height: 1920,
      mimeType: 'video/mp4',
      timeZoneId: 'Asia/Kolkata',
      generationAdded: 40 + number,
    );
