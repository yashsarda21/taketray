import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/data/repositories/edit_sessions_repository.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/data/repositories/settings_repository.dart';
import 'package:taketray/domain/models/app_settings.dart';
import 'package:taketray/domain/models/edit_copy.dart';
import 'package:taketray/domain/models/editor_app.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/features/editors/view_models/copies_storage_controller.dart';
import 'package:taketray/features/media_access/view_models/media_access_controller.dart';
import 'package:taketray/features/notifications/view_models/notification_access_controller.dart';
import 'package:taketray/features/settings/view_models/settings_controller.dart';
import 'package:taketray/features/settings/views/settings_screen.dart';
import 'package:taketray/platform/background_bridge.dart';
import 'package:taketray/platform/files_bridge.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../../../support/accessibility.dart';
import '../../../support/fake_files_bridge.dart';
import '../../../support/fake_settings.dart';
import '../../../support/fixed_clock.dart';
import '../../../support/pump_screen.dart';
import '../../../support/reel_videos.dart';
import '../../../support/test_app.dart';
import '../../../support/view_model_fakes.dart';
import '../../../support/vm_harness.dart';
import '../../reels/edit_session_support.dart' hide settleApp;

const _allowed = NotificationAccess(granted: true, canAsk: false, sdkInt: 34);
const _askable = NotificationAccess(granted: false, canAsk: true, sdkInt: 34);
const _blocked = NotificationAccess(granted: false, canAsk: false, sdkInt: 34);

/// The day the tests are on: the backup date's year is left out in it.
final DateTime _today = DateTime.utc(2026, 11, 17, 12);

