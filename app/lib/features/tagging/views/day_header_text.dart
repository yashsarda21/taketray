import 'package:flutter/widgets.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray_ui/taketray_ui.dart';

/// A day header's words on To tag (D-98, the prototype's `fmt.dayRel`):
/// "Today · Wed, Oct 28", "Yesterday · Tue, Oct 27", or just "Mon, Oct 26".
///
/// [day] is the day where the clips were shot (`Scene.day`: a UTC-flagged date,
/// never converted) and [today] is the phone's local day. They are compared by
/// calendar date, so a change of clocks cannot move a day. The date part is
/// `ttDayWeekdayText` (the phone's order, with the year only for another year).
String toTagDayText(
  BuildContext context,
  DateTime day, {
  required DateTime today,
}) {
  final l10n = AppLocalizations.of(context);
  final date = ttDayWeekdayText(context, day, today: today);
  final todayDate = DateTime.utc(today.year, today.month, today.day);
  final days = todayDate.difference(DateTime.utc(day.year, day.month, day.day));
  return switch (days.inDays) {
    0 => l10n.toTagDayToday(date),
    1 => l10n.toTagDayYesterday(date),
    _ => date,
  };
}
