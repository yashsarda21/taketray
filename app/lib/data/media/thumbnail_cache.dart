import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/platform/media_bridge.dart';

part 'thumbnail_cache.g.dart';

// Volume names and error codes only: never a path, a display name or an error
// message, which can hold either (D-10).
final Logger _log = Logger('thumbnails');

/// The longest side the bridge accepts (`Thumbnails.load` on the Kotlin side).
const int maxThumbnailPx = 4096;

/// The default size limit of the thumbnail folder (D-74).
const int defaultThumbnailCacheBytes = 64 * 1024 * 1024;

const String _picture = '.jpg';
const String _temp = '.tmp';

/// What one cached thumbnail is: which video (volume and MediaStore number),
/// as which video (size and date taken), at which size in pixels (D-74).
///
/// Its [fileName] is
/// `<volume>_<mediaStoreId>_<sizeBytes>_<dateTakenMs>_<sizePx>.jpg`.
/// The size and the date are part of it, so a number that Android gives to
/// another video, or a video edited in place, never reuses an old picture
/// (Review Focus 5). Equality uses exactly these five fields.
@immutable
class ClipThumbnailKey {
  const ClipThumbnailKey._({
    required this.volumeName,
    required this.mediaStoreId,
    required this.sizeBytes,
    required this.dateTakenMs,
    required this.sizePx,
  });

  /// The key of [clip] at [sizePx], or null when the clip has no thumbnail to
  /// ask for: it is a picked or a detached clip (a number of 0 or less), has
  /// no volume, or [sizePx] is below 1. A [sizePx] above [maxThumbnailPx] is
  /// the same picture as [maxThumbnailPx].
  static ClipThumbnailKey? of(Clip clip, int sizePx) {
    final id = clip.mediaStoreId;
    final volume = clip.volumeName;
    if (clip.source != ClipSource.mediaStore ||
        id == null ||
        id <= 0 ||
        volume == null ||
        volume.isEmpty ||
        sizePx < 1) {
      return null;
    }
    return ClipThumbnailKey._(
      volumeName: volume,
      mediaStoreId: id,
      sizeBytes: clip.fingerprint.sizeBytes,
      dateTakenMs: clip.fingerprint.dateTakenUtc.millisecondsSinceEpoch,
      sizePx: sizePx > maxThumbnailPx ? maxThumbnailPx : sizePx,
    );
  }

  /// The real volume name, as the bridge wants it.
  final String volumeName;
  final int mediaStoreId;
  final int sizeBytes;
  final int dateTakenMs;

  /// Both sides of the picture, 1 to [maxThumbnailPx].
  final int sizePx;

  /// The file name. Any character of the volume name outside `A-Z a-z 0-9 _ -`
  /// becomes `_`, so a crafted name cannot reach outside the folder.
  String get fileName {
    final volume = volumeName.replaceAll(RegExp('[^A-Za-z0-9_-]'), '_');
    return '${volume}_${mediaStoreId}_${sizeBytes}_${dateTakenMs}_$sizePx'
        '$_picture';
  }

  @override
  bool operator ==(Object other) =>
      other is ClipThumbnailKey &&
      other.volumeName == volumeName &&
      other.mediaStoreId == mediaStoreId &&
      other.sizeBytes == sizeBytes &&
      other.dateTakenMs == dateTakenMs &&
      other.sizePx == sizePx;

  @override
  int get hashCode =>
      Object.hash(volumeName, mediaStoreId, sizeBytes, dateTakenMs, sizePx);

  @override
  String toString() => 'ClipThumbnailKey($fileName)';
}

/// Thumbnails on disk, in front of [MediaBridge.thumbnail] (D-74).
///
/// - [load] returns the JPEG bytes of a clip's thumbnail: from the folder when
///   it is there (and then touches the file's modified time), else from the
///   bridge, which it then writes to the folder.
/// - A new file is written under a `.tmp` name and renamed into place, so a
///   kill between the two steps leaves no half picture under a real name.
/// - Loads of one key at the same time share one bridge call. A failure is not
///   remembered: the next call asks again.
/// - [prune] keeps the folder under [maxBytes]; the app runs it once at start.
class ThumbnailCache {
  /// [renameFile] replaces the step that moves the finished temp file into
  /// place; tests pass one that throws, to stand for a kill in between.
  ThumbnailCache(
    this._bridge,
    this._dir, {
    this.maxBytes = defaultThumbnailCacheBytes,
    this._clock = const Clock(),
    @visibleForTesting
    Future<void> Function(File temp, String finalPath)? renameFile,
  }) : _rename = renameFile ?? _renameTo;

  final MediaBridge _bridge;
  final Directory _dir;
  final Clock _clock;
  final Future<void> Function(File temp, String finalPath) _rename;

  /// The size [prune] keeps the folder under.
  final int maxBytes;

  final Map<String, Future<Uint8List?>> _inFlight = {};

  /// Temp files this cache is writing right now; [prune] leaves them alone.
  final Set<String> _writing = {};

  static Future<void> _renameTo(File temp, String finalPath) =>
      temp.rename(finalPath);