/// Pumps the Settings screen. The settings, the video access and the version
/// are what a test gives; the defaults are the ones that leave the rows of
/// the earlier phases alone: video access is still being read (no Video
/// access row), the settings are the defaults, the version is 1.0.0.
Future<FakeNotificationAccess> pump(
  WidgetTester tester,
  NotificationAccess? access, {
  bool allowResult = true,
  bool loading = false,
  Brightness brightness = Brightness.light,
  double textScale = 1,
  CopiesSummary? copies = const CopiesSummary(bytes: 0, reels: 0),
  FakeSettings? settings,
  FakeAccess? media,
  FakeFilesBridge? files,
  Future<DateTime?> Function()? lastExport,
  bool use24Hour = false,
  Size size = const Size(360, 1700),
}) async {
  final fake = FakeNotificationAccess(
    access,
    allowResult: allowResult,
    loading: loading,
  );
  await pumpScreen(
    tester,
    const SettingsScreen(),
    use24Hour: use24Hour,
    size: size,
    overrides: <Override>[
      notificationAccessControllerProvider.overrideWith(() => fake),
      settingsControllerProvider.overrideWith(
        () => settings ?? FakeSettings(const AppSettings()),
      ),
      mediaAccessControllerProvider.overrideWith(
        () => media ?? FakeAccess(null, loading: true),
      ),
      filesBridgeProvider.overrideWithValue(files ?? FakeFilesBridge()),
      lastExportProvider.overrideWith(
        (ref) => (lastExport ?? () async => null)(),
      ),
      clockProvider.overrideWithValue(FixedClock(_today)),
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

  group('the full Settings screen (Phase 10B, D-148)', () {
    Future<({FakeSettings settings, FakeAccess media, FakeFilesBridge files})>
    pumpFull(
      WidgetTester tester, {
      AppSettings initial = const AppSettings(),
      MediaAccessLevel? level = MediaAccessLevel.full,
      FakeFilesBridge? files,
      Future<DateTime?> Function()? lastExport,
      bool use24Hour = true,
      NotificationAccess notifications = _allowed,
    }) async {
      final settings = FakeSettings(initial);
      final media = FakeAccess(level);
      final bridge = files ?? FakeFilesBridge();
      await pump(
        tester,
        notifications,
        settings: settings,
        media: media,
        files: bridge,
        lastExport: lastExport,
        use24Hour: use24Hour,
      );
      return (settings: settings, media: media, files: bridge);
    }

    String plain(String? text) => (text ?? '').replaceAll(RegExp('[  ]'), ' ');

    Finder switchIn(String title) =>
        find.descendant(of: rowTitled(title), matching: find.byType(TtSwitch));

    String? subtitleOf(WidgetTester tester, String title) =>
        plain(tester.widget<TtListRow>(rowTitled(title)).subtitle);

    double top(WidgetTester tester, Finder finder) =>
        tester.getTopLeft(finder).dy;

    testWidgets('the groups and rows are in the prototype order', (
      tester,
    ) async {
      await pumpFull(tester);

      final groups = [
        'Shooting mode',
        'Reminders',
        'Clips',
        'Help',
        'Your data',
        'Permissions',
        'About',
      ];
      final rows = [
        'Remind me to turn it off',
        'Evening reminder',
        'Reminder time',
        'VN copies reminder',
        'Watched folders',
        'Storage used by VN copies',
        'Notifications not arriving?',
        'Send error log',
        'Export and import',
        'Video access',
        'Notifications',
        'Your videos never leave your phone',
        'TakeTray',
      ];
      // Every label and row one under the other, in one list.
      final tops = [
        top(tester, groupLabel('Shooting mode')),
        top(tester, rowTitled('Remind me to turn it off')),
        top(tester, groupLabel('Reminders')),
        top(tester, rowTitled('Evening reminder')),
        top(tester, rowTitled('Reminder time')),
        top(tester, rowTitled('VN copies reminder')),
        top(tester, groupLabel('Clips')),
        top(tester, rowTitled('Watched folders')),
        top(tester, rowTitled('Storage used by VN copies')),
        top(tester, groupLabel('Help')),
        top(tester, rowTitled('Notifications not arriving?')),
        top(tester, rowTitled('Send error log')),
        top(tester, groupLabel('Your data')),
        top(tester, rowTitled('Export and import')),
        top(tester, groupLabel('Permissions')),
        top(tester, rowTitled('Video access')),
        top(tester, rowTitled('Notifications')),
        top(tester, groupLabel('About')),
        top(tester, rowTitled('Your videos never leave your phone')),
        top(tester, rowTitled('TakeTray')),
      ];
      for (var i = 1; i < tops.length; i++) {
        expect(tops[i], greaterThan(tops[i - 1]), reason: 'item $i is lower');
      }
      for (final g in groups) {
        expect(groupLabel(g), findsOneWidget);
      }
      for (final r in rows) {
        expect(rowTitled(r), findsOneWidget);
      }
    });

    group('Remind me to turn it off', () {
      testWidgets('shows its copy and follows the setting', (tester) async {
        await pumpFull(
          tester,
          initial: const AppSettings(stillReminderEnabled: false),
        );

        expect(
          subtitleOf(tester, 'Remind me to turn it off'),
          'If Shooting mode stays on for 14 days',
        );
        expect(
          tester.widget<TtSwitch>(switchIn('Remind me to turn it off')).value,
          isFalse,
        );
      });

      testWidgets('a tap on the switch turns it off, then on', (tester) async {
        final h = await pumpFull(tester);
        expect(
          tester.widget<TtSwitch>(switchIn('Remind me to turn it off')).value,
          isTrue,
        );

        await tester.tap(switchIn('Remind me to turn it off'));
        await tester.pumpAndSettle();
        expect(h.settings.calls, ['setStillReminder(false)']);
        expect(
          tester.widget<TtSwitch>(switchIn('Remind me to turn it off')).value,
          isFalse,
        );

        await tester.tap(switchIn('Remind me to turn it off'));
        await tester.pumpAndSettle();
        expect(h.settings.calls.last, 'setStillReminder(true)');
      });

      testWidgets('a screen reader hears the switch by its own name', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await pumpFull(tester);

        expect(
          find.bySemanticsLabel('Remind me to turn off Shooting mode'),
          findsOneWidget,
        );
        handle.dispose();
      });
    });

    group('Evening reminder and Reminder time', () {
      testWidgets('the time row is only there while the reminder is on', (
        tester,
      ) async {
        final h = await pumpFull(tester);
        expect(rowTitled('Reminder time'), findsOneWidget);

        await tester.tap(switchIn('Evening reminder'));
        await tester.pumpAndSettle();

        expect(h.settings.calls, ['setEvening(false)']);
        expect(rowTitled('Reminder time'), findsNothing);
        expect(rowTitled('Evening reminder'), findsOneWidget);
        expect(rowTitled('VN copies reminder'), findsOneWidget);

        await tester.tap(switchIn('Evening reminder'));
        await tester.pumpAndSettle();
        expect(h.settings.calls.last, 'setEvening(true)');
        expect(rowTitled('Reminder time'), findsOneWidget);
      });

      testWidgets('the reminder starts off: no time row', (tester) async {
        await pumpFull(
          tester,
          initial: const AppSettings(eveningReminderEnabled: false),
        );

        expect(rowTitled('Reminder time'), findsNothing);
        expect(
          tester.widget<TtSwitch>(switchIn('Evening reminder')).value,
          isFalse,
        );
        // The line under the title still says when it would come.
        expect(
          subtitleOf(tester, 'Evening reminder'),
          '21:00, only if clips are waiting',
        );
      });

      for (final (minutes, h24, h12) in [
        (1260, '21:00', '9:00 PM'),
        (0, '00:00', '12:00 AM'),
        (1439, '23:59', '11:59 PM'),
        (725, '12:05', '12:05 PM'),
        (65, '01:05', '1:05 AM'),
      ]) {
        testWidgets('$minutes minutes read "$h24" on a 24-hour phone', (
          tester,
        ) async {
          await pumpFull(
            tester,
            initial: AppSettings(eveningReminderMinutes: minutes),
          );

          expect(
            subtitleOf(tester, 'Evening reminder'),
            '$h24, only if clips are waiting',
          );
          expect(subtitleOf(tester, 'Reminder time'), h24);
        });

        testWidgets('$minutes minutes read "$h12" on a 12-hour phone', (
          tester,
        ) async {
          await pumpFull(
            tester,
            initial: AppSettings(eveningReminderMinutes: minutes),
            use24Hour: false,
          );

          expect(
            subtitleOf(tester, 'Evening reminder'),
            '$h12, only if clips are waiting',
          );
          expect(subtitleOf(tester, 'Reminder time'), h12);
        });
      }

      testWidgets('the time row has a chevron and opens the time picker at '
          'the time now', (tester) async {
        await pumpFull(
          tester,
          initial: const AppSettings(eveningReminderMinutes: 450),
        );
        expect(
          find.descendant(
            of: rowTitled('Reminder time'),
            matching: find.byIcon(Symbols.chevron_right_rounded),
          ),
          findsOneWidget,
        );

        await tester.tap(find.text('Reminder time'));
        await tester.pumpAndSettle();

        expect(find.byType(Dialog), findsOneWidget);
        final dialog = tester.widget<TimePickerDialog>(
          find.byType(TimePickerDialog),
        );
        expect(dialog.initialTime, const TimeOfDay(hour: 7, minute: 30));
      });

      /// Types the time into the picker's text fields and presses OK.
      Future<void> pickTime(
        WidgetTester tester,
        String hour,
        String minute, {
        String? period,
      }) async {
        await tester.tap(find.byTooltip('Switch to text input mode'));
        await tester.pumpAndSettle();
        final fields = find.byType(TextField);
        await tester.enterText(fields.at(0), hour);
        await tester.enterText(fields.at(1), minute);
        if (period != null) {
          await tester.tap(find.text(period));
          await tester.pumpAndSettle();
        }
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
      }

      testWidgets('a picked time is saved as minutes after midnight', (
        tester,
      ) async {
        final h = await pumpFull(tester);

        await tester.tap(find.text('Reminder time'));
        await tester.pumpAndSettle();
        await pickTime(tester, '07', '05');

        expect(h.settings.calls, ['setEveningMinutes(425)']);
        expect(find.byType(Dialog), findsNothing);
        expect(subtitleOf(tester, 'Reminder time'), '07:05');
        expect(
          subtitleOf(tester, 'Evening reminder'),
          '07:05, only if clips are waiting',
        );
      });

      for (final (hour, minute, minutes) in [
        ('00', '00', 0),
        ('23', '59', 1439),
      ]) {
        testWidgets('$hour:$minute is saved as $minutes, exactly', (
          tester,
        ) async {
          final h = await pumpFull(tester);

          await tester.tap(find.text('Reminder time'));
          await tester.pumpAndSettle();
          await pickTime(tester, hour, minute);

          expect(h.settings.calls, ['setEveningMinutes($minutes)']);
        });
      }

      testWidgets('on a 12-hour phone 11:59 PM is saved as 1439', (
        tester,
      ) async {
        final h = await pumpFull(tester, use24Hour: false);

        await tester.tap(find.text('Reminder time'));
        await tester.pumpAndSettle();
        await pickTime(tester, '11', '59');

        expect(h.settings.calls, ['setEveningMinutes(1439)']);
      });

      testWidgets('on a 12-hour phone 12:00 AM is saved as 0', (tester) async {
        final h = await pumpFull(tester, use24Hour: false);

        await tester.tap(find.text('Reminder time'));
        await tester.pumpAndSettle();
        await pickTime(tester, '12', '00', period: 'AM');

        expect(h.settings.calls, ['setEveningMinutes(0)']);
      });

      testWidgets('cancelling the picker changes nothing', (tester) async {
        final h = await pumpFull(tester);

        await tester.tap(find.text('Reminder time'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        expect(h.settings.calls, isEmpty);
        expect(find.byType(Dialog), findsNothing);
        expect(subtitleOf(tester, 'Reminder time'), '21:00');
      });

      testWidgets('two fast taps on the row open one picker', (tester) async {
        await pumpFull(tester);

        await tester.tap(find.text('Reminder time'));
        await tester.tap(find.text('Reminder time'), warnIfMissed: false);
        await tester.pumpAndSettle();

        expect(find.byType(TimePickerDialog), findsOneWidget);
      });

      testWidgets('the switch is named for a screen reader', (tester) async {
        final handle = tester.ensureSemantics();
        await pumpFull(tester);

        expect(find.bySemanticsLabel('Evening reminder'), findsWidgets);
        handle.dispose();
      });
    });

    group('VN copies reminder', () {
      testWidgets('shows its copy and the switch calls setCopiesReminder', (
        tester,
      ) async {
        final h = await pumpFull(tester);

        expect(
          subtitleOf(tester, 'VN copies reminder'),
          '3 days after copying, if copies are still there',
        );
        await tester.tap(switchIn('VN copies reminder'));
        await tester.pumpAndSettle();

        expect(h.settings.calls, ['setCopiesReminder(false)']);
        expect(
          tester.widget<TtSwitch>(switchIn('VN copies reminder')).value,
          isFalse,
        );
      });

      testWidgets('two switches tapped one after the other both reach the '
          'controller', (tester) async {
        final h = await pumpFull(tester);

        await tester.tap(switchIn('VN copies reminder'));
        await tester.tap(switchIn('Remind me to turn it off'));
        await tester.pumpAndSettle();

        expect(h.settings.calls, [
          'setCopiesReminder(false)',
          'setStillReminder(false)',
        ]);
      });
    });

    group('while the settings are not known', () {
      testWidgets('the rows are there, and the switches cannot be used', (
        tester,
      ) async {
        final settings = FakeSettings(null);
        await pump(
          tester,
          _allowed,
          settings: settings,
          media: FakeAccess(MediaAccessLevel.full),
        );

        expect(rowTitled('Remind me to turn it off'), findsOneWidget);
        expect(rowTitled('Evening reminder'), findsOneWidget);
        expect(rowTitled('VN copies reminder'), findsOneWidget);
        for (final title in [
          'Remind me to turn it off',
          'Evening reminder',
          'VN copies reminder',
        ]) {
          expect(
            tester.widget<TtSwitch>(switchIn(title)).onChanged,
            isNull,
            reason: title,
          );
        }
        expect(tester.takeException(), isNull);
        expect(settings.calls, isEmpty);
      });

      testWidgets('they work as soon as the settings arrive', (tester) async {
        final settings = FakeSettings(null);
        await pump(tester, _allowed, settings: settings);

        settings.show(const AppSettings(eveningReminderEnabled: false));
        await tester.pump();

        expect(
          tester.widget<TtSwitch>(switchIn('Evening reminder')).onChanged,
          isNotNull,
        );
        expect(rowTitled('Reminder time'), findsNothing);
      });
    });

    group('Watched folders', () {
      for (final (folders, text) in [
        (<String>['DCIM/Camera'], 'Camera'),
        (
          <String>['DCIM/Camera', 'WhatsApp/Media/WhatsApp Video'],
          'Camera, WhatsApp Video',
        ),
        (<String>[], 'None'),
        (<String>['DCIM/Camera/'], 'Camera'),
        (<String>[''], 'Main folder'),
        (
          <String>['Movies/Open Camera', 'Movies/MotionCam', 'DCIM/Camera'],
          'Open Camera, MotionCam, Camera',
        ),
      ]) {
        testWidgets('$folders read "$text"', (tester) async {
          await pumpFull(tester, initial: AppSettings(watchedFolders: folders));

          expect(subtitleOf(tester, 'Watched folders'), text);
        });
      }

      testWidgets('the row has a chevron and opens the watched folders '
          'screen', (tester) async {
        await pumpFull(tester);
        expect(
          find.descendant(
            of: rowTitled('Watched folders'),
            matching: find.byIcon(Symbols.chevron_right_rounded),
          ),
          findsOneWidget,
        );

        await tester.tap(find.text('Watched folders'));
        await tester.pumpAndSettle();

        expect(find.text(watchedFoldersRouteMarker), findsOneWidget);
      });

      testWidgets('two fast taps push one screen', (tester) async {
        await pumpFull(tester);

        await tester.tap(find.text('Watched folders'));
        await tester.tap(find.text('Watched folders'), warnIfMissed: false);
        await tester.pumpAndSettle();
        routerOf(tester).pop();
        await tester.pumpAndSettle();

        expect(find.text(watchedFoldersRouteMarker), findsNothing);
        expect(find.byType(SettingsScreen), findsOneWidget);
      });
    });

    group('Send error log (Task 8 adds the action)', () {
      testWidgets('shows its title and subtitle, and a tap does nothing yet', (
        tester,
      ) async {
        await pumpFull(tester);

        expect(
          subtitleOf(tester, 'Send error log'),
          'Logs from this phone, to send by email or chat',
        );
        await tester.tap(find.text('Send error log'));
        await tester.pumpAndSettle();

        expect(find.byType(TtSnack), findsNothing);
        expect(find.byType(SettingsScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });

    group('Export and import', () {
      testWidgets('"No backup yet" before any export', (tester) async {
        await pumpFull(tester);

        expect(subtitleOf(tester, 'Export and import'), 'No backup yet');
      });

      for (final (time, text) in [
        (DateTime.utc(2026, 11, 12, 12), 'Last backup: Nov 12'),
        (DateTime.utc(2026, 1, 3, 12), 'Last backup: Jan 3'),
        (DateTime.utc(2025, 3, 5, 12), 'Last backup: Mar 5, 2025'),
      ]) {
        testWidgets('a backup on $time reads "$text"', (tester) async {
          await pumpFull(tester, lastExport: () async => time);

          expect(subtitleOf(tester, 'Export and import'), text);
        });
      }

      testWidgets('a last export that cannot be read says "No backup yet"', (
        tester,
      ) async {
        await pumpFull(
          tester,
          lastExport: () => Future<DateTime?>.error(StateError('x')),
        );

        expect(subtitleOf(tester, 'Export and import'), 'No backup yet');
        expect(tester.takeException(), isNull);
      });

      testWidgets('the row has a chevron and opens the backup screen', (
        tester,
      ) async {
        await pumpFull(tester);
        expect(
          find.descendant(
            of: rowTitled('Export and import'),
            matching: find.byIcon(Symbols.chevron_right_rounded),
          ),
          findsOneWidget,
        );

        await tester.tap(find.text('Export and import'));
        await tester.pumpAndSettle();

        expect(find.text(backupRouteMarker), findsOneWidget);
      });

      testWidgets('coming back from the backup screen reads the date again', (
        tester,
      ) async {
        var exported = false;
        await pumpFull(
          tester,
          lastExport: () async =>
              exported ? DateTime.utc(2026, 11, 14, 12) : null,
        );
        expect(subtitleOf(tester, 'Export and import'), 'No backup yet');

        await tester.tap(find.text('Export and import'));
        await tester.pumpAndSettle();
        exported = true;
        routerOf(tester).pop();
        await tester.pumpAndSettle();

        expect(subtitleOf(tester, 'Export and import'), 'Last backup: Nov 14');
      });
    });

    group('Video access', () {
      Finder buttonIn(String title) => find.descendant(
        of: rowTitled(title),
        matching: find.byType(TtButton),
      );

      testWidgets('all videos: a check and no button', (tester) async {
        await pumpFull(tester);

        expect(subtitleOf(tester, 'Video access'), 'All videos');
        expect(
          find.descendant(
            of: rowTitled('Video access'),
            matching: find.byIcon(Symbols.check_circle_rounded),
          ),
          findsOneWidget,
        );
        expect(buttonIn('Video access'), findsNothing);
      });

      testWidgets('some videos: "Manual mode" and a tonal Allow all', (
        tester,
      ) async {
        await pumpFull(tester, level: MediaAccessLevel.limited);

        expect(
          subtitleOf(tester, 'Video access'),
          'Some videos only · Manual mode',
        );
        expect(
          find.descendant(
            of: rowTitled('Video access'),
            matching: find.byIcon(Symbols.check_circle_rounded),
          ),
          findsNothing,
        );
        final button = tester.widget<TtButton>(buttonIn('Video access'));
        expect(button.label, 'Allow all');
        expect(button.kind, TtButtonKind.tonal);
        expect(button.size, TtButtonSize.small);
      });

      testWidgets('not allowed: a tonal Allow', (tester) async {
        await pumpFull(tester, level: MediaAccessLevel.denied);

        expect(subtitleOf(tester, 'Video access'), 'Not allowed');
        final button = tester.widget<TtButton>(buttonIn('Video access'));
        expect(button.label, 'Allow');
        expect(button.kind, TtButtonKind.tonal);
        expect(button.size, TtButtonSize.small);
      });

      for (final (level, label) in [
        (MediaAccessLevel.limited, 'Allow all'),
        (MediaAccessLevel.denied, 'Allow'),
      ]) {
        testWidgets('the $label button calls allow() once, whatever the '
            'taps', (tester) async {
          final h = await pumpFull(tester, level: level);

          await tester.tap(buttonIn('Video access'));
          await tester.pump();
          await tester.tap(buttonIn('Video access'));
          await tester.pumpAndSettle();

          expect(h.media.allowed, 1);
          expect(find.byType(TtSnack), findsNothing);
        });
      }

      testWidgets('the button works again after the window of the first '
          'tap', (tester) async {
        final h = await pumpFull(tester, level: MediaAccessLevel.denied);

        await tester.tap(buttonIn('Video access'));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 2));
        await tester.tap(buttonIn('Video access'));
        await tester.pumpAndSettle();

        expect(h.media.allowed, 2);
      });

      testWidgets('the row follows the state: Manual mode turns to a check', (
        tester,
      ) async {
        final h = await pumpFull(tester, level: MediaAccessLevel.limited);

        h.media.show(MediaAccessLevel.full);
        await tester.pump();

        expect(subtitleOf(tester, 'Video access'), 'All videos');
        expect(buttonIn('Video access'), findsNothing);
      });

      testWidgets('the Allow buttons of the two permissions are told apart '
          'by a screen reader', (tester) async {
        final handle = tester.ensureSemantics();
        await pumpFull(
          tester,
          level: MediaAccessLevel.denied,
          notifications: _askable,
        );

        expect(find.bySemanticsLabel('Allow video access'), findsOneWidget);
        expect(find.bySemanticsLabel('Allow notifications'), findsOneWidget);
        handle.dispose();
      });

      testWidgets('a limited level: the button reads "Allow all videos" to a '
          'screen reader', (tester) async {
        final handle = tester.ensureSemantics();
        await pumpFull(tester, level: MediaAccessLevel.limited);

        expect(find.bySemanticsLabel('Allow all videos'), findsOneWidget);
        handle.dispose();
      });

      testWidgets('a first read that failed shows Not allowed with Allow', (
        tester,
      ) async {
        final h = await pumpFull(tester, level: null);

        expect(subtitleOf(tester, 'Video access'), 'Not allowed');
        await tester.tap(buttonIn('Video access'));
        await tester.pumpAndSettle();
        expect(h.media.allowed, 1);
        expect(tester.takeException(), isNull);
      });

      testWidgets('while the first read runs there is no Video access row', (
        tester,
      ) async {
        await pump(tester, _allowed);

        expect(rowTitled('Video access'), findsNothing);
        // The Notifications row still has its group.
        expect(groupLabel('Permissions'), findsOneWidget);
        expect(rowTitled('Notifications'), findsOneWidget);
      });

      testWidgets('with both reads running, no Permissions group', (
        tester,
      ) async {
        await pump(tester, null, loading: true);

        expect(groupLabel('Permissions'), findsNothing);
        expect(rowTitled('Video access'), findsNothing);
      });
    });

    group('About', () {
      testWidgets('the privacy line and the version', (tester) async {
        await pumpFull(tester);

        expect(
          subtitleOf(tester, 'Your videos never leave your phone'),
          'No account, no cloud, no ads. TakeTray only stores which clips '
          'are in which reel.',
        );
        expect(subtitleOf(tester, 'TakeTray'), 'Version 1.0.0');
        // Plain rows: nothing to tap.
        expect(tester.widget<TtListRow>(rowTitled('TakeTray')).onTap, isNull);
        expect(
          tester
              .widget<TtListRow>(
                rowTitled('Your videos never leave your phone'),
              )
              .onTap,
          isNull,
        );
      });

      testWidgets('the version is the one the phone reports', (tester) async {
        final files = FakeFilesBridge()
          ..appInfoAnswer = const AppInfo(
            versionName: '2.14.3',
            androidRelease: '15',
          );
        await pumpFull(tester, files: files);

        expect(subtitleOf(tester, 'TakeTray'), 'Version 2.14.3');
      });

      testWidgets('when the version cannot be read: "Version" alone, no '
          'error', (tester) async {
        final files = FakeFilesBridge()..failNext('appInfo');
        await pumpFull(tester, files: files);

        expect(subtitleOf(tester, 'TakeTray'), 'Version');
        expect(tester.takeException(), isNull);
      });

      testWidgets('an empty version name reads "Version" with no gap at the '
          'end', (tester) async {
        final files = FakeFilesBridge()
          ..appInfoAnswer = const AppInfo(
            versionName: '',
            androidRelease: '15',
          );
        await pumpFull(tester, files: files);

        expect(subtitleOf(tester, 'TakeTray'), 'Version');
      });

      testWidgets('while the version is being read: "Version" alone', (
        tester,
      ) async {
        final files = FakeFilesBridge()..hold('appInfo');
        await pump(
          tester,
          _allowed,
          files: files,
          media: FakeAccess(MediaAccessLevel.full),
        );

        expect(subtitleOf(tester, 'TakeTray'), 'Version');

        files.release('appInfo');
        await tester.pumpAndSettle();
        expect(subtitleOf(tester, 'TakeTray'), 'Version 1.0.0');
      });
    });

    testApp('with the real database the switches save, and two quick '
        'taps both stay', (tester) async {
      final h = reelHarness();
      await pumpScreen(
        tester,
        const SettingsScreen(),
        size: const Size(360, 1700),
        overrides: [
          ...h.appOverrides,
          notificationAccessControllerProvider.overrideWith(
            () => FakeNotificationAccess(_allowed),
          ),
          mediaAccessControllerProvider.overrideWith(
            () => FakeAccess(MediaAccessLevel.full),
          ),
        ],
        settle: false,
      );
      await settleApp(tester);
      expect(
        tester.widget<TtSwitch>(switchIn('Evening reminder')).value,
        isTrue,
      );

      await tester.tap(switchIn('Evening reminder'));
      await tester.tap(switchIn('VN copies reminder'));
      await settleApp(tester);

      final repo = h.container.read(settingsRepositoryProvider);
      expect(
        await real(tester, repo.load),
        const AppSettings(
          eveningReminderEnabled: false,
          copiesReminderEnabled: false,
        ),
      );
      expect(
        tester.widget<TtSwitch>(switchIn('Evening reminder')).value,
        isFalse,
      );
      expect(
        tester.widget<TtSwitch>(switchIn('VN copies reminder')).value,
        isFalse,
      );
      expect(rowTitled('Reminder time'), findsNothing);
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
