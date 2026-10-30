import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/core/clock.dart';

part 'midnight_tick.g.dart';

/// The phone's local date: midnight of today, in local time, now, and again
/// at every local midnight after that.
///
/// A screen that writes "since 9:41 AM" or "Oct 27, 9:41 PM" depending on the
/// day watches this, so it is built again when the day changes instead of
/// keeping yesterday's text until something else redraws it (D-86). The
/// value is the day; callers watch it for the change and read the time from
/// the `clockProvider`.
///
/// The timer is set for the next local midnight (`DateTime(y, m, d + 1)`),
/// not for 24 hours later, so a day with a daylight-saving change (23 or 25
/// hours) still ends at midnight. When the timer fires and the clock still
/// shows the same day (it fired a moment early, or the clock was set back),
/// nothing is emitted and the timer is set again. The timer is cancelled when
/// nothing watches the provider any more.
@riverpod
Stream<DateTime> localDay(Ref ref) {
  final clock = ref.watch(clockProvider);
  final days = StreamController<DateTime>();
  Timer? timer;
  DateTime? lastDay;

  void tick() {
    final now = clock.now().toLocal();
    final today = DateTime(now.year, now.month, now.day);
    if (today != lastDay) {
      lastDay = today;
      days.add(today);
    }
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    timer = Timer(nextMidnight.difference(now), tick);
  }

  ref.onDispose(() {
    timer?.cancel();
    unawaited(days.close());
  });
  tick();
  return days.stream;
}
