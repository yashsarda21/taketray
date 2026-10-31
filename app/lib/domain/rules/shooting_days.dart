import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/models/clip_local_time.dart';

/// One shooting day of a reel: the clips shot on one local calendar date
/// (spec §8.4, D-83).
@immutable
class ShootingDay<T> {
  const ShootingDay({
    required this.date,
    required this.number,
    required this.clips,
  });

  /// The local calendar date, as `DateTime.utc(year, month, day)` (a date,
  /// not an instant; like `ClipLocalTime.wallClock`, never convert it).
  final DateTime date;

  /// "Day N": 1 for the earliest date, then one more per calendar day, so
  /// three empty days between two days give Day 1 and Day 5 ([dayNumber]).
  final int number;

  /// The items of this day, in the order they were given.
  final List<T> clips;
}

/// [items] grouped by the local calendar date each was shot on, earliest date
/// first (D-83).
///
/// - [clipOf] gives an item's clip (`(c) => c` for plain clips; a reel's
///   clip row elsewhere), and [times] its `ClipLocalTime` by clip id. A
///   clip's date is the date of its `wallClock`, so each clip is grouped by
///   the date where it was shot, even when one reel spans two zones.
/// - A clip missing from [times] uses its phone-local date (Dart's local
///   time), so it is never dropped.
/// - [items] are expected oldest first; each group keeps them in that order.
///   A clip whose local date is earlier than the clip before it (a later
///   instant in a zone further west) still goes in its own date's group, and
///   the groups are sorted by date.
/// - Day numbers count calendar days from the earliest date ([dayNumber]).
List<ShootingDay<T>> groupByShootingDay<T>(
  List<T> items,
  Clip Function(T) clipOf,
  Map<int, ClipLocalTime> times,
) {
  final byDate = SplayTreeMap<DateTime, List<T>>();
  for (final item in items) {
    final clip = clipOf(item);
    final wall =
        times[clip.id]?.wallClock ?? clip.fingerprint.dateTakenUtc.toLocal();
    byDate
        .putIfAbsent(DateTime.utc(wall.year, wall.month, wall.day), () => [])
        .add(item);
  }
  if (byDate.isEmpty) return const [];
  final first = byDate.firstKey()!;
  return [
    for (final MapEntry(key: date, value: clips) in byDate.entries)
      ShootingDay(
        date: date,
        number: dayNumber(first, date),
        clips: List.unmodifiable(clips),
      ),
  ];
}

/// The number of [day] counted from [firstDay] (Day 1): the calendar days
/// between their dates, plus 1. Only the year, month and day fields are read
/// (a local or a UTC value, any time of day), and the count is made between
/// `DateTime.utc` dates, which are always 24 hours apart: counting between
/// local midnights would make a 23-hour spring-forward day count as 0 days.
int dayNumber(DateTime firstDay, DateTime day) {
  final from = DateTime.utc(firstDay.year, firstDay.month, firstDay.day);
  final to = DateTime.utc(day.year, day.month, day.day);
  return to.difference(from).inDays + 1;
}
