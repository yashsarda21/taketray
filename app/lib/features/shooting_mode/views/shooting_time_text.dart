import 'package:intl/intl.dart';

/// The time of day of [time], in the phone's local time, as the phone shows
/// times (D-76, Ruling AG): "9:41 AM" (`DateFormat.jm`) or, when the phone is
/// set to 24-hour time ([use24Hour], read from
/// `MediaQuery.alwaysUse24HourFormatOf`), "09:41" (`DateFormat.Hm`).
///
/// [locale] is the app's locale (`Localizations.localeOf`). It is the phone's
/// own locale when the app has its language (`resolvePhoneLocale`, D-79), so
/// an English (India) phone gives `en_IN`; Flutter's localization delegates
/// load the `intl` date data for that locale, and a locale they did not load
/// throws. The app has English only for now. [time] may be UTC (as the
/// database stores it).
String timeOfDayText(
  DateTime time, {
  required String locale,
  required bool use24Hour,
}) {
  final local = time.toLocal();
  return use24Hour
      ? DateFormat.Hm(locale).format(local)
      : DateFormat.jm(locale).format(local);
}

/// The `{time}` of "On since {time}" and "Shooting since {time}" (D-76).
///
/// When [since] is on the same calendar day as [now] in the phone's local
/// time, only the time of day ([timeOfDayText]: "9:41 AM", or "09:41" with
/// [use24Hour]). Otherwise the date too (`MMMd`, then the time, joined with a
/// comma: "Oct 27, 9:41 PM" or "Oct 27, 21:41"): a time alone is ambiguous
/// after midnight, when Shooting mode has been on since "9:41 PM" of
/// yesterday.
///
/// Both instants are converted to local time first, so a UTC value (as the
/// database stores them) gives the same answer as a local one. Local midnight
/// of today counts as today; 23:59 yesterday does not. [now] is the time when
/// the widget was built: the text is not recomputed at midnight until the next
/// rebuild.
String shootingTimeText({
  required DateTime since,
  required DateTime now,
  required String locale,
  required bool use24Hour,
}) {
  final s = since.toLocal();
  final n = now.toLocal();
  final today = s.year == n.year && s.month == n.month && s.day == n.day;
  if (today) return timeOfDayText(s, locale: locale, use24Hour: use24Hour);
  return DateFormat.MMMd(locale)
      .addPattern(use24Hour ? 'Hm' : 'jm', ', ')
      .format(s);
}
