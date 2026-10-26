import 'package:freezed_annotation/freezed_annotation.dart';

part 'clip_fingerprint.freezed.dart';
part 'clip_fingerprint.g.dart';

/// The facts used to recognise a video again after Android renumbers it
/// (spec §8.1). Never the video itself.
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
