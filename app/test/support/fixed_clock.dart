import 'package:taketray/core/clock.dart';

/// A [Clock] whose time only moves when a test moves it.
class FixedClock extends Clock {
  new(DateTime time) : _now = time.toUtc();

  DateTime _now;

  @override
  DateTime now() => _now;

  /// Moves the time forward by [by].
  void advance(Duration by) => _now = _now.add(by);
}
