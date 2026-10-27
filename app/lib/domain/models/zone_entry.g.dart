// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'zone_entry.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ZoneEntry _$ZoneEntryFromJson(Map<String, dynamic> json) => _ZoneEntry(
  at: DateTime.parse(json['at'] as String),
  zoneId: json['zoneId'] as String,
);

Map<String, dynamic> _$ZoneEntryToJson(_ZoneEntry instance) =>
    <String, dynamic>{
      'at': instance.at.toIso8601String(),
      'zoneId': instance.zoneId,
    };
