import 'package:meta/meta.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/domain/rules/clip_date.dart';
import 'package:taketray/domain/rules/media_clip.dart';

/// Which videos "Add earlier videos" looks at (D-73, D-78): the videos shot
/// today, or the videos shot on the days the user chose.
@immutable
sealed class EarlierRange {
  const EarlierRange();
}

/// Today, in the phone's local time.
final class EarlierToday extends EarlierRange {
  const EarlierToday();

  @override
  bool operator ==(Object other) => other is EarlierToday;

  @override
  int get hashCode => 0;
}

/// The calendar days from [from] to [to], both included, in the phone's local
/// time. Only the year, month and day of each are read; the time of day is
/// ignored. A one-day range has [from] and [to] on the same day.
final class EarlierCustom extends EarlierRange {
  const EarlierCustom(this.from, this.to);

  final DateTime from;
  final DateTime to;

  @override
  bool operator ==(Object other) =>
      other is EarlierCustom &&
      other.from.year == from.year &&
      other.from.month == from.month &&
      other.from.day == from.day &&
      other.to.year == to.year &&
      other.to.month == to.month &&
      other.to.day == to.day;

  @override
  int get hashCode =>
      Object.hash(from.year, from.month, from.day, to.year, to.month, to.day);
}

/// A window of time as UTC instants: `startUtc` is inside it, `endUtc` is
/// not.
typedef EarlierBounds = ({DateTime startUtc, DateTime endUtc});

/// The start (inclusive) and the end (exclusive) of [range], as UTC instants.
///
/// Days are counted in the phone's local time, the way a creator thinks. The
/// start is local midnight of the first day, the end is local midnight of the
/// day after the last one. Both are built with `DateTime(year, month,
/// day + n)` rather than by adding hours, so a day on which the clocks change
/// (23 or 25 hours long) still starts and ends at midnight.
///
/// [now] decides which day is today. A "to" day after today is clamped to
/// today (no videos exist in the future). Throws [ArgumentError] when "from"
/// is after "to", or after today.
EarlierBounds earlierWindowBounds(EarlierRange range, DateTime now) {
  final today = _day(now.toLocal());
  final (from, to) = switch (range) {
    EarlierToday() => (today, today),
    EarlierCustom(:final from, :final to) => (_day(from), _day(to)),
  };
  final last = to.isAfter(today) ? today : to;
  // "from" after "to", or after today (nothing can be shot there).
  if (from.isAfter(last)) {
    throw ArgumentError.value(from, 'from', 'is after "to" or after today');
  }
  return (
    startUtc: DateTime(from.year, from.month, from.day).toUtc(),
    endUtc: DateTime(last.year, last.month, last.day + 1).toUtc(),
  );
}

/// The calendar day of [d] as a local midnight.
DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// Whether [v] belongs in a window from [startUtc] (inclusive) to [endUtc]
/// (exclusive): it is usable ([isUsable]) and was shot ([shotAt]) inside it.
bool shotInWindow(
  MediaVideo v,
  DateTime startUtc,
  DateTime endUtc, {
  required DateTime now,
}) {
  final shot = shotAt(v, now: now);
  return !shot.isBefore(startUtc) && shot.isBefore(endUtc) && isUsable(v);
}
