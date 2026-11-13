// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'edit_copy.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_EditCopy _$EditCopyFromJson(Map<String, dynamic> json) => _EditCopy(
  reelId: (json['reelId'] as num).toInt(),
  clipId: (json['clipId'] as num).toInt(),
  copyMediaStoreId: (json['copyMediaStoreId'] as num).toInt(),
  fileName: json['fileName'] as String,
  sizeBytes: (json['sizeBytes'] as num).toInt(),
  copiedAt: DateTime.parse(json['copiedAt'] as String),
);

Map<String, dynamic> _$EditCopyToJson(_EditCopy instance) => <String, dynamic>{
  'reelId': instance.reelId,
  'clipId': instance.clipId,
  'copyMediaStoreId': instance.copyMediaStoreId,
  'fileName': instance.fileName,
  'sizeBytes': instance.sizeBytes,
  'copiedAt': instance.copiedAt.toIso8601String(),
};
