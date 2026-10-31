import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'clock.g.dart';

/// Where "now" comes from. Code that stores a time asks the [clockProvider]
/// instead of calling `DateTime.now()`, so tests can fix the time.
class Clock {
  const new();

  /// The current time, in UTC. A real clock's time has microseconds.
  DateTime now() => DateTime.now().toUtc();

  /// [now] as the database stores it: UTC, to the millisecond (the
  /// microseconds are dropped, as `UtcMillisConverter` drops them).
  ///
  /// Repositories take the time they write into a row from here, so what
  /// they return and what they put in an undo record is exactly the stored
  /// value: a comparison in Dart then agrees with one in SQL (D-84 point 9).
  DateTime storedNow() => DateTime.fromMillisecondsSinceEpoch(
    now().millisecondsSinceEpoch,
    isUtc: true,
  );
}

@Riverpod(keepAlive: true)
Clock clock(Ref ref) => const Clock();
