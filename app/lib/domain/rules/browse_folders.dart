import 'package:flutter/foundation.dart';
import 'package:taketray/domain/models/media.dart';

/// The name Android gives the phone's own storage (`VOLUME_EXTERNAL_PRIMARY`).
/// Every other volume is an SD card or a USB drive, which a volume name
/// cannot tell apart (both are a serial such as `1234-5678`).
const primaryVolumeName = 'external_primary';

/// Which storage a folder is on, as the Add videos list names it (D-114):
/// the phone's own, or other storage (an SD card or a USB drive), numbered
/// when the list has more than one other storage.
///
/// It never holds a volume's name: the view turns it into words ("Phone",
/// "Other storage 2").
@immutable
class FolderStorage {
  const FolderStorage._(this.isPhone, this.number);

  /// Other storage: [number] is 1, 2, … in the order of the volume names when
  /// the list has two or more other storages, else null.
  const FolderStorage.other([this.number]) : isPhone = false;

  /// The phone's own storage.
  static const phone = FolderStorage._(true, null);

  final bool isPhone;
  final int? number;

  @override
  bool operator ==(Object other) =>
      other is FolderStorage &&
      other.isPhone == isPhone &&
      other.number == number;

  @override
  int get hashCode => Object.hash(isPhone, number);

  @override
  String toString() => isPhone
      ? 'FolderStorage(phone)'
      : 'FolderStorage(other${number == null ? '' : ' $number'})';
}

/// One row of the Add videos folder list (D-113, D-114).
@immutable
class BrowseFolder {
  const BrowseFolder({
    required this.volumeName,
    required this.relativePath,
    required this.videoCount,
    required this.name,
    this.parent,
    this.storage,
  });

  /// The [name] of a volume's root folder: the view shows "Main folder".
  static const mainFolder = '';

  final String volumeName;
  final String relativePath;
  final int videoCount;
  final String name;

  /// For a name another row shares: the path segment before the name, or
  /// null (a root, or a name no other row has).
  final String? parent;

  /// For a name another row on another volume shares: the storage it is on,
  /// or null.
  final FolderStorage? storage;

  bool get isMainFolder => name == mainFolder;

  @override
  bool operator ==(Object other) =>
      other is BrowseFolder &&
      other.volumeName == volumeName &&
      other.relativePath == relativePath &&
      other.videoCount == videoCount &&
      other.name == name &&
      other.parent == parent &&
      other.storage == storage;

  @override
  int get hashCode =>
      Object.hash(volumeName, relativePath, videoCount, name, parent, storage);

  @override
  String toString() =>
      'BrowseFolder($volumeName, $relativePath, $videoCount, $name, $parent, '
      '$storage)';
}

