import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// A calendar day as text, in the phone's language and order: "8 Oct" on
/// en-IN and en-GB, "Oct 8" on en-US.
///
/// The year is added only when [day] is not in [today]'s year ("30 Dec 2025"),
/// because the date range picker reaches ten years back and "8 Oct" alone can
/// be the wrong year. This is the one place that rule lives (D-79): to drop
/// the year again, return `formatShortMonthDay` here for every day.
///
/// Spaces inside the text are no-break spaces, so a date never wraps in the
/// middle ("8" on one line and "Oct" on the next).
String ttDayText(
  BuildContext context,
  DateTime day, {
  required DateTime today,
}) {
  final dates = MaterialLocalizations.of(context);
  final text = day.year == today.year
      ? dates.formatShortMonthDay(day)
      : dates.formatShortDate(day);
  return _keepTogether(text);
}

/// [text] with every space (and narrow space) made a no-break space.
String _keepTogether(String text) =>
    text.replaceAll(RegExp('[ \u202f]'), '\u00a0');

/// [ttDayText] with the weekday: "Wed, Oct 28" on en-US, "Wed, 28 Oct" on
/// en-IN and en-GB (`MMMEd`), and with the year when [day] is not in
/// [today]'s year: "Tue, Dec 30, 2025" (`yMMMEd`). The year rule and the
/// no-break spaces are the same as [ttDayText]'s (D-79); the reel page's day
/// headers use it (D-87).
///
/// The format is the app's locale (`Localizations.localeOf`): the date data
/// is loaded for the locales the app resolves, as for [ttDayText].
String ttDayWeekdayText(
  BuildContext context,
  DateTime day, {
  required DateTime today,
}) {
  final locale = Localizations.localeOf(context).toString();
  final format = day.year == today.year
      ? DateFormat.MMMEd(locale)
      : DateFormat.yMMMEd(locale);
  return _keepTogether(format.format(day));
}
