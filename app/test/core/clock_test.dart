import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/core/clock.dart';

import '../support/fixed_clock.dart';

void main() {
  test('the clock tells the time in UTC', () {
    final before = DateTime.now();
    final now = const Clock().now();

    expect(now.isUtc, isTrue);
    expect(now.isBefore(before), isFalse);
  });

  test('storedNow is now to the millisecond, as the database stores it', () {
    final fixed = FixedClock(DateTime.utc(2026, 10, 26, 9, 0, 0, 123, 456));

    expect(fixed.now(), DateTime.utc(2026, 10, 26, 9, 0, 0, 123, 456));
    expect(fixed.storedNow(), DateTime.utc(2026, 10, 26, 9, 0, 0, 123));
    expect(fixed.storedNow().isUtc, isTrue);
    expect(const Clock().storedNow().microsecond, 0);
    expect(const Clock().storedNow().isUtc, isTrue);
  });

  test('clockProvider gives the real clock, and tests can replace it', () {
    final real = ProviderContainer();
    addTearDown(real.dispose);
    expect(real.read(clockProvider), isNot(isA<FixedClock>()));

    final fixed = FixedClock(DateTime.utc(2026, 10, 26, 9));
    final container = ProviderContainer(
      overrides: [clockProvider.overrideWithValue(fixed)],
    );
    addTearDown(container.dispose);
    fixed.advance(const Duration(minutes: 5));

    expect(
      container.read(clockProvider).now(),
      DateTime.utc(2026, 10, 26, 9, 5),
    );
  });
}
