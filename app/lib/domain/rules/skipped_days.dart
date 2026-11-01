import 'package:flutter/foundation.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/models/clip_local_time.dart';

/// The skipped clips of one day, as the Skipped list shows them (D-99).
@immutable
class SkippedDay {
  const SkippedDay({required this.day, required this.clips});

  /// The day where the clips were shot, as `DateTime.utc(year, month, day)`
  /// (a date, never converted: the same shape as `Scene.day`).
  final DateTime day;

  /// The day's clips, newest first (never empty).
  final List<Clip> clips;
}

/// [clips] grouped by the day where each was shot, **newest day first and
/// newest clip first inside a day** (D-99; the prototype sorts the skipped
/// clips newest first and then cuts them into days, `q.days`).
///
/// - Clips are ordered by the UTC instant they were taken, then by the higher
///   id, so a clip shot in another zone sits where it happened.
/// - A clip's day is its calendar day where it was shot (`times`, D-83). A
///   clip with no entry uses the phone's local time, so no clip is dropped
///   and the list never waits for the times.
/// - Days are keyed by date, so a day never appears twice: clips shot in
///   London and in India on the same date share one header, whatever
///   instants they sit at.
List<SkippedDay> groupIntoDays(
  List<Clip> clips,
  Map<int, ClipLocalTime> times,
) {
  final newestFirst = [...clips]
    ..sort((a, b) {
      final byDate = b.fingerprint.dateTakenUtc.compareTo(
        a.fingerprint.dateTakenUtc,
      );
      return byDate != 0 ? byDate : b.id.compareTo(a.id);
    });
  final byDay = <DateTime, List<Clip>>{};
  for (final clip in newestFirst) {
    (byDay[_dayOf(clip, times)] ??= []).add(clip);
  }
  final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
  return List.unmodifiable([
    for (final day in days)
      SkippedDay(day: day, clips: List.unmodifiable(byDay[day]!)),
  ]);
}

DateTime _dayOf(Clip clip, Map<int, ClipLocalTime> times) {
  final wall =
      times[clip.id]?.wallClock ?? clip.fingerprint.dateTakenUtc.toLocal();
  return DateTime.utc(wall.year, wall.month, wall.day);
}
