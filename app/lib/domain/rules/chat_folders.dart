/// The folder names of the chat apps, compared whole and ignoring A to Z case:
/// WhatsApp and WhatsApp Business (and their `WhatsApp Video` and
/// `WhatsApp Business Video` folders, which older phones keep straight under
/// `Movies`), Telegram, Signal, Messenger and Snapchat, each by its display
/// name and by its Android package name (D-149).
const Set<String> _chatSegments = {
  'whatsapp',
  'whatsapp business',
  'whatsapp video',
  'whatsapp business video',
  'com.whatsapp',
  'com.whatsapp.w4b',
  'telegram',
  'org.telegram.messenger',
  'signal',
  'org.thoughtcrime.securesms',
  'messenger',
  'com.facebook.orca',
  'snapchat',
  'com.snapchat.android',
};

/// Whether [relativePath] is a chat app's folder, so the Watched folders
/// screen warns that its videos are dated when they arrived (D-149).
///
/// True when **any** path segment is exactly one of the chat apps' names (see
/// the list above), ignoring A to Z case only, like the media library's
/// folder matching. A part of a name never matches: `Pictures/Signals`,
/// `Movies/Telegrams` and `Movies/MyWhatsApp` are not chat folders. Slashes at
/// either end and empty segments are ignored.
bool isChatFolder(String relativePath) =>
    _segments(relativePath).any((s) => _chatSegments.contains(_lower(s)));

/// Whether [relativePath] is TakeTray's own copy folder on the phone, or one
/// inside it: its first two segments are `Movies` and `TakeTray`, compared
/// whole and ignoring A to Z case, the copy guard's rule (D-121, D-130).
///
/// A copy there is temporary, so a watched folder there would pull the copies
/// into To tag. `Movies/TakeTray Test`, `Movies/TakeTrayX` and
/// `DCIM/TakeTray` are not.
///
/// A path that a folder picker gave has no volume, so this cannot tell
/// another storage's `Movies/TakeTray` from the phone's; it says yes to both,
/// the safe answer.
bool isOwnCopyFolder(String relativePath) {
  final segments = _segments(relativePath);
  return segments.length >= 2 &&
      _lower(segments[0]) == 'movies' &&
      _lower(segments[1]) == 'taketray';
}

List<String> _segments(String relativePath) => [
  for (final s in relativePath.split('/'))
    if (s.isNotEmpty) s,
];

/// Lower case for A to Z only, like the media library's folder matching.
String _lower(String s) => s.replaceAllMapped(
  RegExp('[A-Z]'),
  (m) => String.fromCharCode(m[0]!.codeUnitAt(0) + 32),
);
