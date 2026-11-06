import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../patrol_test/support/own_texts.dart';

/// The guard of the on-device shade helpers (patrol_test/support): the shade
/// is only ever matched against TakeTray's own exact texts.
void main() {
  group('OwnText', () {
    // The native copy the notifications are built from (D-101).
    final strings = File('android/app/src/main/res/values/strings.xml')
        .readAsStringSync();

    String plural(String name, String quantity, int n) {
      final block = RegExp(
        '<plurals name="$name">(.*?)</plurals>',
        dotAll: true,
      ).firstMatch(strings)!.group(1)!;
      final item = RegExp('<item quantity="$quantity">(.*?)</item>')
          .firstMatch(block)!
          .group(1)!;
      return item.replaceAll('%d', '$n');
    }

    test('the new-clips title is the native plural, one and other', () {
      expect(OwnText.newClips(1).value, plural('new_clips_title', 'one', 1));
      expect(OwnText.newClips(1).value, '1 new clip to tag');
      expect(OwnText.newClips(2).value, plural('new_clips_title', 'other', 2));
      expect(OwnText.newClips(3).value, '3 new clips to tag');
    });

    test('the evening title is the native plural, one and other', () {
      expect(OwnText.evening(1).value, plural('evening_title', 'one', 1));
      expect(OwnText.evening(2).value, plural('evening_title', 'other', 2));
      expect(OwnText.evening(2).value, 'You shot 2 clips today. Tag them?');
    });

    test('a count of zero or less is no notification text', () {
      expect(() => OwnText.newClips(0), throwsArgumentError);
      expect(() => OwnText.evening(-1), throwsArgumentError);
    });

    test('matches only the exact text, never a part of it', () {
      final two = OwnText.newClips(2);
      expect(two.matches('2 new clips to tag'), isTrue);
      expect(two.matches('12 new clips to tag'), isFalse);
      expect(two.matches('2 new clips to tag today'), isFalse);
      expect(two.matches('new clip'), isFalse);
      expect(two.matches(null), isFalse);
    });
  });
}