  /// The JPEG bytes of [clip]'s thumbnail at [sizePx] on both sides (1 to
  /// [maxThumbnailPx]; larger counts as [maxThumbnailPx]), or null.
  ///
  /// Null for a detached or picked clip and for [sizePx] below 1 (no bridge
  /// call), and when the bridge has no picture, answers with nothing, or
  /// fails (the failure is logged by volume name and code; nothing is
  /// cached). Never throws for those reasons.
  Future<Uint8List?> load(Clip clip, int sizePx) {
    final key = ClipThumbnailKey.of(clip, sizePx);
    if (key == null) return Future.value();
    return _inFlight[key.fileName] ??= _loadShared(key);
  }

  Future<Uint8List?> _loadShared(ClipThumbnailKey key) async {
    try {
      final onDisk = await _readFromDisk(key);
      if (onDisk != null) return onDisk;
      return await _fromBridge(key);
    } finally {
      // The awaits above cannot finish before `load` has stored this future,
      // so the entry exists by now.
      unawaited(_inFlight.remove(key.fileName));
    }
  }

  File _fileOf(ClipThumbnailKey key) => File('${_dir.path}/${key.fileName}');

  Future<Uint8List?> _readFromDisk(ClipThumbnailKey key) async {
    final file = _fileOf(key);
    final Uint8List bytes;
    try {
      bytes = await file.readAsBytes();
    } on FileSystemException {
      return null; // not there (or the folder is gone, or prune took it)
    }
    if (bytes.isEmpty) {
      // A write that was cut short in some other way: not a picture.
      await _tryDelete(file);
      return null;
    }
    try {
      await file.setLastModified(_clock.now());
    } on FileSystemException {
      // Only the pruning order suffers.
    }
    return bytes;
  }

  Future<Uint8List?> _fromBridge(ClipThumbnailKey key) async {
    final Uint8List? bytes;
    try {
      bytes = await _bridge.thumbnail(
        key.volumeName,
        key.mediaStoreId,
        key.sizePx,
        key.sizePx,
      );
    } on PlatformException catch (e) {
      _log.info('No thumbnail from volume ${key.volumeName}: ${e.code}');
      return null;
    } on Exception catch (e) {
      _log.info('No thumbnail from volume ${key.volumeName}: ${e.runtimeType}');
      return null;
    }
    if (bytes == null || bytes.isEmpty) return null;
    await _store(key, bytes);
    return bytes;
  }

  /// Temp file, then rename. A failure only costs the cache entry.
  Future<void> _store(ClipThumbnailKey key, Uint8List bytes) async {
    final temp = File('${_dir.path}/${key.fileName}$_temp');
    _writing.add(temp.path);
    try {
      await _dir.create(recursive: true);
      await temp.writeAsBytes(bytes, flush: true);
      await _rename(temp, _fileOf(key).path);
    } on Exception catch (e) {
      _log.warning(
        'Could not cache a thumbnail of volume ${key.volumeName}: '
        '${e.runtimeType}',
      );
      await _tryDelete(temp);
    } finally {
      _writing.remove(temp.path);
    }
  }

  /// Deletes the oldest thumbnails (by modified time) until the total is at
  /// most [maxBytes], and every `.tmp` file a crash left behind (those are
  /// not counted). A temp file this cache is writing right now is kept. Files
  /// with other names are left alone. A missing folder is fine.
  Future<void> prune() async {
    final pictures = <(File, FileStat)>[];
    try {
      await for (final entity in _dir.list()) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.last;
        if (name.endsWith(_temp)) {
          if (!_writing.contains(entity.path)) await _tryDelete(entity);
        } else if (name.endsWith(_picture)) {
          try {
            pictures.add((entity, entity.statSync()));
          } on FileSystemException {
            // Deleted meanwhile.
          }
        }
      }
    } on FileSystemException {
      return; // no folder yet
    }
    pictures.sort((a, b) {
      final byTime = a.$2.modified.compareTo(b.$2.modified);
      return byTime != 0 ? byTime : a.$1.path.compareTo(b.$1.path);
    });
    var total = pictures.fold<int>(0, (sum, p) => sum + p.$2.size);
    for (final (file, stat) in pictures) {
      if (total <= maxBytes) break;
      await _tryDelete(file);
      total -= stat.size;
    }
  }

  Future<void> _tryDelete(File file) async {
    try {
      await file.delete();
    } on FileSystemException {
      // Already gone.
    }
  }
}

/// `getApplicationCacheDirectory()/thumbs`: Android may empty the cache
/// folder, which the cache survives (D-74).
@Riverpod(keepAlive: true)
Future<Directory> thumbnailCacheDir(Ref ref) async {
  final cache = await getApplicationCacheDirectory();
  return Directory('${cache.path}/thumbs');
}

/// The one [ThumbnailCache] of the app. Task 10 calls `prune()` on it once at
/// start.
@Riverpod(keepAlive: true)
Future<ThumbnailCache> thumbnailCache(Ref ref) async => ThumbnailCache(
  ref.watch(mediaBridgeProvider),
  await ref.watch(thumbnailCacheDirProvider.future),
  clock: ref.watch(clockProvider),
);
