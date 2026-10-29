import 'package:intl/intl.dart';

/// The `{time}` of "On since {time}" and "Shooting since {time}" (D-76).
///
/// When [since] is on the same calendar day as [now] in the phone's local
/// time, only the time of day, as `DateFormat.jm` writes it in [locale]
/// ("9:41 AM"). Otherwise the date too (`MMMd`, then `jm`, joined with a comma:
/// "Oct 27, 9:41 PM"): a time alone is ambiguous after midnight, when
/// Shooting mode has been on since "9:41 PM" of yesterday.
///
/// [locale] is the app's locale (`Localizations.localeOf`), the one whose
/// date data `intl` has loaded; the app only has English for now.
///
/// Both instants are converted to local time first, so a UTC value (as the
/// database stores them) gives the same answer as a local one. Local midnight
/// of today counts as today; 23:59 yesterday does not.
String shootingTimeText({
  required DateTime since,
  required DateTime now,
  required String locale,
}) {
  final s = since.toLocal();
  final n = now.toLocal();
  final today = s.year == n.year && s.month == n.month && s.day == n.day;
  return today
      ? DateFormat.jm(locale).format(s)
      : DateFormat.MMMd(locale).addPattern('jm', ', ').format(s);
}
