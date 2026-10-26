import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'clock.g.dart';

/// Where "now" comes from. Code that stores a time asks the [clockProvider]
/// instead of calling `DateTime.now()`, so tests can fix the time.
class Clock {
  const new();

  /// The current time, in UTC.
  DateTime now() => DateTime.now().toUtc();
}

@Riverpod(keepAlive: true)
Clock clock(Ref ref) => const Clock();
