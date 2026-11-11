// The contract between Dart and Kotlin for reading Android's media library
// (D-66). Pigeon turns this file into `lib/platform/media_api.g.dart` and
// `android/.../media/MediaApi.g.kt`; regenerate with
// `cd app && ../tool/dart run pigeon --input pigeons/media_api.dart`
// (`tool/check_generated` does it for you and fails on a stale copy).
//
// Kotlin is a thin pipe: it reads MediaStore and reports. Every decision
// (which video is which, what counts as new) is Dart code (see D-66).
//
// Privacy: nothing in this contract is ever logged with a display name or a
// folder (D-10).
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/platform/media_api.g.dart',
    kotlinOut: 'android/app/src/main/kotlin/app/taketray/media/MediaApi.g.kt',
    kotlinOptions: KotlinOptions(package: 'app.taketray.media'),
  ),
)
class MediaApiConfig;

/// How much of the media library the user lets TakeTray see.
enum MediaAccessLevelMsg { full, limited, denied }

class AccessReportMsg {
  AccessReportMsg({
    required this.level,
    required this.canAskAgain,
    required this.sdkInt,
  });

  MediaAccessLevelMsg level;
  bool canAskAgain;
  int sdkInt;
}

/// One storage volume. [version] is MediaStore's opaque version string (null
/// when the volume is not mounted); [generation] is its current generation.
class VolumeMsg {
  VolumeMsg({
    required this.volumeName,
    required this.version,
    required this.generation,
  });

  String volumeName;
  String? version;
  int generation;
}

/// One MediaStore video row. Times keep MediaStore's units: DATE_TAKEN in
/// milliseconds, DATE_ADDED and DATE_MODIFIED in seconds. Kotlin maps a null
/// SIZE to 0 and a null DISPLAY_NAME or RELATIVE_PATH to ''.
class VideoRowMsg {
  VideoRowMsg({
    required this.volumeName,
    required this.mediaStoreId,
    required this.generationAdded,
    required this.sizeBytes,
    required this.durationMs,
    required this.dateTakenMs,
    required this.dateAddedSec,
    required this.dateModifiedSec,
    required this.displayName,
    required this.relativePath,
    required this.width,
    required this.height,
    required this.mimeType,
    required this.isPending,
  });

  String volumeName;
  int mediaStoreId;
  int generationAdded;
  int sizeBytes;
  int? durationMs;
  int? dateTakenMs;
  int? dateAddedSec;
  int? dateModifiedSec;
  String displayName;
  String relativePath;
  int? width;
  int? height;
  String? mimeType;
  bool isPending;
}

/// A folder that holds videos, with how many.
class VideoFolderMsg {
  VideoFolderMsg({
    required this.volumeName,
    required this.relativePath,
    required this.videoCount,
  });

  String volumeName;
  String relativePath;
  int videoCount;
}

/// One video the user picked in Android's photo picker (or its document
/// picker fallback), identified by its content [uri]. Facts the provider does
/// not give stay null; Kotlin maps a null size to 0 and a null name to ''.
/// [persisted] is true when Android agreed to keep read access to [uri] across
/// restarts (takePersistableUriPermission did not throw).
class PickedVideoMsg {
  PickedVideoMsg({
    required this.uri,
    required this.sizeBytes,
    required this.durationMs,
    required this.dateTakenMs,
    required this.displayName,
    required this.width,
    required this.height,
    required this.mimeType,
    required this.persisted,
  });

  String uri;
  int sizeBytes;
  int? durationMs;
  int? dateTakenMs;
  String displayName;
  int? width;
  int? height;
  String? mimeType;
  bool persisted;
}

/// "From [atMs] (UTC milliseconds) the phone was in [zoneId]."
class ZoneChangeMsg {
  ZoneChangeMsg({required this.atMs, required this.zoneId});

  int atMs;
  String zoneId;
}

@HostApi()
abstract class MediaHostApi {
  AccessReportMsg accessReport();

  @async
  AccessReportMsg requestAccess();

  void openAppSettings();

