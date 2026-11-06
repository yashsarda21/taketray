import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/features/notifications/view_models/notification_access_controller.dart';
import 'package:taketray/features/settings/views/settings_screen.dart';
import 'package:taketray/platform/background_bridge.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../../../support/accessibility.dart';
import '../../../support/pump_screen.dart';
import '../../../support/view_model_fakes.dart';

const _allowed = NotificationAccess(granted: true, canAsk: false, sdkInt: 34);
const _askable = NotificationAccess(granted: false, canAsk: true, sdkInt: 34);
const _blocked = NotificationAccess(granted: false, canAsk: false, sdkInt: 34);

Future<FakeNotificationAccess> pump(
  WidgetTester tester,
  NotificationAccess? access, {
  bool allowResult = true,
  bool loading = false,
  Brightness brightness = Brightness.light,
  double textScale = 1,
}) async {
  final fake = FakeNotificationAccess(
    access,
    allowResult: allowResult,
    loading: loading,
  );
  await pumpScreen(
    tester,
    const SettingsScreen(),
    overrides: <Override>[
      notificationAccessControllerProvider.overrideWith(() => fake),
    ],
    brightness: brightness,
    textScale: textScale,
  );
  return fake;
}

Finder groupLabel(String text) => find.byWidgetPredicate(
  (w) => w is TtGroupLabel && w.text == text,
  description: 'a group label "$text"',
);

Finder rowTitled(String title) =>
    find.ancestor(of: find.text(title), matching: find.byType(TtListRow));

