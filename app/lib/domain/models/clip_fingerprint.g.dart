// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'clip_fingerprint.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ClipFingerprint _$ClipFingerprintFromJson(Map<String, dynamic> json) =>
    _ClipFingerprint(
      sizeBytes: (json['sizeBytes'] as num).toInt(),
      durationMs: (json['durationMs'] as num).toInt(),
      dateTakenUtc: DateTime.parse(json['dateTakenUtc'] as String),
      displayName: json['displayName'] as String,
    );

Map<String, dynamic> _$ClipFingerprintToJson(_ClipFingerprint instance) =>
    <String, dynamic>{
      'sizeBytes': instance.sizeBytes,
      'durationMs': instance.durationMs,
      'dateTakenUtc': instance.dateTakenUtc.toIso8601String(),
      'displayName': instance.displayName,
    };
