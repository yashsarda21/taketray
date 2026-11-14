import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/data/repositories/edit_sessions_repository.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/edit_copy.dart';
import 'package:taketray/domain/models/editor_app.dart';
import 'package:taketray/features/editors/view_models/copies_storage_controller.dart';
import 'package:taketray/features/notifications/view_models/notification_access_controller.dart';
import 'package:taketray/features/settings/views/settings_screen.dart';
import 'package:taketray/platform/background_bridge.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../../../support/accessibility.dart';
import '../../../support/pump_screen.dart';
import '../../../support/reel_videos.dart';
import '../../../support/test_app.dart';
import '../../../support/view_model_fakes.dart';
import '../../../support/vm_harness.dart';
import '../../reels/edit_session_support.dart' hide settleApp;

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
  CopiesSummary? copies = const CopiesSummary(bytes: 0, reels: 0),
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
      // Not read yet when null.
      copiesSummaryProvider.overrideWith(
        (ref) => copies == null
            ? const Stream<CopiesSummary>.empty()
            : Stream.value(copies),
      ),
    ],
    brightness: brightness,
    textScale: textScale,
  );
  return fake;
}

/// Lets the database answer a few times, then redraws.
Future<void> settleApp(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(settle);
    await tester.pump();
  }
  await tester.pumpAndSettle();
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
      expect(
        find.descendant(
          of: rowTitled('Notifications not arriving?'),
          matching: find.byIcon(Symbols.chevron_right_rounded),
        ),
        findsOneWidget,
      );
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

  group('the VN copies row (Phase 8, D-130)', () {
    testWidgets('an interim Clips group above Help holds one row with a '
        'chevron', (tester) async {
      await pump(tester, _allowed);

      expect(groupLabel('Clips'), findsOneWidget);
      expect(find.text('Storage used by VN copies'), findsOneWidget);
      final row = tester.widget<TtListRow>(
        rowTitled('Storage used by VN copies'),
      );
      expect(row.onTap, isNotNull);
      expect(
        find.descendant(
          of: rowTitled('Storage used by VN copies'),
          matching: find.byIcon(Symbols.chevron_right_rounded),
        ),
        findsOneWidget,
      );
      expect(
        tester.getTopLeft(groupLabel('Clips')).dy,
        lessThan(tester.getTopLeft(groupLabel('Help')).dy),
      );
      expect(
        tester.getTopLeft(groupLabel('Help')).dy,
        lessThan(tester.getTopLeft(groupLabel('Permissions')).dy),
      );
    });

    for (final (summary, text) in [
      (const CopiesSummary(bytes: 0, reels: 0), 'None'),
      (
        const CopiesSummary(bytes: 900 * 1000 * 1000, reels: 1),
        '900 MB in 1 reel',
      ),
      (
        const CopiesSummary(bytes: 1800 * 1000 * 1000, reels: 3),
        '1.8 GB in 3 reels',
      ),
    ]) {
      testWidgets('the summary is "$text"', (tester) async {
        await pump(tester, _allowed, copies: summary);

        expect(
          tester
              .widget<TtListRow>(rowTitled('Storage used by VN copies'))
              .subtitle
              ?.replaceAll('\u00a0', ' '),
          text,
        );
      });
    }

    testWidgets('before the first read the row has no summary yet', (
      tester,
    ) async {
      await pump(tester, _allowed, copies: null);

      expect(
        tester
            .widget<TtListRow>(rowTitled('Storage used by VN copies'))
            .subtitle,
        isNull,
      );
    });

    testWidgets('the row opens the VN copies screen', (tester) async {
      await pump(tester, _allowed);

      await tester.tap(find.text('Storage used by VN copies'));
      await tester.pumpAndSettle();

      expect(find.text(copiesStorageRouteMarker), findsOneWidget);
    });

    testApp('with the real database the summary counts the reels that hold '
        'copies, and follows changes', (tester) async {
      final h = reelHarness();
      final goa = await real(
        tester,
        () => h.container.read(reelsRepositoryProvider).create('Goa'),
      );
      final ids = await real(
        tester,
        () => putInReel(h, goa.id, [reelVideo(1), reelVideo(2)]),
      );
      // A session that only sent originals holds nothing.
      final other = await real(
        tester,
        () => h.container.read(reelsRepositoryProvider).create('Cut'),
      );
      await real(
        tester,
        () => h.container
            .read(editSessionsRepositoryProvider)
            .startSession(other.id, EditorApp.capcut, 'Cut'),
      );
      await pumpScreen(
        tester,
        const SettingsScreen(),
        overrides: [
          ...h.appOverrides,
          notificationAccessControllerProvider.overrideWith(
            () => FakeNotificationAccess(_allowed),
          ),
        ],
        settle: false,
      );
      await settleApp(tester);
      expect(
        tester
            .widget<TtListRow>(rowTitled('Storage used by VN copies'))
            .subtitle,
        'None',
      );

      // Two writes, the screen reading in between: a write that starts
      // while its read runs waits for the test's pump (the database answers
      // the fake clock's zone only then).
      final sessions = h.container.read(editSessionsRepositoryProvider);
      final started = await real(
        tester,
        () => sessions.startSession(goa.id, EditorApp.vn, 'Goa'),
      );
      await settleApp(tester);
      await real(
        tester,
        () => sessions.recordCopies([
          for (final (i, id) in ids.indexed)
            EditCopy(
              reelId: goa.id,
              clipId: id,
              copyMediaStoreId: 500 + i,
              fileName: 'copy_$i.mp4',
              sizeBytes: 300 * 1000 * 1000,
              copiedAt: started.createdAt,
            ),
        ]),
      );
      await settleApp(tester);

      expect(
        tester
            .widget<TtListRow>(rowTitled('Storage used by VN copies'))
            .subtitle
            ?.replaceAll('\u00a0', ' '),
        '600 MB in 1 reel',
      );
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
