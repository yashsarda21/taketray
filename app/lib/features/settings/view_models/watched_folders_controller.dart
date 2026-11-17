import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/core/guarded.dart';
import 'package:taketray/data/repositories/settings_repository.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/domain/rules/browse_folders.dart';
import 'package:taketray/domain/rules/chat_folders.dart';
import 'package:taketray/features/media_access/view_models/media_access_controller.dart';
import 'package:taketray/features/settings/view_models/settings_controller.dart';
import 'package:taketray/platform/files_bridge.dart';
import 'package:taketray/platform/media_bridge.dart';

part 'watched_folders_controller.g.dart';

// Counts and error types only: never a folder's name or path (D-10).
final Logger _log = Logger('watchedFolders');

/// One row of the Watched folders screen.
///
/// [relativePath] is the folder's path on the storage, with no slash at
/// either end (`DCIM/Camera`); it never says which storage, because the
/// settings do not either (a folder on the SD card is the same watched
/// folder as the phone's of that name). [name] is its last segment (`''` for
/// a storage root). [videoCount] is null when it is not known: [gone], or
/// TakeTray cannot read the phone's folders. [chat] is a chat app's folder
/// (`isChatFolder`), whose clips are dated when they arrived. [gone] is a
/// watched folder that is not on the phone now.
@immutable
class WatchedRow {
  const WatchedRow({
    required this.relativePath,
    required this.name,
    required this.videoCount,
    required this.watched,
    required this.chat,
    required this.gone,
  });

  final String relativePath;
  final String name;
  final int? videoCount;
  final bool watched;
  final bool chat;
  final bool gone;

  WatchedRow copyWith({bool? watched}) => WatchedRow(
    relativePath: relativePath,
    name: name,
    videoCount: videoCount,
    watched: watched ?? this.watched,
    chat: chat,
    gone: gone,
  );

  @override
  bool operator ==(Object other) =>
      other is WatchedRow &&
      other.relativePath == relativePath &&
      other.name == name &&
      other.videoCount == videoCount &&
      other.watched == watched &&
      other.chat == chat &&
      other.gone == gone;

  @override
  int get hashCode =>
      Object.hash(relativePath, name, videoCount, watched, chat, gone);

  @override
  String toString() =>
      'WatchedRow($relativePath, $name, $videoCount, watched: $watched, '
      'chat: $chat, gone: $gone)';
}

/// What the Watched folders screen shows: the [rows], and whether TakeTray
/// has [fullAccess] to the videos (without it only the watched folders are
/// listed, and the screen offers **Allow all**).
@immutable
class WatchedFoldersView {
  const WatchedFoldersView({required this.rows, required this.fullAccess});

  final List<WatchedRow> rows;
  final bool fullAccess;

  @override
  bool operator ==(Object other) =>
      other is WatchedFoldersView &&
      other.fullAccess == fullAccess &&
      listEquals(other.rows, rows);

  @override
  int get hashCode => Object.hash(fullAccess, Object.hashAll(rows));

  @override
  String toString() => 'WatchedFoldersView(fullAccess: $fullAccess, $rows)';
}

/// What `addFolder` did, for the screen's message.
///
/// - [watched]: the folder is watched now (it was added, or turned on, or was
///   already watched). No message.
/// - [cancelled]: the user left the picker. No message.
/// - [unsupportedFolder]: not a folder on the phone or its SD card (Downloads,
///   a cloud drive, a USB drive, the storage root).
/// - [ownCopyFolder]: TakeTray's own `Movies/TakeTray/` copies.
/// - [failed]: anything else; the picker or the save did not work.
enum AddFolderResult {
  watched,
  cancelled,
  unsupportedFolder,
  ownCopyFolder,
  failed,
}

/// The phone's folders with videos, for the rows: [folders] is null when they
/// were not read (no full access, or the read failed).
@immutable
class PhoneFolders {
  const PhoneFolders({required this.fullAccess, required this.folders});

  final bool fullAccess;
  final List<VideoFolder>? folders;
}

/// The folders on the phone, read once for each access level and not again
/// for each switch (a toggle changes the settings, not the phone). Read only
/// with full access (`MediaAccessController`); a failed read is logged by
/// type and leaves [PhoneFolders.folders] null. A first access read that
/// failed counts as no full access.
@Riverpod(retry: noRetry)
Future<PhoneFolders> phoneFolders(Ref ref) async {
  MediaAccessLevel? level;
  try {
    level = (await ref.watch(mediaAccessControllerProvider.future)).level;
  } on Object catch (error) {
    _log.warning('Reading the access failed: ${error.runtimeType}');
  }
  if (level != MediaAccessLevel.full) {
    return const PhoneFolders(fullAccess: false, folders: null);
  }
  final folders = await guarded(
    _log,
    'Reading the folders',
    ref.read(mediaBridgeProvider).videoFolders,
  );
  return PhoneFolders(fullAccess: true, folders: folders);
}

