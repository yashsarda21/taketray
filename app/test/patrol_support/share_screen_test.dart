import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import '../../patrol_test/support/share_screen.dart';

/// A phone for [ShareScreen]: [shown] are the selectors that match something
/// now (with the count they match), and what was asked of it is written down.
class _FakeScreen implements NativeScreen {
  final Map<AndroidSelector, int> shown = {};
  final List<AndroidSelector> taps = [];
  final List<(String, int)> typed = [];
  final List<AndroidSelector> looked = [];
  int looks = 0;
  void Function(int looks)? onLook;
  Exception? describeError;

  @override
  Future<int> count(AndroidSelector selector) async {
    looks++;
    looked.add(selector);
    onLook?.call(looks);
    return shown[selector] ?? 0;
  }

  @override
  Future<void> tap(AndroidSelector selector) async => taps.add(selector);

  @override
  Future<void> enterTextByIndex(String text, {required int index}) async =>
      typed.add((text, index));

  @override
  Future<String> describe() async {
    final error = describeError;
    if (error != null) throw error;
    return 'android:id/content, android.widget.FrameLayout';
  }
}

const _states = [
  ShareState(title: 'Save reference', button: 'Cancel'),
  ShareState(title: "This isn't a link", button: 'Close'),
  ShareState(title: 'Saved to', titleContains: true, button: 'Done'),
];

