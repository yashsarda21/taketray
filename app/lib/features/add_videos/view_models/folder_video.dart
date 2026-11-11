import 'package:flutter/foundation.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/models/clip_fingerprint.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/domain/rules/clip_date.dart' as clip_date;

/// One video of a folder in Add videos: the phone's row, when it was shot,
/// and the stand-in clip its picture is asked for with.
@immutable
class FolderVideo {
  const FolderVideo._(this.video, this.shotAt, this.picture);

  /// [video] as Add videos shows it. [now] is the moment its folder page was
  /// read: a video with no plausible date is shot "now" ([shotAt]), and the
  /// same [now] for a whole page keeps its picture's key steady.
  factory FolderVideo.of(MediaVideo video, {required DateTime now}) {
    final shot = clip_date.shotAt(video, now: now);
    return FolderVideo._(
      video,
      shot,
      // Never stored: only the thumbnail cache sees it. Its identity and
      // fingerprint are those the clip saved for this video will have
      // (`clipFromVideo`), so the cache's file is the same picture To tag and
      // the reels later show (D-74).
      Clip(
        id: 0,
        source: ClipSource.mediaStore,
        mediaStoreId: video.mediaStoreId,
        volumeName: video.volumeName,
        fingerprint: ClipFingerprint(
          sizeBytes: video.sizeBytes,
          durationMs: video.durationMs ?? 0,
          dateTakenUtc: shot,
          displayName: video.displayName,
        ),
        width: video.width ?? 0,
        height: video.height ?? 0,
        mimeType: video.mimeType,
        firstSeenAt: now,
        missing: false,
      ),
    );
  }

  /// The phone's row. Never log its name or folder (D-10).
  final MediaVideo video;

  /// When it was shot (UTC), by the same rule a saved clip gets.
  final DateTime shotAt;

  /// What `ClipThumbnailImage` asks the cache for.
  final Clip picture;

  /// The video's MediaStore id: unique in a folder, which is on one volume.
  int get id => video.mediaStoreId;

  int get durationMs => video.durationMs ?? 0;

  bool get horizontal => (video.width ?? 0) > (video.height ?? 0);
}
