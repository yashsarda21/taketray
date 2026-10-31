import 'package:flutter/foundation.dart';

/// When a clip was shot, as the clock read where it was shot (D-83).
///
/// Built by `ClipTimeService.localTimes` (`data/media/clip_time.dart`).
@immutable
class ClipLocalTime {
  const ClipLocalTime({
    required this.wallClock,
    required this.zoneId,
    required this.isPhoneZone,
  });

  /// The local wall-clock time where the clip was shot, held as a **UTC**
  /// [DateTime] whose fields (year to microsecond) are that wall clock: a
  /// clip shot at 13:00 in London in July is `DateTime.utc(…, 13)`, whatever
  /// zone the phone or the test machine is in.
  ///
  /// It is not an instant. Read its fields, or format it as it is
  /// (`wallClockTimeText`, `ttDayText`, `DateFormat`). Never call `toLocal()`
  /// or `toUtc()` on it, and never compare it with a real instant. A UTC
  /// value is used because a local one would be re-read in the phone's zone:
  /// a wall-clock time that falls in the phone's spring-forward gap (01:30 on
  /// a London clock-change day) cannot exist as a local `DateTime` and would
  /// move by an hour; every UTC field set exists.
  final DateTime wallClock;

  /// The IANA zone the time is in: the clip's own zone, or the phone's when
  /// the clip has none or the phone does not know it. Null only when the
  /// phone's zone could not be read either (then [wallClock] is Dart's local
  /// time).
  final String? zoneId;

  /// True when [wallClock] is in the phone's current zone (the clip's own
  /// zone is the phone's, or the phone's was used instead). The clip viewer
  /// names the city ("London time") only when this is false.
  final bool isPhoneZone;

  @override
  bool operator ==(Object other) =>
      other is ClipLocalTime &&
      other.wallClock == wallClock &&
      other.zoneId == zoneId &&
      other.isPhoneZone == isPhoneZone;

  @override
  int get hashCode => Object.hash(wallClock, zoneId, isPhoneZone);

  /// For test failures only: holds a zone id, so never log it (D-10).
  @override
  String toString() =>
      'ClipLocalTime($wallClock, $zoneId, '
      '${isPhoneZone ? 'phone zone' : 'own zone'})';
}
