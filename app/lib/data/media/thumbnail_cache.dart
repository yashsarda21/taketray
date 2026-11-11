import 'dart:async';
import 'dart:convert';
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

/// How long one bridge call may take before the load gives up (D-74). Android
/// answers in milliseconds; a call that never returns would otherwise keep
/// the tile, and every load sharing it, waiting for ever.
const Duration defaultBridgeTimeout = Duration(seconds: 15);

/// The default size limit of the thumbnail folder (D-74).
const int defaultThumbnailCacheBytes = 64 * 1024 * 1024;

const String _picture = '.jpg';
const String _temp = '.tmp';

/// What one cached thumbnail is: which video, as which video (size and date
/// taken), at which size in pixels (D-74).
///
/// - A MediaStore clip is its volume and MediaStore number. Its [fileName] is
///   `<volume>_<mediaStoreId>_<sizeBytes>_<dateTakenMs>_<sizePx>.jpg`.
/// - A picked clip (Phase 7) is its picker address. Its [fileName] is
///   `picked-<hash>_<sizeBytes>_<dateTakenMs>_<sizePx>.jpg`, where `<hash>` is
///   the FNV-1a 64-bit hash of the address's UTF-8 bytes in 16 hex digits:
///   **the address itself is never in a file name** (nor in [toString] or a
///   log line, D-10). The name has three underscores and a MediaStore name at
///   least four, so the two never meet.
///
/// The size and the date are part of both, so a number that Android gives to
/// another video, or a video edited in place, never reuses an old picture
/// (Review Focus 5). Equality uses the identity (the full address for a
/// picked clip, not its hash) and these three fields.
@immutable
class ClipThumbnailKey {
  const ClipThumbnailKey._({
    required this.sizeBytes,
    required this.dateTakenMs,
    required this.sizePx,
    this.volumeName,
    this.mediaStoreId,
    this.pickerUri,
  });

  /// The key of [clip] at [sizePx], or null when the clip has no thumbnail to
  /// ask for: a detached MediaStore clip (a number of 0 or less), one with no
  /// volume, a picked clip with no address, or [sizePx] below 1. A [sizePx]
  /// above [maxThumbnailPx] is the same picture as [maxThumbnailPx].
  static ClipThumbnailKey? of(Clip clip, int sizePx) {
    if (sizePx < 1) return null;
    final px = sizePx > maxThumbnailPx ? maxThumbnailPx : sizePx;
    final sizeBytes = clip.fingerprint.sizeBytes;
    final dateTakenMs = clip.fingerprint.dateTakenUtc.millisecondsSinceEpoch;
    switch (clip.source) {
      case ClipSource.mediaStore:
        final id = clip.mediaStoreId;
        final volume = clip.volumeName;
        if (id == null || id <= 0 || volume == null || volume.isEmpty) {
          return null;
        }
        return ClipThumbnailKey._(
          volumeName: volume,
          mediaStoreId: id,
          sizeBytes: sizeBytes,
          dateTakenMs: dateTakenMs,
          sizePx: px,
        );
      case ClipSource.picker:
        final uri = clip.pickerUri;
        if (uri == null || uri.isEmpty) return null;
        return ClipThumbnailKey._(
          pickerUri: uri,
          sizeBytes: sizeBytes,
          dateTakenMs: dateTakenMs,
          sizePx: px,
        );
    }
  }

  /// The real volume name, as the bridge wants it; null for a picked clip.
  final String? volumeName;

  /// Null for a picked clip.
  final int? mediaStoreId;

  /// The picker address, for the bridge only; null for a MediaStore clip.
  /// Never print or log it (D-10).
  final String? pickerUri;

  final int sizeBytes;
  final int dateTakenMs;

  /// Both sides of the picture, 1 to [maxThumbnailPx].
  final int sizePx;

  /// The file name. Any character of the volume name outside `A-Z a-z 0-9 _ -`
  /// becomes `_`, so a crafted name cannot reach outside the folder; a picked
  /// clip's name holds only hex digits of its address's hash.
  String get fileName {
    final uri = pickerUri;
    if (uri != null) {
      return 'picked-${addressHash(uri)}_${sizeBytes}_${dateTakenMs}_$sizePx'
          '$_picture';
    }
    final volume = volumeName!.replaceAll(RegExp('[^A-Za-z0-9_-]'), '_');
    return '${volume}_${mediaStoreId}_${sizeBytes}_${dateTakenMs}_$sizePx'
        '$_picture';
  }

  /// What a log line may say about this key's video: the volume name, or
  /// "a picked video" (never the address, D-10).
  String get logLabel =>
      pickerUri == null ? 'volume $volumeName' : 'a picked video';

  @override
  bool operator ==(Object other) =>
      other is ClipThumbnailKey &&
      other.volumeName == volumeName &&
      other.mediaStoreId == mediaStoreId &&
      other.pickerUri == pickerUri &&
      other.sizeBytes == sizeBytes &&
      other.dateTakenMs == dateTakenMs &&
      other.sizePx == sizePx;

  @override
  int get hashCode => Object.hash(
    volumeName,
    mediaStoreId,
    pickerUri,
    sizeBytes,
    dateTakenMs,
    sizePx,
  );

  @override
  String toString() => 'ClipThumbnailKey($fileName)';
}

