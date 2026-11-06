import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/domain/rules/phone_brand.dart';

void main() {
  group('brand mapping', () {
    test('every maker TakeTray has steps for', () {
      expect(brandOf('samsung'), PhoneBrand.samsung);
      expect(brandOf('xiaomi'), PhoneBrand.xiaomi);
      expect(brandOf('redmi'), PhoneBrand.xiaomi);
      expect(brandOf('poco'), PhoneBrand.xiaomi);
      expect(brandOf('oppo'), PhoneBrand.oppo);
      expect(brandOf('realme'), PhoneBrand.oppo);
      expect(brandOf('vivo'), PhoneBrand.vivo);
      expect(brandOf('iqoo'), PhoneBrand.vivo);
      expect(brandOf('oneplus'), PhoneBrand.oneplus);
    });

    test('any other maker is no brand', () {
      for (final maker in ['google', 'motorola', 'honor', 'nothing', '']) {
        expect(brandOf(maker), isNull, reason: 'maker "$maker"');
      }
    });

    test('only the whole name counts, not a part of it', () {
      expect(brandOf('samsungx'), isNull);
      expect(brandOf('notsamsung'), isNull);
      expect(brandOf('one plus'), isNull);
      expect(brandOf('vivox'), isNull);
    });

    test('letter case and stray spaces do not matter', () {
      expect(brandOf('Samsung'), PhoneBrand.samsung);
      expect(brandOf(' ONEPLUS '), PhoneBrand.oneplus);
      expect(brandOf('Realme\n'), PhoneBrand.oppo);
    });

    test('the brands, in the order the help screen lists them', () {
      expect(PhoneBrand.values, [
        PhoneBrand.samsung,
        PhoneBrand.xiaomi,
        PhoneBrand.oppo,
        PhoneBrand.vivo,
        PhoneBrand.oneplus,
      ]);
    });
  });
}
