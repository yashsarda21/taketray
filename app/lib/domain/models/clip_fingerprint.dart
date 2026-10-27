import 'package:freezed_annotation/freezed_annotation.dart';

part 'clip_fingerprint.freezed.dart';
part 'clip_fingerprint.g.dart';

/// The facts used to recognise a video again after Android renumbers it
/// (spec §8.1). Never the video itself.
///
/// None of the fields is null: [dateTakenUtc] is required by the database
/// (`NOT NULL`). Whoever builds a fingerprint supplies the values as given.
/// Phase 3's bridge falls back to MediaStore's DATE_ADDED, then DATE_MODIFIED,
/// when a video has no date taken (D-57); the repository never guesses.
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
