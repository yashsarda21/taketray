/// How old the insert may be when the shade button is tapped. The real job
/// runs 5 s after the last change it saw (D-104, `Trigger update delay`) and
/// then posts the new-clips notification, which would sit beside Still
/// shooting? and fold it away; 4.5 s keeps a margin under that.
const Duration maxTapAge = Duration(milliseconds: 4500);

/// Why the tap on Still shooting?'s "Turn off" must not happen now, or null
/// when it may.
///
/// [ownIds] are the ids of TakeTray's own notifications in the shade
/// (`TestBackground.activeNotifications`: Android only ever lists the
/// calling app's), [sinceInsert] the time since the video went in, [stillId]
/// the id Still shooting? is posted under.
///
/// Two notifications from one app are grouped by the phone and the older one
/// is folded away (seen on the S24: the Still shooting? text was not in the
/// shade, only the new-clips one), so "Turn off" is only there to tap when
/// Still shooting? is the app's only notification. Any other id counts: the
/// app posts ids 1 (new clips) and 2 (evening) itself, and an id it never
/// posts, such as 0, is the phone's own summary of a group, which means the
/// phone has grouped them. The test refuses; it never expands a group.
String? stillTapRefusal({
  required List<int> ownIds,
  required Duration sinceInsert,
  required int stillId,
}) {
  if (!ownIds.contains(stillId)) {
    return 'Still shooting? is not showing (own notifications: '
        '${ownIds.length}), so there is no button to tap';
  }
  if (ownIds.length != 1) {
    return 'a second TakeTray notification is showing (own notifications: '
        '${ownIds.length}); the phone groups them and folds Still shooting? '
        'away';
  }
  if (sinceInsert.isNegative || sinceInsert >= maxTapAge) {
    return 'too slow: the job may post its notification '
        '(${sinceInsert.inMilliseconds} ms since the insert, '
        'limit ${maxTapAge.inMilliseconds} ms)';
  }
  return null;
}
