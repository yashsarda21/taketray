const _knownExtensions = {'mp4', 'mov', 'm4v', '3gp', 'mkv', 'webm'};

const _mimeExtensions = {
  'video/mp4': 'mp4',
  'video/quicktime': 'mov',
  'video/3gpp': '3gp',
  'video/x-matroska': 'mkv',
  'video/webm': 'webm',
};

/// The extension a copy keeps (D-119): the display name's, lower-cased, when
/// it is one of `mp4 mov m4v 3gp mkv webm`; otherwise the one for the MIME
/// type; otherwise `mp4`. A name with no dot, or a trailing dot, has no
/// extension (the empty text after the dot is not a known one), so it uses
/// the MIME type.
String copyExtension(String displayName, String mimeType) {
  final dot = displayName.lastIndexOf('.');
  if (dot >= 0) {
    final extension = displayName.substring(dot + 1).toLowerCase();
    if (_knownExtensions.contains(extension)) return extension;
  }
  return _mimeExtensions[mimeType.toLowerCase()] ?? 'mp4';
}

/// What [copyFileNames] needs to know about one clip.
class CopyNameSource {
  const CopyNameSource({
    required this.clipId,
    required this.localShotAt,
    required this.extension,
  });

  final int clipId;

  /// The clip's `ClipLocalTime.wallClock`: the local wall clock held in the
  /// fields of a UTC [DateTime] (D-83). Only year to second are read; never
  /// `toLocal()` or `toUtc()`.
  final DateTime localShotAt;

  /// Without the dot, as [copyExtension] gives it.
  final String extension;
}

/// File names for the copies of a reel's clips: `yyyy-MM-dd_HH-mm-ss.ext`
/// from the clip's local shooting time (D-119, R2).
///
/// [inShootingOrder] decides who keeps the plain name when two clips share a
/// second (the repeated hour at a clock change gives the same wall clock
/// twice): the first keeps it, the next gets `_2`, then `_3`. A name in
/// [taken] (files already in the folder) is also skipped. Names are compared
/// without regard to case, as Android's storage does; the same time with a
/// different extension is a different name. The keys are clip ids, so every
/// [CopyNameSource.clipId] must be different: a repeated id would let one
/// name overwrite the other in the map, so it throws an [ArgumentError].
Map<int, String> copyFileNames(
  List<CopyNameSource> inShootingOrder,
  Set<String> taken,
) {
  final ids = <int>{};
  for (final clip in inShootingOrder) {
    if (!ids.add(clip.clipId)) {
      throw ArgumentError('clip ids must be unique');
    }
  }
  final used = {for (final name in taken) name.toLowerCase()};
  final names = <int, String>{};
  for (final clip in inShootingOrder) {
    final stem = _stem(clip.localShotAt);
    var name = '$stem.${clip.extension}';
    for (var n = 2; used.contains(name.toLowerCase()); n++) {
      name = '${stem}_$n.${clip.extension}';
    }
    used.add(name.toLowerCase());
    names[clip.clipId] = name;
  }
  return names;
}

String _stem(DateTime t) {
  String two(int v) => v.toString().padLeft(2, '0');
  final year = t.year.toString().padLeft(4, '0');
  return '$year-${two(t.month)}-${two(t.day)}_'
      '${two(t.hour)}-${two(t.minute)}-${two(t.second)}';
}
