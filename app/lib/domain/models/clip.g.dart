// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'clip.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Clip _$ClipFromJson(Map<String, dynamic> json) => _Clip(
  id: (json['id'] as num).toInt(),
  source: $enumDecode(_$ClipSourceEnumMap, json['source']),
  fingerprint: ClipFingerprint.fromJson(
    json['fingerprint'] as Map<String, dynamic>,
  ),
  width: (json['width'] as num).toInt(),
  height: (json['height'] as num).toInt(),
  mimeType: json['mimeType'] as String,
  firstSeenAt: DateTime.parse(json['firstSeenAt'] as String),
  missing: json['missing'] as bool,
  mediaStoreId: (json['mediaStoreId'] as num?)?.toInt(),
  volumeName: json['volumeName'] as String?,
  pickerUri: json['pickerUri'] as String?,
  timeZoneId: json['timeZoneId'] as String?,
  generationAdded: (json['generationAdded'] as num?)?.toInt(),
  lastVerifiedAt: json['lastVerifiedAt'] == null
      ? null
      : DateTime.parse(json['lastVerifiedAt'] as String),
);

Map<String, dynamic> _$ClipToJson(_Clip instance) => <String, dynamic>{
  'id': instance.id,
  'source': _$ClipSourceEnumMap[instance.source]!,
  'fingerprint': instance.fingerprint.toJson(),
  'width': instance.width,
  'height': instance.height,
  'mimeType': instance.mimeType,
  'firstSeenAt': instance.firstSeenAt.toIso8601String(),
  'missing': instance.missing,
  'mediaStoreId': instance.mediaStoreId,
  'volumeName': instance.volumeName,
  'pickerUri': instance.pickerUri,
  'timeZoneId': instance.timeZoneId,
  'generationAdded': instance.generationAdded,
  'lastVerifiedAt': instance.lastVerifiedAt?.toIso8601String(),
};

const _$ClipSourceEnumMap = {
  ClipSource.mediaStore: 'mediaStore',
  ClipSource.picker: 'picker',
};

_NewClip _$NewClipFromJson(Map<String, dynamic> json) => _NewClip(
  source: $enumDecode(_$ClipSourceEnumMap, json['source']),
  fingerprint: ClipFingerprint.fromJson(
    json['fingerprint'] as Map<String, dynamic>,
  ),
  width: (json['width'] as num).toInt(),
  height: (json['height'] as num).toInt(),
  mimeType: json['mimeType'] as String,
  mediaStoreId: (json['mediaStoreId'] as num?)?.toInt(),
  volumeName: json['volumeName'] as String?,
  pickerUri: json['pickerUri'] as String?,
  timeZoneId: json['timeZoneId'] as String?,
  generationAdded: (json['generationAdded'] as num?)?.toInt(),
);

Map<String, dynamic> _$NewClipToJson(_NewClip instance) => <String, dynamic>{
  'source': _$ClipSourceEnumMap[instance.source]!,
  'fingerprint': instance.fingerprint.toJson(),
  'width': instance.width,
  'height': instance.height,
  'mimeType': instance.mimeType,
  'mediaStoreId': instance.mediaStoreId,
  'volumeName': instance.volumeName,
  'pickerUri': instance.pickerUri,
  'timeZoneId': instance.timeZoneId,
  'generationAdded': instance.generationAdded,
};
