import 'package:taketray/domain/models/media.dart';

/// When [v] was shot, as a UTC instant (D-69).
///
/// MediaStore's dates are tried in this order, and the first plausible one
/// wins: DATE_TAKEN (milliseconds), DATE_ADDED, DATE_MODIFIED (both seconds).
/// If none is plausible, the answer is [now].
///
/// A date is plausible when it is not before 1970-01-01 (0) and not after
/// [now] plus one day (24 hours). Container metadata holds garbage: QuickTime
/// epochs (1904), wrong units, clocks set years ahead. Such a date would sort
/// the clip to the far end of To tag and of its reels.
DateTime shotAt(MediaVideo v, {required DateTime now}) => shotAtFrom(
  takenMs: v.dateTakenMs,
  addedSec: v.dateAddedSec,
  modifiedSec: v.dateModifiedSec,
  now: now,
);

/// The [shotAt] rule on dates given one by one: [takenMs] (milliseconds),
/// then [addedSec] and [modifiedSec] (seconds); the first plausible one wins,
/// else [now]. A video from the photo picker has only a taken date (D-113).
DateTime shotAtFrom({
  required DateTime now,
  int? takenMs,
  int? addedSec,
  int? modifiedSec,
}) {
  final nowUtc = now.toUtc();
  final latestMs = nowUtc.add(const Duration(days: 1)).millisecondsSinceEpoch;
  // Compared in seconds, so a huge value cannot overflow when it is
  // multiplied by 1000 and wrap around into a plausible date.
  final latestSec = latestMs ~/ 1000;

  if (takenMs != null && takenMs >= 0 && takenMs <= latestMs) {
    return DateTime.fromMillisecondsSinceEpoch(takenMs, isUtc: true);
  }
  for (final seconds in [addedSec, modifiedSec]) {
    if (seconds != null && seconds >= 0 && seconds <= latestSec) {
      return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
    }
  }
  return nowUtc;
}
