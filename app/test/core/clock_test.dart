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
