import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/domain/rules/still_shooting.dart';

final DateTime _since = DateTime.utc(2026, 11, 1, 3);

ShootingState _on({bool answered = false}) => ShootingState(
  on: true,
  since: _since,
  baselines: const {},
  stillAnswered: answered,
);

void main() {
  test('the wait is 14 days of 24 hours, as on the phone', () {
    expect(stillShootingAfter, const Duration(hours: 14 * 24));
  });

  test('due at exactly 14 days', () {
    final at = _since.add(const Duration(days: 14));

    expect(stillShootingDue(_on(), at), isTrue);
    expect(
      stillShootingDue(_on(), at.subtract(const Duration(microseconds: 1))),
      isFalse,
    );
    expect(stillShootingDue(_on(), at.add(const Duration(days: 3))), isTrue);
  });

  test('not due when answered', () {
    final late = _since.add(const Duration(days: 20));

    expect(stillShootingDue(_on(answered: true), late), isFalse);
  });

  test('not due when off', () {
    final late = _since.add(const Duration(days: 20));

    expect(stillShootingDue(ShootingState.off, late), isFalse);
    // Off, but with a stale start time: still not due.
    expect(
      stillShootingDue(
        ShootingState(on: false, since: _since, baselines: const {}),
        late,
      ),
      isFalse,
    );
  });

  test('not due with the clock set before the start', () {
    expect(
      stillShootingDue(_on(), _since.subtract(const Duration(days: 30))),
      isFalse,
    );
  });

  test('a local now compares as the same instant', () {
    final at = _since.add(const Duration(days: 14)).toLocal();

    expect(stillShootingDue(_on(), at), isTrue);
  });
}
