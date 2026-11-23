import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/domain/rules/reference_url.dart';

/// What a shared link is, for the source row of the Save reference sheet
/// (D-166). Finer than `ReferenceKind`: the card of a saved link cannot tell
/// an Instagram reel from a post (normalisation makes both `/p/`, D-154), but
/// the share screen sees the link as it was shared.
enum SharedLinkKind {
  instagramReel,
  instagramPost,
  instagramVideo,
  instagramProfile,
  youtubeShort,
  youtubeVideo,
  tiktokVideo,
  link,
}

/// An Instagram post path as the link was shared: `/reel/CODE`,
/// `/reels/CODE`, `/p/CODE` or `/tv/CODE`, optionally behind a `/user`
/// segment (`/someuser/reel/CODE`), the same shape `normalizeReferenceUrl`
/// rewrites. Group 1 is the kind of post.
final _instagramPostPath = RegExp(
  r'^/(?:[^/]+/)?(reel|reels|p|tv)/[A-Za-z0-9_-]+/*$',
);

/// The kind of the link [raw], **read before it is normalised**: normalising
/// turns `/reel/` into `/p/`, after which a reel could no longer be told from
/// a post.
///
/// - Instagram: `/reel/` or `/reels/` is a reel, `/p/` a post, `/tv/` a
///   video (each with a code, and optionally behind a user name); every
///   other path, a profile.
/// - YouTube: `/shorts/` is a Short, any other path a video.
/// - TikTok: a video.
/// - Anything else: [SharedLinkKind.link].
SharedLinkKind sharedLinkKindOf(Uri raw) => switch (referenceSourceOf(raw)) {
  ReferenceSource.instagram => switch (_instagramPostPath
      .firstMatch(raw.path)
      ?.group(1)) {
    'reel' || 'reels' => SharedLinkKind.instagramReel,
    'p' => SharedLinkKind.instagramPost,
    'tv' => SharedLinkKind.instagramVideo,
    _ => SharedLinkKind.instagramProfile,
  },
  ReferenceSource.youtube =>
    raw.path.startsWith('/shorts/')
        ? SharedLinkKind.youtubeShort
        : SharedLinkKind.youtubeVideo,
  ReferenceSource.tiktok => SharedLinkKind.tiktokVideo,
  ReferenceSource.link => SharedLinkKind.link,
};