void main() {
  late _FakeScreen phone;
  late ShareScreen screen;

  setUp(() {
    phone = _FakeScreen();
    screen = ShareScreen(phone, poll: const Duration(milliseconds: 1));
  });

  group('selectorsFor', () {
    test('exact words: the text, then the description', () {
      expect(selectorsFor('Save'), [
        const AndroidSelector(text: 'Save'),
        const AndroidSelector(contentDescription: 'Save'),
      ]);
    });

    test('part of the words: the text, then the description', () {
      expect(selectorsFor('Saved to', contains: true), [
        const AndroidSelector(textContains: 'Saved to'),
        const AndroidSelector(contentDescriptionContains: 'Saved to'),
      ]);
    });
  });

  group('enabled', () {
    test('adds the enabled state to both selectors, and only then', () {
      expect(selectorsFor('Save', enabled: true), [
        const AndroidSelector(text: 'Save', isEnabled: true),
        const AndroidSelector(contentDescription: 'Save', isEnabled: true),
      ]);
      expect(selectorsFor('Save'), [
        const AndroidSelector(text: 'Save'),
        const AndroidSelector(contentDescription: 'Save'),
      ]);
      expect(selectorsFor('Sa', contains: true, enabled: true), [
        const AndroidSelector(textContains: 'Sa', isEnabled: true),
        const AndroidSelector(
          contentDescriptionContains: 'Sa',
          isEnabled: true,
        ),
      ]);
    });

    test(
      'a disabled button is not found, and waiting for it taps nothing',
      () async {
        // Only the disabled node matches the plain words.
        phone.shown[const AndroidSelector(text: 'Save')] = 1;
        expect(await screen.isShown('Save', enabled: true), isFalse);
        await expectLater(
          screen.tap(
            'Save',
            what: 'Save',
            enabled: true,
            timeout: const Duration(milliseconds: 10),
          ),
          throwsA(isA<TestFailure>()),
        );
        expect(phone.taps, isEmpty);
      },
    );

    test('an enabled button is tapped by its enabled selector', () async {
      phone.shown[const AndroidSelector(text: 'Save', isEnabled: true)] = 1;
      await screen.tap('Save', what: 'Save', enabled: true);
      expect(phone.taps, [
        const AndroidSelector(text: 'Save', isEnabled: true),
      ]);
    });
  });

  group('find', () {
    test('finds words that are in the text, and says which selector', () async {
      phone.shown[const AndroidSelector(text: 'Save')] = 1;
      expect(await screen.find('Save'), const AndroidSelector(text: 'Save'));
    });

    test('finds words that are only in the description', () async {
      phone.shown[const AndroidSelector(contentDescription: 'Save')] = 1;
      expect(
        await screen.find('Save'),
        const AndroidSelector(contentDescription: 'Save'),
      );
    });

    test('is null when neither has them, and looked at both', () async {
      expect(await screen.find('Save'), isNull);
      expect(phone.looked, selectorsFor('Save'));
    });

    test(
      'exact words never match a part (Save is not Save reference)',
      () async {
        phone.shown[const AndroidSelector(textContains: 'Save')] = 2;
        expect(await screen.find('Save'), isNull);
        expect(await screen.isShown('Save'), isFalse);
        expect(await screen.isShown('Save', contains: true), isTrue);
      },
    );
  });

  group('waitFor', () {
    test('returns as soon as the words show, however late', () async {
      phone.onLook = (n) {
        if (n == 6) phone.shown[const AndroidSelector(text: 'Done')] = 1;
      };
      final found = await screen.waitFor('Done', what: 'Done');
      expect(found, const AndroidSelector(text: 'Done'));
      expect(phone.looks, greaterThanOrEqualTo(6));
    });

    test('fails saying what it waited for, and the ids on screen', () async {
      await expectLater(
        screen.waitFor(
          'Done',
          what: 'the Done button',
          timeout: const Duration(milliseconds: 30),
        ),
        throwsA(
          isA<TestFailure>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('the Done button'),
              contains('Timed out after 0 s'),
              contains('android:id/content'),
              isNot(contains('"Done"')),
            ),
          ),
        ),
      );
    });

    test('still fails clearly when the screen cannot be described', () async {
      phone.describeError = Exception('no screen');
      await expectLater(
        screen.waitFor(
          'Done',
          what: 'the Done button',
          timeout: const Duration(milliseconds: 10),
        ),
        throwsA(
          isA<TestFailure>().having(
            (e) => e.message,
            'message',
            allOf(contains('the Done button'), contains('(not readable)')),
          ),
        ),
      );
    });
  });

  group('waitGone', () {
    test('returns when the words have gone', () async {
      phone.shown[const AndroidSelector(text: 'Done')] = 1;
      phone.onLook = (n) {
        if (n == 5) phone.shown.clear();
      };
      await screen.waitGone('Done', what: 'Done');
      expect(phone.looks, greaterThanOrEqualTo(5));
    });

    test('returns at once when they were never there', () async {
      await screen.waitGone('Done', what: 'Done');
    });

    test('fails when they stay, saying what', () async {
      phone.shown[const AndroidSelector(contentDescription: 'Done')] = 1;
      await expectLater(
        screen.waitGone(
          'Done',
          what: 'the Done button to go',
          timeout: const Duration(milliseconds: 20),
        ),
        throwsA(
          isA<TestFailure>().having(
            (e) => e.message,
            'message',
            contains('the Done button to go'),
          ),
        ),
      );
    });
  });

  group('tap', () {
    test('taps the selector that matched, once', () async {
      phone.shown[const AndroidSelector(contentDescription: 'Save')] = 1;
      await screen.tap('Save', what: 'Save');
      expect(phone.taps, [const AndroidSelector(contentDescription: 'Save')]);
    });

    test('waits for the words first', () async {
      phone.onLook = (n) {
        if (n == 4) phone.shown[const AndroidSelector(text: 'Save')] = 1;
      };
      await screen.tap('Save', what: 'Save');
      expect(phone.taps, [const AndroidSelector(text: 'Save')]);
    });

    test('taps nothing when the words never show', () async {
      await expectLater(
        screen.tap(
          'Save',
          what: 'Save',
          timeout: const Duration(milliseconds: 10),
        ),
        throwsA(isA<TestFailure>()),
      );
      expect(phone.taps, isEmpty);
    });

    test('a row is found by part of its words', () async {
      phone.shown[const AndroidSelector(
            textContains: 'TakeTray Test Share A',
          )] =
          1;
      await screen.tap('TakeTray Test Share A', what: 'row', contains: true);
      expect(phone.taps, [
        const AndroidSelector(textContains: 'TakeTray Test Share A'),
      ]);
    });
  });

  group('enterText', () {
    test('waits for enough fields, then types in the one asked for', () async {
      phone.onLook = (n) {
        if (n == 3) phone.shown[textFieldSelector] = 1;
        if (n == 6) phone.shown[textFieldSelector] = 2;
      };
      await screen.enterText('TakeTray Test Share B', index: 1, what: 'name');
      expect(phone.typed, [('TakeTray Test Share B', 1)]);
      expect(phone.looks, greaterThanOrEqualTo(6));
    });

    test('types nothing, and says so, when the field never comes', () async {
      phone.shown[textFieldSelector] = 1;
      await expectLater(
        screen.enterText(
          'x',
          index: 1,
          what: 'the name field',
          timeout: const Duration(milliseconds: 10),
        ),
        throwsA(
          isA<TestFailure>().having(
            (e) => e.message,
            'message',
            contains('the name field'),
          ),
        ),
      );
      expect(phone.typed, isEmpty);
    });
  });

  group('closeIfOpen', () {
    test(
      'taps nothing when no share screen is up (the app has a Done)',
      () async {
        phone.shown[const AndroidSelector(text: 'Done')] = 1;
        phone.shown[const AndroidSelector(text: 'Cancel')] = 1;
        phone.shown[const AndroidSelector(text: 'Close')] = 1;
        expect(await screen.closeIfOpen(_states), isFalse);
        expect(phone.taps, isEmpty);
      },
    );

    test('the form is closed with Cancel only', () async {
      phone.shown[const AndroidSelector(text: 'Save reference')] = 1;
      phone.shown[const AndroidSelector(text: 'Cancel')] = 1;
      phone.shown[const AndroidSelector(text: 'Done')] = 1;
      phone.onLook = (n) {
        if (phone.taps.isNotEmpty) phone.shown.clear();
      };
      expect(await screen.closeIfOpen(_states), isTrue);
      expect(phone.taps, [const AndroidSelector(text: 'Cancel')]);
    });

    test('"not a link" is closed with Close', () async {
      phone.shown[const AndroidSelector(text: "This isn't a link")] = 1;
      phone.shown[const AndroidSelector(text: 'Close')] = 1;
      phone.onLook = (n) {
        if (phone.taps.isNotEmpty) phone.shown.clear();
      };
      expect(await screen.closeIfOpen(_states), isTrue);
      expect(phone.taps, [const AndroidSelector(text: 'Close')]);
    });

    test(
      'the saved state (a title with the reel after it) is closed with Done',
      () async {
        phone.shown[const AndroidSelector(textContains: 'Saved to')] = 1;
        phone.shown[const AndroidSelector(text: 'Done')] = 1;
        phone.onLook = (n) {
          if (phone.taps.isNotEmpty) phone.shown.clear();
        };
        expect(await screen.closeIfOpen(_states), isTrue);
        expect(phone.taps, [const AndroidSelector(text: 'Done')]);
      },
    );

    test('a title with no button on screen fails, it does not guess', () async {
      phone.shown[const AndroidSelector(text: 'Save reference')] = 1;
      await expectLater(
        screen.closeIfOpen(
          _states,
          buttonTimeout: const Duration(milliseconds: 10),
        ),
        throwsA(isA<TestFailure>()),
      );
      expect(phone.taps, isEmpty);
    });

    test('never taps more often than there are states', () async {
      phone.shown[const AndroidSelector(text: 'Save reference')] = 1;
      phone.shown[const AndroidSelector(text: 'Cancel')] = 1;
      // The screen never goes away.
      expect(await screen.closeIfOpen(_states), isTrue);
      expect(phone.taps, hasLength(_states.length));
    });
  });
}
