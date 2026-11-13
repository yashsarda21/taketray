import 'package:flutter/foundation.dart';
import 'package:taketray/domain/models/editor_app.dart';

/// One clip of a [CopyJobPlan]: the clip, the file name Dart chose for its
/// copy (D-119, R2) and its size as Dart knew it.
typedef CopyPlanItem = ({int clipId, String fileName, int sizeBytes});

/// The copy job that is running or waiting, saved before it starts so a
/// restart can find its copies again (D-118 R4, D-123).
///
/// A phone-state row (`PhoneStateRepository.copyJobPlanKey`, D-71): never
/// exported, and an import forgets it. One at a time (R4). After a restart,
/// TakeTray's own finished rows in [folderName] whose file name is an item's
/// are that item's copies; there is no other record.
///
/// [editor] and [startedSession] say which screens follow the job (the first
/// VN copy or an add-later batch), also after a restart.
@immutable
class CopyJobPlan {
  CopyJobPlan({
    required this.jobId,
    required this.reelId,
    required this.editor,
    required this.folderName,
    required this.startedSession,
    required List<CopyPlanItem> items,
  }) : items = List.unmodifiable(items);

  final String jobId;
  final int reelId;
  final EditorApp editor;

  /// The folder under `Movies/TakeTray/`: the session's.
  final String folderName;

  /// Whether this job started the reel's editing session (the first VN copy):
  /// cancelling it ends the session again when nothing is left in it.
  final bool startedSession;

  /// In shooting order, the order the engine copies them.
  final List<CopyPlanItem> items;

  /// The JSON stored in the settings table.
  Map<String, Object?> toJson() => {
    'jobId': jobId,
    'reelId': reelId,
    'editor': editor.name,
    'folderName': folderName,
    'startedSession': startedSession,
    'items': [
      for (final item in items)
        {
          'clipId': item.clipId,
          'fileName': item.fileName,
          'sizeBytes': item.sizeBytes,
        },
    ],
  };

  /// The plan in [json], or null when any part of it is missing or of the
  /// wrong type (an unreadable plan is no plan).
  static CopyJobPlan? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final jobId = json['jobId'];
    final reelId = json['reelId'];
    final editorName = json['editor'];
    final folderName = json['folderName'];
    final startedSession = json['startedSession'];
    final rawItems = json['items'];
    if (jobId is! String ||
        jobId.isEmpty ||
        reelId is! int ||
        editorName is! String ||
        folderName is! String ||
        folderName.isEmpty ||
        startedSession is! bool ||
        rawItems is! List<dynamic>) {
      return null;
    }
    final editor = EditorApp.values.where((e) => e.name == editorName);
    if (editor.isEmpty) return null;
    final items = <CopyPlanItem>[];
    for (final raw in rawItems) {
      if (raw is! Map<String, dynamic>) return null;
      final clipId = raw['clipId'];
      final fileName = raw['fileName'];
      final sizeBytes = raw['sizeBytes'];
      if (clipId is! int ||
          fileName is! String ||
          fileName.isEmpty ||
          sizeBytes is! int) {
        return null;
      }
      items.add((clipId: clipId, fileName: fileName, sizeBytes: sizeBytes));
    }
    return CopyJobPlan(
      jobId: jobId,
      reelId: reelId,
      editor: editor.single,
      folderName: folderName,
      startedSession: startedSession,
      items: items,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CopyJobPlan &&
      other.jobId == jobId &&
      other.reelId == reelId &&
      other.editor == editor &&
      other.folderName == folderName &&
      other.startedSession == startedSession &&
      listEquals(other.items, items);

  @override
  int get hashCode => Object.hash(
    jobId,
    reelId,
    editor,
    folderName,
    startedSession,
    Object.hashAll(items),
  );

  // No folder or file name in a log line (D-10).
  @override
  String toString() =>
      'CopyJobPlan($jobId, reel $reelId, ${editor.name}, '
      '${items.length} items, startedSession: $startedSession)';
}
