import 'dart:typed_data';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/domain/models/zone_entry.dart';
import 'package:taketray/platform/media_api.g.dart';

part 'media_bridge.g.dart';

/// What the app can ask Android's media library, in domain types.
///
/// The Kotlin side only reads and reports; every decision (which video is
/// which, what counts as new) is Dart code on top of this seam (D-66). Tests
/// use `FakeMediaBridge` instead of a phone.
///
/// Every call is a [Future]. A failure on the Kotlin side arrives as a
/// `PlatformException`, unchanged: the caller decides what to do with it.
/// Never log a display name, a folder or a URI from these answers (D-10).
abstract interface class MediaBridge {
  /// What the app may read right now. Asks the user nothing.
  Future<MediaAccess> accessReport();

  /// Shows Android's permission dialog and returns the answer.
  Future<MediaAccess> requestAccess();

  /// Opens this app's page in Android's settings.
  Future<void> openAppSettings();

  /// Every volume with its MediaStore version and generation.
  Future<List<MediaVolume>> volumes();

  /// Videos with `GENERATION_ADDED > afterGeneration`, pending rows included,
  /// in one of [folders] (exact folder, case-insensitive), oldest generation
  /// first, at most [limit] of them.
  Future<List<MediaVideo>> videosAddedAfter(
    String volumeName,
    int afterGeneration,
    List<String> folders,
    int limit,
  );

  /// The videos with these MediaStore ids that still exist.
  Future<List<MediaVideo>> videosByIds(String volumeName, List<int> ids);

  /// Every non-pending video on the volume (for the rebuild resync).
  Future<List<MediaVideo>> allVideos(String volumeName);

  /// Non-pending videos in one of [folders] whose date taken (ms) is at or
  /// after [sinceMs], or whose date added / modified (seconds) is at or after
  /// `sinceMs ~/ 1000` (rounded down), or whose date added is unknown: a
  /// superset that the caller narrows ("Add earlier videos").
  Future<List<MediaVideo>> videosShotSince(
    String volumeName,
    List<String> folders,
    int sinceMs,
  );

  /// Every folder that holds videos, with a count.
  Future<List<VideoFolder>> videoFolders();

  /// JPEG bytes, or null when the video is gone or unreadable.
  Future<Uint8List?> thumbnail(
    String volumeName,
    int mediaStoreId,
    int widthPx,
    int heightPx,
  );

  /// The phone's current IANA time zone, e.g. `Europe/London`.
  Future<String> currentZoneId();

  /// The UTC offset in milliseconds of `zoneIds[i]` at `instantsMs[i]` (UTC
  /// milliseconds since the epoch), from the phone's own time-zone rules, for
  /// every i, in order; null for an id the phone does not know. The two lists
  /// must be the same length (otherwise it throws). One call for a whole
  /// batch (D-83).
  Future<List<int?>> zoneOffsetsMs(List<String> zoneIds, List<int> instantsMs);

  /// Zone changes that the native side saw while the app was not running.
  Future<List<ZoneEntry>> pendingZoneChanges();

  /// Forgets the zone changes at or before [atMs] (UTC milliseconds since the
  /// epoch), once they are safely recorded.
  Future<void> clearZoneChangesUpTo(int atMs);

  /// Opens the phone's camera in video mode; false when no app could.
  Future<bool> openVideoCamera();

  /// One page of a folder: finished videos with a duration in exactly
  /// [relativePath] (case-insensitive; '' is the volume root), newest shot
  /// first (date taken, then date added, then date modified), at most [limit]
  /// from [offset]. The order is stable, so pages never repeat a video. A
  /// volume that is gone gives an empty list.
  Future<List<MediaVideo>> videosInFolder(
    String volumeName,
    String relativePath,
    int limit,
    int offset,
  );

  /// Opens Android's photo picker (its document picker where that is missing)
  /// and returns what the user picked: empty when they cancelled. Throws a
  /// `PlatformException` with code `busy` while a picker is already open.
  Future<List<PickedVideo>> pickVideos();

  /// JPEG bytes of a picked video, or null when it is gone or unreadable.
  Future<Uint8List?> thumbnailOfUri(String uri, int widthPx, int heightPx);

  /// The subset of [uris] that can still be read, in the order given. Only a
  /// refused read or a missing row means gone. A failed call throws (any other
  /// error, and a provider that gives no cursor, code `no-cursor`): a caller
  /// must never read "failed" as "gone", nor release a grant after one.
  Future<List<String>> readableUris(List<String> uris);

  /// Every address the app still holds a saved read grant for.
  Future<List<String>> persistedUris();

  /// Gives up the saved grants of exactly [uris].
  Future<void> releaseUris(List<String> uris);
}

/// The address the viewer plays [clip] from, or null when it must not be
/// played (D-89).
///
/// - A MediaStore clip: `content://media/{volumeName}/video/media/{id}`, from
///   its stored identity only. A clip with no volume, or an id that is not a
///   real row (0, negative, unknown), has none.
/// - A picked clip: its picker address, as it was stored.
/// - **A clip flagged `missing` has none**, whatever its identity says: its
///   video is gone, and MediaStore may have given the number to another one.
///   Playing it would show the wrong video, the worst bug there is (spec §4).
///
/// Pure: no channel, nothing is read or checked on the phone. Never log the
/// result (D-10).
Uri? clipVideoUri(Clip clip) {
  if (clip.missing) return null;
  switch (clip.source) {
    case ClipSource.mediaStore:
      final id = clip.mediaStoreId;
      final volume = clip.volumeName;
      if (id == null || id <= 0 || volume == null || volume.isEmpty) {
        return null;
      }
      return Uri(
        scheme: 'content',
        host: 'media',
        pathSegments: [volume, 'video', 'media', '$id'],
      );
    case ClipSource.picker:
      final picked = clip.pickerUri;
      if (picked == null || picked.isEmpty) return null;
      // An address that does not parse is as unusable as none.
      return Uri.tryParse(picked);
  }
}

