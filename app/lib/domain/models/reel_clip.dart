import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:taketray/domain/models/clip.dart';

part 'reel_clip.freezed.dart';

/// A clip as a reel's page shows it.
///
/// Built by `ClipsRepository.watchReelClips`.
@freezed
abstract class ReelClip with _$ReelClip {
  const factory ReelClip({
    required Clip clip,

    /// How many reels the clip is in, this one included (the "in N reels"
    /// badge shows when it is 2 or more).
    required int reelCount,

    /// When the clip joined this reel.
    required DateTime addedAt,
  }) = _ReelClip;
}