void main() {
  group('settings rows and their states', () {
    testWidgets('the large app bar, the Help group and its row', (
      tester,
    ) async {
      await pump(tester, _allowed);

      final bar = tester.widget<TtAppBar>(find.byType(TtAppBar));
      expect(bar.large, isTrue);
      expect(bar.title, 'Settings');
      expect(groupLabel('Help'), findsOneWidget);
      expect(find.text('Notifications not arriving?'), findsOneWidget);
      expect(
        find.text('Steps for Samsung, Xiaomi, Realme and more'),
        findsOneWidget,
      );
      final row = tester.widget<TtListRow>(
        rowTitled('Notifications not arriving?'),
      );
      expect(row.onTap, isNotNull);
      expect(find.byIcon(Symbols.chevron_right_rounded), findsOneWidget);
    });

    testWidgets('the help row opens the help screen', (tester) async {
      await pump(tester, _allowed);

      await tester.tap(find.text('Notifications not arriving?'));
      await tester.pumpAndSettle();

      expect(find.text(notificationsHelpRouteMarker), findsOneWidget);
    });

    testWidgets('allowed: a check and no button', (tester) async {
      await pump(tester, _allowed);

      expect(groupLabel('Permissions'), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Allowed'), findsOneWidget);
      expect(find.text('Not allowed'), findsNothing);
      expect(find.byIcon(Symbols.check_circle_rounded), findsOneWidget);
      expect(find.byType(TtButton), findsNothing);
    });

    testWidgets('not allowed: a tonal Allow button', (tester) async {
      await pump(tester, _askable);

      expect(find.text('Not allowed'), findsOneWidget);
      expect(find.text('Allowed'), findsNothing);
      expect(find.byIcon(Symbols.check_circle_rounded), findsNothing);
      final button = tester.widget<TtButton>(find.byType(TtButton));
      expect(button.label, 'Allow');
      expect(button.kind, TtButtonKind.tonal);
      expect(button.size, TtButtonSize.small);
    });

    testWidgets('Allow calls allow(), and nothing else shows', (tester) async {
      final fake = await pump(tester, _blocked);

      await tester.tap(find.widgetWithText(TtButton, 'Allow'));
      await tester.pumpAndSettle();

      expect(fake.allowed, 1);
      expect(find.byType(TtSnack), findsNothing);
    });

    testWidgets('settings that will not open show the snack', (tester) async {
      final fake = await pump(tester, _blocked, allowResult: false);

      await tester.tap(find.widgetWithText(TtButton, 'Allow'));
      await tester.pumpAndSettle();

      expect(fake.allowed, 1);
      expect(
        find.text("Couldn't open settings on this phone."),
        findsOneWidget,
      );
    });

    testWidgets('the row follows the state: it turns to a check', (
      tester,
    ) async {
      final fake = await pump(tester, _askable);
      expect(find.byType(TtButton), findsOneWidget);

      fake.show(_allowed);
      await tester.pump();

      expect(find.byType(TtButton), findsNothing);
      expect(find.text('Allowed'), findsOneWidget);
    });

    testWidgets('while the first read runs, no Permissions group', (
      tester,
    ) async {
      await pump(tester, null, loading: true);

      expect(groupLabel('Help'), findsOneWidget);
      expect(groupLabel('Permissions'), findsNothing);
      expect(find.text('Allowed'), findsNothing);
      expect(find.text('Not allowed'), findsNothing);
    });

    testWidgets('a first read that failed shows Not allowed with Allow, no '
        'error', (tester) async {
      await pump(tester, null);

      expect(groupLabel('Help'), findsOneWidget);
      expect(groupLabel('Permissions'), findsOneWidget);
      expect(find.text('Not allowed'), findsOneWidget);
      expect(find.text('Allowed'), findsNothing);
      expect(find.byIcon(Symbols.check_circle_rounded), findsNothing);
      final button = tester.widget<TtButton>(find.byType(TtButton));
      expect(button.label, 'Allow');
      expect(tester.takeException(), isNull);
    });

    testWidgets('Allow after a failed first read calls allow(), and a later '
        'good read replaces the row', (tester) async {
      final fake = await pump(tester, null);

      await tester.tap(find.widgetWithText(TtButton, 'Allow'));
      await tester.pumpAndSettle();
      expect(fake.allowed, 1);
      expect(find.byType(TtSnack), findsNothing);

      fake.show(_allowed);
      await tester.pump();
      expect(find.text('Allowed'), findsOneWidget);
      expect(find.byType(TtButton), findsNothing);
    });

    testWidgets('a failed first read with a settings page that will not open '
        'shows the snack', (tester) async {
      await pump(tester, null, allowResult: false);

      await tester.tap(find.widgetWithText(TtButton, 'Allow'));
      await tester.pumpAndSettle();

      expect(
        find.text("Couldn't open settings on this phone."),
        findsOneWidget,
      );
    });

    testWidgets('a screen reader hears the state, and which Allow it is', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pump(tester, _askable);

      expect(find.bySemanticsLabel('Allow notifications'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Notifications')), findsWidgets);
      handle.dispose();
    });
  });

  group('layout', () {
    for (final (scale, brightness, access) in [
      (1.0, Brightness.light, _allowed),
      (1.0, Brightness.light, _askable),
      (1.0, Brightness.dark, _askable),
      (2.0, Brightness.light, _askable),
      (2.0, Brightness.dark, _allowed),
    ]) {
      testWidgets('accessible at ${scale}x, ${brightness.name}, '
          '${access.granted ? 'allowed' : 'not allowed'}', (tester) async {
        await pump(tester, access, brightness: brightness, textScale: scale);

        await expectTtAccessible(tester);
        expect(tester.takeException(), isNull);
      });
    }

    for (final scale in [1.0, 2.0]) {
      testWidgets('accessible at ${scale}x after a failed first read', (
        tester,
      ) async {
        await pump(tester, null, textScale: scale);

        await expectTtAccessible(tester);
        expect(tester.takeException(), isNull);
        expect(find.text('Allow'), findsOneWidget);
      });
    }

    testWidgets('settings 2x no overflow: the Allow button stays whole', (
      tester,
    ) async {
      await pump(tester, _askable, textScale: 2);

      expect(tester.takeException(), isNull);
      expect(find.text('Allow'), findsOneWidget);
      final screen = tester.getRect(find.byType(SettingsScreen));
      expect(
        tester.getRect(find.byType(TtButton)).right,
        lessThanOrEqualTo(screen.right),
      );
    });
  });
}
