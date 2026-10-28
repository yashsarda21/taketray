import 'dart:async';

import 'package:flutter/services.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/domain/models/zone_entry.dart';
import 'package:taketray/platform/media_bridge.dart';

/// A [MediaVideo] for tests, with plain defaults: volume `external_primary`,
/// folder `DCIM/Camera/`, not pending, dated in 2026 (every date set).
///
/// [id] is the MediaStore id and [generation] its GENERATION_ADDED. Pass
/// `null` explicitly to leave a nullable field unknown.
MediaVideo fakeVideo({
  required int id,
  int generation = 1,
  String volume = 'external_primary',
  String folder = 'DCIM/Camera/',
  bool pending = false,
  int sizeBytes = 1000000,
  String? name,
  int? durationMs = 5000,
  int? dateTakenMs = 1780000000000,
  int? dateAddedSec = 1780000000,
  int? dateModifiedSec = 1780000000,
  int? width = 1920,
  int? height = 1080,
  String mimeType = 'video/mp4',
}) => MediaVideo(
  volumeName: volume,
  mediaStoreId: id,
  generationAdded: generation,
  sizeBytes: sizeBytes,
  durationMs: durationMs,
  dateTakenMs: dateTakenMs,
  dateAddedSec: dateAddedSec,
  dateModifiedSec: dateModifiedSec,
  displayName: name ?? 'VID_$id.mp4',
  relativePath: folder,
  width: width,
  height: height,
  mimeType: mimeType,
  isPending: pending,
);

/// A [MediaBridge] that answers from lists a test sets, with no phone.
///
/// - Settable state: [access], [volumeList], [videosByVolume] (volume name to
///   its videos), [folders], [thumbnails] (keyed by `(volume, id)`),
///   [currentZone], [zoneChanges], [cameraOpens].
/// - [onRequestAccess] gives the result of `requestAccess`, which also becomes
///   the new [access].
/// - [calls] logs the name of every call, in order, including a call that
///   fails. [clearedUpTo] logs the argument of every `clearZoneChangesUpTo`.
/// - [failNext] makes the next call of a method throw a `PlatformException`.
/// - [gate] makes the next call of a method wait. The answer is read when the
///   call starts, so a test can change the data while the call is paused, as
///   the phone could.
///
/// `videosAddedAfter`, `videosShotSince`, `allVideos` and `videosByIds` filter
/// the way the contract in `pigeons/media_api.dart` says. A folder matches a
/// video exactly and ignoring case, both written with exactly one trailing
/// '/'. `videosAddedAfter` includes pending rows; `videosShotSince` and
/// `allVideos` leave them out; `videosByIds` returns any row that exists.
class FakeMediaBridge implements MediaBridge {
  MediaAccess access = const MediaAccess(
    level: MediaAccessLevel.full,
    canAskAgain: true,
    sdkInt: 34,
  );

  /// Called by [requestAccess]; the default answers with the current
  /// [access].
  MediaAccess Function()? onRequestAccess;

  /// Named `volumeList` because `volumes` is the bridge method.
  List<MediaVolume> volumeList = [];

  final Map<String, List<MediaVideo>> videosByVolume = {};

  List<VideoFolder> folders = [];

  final Map<(String, int), Uint8List?> thumbnails = {};

  String currentZone = 'UTC';

  List<ZoneEntry> zoneChanges = [];

  bool cameraOpens = true;

  final List<String> calls = [];

  final List<int> clearedUpTo = [];

  final Map<String, int> _failures = {};
  final Map<String, Completer<void>> _gates = {};

  /// The next call of [method] throws a `PlatformException`. Calling it twice
  /// fails two calls.
  void failNext(String method) =>
      _failures[method] = (_failures[method] ?? 0) + 1;

  /// The next call of [method] waits until the returned completer completes.
  /// Used up by that one call.
  Completer<void> gate(String method) => _gates[method] = Completer<void>();

  /// Logs the call, throws a queued failure, reads the answer, then waits for
  /// a gate.
  Future<T> _call<T>(String method, T Function() answer) async {
    calls.add(method);
    final failures = _failures[method] ?? 0;
    if (failures > 0) {
      _failures[method] = failures - 1;
      throw PlatformException(
        code: 'fake-failure',
        message: '$method failed on purpose',
      );
    }
    final result = answer();
    final gate = _gates.remove(method);
    if (gate != null) await gate.future;
    return result;
  }

