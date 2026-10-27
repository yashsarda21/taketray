// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reel_reference.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ReelReference _$ReelReferenceFromJson(Map<String, dynamic> json) =>
    _ReelReference(
      id: (json['id'] as num).toInt(),
      reelId: (json['reelId'] as num).toInt(),
      url: json['url'] as String,
      source: $enumDecode(_$ReferenceSourceEnumMap, json['source']),
      createdAt: DateTime.parse(json['createdAt'] as String),
      label: json['label'] as String?,
    );

Map<String, dynamic> _$ReelReferenceToJson(_ReelReference instance) =>
    <String, dynamic>{
      'id': instance.id,
      'reelId': instance.reelId,
      'url': instance.url,
      'source': _$ReferenceSourceEnumMap[instance.source]!,
      'createdAt': instance.createdAt.toIso8601String(),
      'label': instance.label,
    };

const _$ReferenceSourceEnumMap = {
  ReferenceSource.instagram: 'instagram',
  ReferenceSource.youtube: 'youtube',
  ReferenceSource.tiktok: 'tiktok',
  ReferenceSource.link: 'link',
};
