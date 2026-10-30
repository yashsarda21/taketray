import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/app.dart';

void main() {
  const supported = [Locale('en')];

  group('resolvePhoneLocale (D-79)', () {
    test("keeps the phone's region when the language is supported", () {
      expect(
        resolvePhoneLocale(const [Locale('en', 'IN')], supported),
        const Locale('en', 'IN'),
      );
      expect(
        resolvePhoneLocale(const [Locale('en', 'GB')], supported),
        const Locale('en', 'GB'),
      );
      expect(
        resolvePhoneLocale(const [Locale('en', 'US')], supported),
        const Locale('en', 'US'),
      );
    });

    test("takes the first of the phone's languages that the app has", () {
      expect(
        resolvePhoneLocale(const [
          Locale('fr', 'FR'),
          Locale('en', 'AU'),
          Locale('de'),
        ], supported),
        const Locale('en', 'AU'),
      );
    });

    test('falls back to the first supported locale', () {
      expect(resolvePhoneLocale(const [Locale('fr')], supported), supported[0]);
      expect(resolvePhoneLocale(null, supported), supported[0]);
      expect(resolvePhoneLocale(const [], supported), supported[0]);
    });
  });
}
