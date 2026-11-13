// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'edit_session.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_EditSession _$EditSessionFromJson(Map<String, dynamic> json) => _EditSession(
  reelId: (json['reelId'] as num).toInt(),
  editor: $enumDecode(_$EditorAppEnumMap, json['editor']),
  folderName: json['folderName'] as String,
  createdAt: DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$EditSessionToJson(_EditSession instance) =>
    <String, dynamic>{
      'reelId': instance.reelId,
      'editor': _$EditorAppEnumMap[instance.editor]!,
      'folderName': instance.folderName,
      'createdAt': instance.createdAt.toIso8601String(),
    };

const _$EditorAppEnumMap = {
  EditorApp.capcut: 'capcut',
  EditorApp.edits: 'edits',
  EditorApp.vn: 'vn',
};
