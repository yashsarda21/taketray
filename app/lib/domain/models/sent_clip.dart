import 'package:freezed_annotation/freezed_annotation.dart';

part 'sent_clip.freezed.dart';
part 'sent_clip.g.dart';

/// A clip that was sent to the editor of reel [reelId]'s editing session, as
/// a share or a copy (D-120). [sentAt] is the first time it was sent.
///
/// [clipId] has no foreign key (D-54): a clip removed from its last reel is
/// deleted, but the editor still has it.
@freezed
abstract class SentClip with _$SentClip {
  const factory SentClip({
    required int reelId,
    required int clipId,
    required DateTime sentAt,
  }) = _SentClip;

  factory SentClip.fromJson(Map<String, dynamic> json) =>
      _$SentClipFromJson(json);
}
