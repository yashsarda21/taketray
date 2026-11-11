import 'package:flutter/foundation.dart';
import 'package:taketray/domain/models/media.dart';

/// One row of the Add videos folder list (D-113).
@immutable
class BrowseFolder {
  const BrowseFolder({
    required this.volumeName,
    required this.relativePath,
    required this.videoCount,
    required this.name,
    this.detail,
  });

  /// The [name] of a volume's root folder: the view shows "Main folder".
  static const mainFolder = '';

  final String volumeName;
  final String relativePath;
  final int videoCount;
  final String name;
  final String? detail;

  bool get isMainFolder => name == mainFolder;

  @override
  bool operator ==(Object other) =>
      other is BrowseFolder &&
      other.volumeName == volumeName &&
      other.relativePath == relativePath &&
      other.videoCount == videoCount &&
      other.name == name &&
      other.detail == detail;

  @override
  int get hashCode =>
      Object.hash(volumeName, relativePath, videoCount, name, detail);

  @override
  String toString() =>
      'BrowseFolder($volumeName, $relativePath, $videoCount, $name, $detail)';
}

/// The folders the Add videos list shows, named and in order (D-113).
///
/// - A folder with no videos is left out, and so is WhatsApp's **Sent**
///   folder (D-111 ruling 3): its last path segment is `Sent` and a segment
///   before it starts with `WhatsApp`, ignoring case. `DCIM/Sent/`,
///   `Movies/Sent stuff/` and `WhatsApp Video/` stay.
/// - [BrowseFolder.name] is the last path segment; a volume's root (`''`, or
///   only slashes) is [BrowseFolder.mainFolder], which the view shows as
///   "Main folder" (no translation in a rule).
/// - Folders that share a name (ignoring case) get a [BrowseFolder.detail]:
///   the segment before the name, joined with ` · ` to the volume name when
///   those folders are on more than one volume (a root, with no segment
///   before it, then has only the volume). A unique name has none.
/// - `DCIM/Camera` (ignoring case, on any volume) comes first, then the
///   rest by video count, most first; ties go by name ignoring case, then
///   by name, path and volume, so the order never depends on the input's.
List<BrowseFolder> browseFolders(List<VideoFolder> all) {
  final shown = [
    for (final f in all)
      if (f.videoCount > 0 && !_isWhatsAppSent(_segments(f.relativePath))) f,
  ];
  final byName = <String, List<VideoFolder>>{};
  for (final f in shown) {
    byName.putIfAbsent(_lower(_nameOf(f)), () => []).add(f);
  }
  final folders = [
    for (final f in shown)
      BrowseFolder(
        volumeName: f.volumeName,
        relativePath: f.relativePath,
        videoCount: f.videoCount,
        name: _nameOf(f),
        detail: _detailOf(f, byName[_lower(_nameOf(f))]!),
      ),
  ]..sort(_order);
  return folders;
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

String? _detailOf(VideoFolder f, List<VideoFolder> sameName) {
  if (sameName.length < 2) return null;
  final segments = _segments(f.relativePath);
  final parent = segments.length >= 2 ? segments[segments.length - 2] : null;
  final volumes = {for (final g in sameName) g.volumeName};
  final parts = [?parent, if (volumes.length > 1) f.volumeName];
  return parts.isEmpty ? null : parts.join(' · ');
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