  @override
  Future<MediaAccess> accessReport() => _call('accessReport', () => access);

  @override
  Future<MediaAccess> requestAccess() => _call('requestAccess', () {
    final result = (onRequestAccess ?? () => access)();
    access = result;
    return result;
  });

  @override
  Future<void> openAppSettings() => _call('openAppSettings', () {});

  @override
  Future<List<MediaVolume>> volumes() =>
      _call('volumes', () => List.of(volumeList));

  @override
  Future<List<MediaVideo>> videosAddedAfter(
    String volumeName,
    int afterGeneration,
    List<String> folders,
    int limit,
  ) => _call('videosAddedAfter', () {
    final wanted = _folderSet(folders);
    final rows =
        _of(volumeName)
            .where(
              (v) =>
                  v.generationAdded > afterGeneration &&
                  wanted.contains(_normalize(v.relativePath)),
            )
            .toList()
          ..sort((a, b) {
            final byGeneration = a.generationAdded.compareTo(b.generationAdded);
            return byGeneration != 0
                ? byGeneration
                : a.mediaStoreId.compareTo(b.mediaStoreId);
          });
    return rows.take(limit < 0 ? 0 : limit).toList();
  });

  @override
  Future<List<MediaVideo>> videosByIds(String volumeName, List<int> ids) =>
      _call('videosByIds', () {
        final wanted = ids.toSet();
        return _of(volumeName)
            .where((v) => wanted.contains(v.mediaStoreId))
            .toList();
      });

  @override
  Future<List<MediaVideo>> allVideos(String volumeName) => _call(
    'allVideos',
    () => _of(volumeName).where((v) => !v.isPending).toList(),
  );

  @override
  Future<List<MediaVideo>> videosShotSince(
    String volumeName,
    List<String> folders,
    int sinceMs,
  ) => _call('videosShotSince', () {
    final wanted = _folderSet(folders);
    final sinceSec = sinceMs ~/ 1000;
    return _of(volumeName)
        .where(
          (v) =>
              !v.isPending &&
              wanted.contains(_normalize(v.relativePath)) &&
              ((v.dateTakenMs ?? -1) >= sinceMs ||
                  v.dateAddedSec == null ||
                  v.dateAddedSec! >= sinceSec ||
                  (v.dateModifiedSec ?? -1) >= sinceSec),
        )
        .toList();
  });

  @override
  Future<List<VideoFolder>> videoFolders() =>
      _call('videoFolders', () => List.of(folders));

  @override
  Future<Uint8List?> thumbnail(
    String volumeName,
    int mediaStoreId,
    int widthPx,
    int heightPx,
  ) => _call('thumbnail', () => thumbnails[(volumeName, mediaStoreId)]);

  @override
  Future<String> currentZoneId() => _call('currentZoneId', () => currentZone);

  @override
  Future<List<ZoneEntry>> pendingZoneChanges() =>
      _call('pendingZoneChanges', () => List.of(zoneChanges));

  @override
  Future<void> clearZoneChangesUpTo(int atMs) =>
      _call('clearZoneChangesUpTo', () {
        clearedUpTo.add(atMs);
        zoneChanges = [
          for (final c in zoneChanges)
            if (c.at.millisecondsSinceEpoch > atMs) c,
        ];
      });

  @override
  Future<bool> openVideoCamera() => _call('openVideoCamera', () => cameraOpens);

  List<MediaVideo> _of(String volumeName) =>
      videosByVolume[volumeName] ?? const [];

  Set<String> _folderSet(List<String> folders) =>
      folders.map(_normalize).toSet();

  /// Lower case, with exactly one trailing '/' and no leading one.
  static String _normalize(String path) {
    var start = 0;
    var end = path.length;
    while (start < end && path[start] == '/') {
      start++;
    }
    while (end > start && path[end - 1] == '/') {
      end--;
    }
    return '${path.substring(start, end).toLowerCase()}/';
  }
}
