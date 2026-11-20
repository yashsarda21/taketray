import 'dart:async';
import 'dart:io';

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

  /// What [count] throws, when set (a screen that cannot be read).
  Error? countError;

  /// The bounds each selector's node has on the screen.
  final Map<AndroidSelector, ({double top, double bottom})> bounds = {};

  /// The top of the keyboard, or null when there is none.
  double? keyboard;

  @override
  Future<int> count(AndroidSelector selector) async {
    looks++;
    looked.add(selector);
    onLook?.call(looks);
    final error = countError;
    if (error != null) throw error;
    return shown[selector] ?? 0;
  }

  @override
  Future<({double top, double bottom})?> boundsOf(
    AndroidSelector selector,
  ) async => bounds[selector];

  @override
  Future<double?> keyboardTop() async => keyboard;

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

/// The app's own package, which the share screen's nodes carry.
const _app = 'app.taketray.dev';

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
        phone.shown[const AndroidSelector(
              text: 'Done',
              applicationPackage: _app,
            )] =
            1;
        phone.shown[const AndroidSelector(
              text: 'Cancel',
              applicationPackage: _app,
            )] =
            1;
        phone.shown[const AndroidSelector(
              text: 'Close',
              applicationPackage: _app,
            )] =
            1;
        expect(await screen.closeIfOpen(_states), isFalse);
        expect(phone.taps, isEmpty);
      },
    );

    test('the form is closed with Cancel only', () async {
      phone.shown[const AndroidSelector(
            text: 'Save reference',
            applicationPackage: _app,
          )] =
          1;
      phone.shown[const AndroidSelector(
            text: 'Cancel',
            applicationPackage: _app,
          )] =
          1;
      phone.shown[const AndroidSelector(
            text: 'Done',
            applicationPackage: _app,
          )] =
          1;
      phone.onLook = (n) {
        if (phone.taps.isNotEmpty) phone.shown.clear();
      };
      expect(await screen.closeIfOpen(_states), isTrue);
      expect(phone.taps, [
        const AndroidSelector(text: 'Cancel', applicationPackage: _app),
      ]);
    });

    test('"not a link" is closed with Close', () async {
      phone.shown[const AndroidSelector(
            text: "This isn't a link",
            applicationPackage: _app,
          )] =
          1;
      phone.shown[const AndroidSelector(
            text: 'Close',
            applicationPackage: _app,
          )] =
          1;
      phone.onLook = (n) {
        if (phone.taps.isNotEmpty) phone.shown.clear();
      };
      expect(await screen.closeIfOpen(_states), isTrue);
      expect(phone.taps, [
        const AndroidSelector(text: 'Close', applicationPackage: _app),
      ]);
    });

    test(
      'the saved state (a title with the reel after it) is closed with Done',
      () async {
        phone.shown[const AndroidSelector(
              textContains: 'Saved to',
              applicationPackage: _app,
            )] =
            1;
        phone.shown[const AndroidSelector(
              text: 'Done',
              applicationPackage: _app,
            )] =
            1;
        phone.onLook = (n) {
          if (phone.taps.isNotEmpty) phone.shown.clear();
        };
        expect(await screen.closeIfOpen(_states), isTrue);
        expect(phone.taps, [
          const AndroidSelector(text: 'Done', applicationPackage: _app),
        ]);
      },
    );

    test('a title with no button on screen fails, it does not guess', () async {
      phone.shown[const AndroidSelector(
            text: 'Save reference',
            applicationPackage: _app,
          )] =
          1;
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
      phone.shown[const AndroidSelector(
            text: 'Save reference',
            applicationPackage: _app,
          )] =
          1;
      phone.shown[const AndroidSelector(
            text: 'Cancel',
            applicationPackage: _app,
          )] =
          1;
      // The screen never goes away.
      expect(await screen.closeIfOpen(_states), isTrue);
      expect(phone.taps, hasLength(_states.length));
    });

    test(
      "another app's Done is never tapped, whatever its words (M26)",
      () async {
        // A foreign app shows every word the share screen does, in its own
        // package; nothing carries the app's own.
        for (final words in [
          'Save reference',
          "This isn't a link",
          'Done',
          'Close',
          'Cancel',
        ]) {
          phone.shown[AndroidSelector(
                text: words,
                applicationPackage: 'com.example.other',
              )] =
              1;
          phone.shown[AndroidSelector(text: words)] = 1;
        }
        phone.shown[const AndroidSelector(
              textContains: 'Saved to',
              applicationPackage: 'com.example.other',
            )] =
            1;

        expect(await screen.closeIfOpen(_states), isFalse);

        expect(phone.taps, isEmpty);
      },
    );

    test("a foreign Done beside the app's own share screen is not the one "
        'tapped (M26)', () async {
      phone.shown[const AndroidSelector(
            text: 'Saved to Goa',
            applicationPackage: _app,
          )] =
          1;
      phone.shown[const AndroidSelector(
            textContains: 'Saved to',
            applicationPackage: _app,
          )] =
          1;
      phone.shown[const AndroidSelector(
            text: 'Done',
            applicationPackage: 'com.example.other',
          )] =
          1;
      phone.shown[const AndroidSelector(
            text: 'Done',
            applicationPackage: _app,
          )] =
          1;
      phone.onLook = (n) {
        if (phone.taps.isNotEmpty) phone.shown.clear();
      };

      expect(await screen.closeIfOpen(_states), isTrue);

      expect(phone.taps, [
        const AndroidSelector(text: 'Done', applicationPackage: _app),
      ]);
    });

    test('every look it makes is scoped to the app package (M26)', () async {
      await screen.closeIfOpen(_states);

      expect(phone.looked, isNotEmpty);
      for (final selector in phone.looked) {
        expect(selector.applicationPackage, _app, reason: '$selector');
      }
    });

    test('a different package can be given (a release build)', () async {
      final other = ShareScreen(
        phone,
        poll: const Duration(milliseconds: 1),
        appPackage: 'app.taketray',
      );
      phone.shown[const AndroidSelector(
            text: 'Save reference',
            applicationPackage: 'app.taketray',
          )] =
          1;
      phone.shown[const AndroidSelector(
            text: 'Cancel',
            applicationPackage: 'app.taketray',
          )] =
          1;
      phone.onLook = (n) {
        if (phone.taps.isNotEmpty) phone.shown.clear();
      };

      expect(await other.closeIfOpen(_states), isTrue);
    });

    test('a screen that cannot be read fails it, it does not close nothing '
        '(M24)', () async {
      phone.countError = StateError('UiAutomation is gone');

      await expectLater(screen.closeIfOpen(_states), throwsStateError);
      expect(phone.taps, isEmpty);
    });
  });

  group('a screen that cannot be read (M24)', () {
    test('an absent check fails with the error, it does not pass', () async {
      phone.countError = StateError('UiAutomation is gone');

      await expectLater(screen.isShown('Save'), throwsStateError);
      await expectLater(screen.find('Save'), throwsStateError);
    });

    test(
      'waitGone does not take an unreadable screen for a gone one',
      () async {
        phone.countError = StateError('UiAutomation is gone');

        await expectLater(
          screen.waitGone('Done', what: 'Done'),
          throwsStateError,
        );
      },
    );

    test('waitFor and tap fail with the error too', () async {
      phone.countError = StateError('UiAutomation is gone');

      await expectLater(screen.waitFor('Done', what: 'Done'), throwsStateError);
      await expectLater(screen.tap('Done', what: 'Done'), throwsStateError);
      expect(phone.taps, isEmpty);
    });

    test(
      'countMatching: "nothing matches" is 0, whichever way Patrol says it',
      () async {
        for (final message in [
          'getNativeViews() failed with UiObjectNotFoundException: x',
          'No views matching the selector',
          'Native view not found',
          'no match for the selector',
        ]) {
          expect(
            await countMatching(
              () async => throw PatrolActionException(message),
            ),
            0,
            reason: message,
          );
        }
      },
    );

    test(
      'countMatching: anything else is rethrown, not counted as 0',
      () async {
        final errors = <Object>[
          PatrolActionException('Connection refused'),
          PatrolActionException('UiAutomation not connected'),
          const SocketException('Connection reset by peer'),
          StateError('dead'),
          TimeoutException('too slow'),
        ];
        for (final error in errors) {
          await expectLater(
            countMatching(
              () async => Error.throwWithStackTrace(error, StackTrace.current),
            ),
            throwsA(same(error)),
            reason: '$error',
          );
        }
      },
    );

    test('countMatching: a count passes through', () async {
      expect(await countMatching(() async => 3), 3);
      expect(await countMatching(() async => 0), 0);
    });
  });

  group('tapSave (M25)', () {
    const save = AndroidSelector(text: 'Save', isEnabled: true);

    test('with no keyboard it taps', () async {
      phone.shown[save] = 1;
      phone.bounds[save] = (top: 1500, bottom: 1620);

      await screen.tapSave('Save', what: 'Save');

      expect(phone.taps, [save]);
    });

    test('above the keyboard it taps', () async {
      phone.shown[save] = 1;
      phone.bounds[save] = (top: 1100, bottom: 1220);
      phone.keyboard = 1300;

      await screen.tapSave('Save', what: 'Save');

      expect(phone.taps, [save]);
    });

    test('touching the keyboard, within two pixels, still taps', () async {
      phone.shown[save] = 1;
      phone.bounds[save] = (top: 1100, bottom: 1302);
      phone.keyboard = 1300;

      await screen.tapSave('Save', what: 'Save');

      expect(phone.taps, [save]);
    });

    test('under the keyboard it fails, saying so, and taps nothing', () async {
      phone.shown[save] = 1;
      phone.bounds[save] = (top: 1100, bottom: 1303);
      phone.keyboard = 1300;

      await expectLater(
        screen.tapSave('Save', what: 'the "Save" button'),
        throwsA(
          isA<TestFailure>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('the "Save" button'),
              contains('keyboard'),
              contains('1303'),
              contains('1300'),
            ),
          ),
        ),
      );
      expect(phone.taps, isEmpty);
    });

    test('wholly under the keyboard fails too', () async {
      phone.shown[save] = 1;
      phone.bounds[save] = (top: 1400, bottom: 1520);
      phone.keyboard = 1300;

      await expectLater(
        screen.tapSave('Save', what: 'Save'),
        throwsA(isA<TestFailure>()),
      );
      expect(phone.taps, isEmpty);
    });

    test(
      'bounds that cannot be read are not a reason to fail: it taps',
      () async {
        phone.shown[save] = 1;
        phone.keyboard = 1300;

        await screen.tapSave('Save', what: 'Save');

        expect(phone.taps, [save]);
      },
    );

    test('a disabled Save is waited for, never tapped', () async {
      phone.shown[const AndroidSelector(text: 'Save')] = 1;

      await expectLater(
        screen.tapSave(
          'Save',
          what: 'Save',
          timeout: const Duration(milliseconds: 10),
        ),
        throwsA(isA<TestFailure>()),
      );
      expect(phone.taps, isEmpty);
    });

    test('a keyboard that cannot be read does not hide the cover', () async {
      // A keyboard read that throws is the screen being unreadable.
      phone.shown[save] = 1;
      phone.bounds[save] = (top: 1100, bottom: 1220);
      phone.countError = StateError('gone');

      await expectLater(screen.tapSave('Save', what: 'Save'), throwsStateError);
      expect(phone.taps, isEmpty);
    });
  });

  group('keyboardTopOf (M25)', () {
    const nodes = <({String? package, double top})>[
      (package: 'app.taketray.dev', top: 0),
    ];

    test('the top of a window of another package that starts below the top '
        'of the screen', () {
      expect(
        keyboardTopOf([
          ...nodes,
          (package: 'com.samsung.android.honeyboard', top: 1300),
          (package: 'com.samsung.android.honeyboard', top: 1420),
        ], appPackage: 'app.taketray.dev'),
        1300,
      );
    });

    test("the app's own nodes are never the keyboard", () {
      expect(
        keyboardTopOf([
          (package: 'app.taketray.dev', top: 1300),
        ], appPackage: 'app.taketray.dev'),
        isNull,
      );
    });

    test('the system bars are not the keyboard', () {
      expect(
        keyboardTopOf([
          (package: 'com.android.systemui', top: 2300),
          (package: 'android', top: 2300),
        ], appPackage: 'app.taketray.dev'),
        isNull,
      );
    });

    test('a full-screen window behind the share (the sharing app) is not '
        'the keyboard', () {
      expect(
        keyboardTopOf([
          (package: 'com.instagram.android', top: 0),
        ], appPackage: 'app.taketray.dev'),
        isNull,
      );
    });

    test('nothing at all, or a node with no package, is no keyboard', () {
      expect(keyboardTopOf(const [], appPackage: 'app.taketray.dev'), isNull);
      expect(
        keyboardTopOf([
          (package: null, top: 1300),
        ], appPackage: 'app.taketray.dev'),
        isNull,
      );
    });
  });
}