  /// Async because it reads MediaStore (binder calls): Kotlin answers off
  /// the main thread.
  @async
  List<VolumeMsg> volumes();

  /// GENERATION_ADDED > afterGeneration, IS_PENDING rows included, rows in
  /// one of [folders] (exact folder, case-insensitive), ordered by
  /// GENERATION_ADDED asc, at most [limit] rows.
  @async
  List<VideoRowMsg> videosAddedAfter(
    String volumeName,
    int afterGeneration,
    List<String> folders,
    int limit,
  );

  @async
  List<VideoRowMsg> videosByIds(String volumeName, List<int> ids);

  /// Every non-pending video on the volume (for the rebuild resync).
  @async
  List<VideoRowMsg> allVideos(String volumeName);

  /// Non-pending videos in one of [folders] whose DATE_TAKEN (ms) >= sinceMs,
  /// or whose DATE_ADDED/DATE_MODIFIED (seconds) >= sinceMs ~/ 1000 (rounded
  /// down), or whose DATE_ADDED is null: a superset that Dart narrows with
  /// shotAt ("Add earlier videos").
  @async
  List<VideoRowMsg> videosShotSince(
    String volumeName,
    List<String> folders,
    int sinceMs,
  );

  @async
  List<VideoFolderMsg> videoFolders();

  /// JPEG bytes, or null when the video is gone or unreadable. [widthPx] and
  /// [heightPx] must be above 0 (otherwise the call fails) and each is capped
  /// at 4096; the picture's longer side is at most max(widthPx, heightPx).
  @async
  Uint8List? thumbnail(
    String volumeName,
    int mediaStoreId,
    int widthPx,
    int heightPx,
  );

  /// One page of a folder: non-pending videos with DURATION > 0 in exactly
  /// [relativePath] (case-insensitive; '' is the volume root), newest shot
  /// first (DATE_TAKEN, then DATE_ADDED, then DATE_MODIFIED), the id as the
  /// tie-break so pages never repeat. At most [limit] rows from [offset].
  /// A volume that is gone gives `[]`, never an error.
  @async
  List<VideoRowMsg> videosInFolder(
    String volumeName,
    String relativePath,
    int limit,
    int offset,
  );

  /// Opens Android's photo picker (the document picker where it is missing)
  /// and answers with what the user picked: `[]` when cancelled. Fails with
  /// code `busy` while one is already open, and `host-gone` if the activity
  /// closes first.
  @async
  List<PickedVideoMsg> pickVideos();

  /// Like [thumbnail], for a content [uri] (a picked video). Null when the
  /// video is gone or unreadable, or [uri] is not a content address.
  @async
  Uint8List? thumbnailOfUri(String uri, int widthPx, int heightPx);

  /// The subset of [uris] that can still be read. A uri whose read is refused
  /// (SecurityException) or has no row is left out; a failure of the whole
  /// call is an error, so "failed" is never read as "gone".
  @async
  List<String> readableUris(List<String> uris);

  /// Every address this app still holds a saved read grant for.
  @async
  List<String> persistedUris();

  /// Gives up the saved grants of exactly [uris]; one that fails does not stop
  /// the rest.
  @async
  void releaseUris(List<String> uris);

  String currentZoneId();

  /// The UTC offset, in milliseconds, of `zoneIds[i]` at `instantsMs[i]` (UTC
  /// milliseconds since the epoch), from the phone's own time-zone rules
  /// (`ZoneId.of(id).rules.getOffset(Instant.ofEpochMilli(ms))`), so it
  /// follows the phone's time-zone updates. An entry is null when its id is
  /// not a zone the phone knows (`DateTimeException`). The two lists must be
  /// the same length (otherwise the call fails). Async: Kotlin answers off the
  /// main thread, since a batch can hold hundreds of clips.
  @async
  List<int?> zoneOffsetsMs(List<String> zoneIds, List<int> instantsMs);

  List<ZoneChangeMsg> pendingZoneChanges();

  void clearZoneChangesUpTo(int atMs);

  bool openVideoCamera();
}