/// The Watched folders screen (D-149): every folder on the phone with
/// videos, with its switch, plus every watched path that is not on the phone
/// now. The state follows the settings and the access.
///
/// - **With full access:** the rows are the Add videos list
///   (`browseFolders`: no empty folder, no WhatsApp Sent folder, no
///   `Movies/TakeTray/`), in its order; then each watched folder that the
///   list does not show, in the order they are watched: one that is on the
///   phone but hidden shows with its count, one that is not is
///   [WatchedRow.gone] with an unknown count, so it can still be turned
///   off. A volume root is never listed: its videos have no folder, so
///   watching it finds none.
/// - **Without it** (limited, denied, or the read failed): only the watched
///   paths, with no count, none of them gone: TakeTray cannot tell.
/// - **One folder, one row, however it is spelled:** a path is compared
///   without slashes at either end and ignoring A to Z case, and the phone's
///   storage and its SD card, which a relative path cannot tell apart, give
///   one row with their counts added.
///
/// Changes go through `SettingsRepository.update`, so a folder turned on here
/// and a switch turned off in Settings in the same frame both stay (D-149,
/// ruling R3).
@Riverpod(retry: noRetry)
class WatchedFoldersController extends _$WatchedFoldersController {
  @override
  Future<WatchedFoldersView> build() async {
    final settings = await ref.watch(settingsControllerProvider.future);
    final phone = await ref.watch(phoneFoldersProvider.future);
    return _view(settings.watchedFolders, phone);
  }

  /// Turns [relativePath] on or off.
  ///
  /// On: appended to the end of the list, unless it is there already (the
  /// same folder however it is spelled), so the order is the order they were
  /// turned on and never has a repeat. Off: every spelling of it is removed;
  /// turning off the last one saves an empty list. A path that is not watched
  /// is left alone when turned off.
  ///
  /// A failed save reaches the caller and changes nothing.
  // ignore: avoid_positional_boolean_parameters
  Future<void> setWatched(String relativePath, bool watched) async {
    final path = _trim(relativePath);
    final key = _key(path);
    await ref.read(settingsRepositoryProvider).update((s) {
      final others = [
        for (final f in s.watchedFolders)
          if (_key(f) != key) f,
      ];
      final isWatched = others.length != s.watchedFolders.length;
      if (!watched) {
        return isWatched ? s.copyWith(watchedFolders: others) : s;
      }
      return isWatched ? s : s.copyWith(watchedFolders: [...others, path]);
    });
  }

  /// **Add a folder**: asks Android's folder picker and watches what the user
  /// chooses (see [AddFolderResult]). A folder already listed or watched just
  /// turns on; a new one is added. Never throws: a failure is logged by type.
  Future<AddFolderResult> addFolder() async {
    final String? picked;
    try {
      picked = await ref.read(filesBridgeProvider).pickFolder();
    } on FileBridgeException catch (error) {
      _log.warning('Choosing a folder failed: ${error.problem.name}');
      return error.problem == FilesProblem.unsupportedFolder
          ? AddFolderResult.unsupportedFolder
          : AddFolderResult.failed;
    } on Object catch (error) {
      _log.warning('Choosing a folder failed: ${error.runtimeType}');
      return AddFolderResult.failed;
    }
    if (picked == null) return AddFolderResult.cancelled;
    final path = _trim(picked);
    // The storage root: MediaStore keeps its videos under no folder, and the
    // scan's folder match never finds them.
    if (path.isEmpty) return AddFolderResult.unsupportedFolder;
    if (isOwnCopyFolder(path)) return AddFolderResult.ownCopyFolder;
    try {
      await setWatched(path, true);
    } on Object catch (error) {
      _log.warning('Saving the folder failed: ${error.runtimeType}');
      return AddFolderResult.failed;
    }
    return AddFolderResult.watched;
  }

  WatchedFoldersView _view(List<String> watched, PhoneFolders phone) {
    final watchedKeys = {for (final w in watched) _key(w)};
    final rows = <WatchedRow>[];
    final shown = <String>{};
    WatchedRow row(String path, {int? count, bool gone = false}) => WatchedRow(
      relativePath: path,
      name: _nameOf(path),
      videoCount: count,
      watched: watchedKeys.contains(_key(path)),
      chat: isChatFolder(path),
      gone: gone,
    );

    final folders = phone.folders;
    final onPhone = <String, int>{};
    if (folders != null) {
      // What the list shows, one row for a folder whichever storage it is on.
      final counts = <String, int>{};
      final firstPath = <String, String>{};
      final order = <String>[];
      for (final f in browseFolders(folders)) {
        final key = _key(f.relativePath);
        if (key.isEmpty) continue;
        if (!counts.containsKey(key)) {
          order.add(key);
          firstPath[key] = _trim(f.relativePath);
        }
        counts[key] = (counts[key] ?? 0) + f.videoCount;
      }
      for (final key in order) {
        shown.add(key);
        rows.add(row(firstPath[key]!, count: counts[key]));
      }
      // What is on the phone at all, shown or not.
      for (final f in folders) {
        if (f.videoCount <= 0) continue;
        final key = _key(f.relativePath);
        onPhone[key] = (onPhone[key] ?? 0) + f.videoCount;
      }
    }

    for (final path in watched) {
      final key = _key(path);
      if (!shown.add(key)) continue;
      if (folders == null) {
        rows.add(row(_trim(path)));
      } else if (onPhone.containsKey(key)) {
        rows.add(row(_trim(path), count: onPhone[key]));
      } else {
        rows.add(row(_trim(path), gone: true));
      }
    }
    return WatchedFoldersView(rows: rows, fullAccess: phone.fullAccess);
  }
}

/// [path] without slashes at either end, as the settings keep it.
String _trim(String path) => _segments(path).join('/');

/// What makes two spellings of a path the same folder: no slash at either
/// end, and A to Z lower case (the media library compares folders so).
String _key(String path) => _lower(_trim(path));

String _nameOf(String path) {
  final segments = _segments(path);
  return segments.isEmpty ? '' : segments.last;
}

List<String> _segments(String path) => [
  for (final s in path.split('/'))
    if (s.isNotEmpty) s,
];

String _lower(String s) => s.replaceAllMapped(
  RegExp('[A-Z]'),
  (m) => String.fromCharCode(m[0]!.codeUnitAt(0) + 32),
);
