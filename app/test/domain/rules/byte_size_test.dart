import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/domain/rules/byte_size.dart';

void expectSize(int bytes, ByteUnit unit, String number) {
  final s = byteSize(bytes);
  expect(s.unit, unit, reason: '$bytes unit');
  expect(s.number, number, reason: '$bytes number');
}

void main() {
  test('0 is 0 MB', () => expectSize(0, ByteUnit.mb, '0'));
  test('1 byte is 1 MB', () => expectSize(1, ByteUnit.mb, '1'));
  test('499,999 is 1 MB (never 0)', () => expectSize(499999, ByteUnit.mb, '1'));
  test('500,000 is 1 MB', () => expectSize(500000, ByteUnit.mb, '1'));
  test('1,499,999 is 1 MB', () => expectSize(1499999, ByteUnit.mb, '1'));
  test(
    '1,500,000 is 2 MB (half up)',
    () => expectSize(1500000, ByteUnit.mb, '2'),
  );
  test('900 MB', () => expectSize(900000000, ByteUnit.mb, '900'));
  test(
    '999,499,999 is 999 MB',
    () => expectSize(999499999, ByteUnit.mb, '999'),
  );
  test('999,500,000 is 1 GB, never 1000 MB', () {
    expectSize(999500000, ByteUnit.gb, '1');
  });
  test('1,000,000,000 is 1 GB', () => expectSize(1000000000, ByteUnit.gb, '1'));
  test('1,049,999,999 is 1 GB', () => expectSize(1049999999, ByteUnit.gb, '1'));
  test('1,050,000,000 is 1.1 GB', () {
    expectSize(1050000000, ByteUnit.gb, '1.1');
  });
  test('1,250,000,000 is 1.3 GB (half up)', () {
    expectSize(1250000000, ByteUnit.gb, '1.3');
  });
  test(
    '1,249,999,999 is 1.2 GB',
    () => expectSize(1249999999, ByteUnit.gb, '1.2'),
  );
  test('12 GB', () => expectSize(12000000000, ByteUnit.gb, '12'));
  test('12.3 GB keeps its decimal', () {
    expectSize(12340000000, ByteUnit.gb, '12.3');
  });
  test('9,950,000,000 is 10 GB, never 9.10', () {
    expectSize(9950000000, ByteUnit.gb, '10');
  });
  test(
    '9,949,999,999 is 9.9 GB',
    () => expectSize(9949999999, ByteUnit.gb, '9.9'),
  );
  test('a very large size', () {
    expectSize(256000000000, ByteUnit.gb, '256');
    expectSize(9000000000000000, ByteUnit.gb, '9000000');
  });
  test('a negative size reads as 0 MB', () {
    expectSize(-5, ByteUnit.mb, '0');
  });
}
