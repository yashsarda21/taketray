import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import '../../patrol_test/support/own_texts.dart';
import '../../patrol_test/support/shade_geometry.dart';

/// The two guards of the on-device shade helpers (patrol_test/support): the
/// shade is only ever matched against TakeTray's own exact texts, and the one
/// tap that is not on a notification ("Turn off") lands only on TakeTray's own
/// button, at the very spot two looks agreed on.
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

    String string(String name) =>
        RegExp('<string name="$name">(.*?)</string>')
            .firstMatch(strings)!
            .group(1)!;

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

    test('the Still shooting? text is the whole native text', () {
      expect(OwnText.stillBody.value, string('still_text'));
    });

    test('the Still shooting? buttons are the native labels', () {
      expect(StillButton.turnOff.label, string('action_turn_off'));
      expect(StillButton.keepOn.label, string('action_keep_on'));
      expect(StillButton.turnOff.sibling, StillButton.keepOn);
      expect(StillButton.keepOn.sibling, StillButton.turnOff);
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
      expect(OwnText.stillBody.matches('Shooting mode has been on'), isFalse);
    });
  });

  group('ownButton', () {
    // S24-like pixels (density 3): TakeTray's Still shooting? text, and its
    // action row just below it, "Turn off" then "Keep on".
    const text = Rect.fromLTWH(96, 900, 880, 60); // bottom 960
    const turnOff = Rect.fromLTWH(96, 990, 300, 130);
    const keepOn = Rect.fromLTWH(420, 990, 300, 130);

    // Another app's notification with the same two button labels.
    Rect otherTurnOff(double top) => Rect.fromLTWH(96, top, 300, 130);
    Rect otherKeepOn(double top) => Rect.fromLTWH(420, top, 300, 130);

    test('picks the Turn off on the row of Keep on, just below the text', () {
      expect(
        ownButton(
          const ShadeLook(
            anchors: [text],
            buttons: [turnOff],
            siblings: [keepOn],
          ),
        ),
        turnOff,
      );
    });

    test("another app's buttons above the text are not ours", () {
      expect(
        ownButton(
          ShadeLook(
            anchors: const [text],
            buttons: [otherTurnOff(600), turnOff],
            siblings: [otherKeepOn(600), keepOn],
          ),
        ),
        turnOff,
      );
    });

    test("another app's buttons above the text, ours collapsed: none", () {
      expect(
        ownButton(
          ShadeLook(
            anchors: const [text],
            buttons: [otherTurnOff(760)],
            siblings: [otherKeepOn(760)],
          ),
        ),
        isNull,
      );
    });

    test("another app's buttons in the notification below are not ours", () {
      expect(
        ownButton(
          ShadeLook(
            anchors: const [text],
            buttons: [otherTurnOff(1400), turnOff],
            siblings: [otherKeepOn(1400), keepOn],
          ),
        ),
        turnOff,
      );
    });

    test("ours collapsed (no buttons): the next notification's row is not "
        'taken instead', () {
      // The notification below starts after ours: its header and title, then
      // its own Turn off / Keep on row, well within 600 px of our text.
      expect(
        ownButton(
          ShadeLook(
            anchors: const [text],
            buttons: [otherTurnOff(1250)],
            siblings: [otherKeepOn(1250)],
          ),
        ),
        isNull,
      );
    });

    test("another app's lone Turn off just below, with no Keep on: none", () {
      expect(
        ownButton(
          const ShadeLook(anchors: [text], buttons: [turnOff], siblings: []),
        ),
        isNull,
      );
    });

    test('a Keep on on another row does not make a Turn off ours', () {
      expect(
        ownButton(
          ShadeLook(
            anchors: const [text],
            buttons: const [turnOff],
            siblings: [otherKeepOn(1400)],
          ),
        ),
        isNull,
      );
    });

    test('no Turn off at all: none', () {
      expect(
        ownButton(
          const ShadeLook(anchors: [text], buttons: [], siblings: [keepOn]),
        ),
        isNull,
      );
    });

    test('two TakeTray texts (two notifications): none, it is not clear '
        'which', () {
      const second = Rect.fromLTWH(96, 1500, 880, 60);
      expect(
        ownButton(
          ShadeLook(
            anchors: const [text, second],
            buttons: [turnOff, otherTurnOff(1590)],
            siblings: [keepOn, otherKeepOn(1590)],
          ),
        ),
        isNull,
      );
    });

    test('no TakeTray text: none', () {
      expect(
        ownButton(
          const ShadeLook(anchors: [], buttons: [turnOff], siblings: [keepOn]),
        ),
        isNull,
      );
    });

    test('the same text reported twice (one view) is one text', () {
      expect(
        ownButton(
          const ShadeLook(
            anchors: [text, text],
            buttons: [turnOff, turnOff],
            siblings: [keepOn],
          ),
        ),
        turnOff,
      );
    });

    test('two different Turn offs on the row: none, it is not clear which', () {
      expect(
        ownButton(
          const ShadeLook(
            anchors: [text],
            buttons: [turnOff, Rect.fromLTWH(740, 990, 230, 130)],
            siblings: [keepOn],
          ),
        ),
        isNull,
      );
    });

    test('a Keep on that overlaps the Turn off is not a second button', () {
      expect(
        ownButton(
          const ShadeLook(
            anchors: [text],
            buttons: [turnOff],
            siblings: [Rect.fromLTWH(200, 990, 300, 130)],
          ),
        ),
        isNull,
      );
    });

    test('an empty (hidden) Turn off is never tapped', () {
      expect(
        ownButton(
          const ShadeLook(
            anchors: [text],
            buttons: [Rect.fromLTWH(96, 990, 0, 0)],
            siblings: [keepOn],
          ),
        ),
        isNull,
      );
    });
  });

  group('ownButtonTapPoint', () {
    const screen = Size(1080, 2340);
    const text = Rect.fromLTWH(96, 900, 880, 60);
    const turnOff = Rect.fromLTWH(96, 990, 300, 130);
    const keepOn = Rect.fromLTWH(420, 990, 300, 130);
    const look = ShadeLook(
      anchors: [text],
      buttons: [turnOff],
      siblings: [keepOn],
    );

    test('the centre of the checked button, as a fraction of the screen', () {
      final point = ownButtonTapPoint(
        first: look,
        second: look,
        screen: screen,
      );
      expect(point, isNotNull);
      expect(point!.dx, closeTo(246 / 1080, 1e-9));
      expect(point.dy, closeTo(1055 / 2340, 1e-9));
    });

    test('the button moved between the two looks (the shade was still '
        'moving): no tap', () {
      const moved = ShadeLook(
        anchors: [Rect.fromLTWH(96, 940, 880, 60)],
        buttons: [Rect.fromLTWH(96, 1030, 300, 130)],
        siblings: [Rect.fromLTWH(420, 1030, 300, 130)],
      );
      expect(
        ownButtonTapPoint(first: look, second: moved, screen: screen),
        isNull,
      );
    });

    test('the second look finds no own button: no tap', () {
      const collapsed = ShadeLook(anchors: [text], buttons: [], siblings: []);
      expect(
        ownButtonTapPoint(first: look, second: collapsed, screen: screen),
        isNull,
      );
      expect(
        ownButtonTapPoint(first: collapsed, second: look, screen: screen),
        isNull,
      );
    });

    test('no screen size: no tap', () {
      expect(
        ownButtonTapPoint(first: look, second: look, screen: Size.zero),
        isNull,
      );
    });

    test('a view outside the screen (the wrong pixel scale): no tap', () {
      // Logical pixels instead of the real display's: the views do not fit.
      expect(
        ownButtonTapPoint(
          first: look,
          second: look,
          screen: const Size(360, 780),
        ),
        isNull,
      );
    });
  });
}
