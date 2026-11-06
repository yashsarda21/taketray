import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/features/notifications/views/notifications_help_screen.dart';
import 'package:taketray/platform/background_bridge.dart';
import 'package:taketray/platform/media_bridge.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../../../support/accessibility.dart';
import '../../../support/fake_background_bridge.dart';
import '../../../support/fake_media_bridge.dart';
import '../../../support/pump_screen.dart';
import '../../../support/vm_harness.dart';

const _snack = "Couldn't open settings on this phone.";

/// Each card: the brand's maker, its title, its steps and its button.
const _cards = <(String, String, List<String>, String)>[
  (
    'samsung',
    'Samsung',
    [
      'Open Settings › Battery › Background usage limits.',
      'Tap Never sleeping apps and add TakeTray.',
      'If TakeTray is under Sleeping apps, remove it.',
    ],
    'Open battery settings',
  ),
  (
    'xiaomi',
    'Xiaomi, Redmi, POCO',
    [
      'Long-press the TakeTray icon › App info.',
      'Turn on Autostart.',
      'Tap Battery saver › No restrictions.',
    ],
    'Open app info',
  ),
  (
    'realme',
    'Oppo, Realme',
    [
      'Long-press the TakeTray icon › App info › Battery usage.',
      'Turn on Allow background activity.',
      'Turn on Allow auto launch.',
    ],
    'Open app info',
  ),
  (
    'iqoo',
    'Vivo, iQOO',
    [
      'Open Settings › Battery › Background power consumption management.',
      'Find TakeTray and choose Allow.',
    ],
    'Open battery settings',
  ),
  (
    'oneplus',
    'OnePlus',
    [
      'Long-press the TakeTray icon › App info › Battery.',
      'Choose Unrestricted.',
    ],
    'Open app info',
  ),
];

late FakeBackgroundBridge background;
late FakeMediaBridge media;

Future<void> pump(
  WidgetTester tester, {
  String maker = 'samsung',
  Brightness brightness = Brightness.light,
  double textScale = 1,
  bool settle = true,
}) async {
  background.maker = maker;
  await pumpScreen(
    tester,
    const NotificationsHelpScreen(),
    overrides: <Override>[
      backgroundBridgeProvider.overrideWithValue(background),
      mediaBridgeProvider.overrideWithValue(media),
    ],
    brightness: brightness,
    textScale: textScale,
    settle: settle,
  );
}

Finder card(String title) => find.byWidgetPredicate(
  (w) => w is TtExpandCard && w.title == title,
  description: 'the card "$title"',
);

bool isOpen(WidgetTester tester, String title) =>
    tester.widget<TtExpandCard>(card(title)).expanded;

List<String> openTitles(WidgetTester tester) => [
  for (final w in tester.widgetList<TtExpandCard>(find.byType(TtExpandCard)))
    if (w.expanded) w.title,
];

