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
    // The S24 upright: the real display (the hook, `Display.getRealSize` and
    // its rotation, read at tap time) and Flutter's own display size.
    const upright = PhoneDisplay(width: 1080, height: 2340, rotation: 0);
    const flutter = Size(1080, 2340);
    const text = Rect.fromLTWH(96, 900, 880, 60);
    const turnOff = Rect.fromLTWH(96, 990, 300, 130);
    const keepOn = Rect.fromLTWH(420, 990, 300, 130);
    const look = ShadeLook(
      anchors: [text],
      buttons: [turnOff],
      siblings: [keepOn],
    );

    Offset? tap({
      ShadeLook first = look,
      ShadeLook second = look,
      PhoneDisplay? display = upright,
      Size flutterDisplay = flutter,
    }) => ownButtonTapPoint(
      first: first,
      second: second,
      display: display,
      flutterDisplay: flutterDisplay,
    );

    test('the centre of the checked button, as a fraction of the real '
        'display', () {
      final point = tap();
      expect(point, isNotNull);
      expect(point!.dx, closeTo(246 / 1080, 1e-9));
      expect(point.dy, closeTo(1055 / 2340, 1e-9));
    });

    test("Flutter's size still landscape from before Home (stale): the real "
        'display is used', () {
      final point = tap(flutterDisplay: const Size(2340, 1080));
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
      expect(tap(second: moved), isNull);
    });

    test('the second look finds no own button: no tap', () {
      const collapsed = ShadeLook(anchors: [text], buttons: [], siblings: []);
      expect(tap(second: collapsed), isNull);
      expect(tap(first: collapsed), isNull);
    });

    test('the phone on its side (landscape size, rotation 1 or 3): no tap', () {
      expect(
        tap(
          display: const PhoneDisplay(width: 2340, height: 1080, rotation: 1),
        ),
        isNull,
      );
      expect(
        tap(
          display: const PhoneDisplay(width: 2340, height: 1080, rotation: 3),
        ),
        isNull,
      );
    });

    test('a landscape size even at rotation 0: no tap', () {
      // A notification high in the shade fits inside a landscape box too, and
      // Flutter (stale) reports the same two numbers: only "upright" refuses.
      const high = ShadeLook(
        anchors: [Rect.fromLTWH(96, 300, 880, 60)],
        buttons: [Rect.fromLTWH(96, 390, 300, 130)],
        siblings: [Rect.fromLTWH(420, 390, 300, 130)],
      );
      expect(
        tap(first: high, second: high),
        isNotNull,
        reason: 'upright',
      );
      expect(
        tap(
          first: high,
          second: high,
          display: const PhoneDisplay(width: 2340, height: 1080, rotation: 0),
        ),
        isNull,
      );
      expect(
        tap(
          first: high,
          second: high,
          display: const PhoneDisplay(width: 2340, height: 1080, rotation: 0),
          flutterDisplay: const Size(2340, 1080),
        ),
        isNull,
      );
    });

    test('rotated with a portrait size (upside down, or any rotation but '
        '0): no tap', () {
      for (final rotation in [1, 2, 3, -1, 4]) {
        expect(
          tap(
            display: PhoneDisplay(
              width: 1080,
              height: 2340,
              rotation: rotation,
            ),
          ),
          isNull,
          reason: 'rotation $rotation',
        );
      }
    });

    test('a square size is not upright: no tap', () {
      expect(
        tap(
          display: const PhoneDisplay(width: 1800, height: 1800, rotation: 0),
          flutterDisplay: const Size(1800, 1800),
        ),
        isNull,
      );
    });

    test("the real size does not match Flutter's display (another display or "
        'another scale): no tap', () {
      expect(tap(flutterDisplay: const Size(1440, 3120)), isNull);
      expect(tap(flutterDisplay: const Size(360, 780)), isNull);
      expect(tap(flutterDisplay: Size.zero), isNull);
    });

    test('a difference under one pixel still matches', () {
      expect(tap(flutterDisplay: const Size(1080.4, 2339.6)), isNotNull);
    });

    test('the size could not be read (unknown, failed): no tap', () {
      expect(tap(display: null), isNull);
    });

    test('no size: no tap', () {
      expect(
        tap(display: const PhoneDisplay(width: 0, height: 0, rotation: 0)),
        isNull,
      );
      expect(
        tap(
          display: const PhoneDisplay(width: 0, height: 0, rotation: 0),
          flutterDisplay: Size.zero,
        ),
        isNull,
      );
    });

    test('a view outside the real display: no tap', () {
      const below = ShadeLook(
        anchors: [text],
        buttons: [turnOff],
        siblings: [keepOn, Rect.fromLTWH(420, 2300, 300, 130)],
      );
      expect(tap(first: below, second: below), isNull);
      const left = ShadeLook(
        anchors: [Rect.fromLTWH(-4, 900, 880, 60)],
        buttons: [turnOff],
        siblings: [keepOn],
      );
      expect(tap(first: left, second: left), isNull);
    });
  });

  group('PhoneDisplay.fromReply', () {
    test('reads the three numbers the hook sends', () {
      expect(
        PhoneDisplay.fromReply(const {
          'width': 1080,
          'height': 2340,
          'rotation': 0,
        }),
        const PhoneDisplay(width: 1080, height: 2340, rotation: 0),
      );
    });

    test('anything else is unknown (null)', () {
      expect(PhoneDisplay.fromReply(null), isNull);
      expect(PhoneDisplay.fromReply('1080x2340'), isNull);
      expect(PhoneDisplay.fromReply(const {'width': 1080}), isNull);
      expect(
        PhoneDisplay.fromReply(const {
          'width': 1080,
          'height': '2340',
          'rotation': 0,
        }),
        isNull,
      );
      expect(
        PhoneDisplay.fromReply(const {
          'width': 1080,
          'height': 2340,
          'rotation': null,
        }),
        isNull,
      );
    });
  });

  group('ShadeLook.numbers', () {
    test('is rects in pixels only, the gap and the row, never a text', () {
      const look = ShadeLook(
        anchors: [Rect.fromLTRB(96, 1200, 996, 1260)],
        buttons: [Rect.fromLTRB(96, 1330, 396, 1400)],
        siblings: [Rect.fromLTRB(420, 1332, 720, 1398)],
      );

      final text = look.numbers;

      expect(text, contains('text [96,1200,996,1260]'));
      expect(text, contains('buttons [96,1330,396,1400]'));
      expect(text, contains('siblings [420,1332,720,1398]'));
      expect(text, contains('gap below the text 70'));
      expect(text, contains('row offset 0'));
      expect(text, isNot(contains(RegExp('[A-Za-z]{12,}'))));
    });

    test('an empty look says none and has no gap', () {
      const look = ShadeLook(anchors: [], buttons: [], siblings: []);

      expect(look.numbers, contains('text []'));
      expect(look.numbers, contains('gap below the text none'));
      expect(look.numbers, contains('row offset none'));
    });

    test('several buttons give a gap and a row for each', () {
      const look = ShadeLook(
        anchors: [Rect.fromLTRB(96, 1200, 996, 1260)],
        buttons: [
          Rect.fromLTRB(96, 1330, 396, 1400),
          Rect.fromLTRB(96, 1900, 396, 1970),
        ],
        siblings: [Rect.fromLTRB(420, 1330, 720, 1400)],
      );

      expect(look.numbers, contains('gap below the text 70 640'));
      expect(look.numbers, contains('row offset 0 570'));
    });
  });
}
