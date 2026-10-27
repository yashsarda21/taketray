import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:taketray/domain/models/clip_fingerprint.dart';
import 'package:taketray/domain/models/enums.dart';

part 'clip.freezed.dart';
part 'clip.g.dart';

/// A video TakeTray knows about: facts about it, never the video.
///
/// A detected clip is identified by [volumeName] + [mediaStoreId]; a picked
/// one by [pickerUri]. Times are UTC.
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

  factory Clip.fromJson(Map<String, dynamic> json) => _$ClipFromJson(json);
}

/// A clip that is about to be saved: everything a [Clip] has except the
/// fields the database or the clock fill in (`id`, `firstSeenAt`, `missing`,
/// `lastVerifiedAt`).
///
/// Build one with [NewClip.mediaStore] or [NewClip.picker], which take the
/// identity their source needs.
///
/// [width], [height] and the fingerprint's `dateTakenUtc` are required, and
/// the repository stores them as given (D-57). Phase 3's bridge supplies the
/// date from DATE_ADDED, then DATE_MODIFIED, when MediaStore has no date
/// taken, and `0` for a width or height MediaStore does not know.
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
