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

    /// Every clip in the reel, missing ones too, photos included.
    required int clipCount,

    /// The clips in the reel that are flagged missing.
    required int missingCount,

    /// The total length of the clips that are not missing, in milliseconds
    /// (a photo's is 0, so this is the live videos').
    required int liveDurationMs,

    /// The photos among [clipCount], missing ones too (Phase 13, D-200): a
    /// clip whose type is an image type, in any case.
    @Default(0) int photoCount,

    /// The picture on the card: the oldest clip (by shooting time, ties by
    /// id) that has a picture to show (`hasPicture`): a MediaStore clip that
    /// is not missing and holds a MediaStore number above 0, or a picked clip
    /// (a photo too, D-200) that is not missing. Null when the reel has none.
    Clip? cover,

    /// How many references (saved links) the reel has. The repository's query
    /// does not read it: Home joins it in from
    /// `ReferencesRepository.watchCounts` (D-158), so it is 0 elsewhere.
    @Default(0) int referenceCount,
  }) = _ReelSummary;
}
