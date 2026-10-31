import 'dart:async';

/// A hold that only ends when the test says so.
class FakeHold implements Timer {
  FakeHold(this.duration, this._callback);

  final Duration duration;
  final void Function() _callback;
  bool _active = true;

  /// Whether it was cancelled before it fired.
  bool cancelled = false;

  /// Ends the hold now, as the real timer would after [duration]. A hold
  /// that was cancelled or has fired already does nothing.
  void fire() {
    if (!_active) return;
    _active = false;
    _callback();
  }

  @override
  void cancel() {
    if (_active) cancelled = true;
    _active = false;
  }

  @override
  bool get isActive => _active;

  @override
  int get tick => 0;
}

/// Every hold the controller asked for, in order.
class FakeHolds {
  final List<FakeHold> made = [];

  Timer call(Duration duration, void Function() callback) {
    final hold = FakeHold(duration, callback);
    made.add(hold);
    return hold;
  }

  /// Ends every hold still running.
  void fireAll() {
    for (final hold in [...made]) {
      hold.fire();
    }
  }
}