void main() {
  setUp(() {
    background = FakeBackgroundBridge();
    media = FakeMediaBridge();
  });

  group('the page', () {
    testWidgets('app bar, intro, success callout and footer, verbatim', (
      tester,
    ) async {
      await pump(tester);

      expect(
        tester.widget<TtAppBar>(find.byType(TtAppBar)).title,
        'Notifications not arriving?',
      );
      expect(
        find.text(
          'Some phones stop apps in the background to save battery. Then the '
          '"new clips" notification can be late or missing.',
        ),
        findsOneWidget,
      );
      final callout = tester.widget<TtCallout>(find.byType(TtCallout));
      expect(callout.success, isTrue);
      expect(callout.title, 'Your clips are never lost');
      expect(callout.body, 'They show up in To tag when you open the app.');
      expect(callout.icon, Symbols.verified_rounded);
      expect(
        find.text('Menu names can be a little different on your phone.'),
        findsOneWidget,
      );
    });

    testWidgets('the title wraps at large text instead of ending in dots', (
      tester,
    ) async {
      await pump(tester, textScale: 2);

      expect(tester.widget<TtAppBar>(find.byType(TtAppBar)).wrapTitle, isTrue);
      final title = find.text('Notifications not arriving?');
      expect(title, findsOneWidget);
      // Read in full: it needs more than one line at 2x, and none is cut.
      expect(tester.getSize(title).height, greaterThan(40));
    });

    testWidgets('one card per brand, in the prototype order', (tester) async {
      await pump(tester, maker: 'google');

      expect(
        [
          for (final w in tester.widgetList<TtExpandCard>(
            find.byType(TtExpandCard),
          ))
            w.title,
        ],
        [for (final c in _cards) c.$2],
      );
    });

    testWidgets('back returns to where the screen was opened', (tester) async {
      await pump(tester);

      expect(find.byType(TtIconButton), findsOneWidget);
      expect(
        tester.widget<TtIconButton>(find.byType(TtIconButton)).semanticLabel,
        'Back',
      );
    });
  });

  group('your phone', () {
    for (final (maker, title, steps, _) in _cards) {
      testWidgets('your phone card is open and badged ($maker)', (
        tester,
      ) async {
        await pump(tester, maker: maker);

        expect(openTitles(tester), [title]);
        expect(tester.widget<TtExpandCard>(card(title)).badge, 'Your phone');
        expect(find.text('Your phone'), findsOneWidget);
        expect(tester.widget<TtStepList>(find.byType(TtStepList)).steps, steps);
      });
    }

    testWidgets('unknown brand opens none', (tester) async {
      await pump(tester, maker: 'google');

      expect(openTitles(tester), isEmpty);
      expect(find.byType(TtStepList), findsNothing);
      expect(find.text('Your phone'), findsNothing);
    });

    testWidgets('a maker that cannot be read opens none, without a word', (
      tester,
    ) async {
      final records = captureLogs();
      background.failNext('phoneMaker');
      await pump(tester, maker: 'secretmaker');

      expect(openTitles(tester), isEmpty);
      expect(find.text('Your phone'), findsNothing);
      expect(tester.takeException(), isNull);
      expect(logText(records), contains('PlatformException'));
      expect(logText(records), isNot(contains('secretmaker')));
    });

    testWidgets('the maker is never logged', (tester) async {
      final records = captureLogs();
      await pump(tester, maker: 'secretmaker');
      background.maker = 'samsung';

      expect(logText(records), isNot(contains('secretmaker')));
    });

    testWidgets('the card opens when the maker arrives', (tester) async {
      final gate = background.gate('phoneMaker');
      await pump(tester, settle: false);
      await tester.pump();
      expect(openTitles(tester), isEmpty);

      gate.complete();
      await tester.pumpAndSettle();

      expect(openTitles(tester), ['Samsung']);
    });

    testWidgets(
      "a card the user opened first is not closed by the maker's arrival",
      (tester) async {
        final gate = background.gate('phoneMaker');
        await pump(tester, settle: false);
        await tester.pump();

        await tester.tap(find.text('OnePlus'));
        await tester.pump();
        gate.complete();
        await tester.pumpAndSettle();

        expect(openTitles(tester), ['OnePlus']);
        expect(
          tester.widget<TtExpandCard>(card('Samsung')).badge,
          'Your phone',
        );
      },
    );
  });

  group('the cards', () {
    testWidgets('one card open at a time', (tester) async {
      await pump(tester);
      expect(openTitles(tester), ['Samsung']);

      await tester.tap(find.text('Xiaomi, Redmi, POCO'));
      await tester.pumpAndSettle();
      expect(openTitles(tester), ['Xiaomi, Redmi, POCO']);

      await tester.tap(find.text('Vivo, iQOO'));
      await tester.pumpAndSettle();
      expect(openTitles(tester), ['Vivo, iQOO']);
    });

    testWidgets('a tap on the open card closes it', (tester) async {
      await pump(tester);

      await tester.tap(find.text('Samsung'));
      await tester.pumpAndSettle();

      expect(openTitles(tester), isEmpty);
      expect(tester.widget<TtExpandCard>(card('Samsung')).badge, 'Your phone');
    });

    testWidgets('every card has its steps and its button, verbatim', (
      tester,
    ) async {
      await pump(tester, maker: 'google');

      for (final (_, title, steps, button) in _cards) {
        await tester.tap(find.text(title));
        await tester.pumpAndSettle();
        expect(
          tester.widget<TtStepList>(find.byType(TtStepList)).steps,
          steps,
          reason: title,
        );
        final b = tester.widget<TtButton>(find.byType(TtButton));
        expect(b.label, button, reason: title);
        expect(b.kind, TtButtonKind.tonal, reason: title);
        expect(b.icon, Symbols.open_in_new_rounded, reason: title);
      }
    });

    testWidgets('a screen reader hears the card and whether it is open', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pump(tester);

      final data = tester
          .getSemantics(find.bySemanticsLabel('Samsung, Your phone'))
          .getSemanticsData();
      expect(data.flagsCollection.isExpanded, ui.Tristate.isTrue);
      final other = tester
          .getSemantics(find.bySemanticsLabel('OnePlus'))
          .getSemanticsData();
      expect(other.flagsCollection.isExpanded, ui.Tristate.isFalse);
      expect(
        find.bySemanticsLabel(
          '1. Open Settings › Battery › Background usage limits.',
        ),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('the buttons', () {
    int battery() =>
        background.calls.where((c) => c == 'openBatterySettings').length;
    int appInfo() => media.calls.where((c) => c == 'openAppSettings').length;

    testWidgets('samsung button opens battery settings', (tester) async {
      await pump(tester);

      await tester.tap(find.text('Open battery settings'));
      await tester.pumpAndSettle();

      expect(battery(), 1);
      expect(appInfo(), 0);
      expect(find.byType(TtSnack), findsNothing);
    });

    testWidgets('vivo button opens battery settings too', (tester) async {
      await pump(tester, maker: 'vivo');

      await tester.tap(find.text('Open battery settings'));
      await tester.pumpAndSettle();

      expect(battery(), 1);
      expect(appInfo(), 0);
    });

    for (final maker in ['xiaomi', 'oppo', 'oneplus']) {
      testWidgets('$maker button opens the app info', (tester) async {
        await pump(tester, maker: maker);

        await tester.tap(find.text('Open app info'));
        await tester.pumpAndSettle();

        expect(appInfo(), 1);
        expect(battery(), 0);
        expect(find.byType(TtSnack), findsNothing);
      });
    }

    testWidgets('failure shows the snack: battery settings that do not open', (
      tester,
    ) async {
      background.batteryOpens = false;
      await pump(tester);

      await tester.tap(find.text('Open battery settings'));
      await tester.pumpAndSettle();

      expect(find.text(_snack), findsOneWidget);
    });

    testWidgets('failure shows the snack: battery settings that throw', (
      tester,
    ) async {
      final records = captureLogs();
      await pump(tester);
      background.failNext('openBatterySettings');

      await tester.tap(find.text('Open battery settings'));
      await tester.pumpAndSettle();

      expect(find.text(_snack), findsOneWidget);
      expect(logText(records), isNot(contains('failed on purpose')));
      expect(logText(records), isNot(contains('samsung')));
    });

    testWidgets('failure shows the snack: app info that throws', (
      tester,
    ) async {
      await pump(tester, maker: 'xiaomi');
      media.failNext('openAppSettings');

      await tester.tap(find.text('Open app info'));
      await tester.pumpAndSettle();

      expect(find.text(_snack), findsOneWidget);
    });

    testWidgets('a second try after a failure works', (tester) async {
      await pump(tester, maker: 'xiaomi');
      media.failNext('openAppSettings');
      await tester.tap(find.text('Open app info'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open app info'));
      await tester.pumpAndSettle();

      expect(appInfo(), 2);
    });
  });

  group('layout', () {
    for (final (scale, brightness, maker) in [
      (1.0, Brightness.light, 'samsung'),
      (1.0, Brightness.dark, 'samsung'),
      (2.0, Brightness.light, 'samsung'),
      (2.0, Brightness.dark, 'google'),
    ]) {
      testWidgets('accessible at ${scale}x, ${brightness.name}, $maker', (
        tester,
      ) async {
        await pump(
          tester,
          maker: maker,
          brightness: brightness,
          textScale: scale,
        );

        await expectTtAccessible(tester);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('help screen 2x no overflow, every card in turn', (
      tester,
    ) async {
      await pump(tester, maker: 'google', textScale: 2);

      for (final (_, title, _, _) in _cards) {
        await tester.scrollUntilVisible(
          find.text(title),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text(title));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: title);
      }
      await tester.scrollUntilVisible(
        find.text('Menu names can be a little different on your phone.'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
