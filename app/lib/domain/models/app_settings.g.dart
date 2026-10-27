// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AppSettings _$AppSettingsFromJson(Map<String, dynamic> json) => _AppSettings(
  watchedFolders:
      (json['watchedFolders'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const ['DCIM/Camera'],
  eveningReminderEnabled: json['eveningReminderEnabled'] as bool? ?? true,
  eveningReminderMinutes:
      (json['eveningReminderMinutes'] as num?)?.toInt() ?? 1260,
);

Map<String, dynamic> _$AppSettingsToJson(_AppSettings instance) =>
    <String, dynamic>{
      'watchedFolders': instance.watchedFolders,
      'eveningReminderEnabled': instance.eveningReminderEnabled,
      'eveningReminderMinutes': instance.eveningReminderMinutes,
    };
