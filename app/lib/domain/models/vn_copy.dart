import 'package:freezed_annotation/freezed_annotation.dart';

part 'vn_copy.freezed.dart';
part 'vn_copy.g.dart';

/// One file TakeTray copied into a VN folder. [clipId] may name a clip that
/// has since been deleted (D-54): the copy is still on the phone.
@freezed
abstract class VnCopy with _$VnCopy {
  const factory VnCopy({
    required int reelId,
    required int clipId,
    required int copyMediaStoreId,
    required String fileName,
    required int sizeBytes,
  }) = _VnCopy;

  factory VnCopy.fromJson(Map<String, dynamic> json) => _$VnCopyFromJson(json);
}
