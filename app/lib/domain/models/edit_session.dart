import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:taketray/domain/models/edit_copy.dart';
import 'package:taketray/domain/models/editor_app.dart';

part 'edit_session.freezed.dart';
part 'edit_session.g.dart';

/// A reel being edited in [editor]: the folder under `Movies/TakeTray/` its
/// copies go into (D-120).
///
/// The folder is recorded for every editor, also CapCut and Edits, which get
/// shares, not copies: a clip added later goes through the folder (spec §3).
@freezed
abstract class EditSession with _$EditSession {
  const factory EditSession({
    required int reelId,
    required EditorApp editor,
    required String folderName,
    required DateTime createdAt,
  }) = _EditSession;

  factory EditSession.fromJson(Map<String, dynamic> json) =>
      _$EditSessionFromJson(json);
}

/// What a reel's editing session holds now: the session, its copies and the
/// ids of the clips sent to the editor (D-120).
///
/// [copies] are the recorded copy files (by file name, ties by clip id); a
/// file the user deleted is still here until it is removed. [sentIds] may
/// hold ids of clips that no longer exist (no foreign key, D-54).
@freezed
abstract class EditState with _$EditState {
  const factory EditState({
    required EditSession session,
    required List<EditCopy> copies,
    required Set<int> sentIds,
  }) = _EditState;
}

/// One editing session as the storage screen and the copies reminder show
/// it (D-120).
@freezed
abstract class EditSessionSummary with _$EditSessionSummary {
  const factory EditSessionSummary({
    required int reelId,

    /// The reel's name now (it may differ from [folderName]: a rename keeps
    /// the folder).
    required String reelName,
    required EditorApp editor,
    required String folderName,
    required DateTime createdAt,

    /// How many copy files are recorded, and their total size in bytes.
    required int copyCount,
    required int copyBytes,

    /// When the newest recorded copy was made; null with no copies.
    DateTime? lastCopiedAt,
  }) = _EditSessionSummary;
}
