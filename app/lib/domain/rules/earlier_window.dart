import 'package:taketray/domain/models/media.dart';
import 'package:taketray/domain/rules/clip_date.dart';
import 'package:taketray/domain/rules/media_clip.dart';

/// How far back "Add earlier videos" looks, in calendar days.
enum EarlierRange { today, lastTwoDays, lastSevenDays }

/// The start of [r]'s window, as a UTC instant: local midnight of today
/// ([EarlierRange.today]), of yesterday ([EarlierRange.lastTwoDays]) or of
/// six days ago ([EarlierRange.lastSevenDays]).
///
/// Days are counted in the phone's local time, the way a creator thinks
/// ("yesterday and today", not "the last 48 hours"). The date is built with
/// `DateTime(year, month, day - n)` rather than by subtracting hours, so a
/// day on which the clocks change (23 or 25 hours long) still starts at
/// midnight.
DateTime earlierWindowStart(EarlierRange r, DateTime nowLocal) {
  final local = nowLocal.toLocal();
  final daysBack = switch (r) {
    EarlierRange.today => 0,
    EarlierRange.lastTwoDays => 1,
    EarlierRange.lastSevenDays => 6,
  };
  return DateTime(local.year, local.month, local.day - daysBack).toUtc();
}

/// Whether [v] belongs in a window that starts at [startUtc]: it is usable
/// ([isUsable]) and was shot ([shotAt]) at or after the start.
bool shotInWindow(MediaVideo v, DateTime startUtc, {required DateTime now}) =>
    !shotAt(v, now: now).isBefore(startUtc) && isUsable(v);
