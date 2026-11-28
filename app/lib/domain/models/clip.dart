import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:taketray/domain/models/clip_fingerprint.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/domain/rules/photo_clip.dart';

part 'clip.freezed.dart';
part 'clip.g.dart';

/// A video or photo TakeTray knows about: facts about it, never the file.
///
/// A photo is a clip with an image type (D-198): [isPhoto] says so, and its
/// duration is 0. A detected clip is identified by [volumeName] +
/// [mediaStoreId]; a picked one by [pickerUri]. Times are UTC.
@freezed
abstract class Clip with _$Clip {
  const factory Clip({
    required int id,
    required ClipSource source,
    required ClipFingerprint fingerprint,
    required int width,
    required int height,
    required String mimeType,
    required DateTime firstSeenAt,
    required bool missing,
    int? mediaStoreId,
    String? volumeName,
    String? pickerUri,

    /// IANA zone where the clip was shot, e.g. `Europe/London`.
    String? timeZoneId,
    int? generationAdded,
    DateTime? lastVerifiedAt,
  }) = _Clip;

  const Clip._();

  factory Clip.fromJson(Map<String, dynamic> json) => _$ClipFromJson(json);

  /// True when this clip is a photo: its [mimeType] is an image type.
  bool get isPhoto => isPhotoMimeType(mimeType);
}

/// A clip that is about to be saved: everything a [Clip] has except the
/// fields the database or the clock fill in (`id`, `firstSeenAt`, `missing`,
/// `lastVerifiedAt`).
///
/// Build one with [NewClip.mediaStore] or [NewClip.picker], which take the
/// identity their source needs.
///
/// [width], [height] and the fingerprint's `dateTakenUtc` are required, and
/// the repository stores them as given (D-57). A detected clip is built by
/// `newClipFrom` (`domain/rules/media_clip.dart`): the date is `shotAt`
/// (`domain/rules/clip_date.dart`, D-69), the first plausible one of
/// DATE_TAKEN, DATE_ADDED and DATE_MODIFIED, and a width or height MediaStore
/// does not know is `0`.
///
/// The main constructor asserts that the identity fields match [source] (the
/// same rule the database enforces with `CHECK`s, D-54), so a half-empty
/// identity fails in tests, not in SQL.
@freezed
abstract class NewClip with _$NewClip {
  @Assert(
    'source != ClipSource.mediaStore || '
        '(mediaStoreId != null && volumeName != null)',
    'a mediaStore clip needs mediaStoreId and volumeName',
  )
  @Assert(
    'source != ClipSource.picker || pickerUri != null',
    'a picker clip needs pickerUri',
  )
  const factory NewClip({
    required ClipSource source,
    required ClipFingerprint fingerprint,
    required int width,
    required int height,
    required String mimeType,
    int? mediaStoreId,
    String? volumeName,
    String? pickerUri,
    String? timeZoneId,
    int? generationAdded,
  }) = _NewClip;

  /// A clip detected in Android's media library.
  factory NewClip.mediaStore({
    required int mediaStoreId,
    required String volumeName,
    required ClipFingerprint fingerprint,
    required int width,
    required int height,
    required String mimeType,
    String? timeZoneId,
    int? generationAdded,
  }) => NewClip(
    source: ClipSource.mediaStore,
    mediaStoreId: mediaStoreId,
    volumeName: volumeName,
    fingerprint: fingerprint,
    width: width,
    height: height,
    mimeType: mimeType,
    timeZoneId: timeZoneId,
    generationAdded: generationAdded,
  );

  /// A clip picked by hand with the system photo picker.
  factory NewClip.picker({
    required String pickerUri,
    required ClipFingerprint fingerprint,
    required int width,
    required int height,
    required String mimeType,
    String? timeZoneId,
  }) => NewClip(
    source: ClipSource.picker,
    pickerUri: pickerUri,
    fingerprint: fingerprint,
    width: width,
    height: height,
    mimeType: mimeType,
    timeZoneId: timeZoneId,
  );

  factory NewClip.fromJson(Map<String, dynamic> json) =>
      _$NewClipFromJson(json);
}
