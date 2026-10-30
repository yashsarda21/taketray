import 'package:flutter/material.dart';

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
