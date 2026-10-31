// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_VolumeBaseline _$VolumeBaselineFromJson(Map<String, dynamic> json) =>
    _VolumeBaseline(
      version: json['version'] as String,
      generation: (json['generation'] as num).toInt(),
    );

Map<String, dynamic> _$VolumeBaselineToJson(_VolumeBaseline instance) =>
    <String, dynamic>{
      'version': instance.version,
      'generation': instance.generation,
    };

_ShootingState _$ShootingStateFromJson(Map<String, dynamic> json) =>
    _ShootingState(
      on: json['on'] as bool,
      baselines: (json['baselines'] as Map<String, dynamic>).map(
        (k, e) =>
            MapEntry(k, VolumeBaseline.fromJson(e as Map<String, dynamic>)),
      ),
      since: json['since'] == null
          ? null
          : DateTime.parse(json['since'] as String),
    );

Map<String, dynamic> _$ShootingStateToJson(_ShootingState instance) =>
    <String, dynamic>{
      'on': instance.on,
      'baselines': instance.baselines.map((k, e) => MapEntry(k, e.toJson())),
      'since': instance.since?.toIso8601String(),
    };
