import 'package:taketray/l10n/gen/app_localizations.dart';

/// How many videos and photos, in one phrase (Phase 13, D-200, R13-1).
///
/// In a mixed count "clips" counts the videos only: "8 clips and 2 photos",
/// "1 clip and 1 photo". With no videos it is the photos alone ("2 photos"),
/// and with no photos it is exactly `reelCardClips(videos)`, so a reel with
/// no photos reads as it always did.
String clipsAndPhotosText(
  AppLocalizations l10n, {
  required int videos,
  required int photos,
}) {
  if (photos == 0) return l10n.reelCardClips(videos);
  if (videos == 0) return l10n.photoCount(photos);
  return l10n.clipsAndPhotos(
    l10n.reelCardClips(videos),
    l10n.photoCount(photos),
  );
}