/// The folders the Add videos list shows, named and in order (D-113, D-114).
///
/// - A folder with no videos is left out, and so is WhatsApp's **Sent**
///   folder (D-111 ruling 3): its last path segment is `Sent` and a segment
///   before it starts with `WhatsApp`, ignoring case. `DCIM/Sent/`,
///   `Movies/Sent stuff/` and `WhatsApp Video/` stay.
/// - TakeTray's own copy folders are left out too (D-130, I-2): on the phone
///   (never on another storage), a path whose first segments are
///   `Movies/TakeTray`, ignoring A to Z case only (the copy guard's rule).
///   `Movies/TakeTray Test/`, `Movies/TakeTrayX/` and `DCIM/TakeTray/` stay.
/// - [BrowseFolder.name] is the last path segment; a volume's root (`''`, or
///   only slashes) is [BrowseFolder.mainFolder], which the view shows as
///   "Main folder" (no translation in a rule).
/// - Folders that share a name (ignoring case) are told apart: each gets its
///   [BrowseFolder.parent] (the segment before the name; a root has none),
///   and, when those folders are on more than one volume, its
///   [BrowseFolder.storage]: [FolderStorage.phone] for [primaryVolumeName],
///   else [FolderStorage.other], numbered 1, 2, … by volume name when the
///   shown folders are on two or more other volumes (the same number on
///   every row). A volume's name is never shown (D-114). A unique name has
///   neither.
/// - `DCIM/Camera` (ignoring case, on any volume) comes first, then the
///   rest by video count, most first; ties go by name ignoring case, then
///   by name, path and volume, so the order never depends on the input's.
List<BrowseFolder> browseFolders(List<VideoFolder> all) {
  final shown = [
    for (final f in all)
      if (f.videoCount > 0 &&
          !_isWhatsAppSent(_segments(f.relativePath)) &&
          !_isTakeTrayCopy(f))
        f,
  ];
  final byName = <String, List<VideoFolder>>{};
  for (final f in shown) {
    byName.putIfAbsent(_lower(_nameOf(f)), () => []).add(f);
  }
  final others = {
    for (final f in shown)
      if (f.volumeName != primaryVolumeName) f.volumeName,
  }.toList()..sort();
  FolderStorage storageOf(String volume) => volume == primaryVolumeName
      ? FolderStorage.phone
      : FolderStorage.other(
          others.length > 1 ? others.indexOf(volume) + 1 : null,
        );
  final folders = [
    for (final f in shown) _named(f, byName[_lower(_nameOf(f))]!, storageOf),
  ]..sort(_order);
  return folders;
}

BrowseFolder _named(
  VideoFolder f,
  List<VideoFolder> sameName,
  FolderStorage Function(String volume) storageOf,
) {
  final clash = sameName.length > 1;
  final segments = _segments(f.relativePath);
  final volumes = {for (final g in sameName) g.volumeName};
  return BrowseFolder(
    volumeName: f.volumeName,
    relativePath: f.relativePath,
    videoCount: f.videoCount,
    name: _nameOf(f),
    parent: clash && segments.length >= 2
        ? segments[segments.length - 2]
        : null,
    storage: clash && volumes.length > 1 ? storageOf(f.volumeName) : null,
  );
}

List<String> _segments(String relativePath) => [
  for (final s in relativePath.split('/'))
    if (s.isNotEmpty) s,
];

String _nameOf(VideoFolder f) {
  final segments = _segments(f.relativePath);
  return segments.isEmpty ? BrowseFolder.mainFolder : segments.last;
}

bool _isWhatsAppSent(List<String> segments) =>
    segments.length >= 2 &&
    _lower(segments.last) == 'sent' &&
    segments
        .take(segments.length - 1)
        .any((s) => _lower(s).startsWith('whatsapp'));

/// A folder in TakeTray's own `Movies/TakeTray/` on the phone (the copies
/// there are temporary: a clip added from them would go when Done editing
/// deletes them). The media library's folder match is by whole segment, so a
/// lookalike name never matches.
bool _isTakeTrayCopy(VideoFolder f) {
  if (f.volumeName != primaryVolumeName) return false;
  final segments = _segments(f.relativePath);
  return segments.length >= 2 &&
      _lower(segments[0]) == 'movies' &&
      _lower(segments[1]) == 'taketray';
}

bool _isCamera(BrowseFolder f) =>
    _lower(_segments(f.relativePath).join('/')) == 'dcim/camera';

int _order(BrowseFolder a, BrowseFolder b) {
  final camera = (_isCamera(b) ? 1 : 0) - (_isCamera(a) ? 1 : 0);
  if (camera != 0) return camera;
  for (final c in [
    b.videoCount.compareTo(a.videoCount),
    _lower(a.name).compareTo(_lower(b.name)),
    a.name.compareTo(b.name),
    a.relativePath.compareTo(b.relativePath),
    a.volumeName.compareTo(b.volumeName),
  ]) {
    if (c != 0) return c;
  }
  return 0;
}

/// Lower case for A to Z only, like the media library's folder matching.
String _lower(String s) => s.replaceAllMapped(
  RegExp('[A-Z]'),
  (m) => String.fromCharCode(m[0]!.codeUnitAt(0) + 32),
);
