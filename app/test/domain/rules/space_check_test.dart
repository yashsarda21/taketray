import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/domain/rules/space_check.dart';

void main() {
  test('the reserve is 500 MB, decimal', () {
    expect(copyReserveBytes, 500000000);
  });

  test('enough exactly at need + reserve == free', () {
    final r = spaceCheck(needBytes: 1000, freeBytes: 1000 + copyReserveBytes);
    expect(r.enough, isTrue);
    expect(r.shortByBytes, 0);
    expect(r.freeAfterBytes, copyReserveBytes);
  });

  test('one byte less is short by exactly 1', () {
    final r = spaceCheck(
      needBytes: 1000,
      freeBytes: 1000 + copyReserveBytes - 1,
    );
    expect(r.enough, isFalse);
    expect(r.shortByBytes, 1);
  });

  test('one byte more is enough', () {
    final r = spaceCheck(
      needBytes: 1000,
      freeBytes: 1000 + copyReserveBytes + 1,
    );
    expect(r.enough, isTrue);
    expect(r.shortByBytes, 0);
  });

  test('freeAfterBytes is free minus need', () {
    expect(
      spaceCheck(needBytes: 3000000000, freeBytes: 10000000000).freeAfterBytes,
      7000000000,
    );
  });

  test('need 0 is enough when free covers the reserve', () {
    expect(
      spaceCheck(needBytes: 0, freeBytes: copyReserveBytes).enough,
      isTrue,
    );
    expect(spaceCheck(needBytes: 0, freeBytes: 0).enough, isFalse);
    expect(
      spaceCheck(needBytes: 0, freeBytes: 0).shortByBytes,
      copyReserveBytes,
    );
  });

  test('a free below the reserve is short even for a tiny need', () {
    final r = spaceCheck(needBytes: 1, freeBytes: copyReserveBytes - 1);
    expect(r.enough, isFalse);
    expect(r.shortByBytes, 2);
  });

  test(
    'when short, shortBy counts the reserve and freeAfter can be negative',
    () {
      final r = spaceCheck(needBytes: 2000000000, freeBytes: 1000000000);
      expect(r.enough, isFalse);
      expect(r.shortByBytes, 1500000000);
      expect(r.freeAfterBytes, -1000000000);
    },
  );
}
