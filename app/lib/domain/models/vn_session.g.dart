// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vn_session.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_VnSession _$VnSessionFromJson(Map<String, dynamic> json) => _VnSession(
  reelId: (json['reelId'] as num).toInt(),
  folderName: json['folderName'] as String,
  createdAt: DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$VnSessionToJson(_VnSession instance) =>
    <String, dynamic>{
      'reelId': instance.reelId,
      'folderName': instance.folderName,
      'createdAt': instance.createdAt.toIso8601String(),
    };
