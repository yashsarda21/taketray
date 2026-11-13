import 'package:freezed_annotation/freezed_annotation.dart';

part 'edit_copy.freezed.dart';
part 'edit_copy.g.dart';

/// One file TakeTray copied into a reel's editing folder (D-120). [clipId]
/// may name a clip that has since been deleted (D-54): the copy is still on
/// the phone.
///
/// [copiedAt] is when the copy was recorded. A copy made before schema v2
/// carries its session's start instead (the migration had no better time).
@freezed
abstract class EditCopy with _$EditCopy {
  const factory EditCopy({
    required int reelId,
    required int clipId,
    required int copyMediaStoreId,
    required String fileName,
    required int sizeBytes,
    required DateTime copiedAt,
  }) = _EditCopy;

  factory EditCopy.fromJson(Map<String, dynamic> json) =>
      _$EditCopyFromJson(json);
}
