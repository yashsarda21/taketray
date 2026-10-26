import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:taketray/domain/models/enums.dart';

part 'reel_reference.freezed.dart';
part 'reel_reference.g.dart';

/// A link saved on a reel (an Instagram reel to copy the style of, say).
/// [url] is the normalised form from `normalizeReferenceUrl`.
@freezed
abstract class ReelReference with _$ReelReference {
  const factory ReelReference({
    required int id,
    required int reelId,
    required String url,
    required ReferenceSource source,
    required DateTime createdAt,
    String? label,
  }) = _ReelReference;

  factory ReelReference.fromJson(Map<String, dynamic> json) =>
      _$ReelReferenceFromJson(json);
}
