import 'package:freezed_annotation/freezed_annotation.dart';

part 'clip_fingerprint.freezed.dart';
part 'clip_fingerprint.g.dart';

/// The facts used to recognise a video again after Android renumbers it
/// (spec §8.1). Never the video itself.
///
/// None of the fields is null: [dateTakenUtc] is required by the database
/// (`NOT NULL`). Whoever builds a fingerprint supplies the values as given;
/// the repository never guesses (D-57). For a video from MediaStore,
/// [dateTakenUtc] is `shotAt` (`domain/rules/clip_date.dart`, D-69): the
/// first plausible one of DATE_TAKEN, DATE_ADDED and DATE_MODIFIED, else
/// "now". `sameVideo` (`domain/rules/fingerprint_match.dart`) compares the
/// size, the duration and this date, never [displayName].
@freezed
abstract class ClipFingerprint with _$ClipFingerprint {
  const factory ClipFingerprint({
    required int sizeBytes,
    required int durationMs,
    required DateTime dateTakenUtc,
    required String displayName,
  }) = _ClipFingerprint;

  factory ClipFingerprint.fromJson(Map<String, dynamic> json) =>
      _$ClipFingerprintFromJson(json);
}
