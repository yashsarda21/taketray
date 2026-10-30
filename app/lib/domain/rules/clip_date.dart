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
DateTime shotAt(MediaVideo v, {required DateTime now}) {
  final nowUtc = now.toUtc();
  final latestMs = nowUtc.add(const Duration(days: 1)).millisecondsSinceEpoch;
  // Compared in seconds, so a huge value cannot overflow when it is
  // multiplied by 1000 and wrap around into a plausible date.
  final latestSec = latestMs ~/ 1000;

  final taken = v.dateTakenMs;
  if (taken != null && taken >= 0 && taken <= latestMs) {
    return DateTime.fromMillisecondsSinceEpoch(taken, isUtc: true);
  }
  for (final seconds in [v.dateAddedSec, v.dateModifiedSec]) {
    if (seconds != null && seconds >= 0 && seconds <= latestSec) {
      return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
    }
  }
  return nowUtc;
}
