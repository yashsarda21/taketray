// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reel.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Reel _$ReelFromJson(Map<String, dynamic> json) => _Reel(
  id: (json['id'] as num).toInt(),
  name: json['name'] as String,
  status: $enumDecode(_$ReelStatusEnumMap, json['status']),
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
  description: json['description'] as String?,
);

Map<String, dynamic> _$ReelToJson(_Reel instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'status': _$ReelStatusEnumMap[instance.status]!,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
  'description': instance.description,
};

const _$ReelStatusEnumMap = {
  ReelStatus.collecting: 'collecting',
  ReelStatus.ready: 'ready',
  ReelStatus.published: 'published',
};