/// The [MediaBridge] that talks to Kotlin through the Pigeon-generated
/// [MediaHostApi]. It only converts between message and domain types.
class PigeonMediaBridge implements MediaBridge {
  /// [api] defaults to a real [MediaHostApi]; tests pass a stub.
  new([MediaHostApi? api]) : _api = api ?? MediaHostApi();

  final MediaHostApi _api;

  @override
  Future<MediaAccess> accessReport() async =>
      _access(await _api.accessReport());

  @override
  Future<MediaAccess> requestAccess() async =>
      _access(await _api.requestAccess());

  @override
  Future<void> openAppSettings() => _api.openAppSettings();

  @override
  Future<List<MediaVolume>> volumes() async => [
    for (final v in await _api.volumes())
      MediaVolume(
        name: v.volumeName,
        version: v.version,
        generation: v.generation,
      ),
  ];

  @override
  Future<List<MediaVideo>> videosAddedAfter(
    String volumeName,
    int afterGeneration,
    List<String> folders,
    int limit,
  ) async => _videos(
    await _api.videosAddedAfter(volumeName, afterGeneration, folders, limit),
  );

  @override
  Future<List<MediaVideo>> videosByIds(
    String volumeName,
    List<int> ids,
  ) async => _videos(await _api.videosByIds(volumeName, ids));

  @override
  Future<List<MediaVideo>> allVideos(String volumeName) async =>
      _videos(await _api.allVideos(volumeName));

  @override
  Future<List<MediaVideo>> videosShotSince(
    String volumeName,
    List<String> folders,
    int sinceMs,
  ) async => _videos(await _api.videosShotSince(volumeName, folders, sinceMs));

  @override
  Future<List<VideoFolder>> videoFolders() async => [
    for (final f in await _api.videoFolders())
      VideoFolder(
        volumeName: f.volumeName,
        relativePath: f.relativePath,
        videoCount: f.videoCount,
      ),
  ];

  @override
  Future<Uint8List?> thumbnail(
    String volumeName,
    int mediaStoreId,
    int widthPx,
    int heightPx,
  ) => _api.thumbnail(volumeName, mediaStoreId, widthPx, heightPx);

  @override
  Future<String> currentZoneId() => _api.currentZoneId();

  @override
  Future<List<int?>> zoneOffsetsMs(
    List<String> zoneIds,
    List<int> instantsMs,
  ) => _api.zoneOffsetsMs(zoneIds, instantsMs);

  @override
  Future<List<ZoneEntry>> pendingZoneChanges() async => [
    for (final c in await _api.pendingZoneChanges())
      ZoneEntry(
        at: DateTime.fromMillisecondsSinceEpoch(c.atMs, isUtc: true),
        zoneId: c.zoneId,
      ),
  ];

  @override
  Future<void> clearZoneChangesUpTo(int atMs) =>
      _api.clearZoneChangesUpTo(atMs);

  @override
  Future<bool> openVideoCamera() => _api.openVideoCamera();

  @override
  Future<List<MediaVideo>> videosInFolder(
    String volumeName,
    String relativePath,
    int limit,
    int offset,
  ) async => _videos(
    await _api.videosInFolder(volumeName, relativePath, limit, offset),
  );

  @override
  Future<List<PickedVideo>> pickVideos() async => [
    for (final p in await _api.pickVideos())
      PickedVideo(
        uri: p.uri,
        sizeBytes: p.sizeBytes,
        displayName: p.displayName,
        persisted: p.persisted,
        durationMs: p.durationMs,
        dateTakenMs: p.dateTakenMs,
        width: p.width,
        height: p.height,
        mimeType: p.mimeType,
      ),
  ];

  @override
  Future<Uint8List?> thumbnailOfUri(String uri, int widthPx, int heightPx) =>
      _api.thumbnailOfUri(uri, widthPx, heightPx);

  @override
  Future<List<String>> readableUris(List<String> uris) =>
      _api.readableUris(uris);

  @override
  Future<List<String>> persistedUris() => _api.persistedUris();

  @override
  Future<void> releaseUris(List<String> uris) => _api.releaseUris(uris);
}

MediaAccess _access(AccessReportMsg msg) => MediaAccess(
  level: switch (msg.level) {
    MediaAccessLevelMsg.full => MediaAccessLevel.full,
    MediaAccessLevelMsg.limited => MediaAccessLevel.limited,
    MediaAccessLevelMsg.denied => MediaAccessLevel.denied,
  },
  canAskAgain: msg.canAskAgain,
  sdkInt: msg.sdkInt,
);

List<MediaVideo> _videos(List<VideoRowMsg> rows) => [
  for (final r in rows)
    MediaVideo(
      volumeName: r.volumeName,
      mediaStoreId: r.mediaStoreId,
      generationAdded: r.generationAdded,
      sizeBytes: r.sizeBytes,
      durationMs: r.durationMs,
      dateTakenMs: r.dateTakenMs,
      dateAddedSec: r.dateAddedSec,
      dateModifiedSec: r.dateModifiedSec,
      displayName: r.displayName,
      relativePath: r.relativePath,
      width: r.width,
      height: r.height,
      mimeType: r.mimeType ?? defaultVideoMimeType,
      isPending: r.isPending,
    ),
];

@Riverpod(keepAlive: true)
MediaBridge mediaBridge(Ref ref) => PigeonMediaBridge();
