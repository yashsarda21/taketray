import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/models/reel.dart';

part 'reel_summary.freezed.dart';

/// A reel as Home's card shows it: the reel and the numbers about its clips.
///
/// Built by `ReelsRepository.watchReelSummaries` in one query for every reel.
@freezed
abstract class ReelSummary with _$ReelSummary {
  const factory ReelSummary({
    required Reel reel,

    /// Every clip in the reel, missing ones too.
    required int clipCount,

    /// The clips in the reel that are flagged missing.
    required int missingCount,

    /// The total length of the clips that are not missing, in milliseconds.
    required int liveDurationMs,

    /// The picture on the card: the oldest clip (by shooting time, ties by
    /// id) that has a picture to show: a MediaStore clip that is not missing
    /// and holds a MediaStore number above 0. Null when the reel has none.
    Clip? cover,
  }) = _ReelSummary;
}