/// The FNV-1a 64-bit hash of [text]'s UTF-8 bytes, as 16 lowercase hex
/// digits: the same on every run and every phone, so a picked clip's file
/// name survives a restart (Dart's own `hashCode` gives no such promise).
@visibleForTesting
String addressHash(String text) {
  // 64-bit arithmetic on the Dart VM wraps, as FNV needs. The app runs on
  // Android only, never compiled to JavaScript.
  // ignore: avoid_js_rounded_ints
  var hash = 0xcbf29ce484222325;
  for (final byte in utf8.encode(text)) {
    hash ^= byte;
    hash *= 0x100000001b3;
  }
  String half(int v) => v.toRadixString(16).padLeft(8, '0');
  return half(hash >>> 32) + half(hash & 0xFFFFFFFF);
}

/// Thumbnails on disk, in front of [MediaBridge.thumbnail] and, for picked
/// clips, [MediaBridge.thumbnailOfUri] (D-74).
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
    @visibleForTesting
    Stream<FileSystemEntity> Function(Directory dir)? listDir,
    @visibleForTesting this._bridgeTimeout = defaultBridgeTimeout,
  }) : _rename = renameFile ?? _renameTo,
       _list = listDir ?? _listOf;

  final MediaBridge _bridge;
  final Directory _dir;
  final Clock _clock;
  final Future<void> Function(File temp, String finalPath) _rename;
  final Stream<FileSystemEntity> Function(Directory dir) _list;
  final Duration _bridgeTimeout;

  /// The size [prune] keeps the folder under.
  final int maxBytes;

  final Map<String, Future<Uint8List?>> _inFlight = {};

  /// Temp files this cache is writing right now; [prune] leaves them alone.
  final Set<String> _writing = {};

  static Stream<FileSystemEntity> _listOf(Directory dir) => dir.list();

  static Future<void> _renameTo(File temp, String finalPath) =>
      temp.rename(finalPath);

  /// The JPEG bytes of [clip]'s thumbnail at [sizePx] on both sides (1 to
  /// [maxThumbnailPx]; larger counts as [maxThumbnailPx]), or null.
  ///
  /// Null for a clip with no key (detached, no volume, a picked clip with no
  /// address) and for [sizePx] below 1 (no bridge call), and when the bridge
  /// has no picture, answers with nothing, or fails (the failure is logged by
  /// volume name, or as "a picked video", and code; nothing is cached).
  /// Never throws for those reasons.
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
    if (!_looksLikeJpeg(bytes)) {
      // Empty, cut short or foreign: not a picture (the bridge's are JPEG).
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

  static bool _looksLikeJpeg(Uint8List bytes) =>
      bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xD8;

  Future<Uint8List?> _fromBridge(ClipThumbnailKey key) async {
    final Uint8List? bytes;
    final uri = key.pickerUri;
    try {
      bytes =
          await (uri == null
                  ? _bridge.thumbnail(
                      key.volumeName!,
                      key.mediaStoreId!,
                      key.sizePx,
                      key.sizePx,
                    )
                  : _bridge.thumbnailOfUri(uri, key.sizePx, key.sizePx))
              .timeout(_bridgeTimeout);
    } on TimeoutException {
      _log.info('No thumbnail from ${key.logLabel}: timeout');
      return null;
    } on PlatformException catch (e) {
      _log.info('No thumbnail from ${key.logLabel}: ${e.code}');
      return null;
    } on Exception catch (e) {
      _log.info('No thumbnail from ${key.logLabel}: ${e.runtimeType}');
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
        'Could not cache a thumbnail of ${key.logLabel}: '
        '${e.runtimeType}',
      );
      await _tryDelete(temp);
    } finally {
      _writing.remove(temp.path);
    }
  }

  /// Deletes the file of [clip] at [sizePx], when its bytes turned out not to
  /// be a picture (the decoder refused them). A no-op when there is no such
  /// file, when the clip has no key, or when a load of that key is running
  /// right now: that load may be writing a fresh file, and if what it returns
  /// is bad too, its own tile discards it afterwards.
  Future<void> discard(Clip clip, int sizePx) async {
    final key = ClipThumbnailKey.of(clip, sizePx);
    if (key == null || _inFlight.containsKey(key.fileName)) return;
    await _tryDelete(_fileOf(key));
  }

  /// Deletes the oldest thumbnails (by modified time) until the total is at
  /// most [maxBytes], and every `.tmp` file a crash left behind (those are
  /// not counted). A temp file this cache is writing right now is kept. Files
  /// with other names are left alone. A missing folder is fine.
  Future<void> prune() async {
    final pictures = <(File, FileStat)>[];
    try {
      await for (final entity in _list(_dir)) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.last;
        if (name.endsWith(_temp)) {
          if (!_writing.contains(entity.path)) await _tryDelete(entity);
        } else if (name.endsWith(_picture)) {
          // The lint prefers sync calls; this runs once at start, off the
          // frame path, and a sync stat would block on every file.
          // ignore: avoid_slow_async_io
          final stat = await entity.stat();
          // Deleted since the listing: nothing to count or delete.
          if (stat.type != FileSystemEntityType.notFound) {
            pictures.add((entity, stat));
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

/// The one [ThumbnailCache] of the app. `MediaLifecycle` calls `prune()` on
/// it once at start (D-75).
@Riverpod(keepAlive: true)
Future<ThumbnailCache> thumbnailCache(Ref ref) async => ThumbnailCache(
  ref.watch(mediaBridgeProvider),
  await ref.watch(thumbnailCacheDirProvider.future),
  clock: ref.watch(clockProvider),
);
