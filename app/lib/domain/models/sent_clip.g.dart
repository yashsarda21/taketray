// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sent_clip.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SentClip _$SentClipFromJson(Map<String, dynamic> json) => _SentClip(
  reelId: (json['reelId'] as num).toInt(),
  clipId: (json['clipId'] as num).toInt(),
  sentAt: DateTime.parse(json['sentAt'] as String),
);

Map<String, dynamic> _$SentClipToJson(_SentClip instance) => <String, dynamic>{
  'reelId': instance.reelId,
  'clipId': instance.clipId,
  'sentAt': instance.sentAt.toIso8601String(),
};
