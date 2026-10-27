// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vn_copy.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_VnCopy _$VnCopyFromJson(Map<String, dynamic> json) => _VnCopy(
  reelId: (json['reelId'] as num).toInt(),
  clipId: (json['clipId'] as num).toInt(),
  copyMediaStoreId: (json['copyMediaStoreId'] as num).toInt(),
  fileName: json['fileName'] as String,
  sizeBytes: (json['sizeBytes'] as num).toInt(),
);

Map<String, dynamic> _$VnCopyToJson(_VnCopy instance) => <String, dynamic>{
  'reelId': instance.reelId,
  'clipId': instance.clipId,
  'copyMediaStoreId': instance.copyMediaStoreId,
  'fileName': instance.fileName,
  'sizeBytes': instance.sizeBytes,
};
