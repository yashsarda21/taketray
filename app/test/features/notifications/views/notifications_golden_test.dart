import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/features/editors/view_models/copies_storage_controller.dart';
import 'package:taketray/features/notifications/view_models/notification_access_controller.dart';
import 'package:taketray/features/notifications/views/notifications_help_screen.dart';
import 'package:taketray/features/notifications/views/still_shooting_dialog.dart';
import 'package:taketray/features/settings/views/settings_screen.dart';
import 'package:taketray/platform/background_bridge.dart';
import 'package:taketray/platform/media_bridge.dart';

import '../../../support/fake_background_bridge.dart';
import '../../../support/fake_media_bridge.dart';
import '../../../support/pump_screen.dart';
import '../../../support/test_app.dart';
import '../../../support/view_model_fakes.dart';
import '../../../support/vm_harness.dart';

/// The screenshots of Phase 6's screens (Task 7, D-107): the help screen
/// (Samsung's card open; a phone TakeTray has no steps for), the Still
/// shooting? dialog and the Settings rows (notifications allowed; not
/// allowed), light and dark, at text 1x and 2x.
///
/// **macOS only, and not on CI** (D-61): the images are made with real text on
/// the owner's Mac (`goldens/macos/`). Make or update them with
/// `tool/flutter test --update-goldens
/// test/features/notifications/views/notifications_golden_test.dart` from
/// `app/`.
final bool _goldens =
    Platform.isMacOS && !Platform.environment.containsKey('CI');

const _allowed = NotificationAccess(granted: true, canAsk: false, sdkInt: 34);
const _askable = NotificationAccess(granted: false, canAsk: true, sdkInt: 34);

/// Registers [body] four times: light and dark, text 1x and 2x.
void both(
  String description,
  String name,
  Future<void> Function(WidgetTester tester, double scale, Brightness b) body,
) {
  for (final (scale, brightness, suffix) in [
    (1.0, Brightness.light, '1x'),
    (2.0, Brightness.light, '2x'),
    (1.0, Brightness.dark, 'dark_1x'),
    (2.0, Brightness.dark, 'dark_2x'),
  ]) {
    testApp('$description ($suffix)', (tester) async {
      tester.view
        ..physicalSize = const Size(360, 800)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await body(tester, scale, brightness);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/macos/${name}_$suffix.png'),
      );
    }, skip: !_goldens);
  }
}

Future<void> _help(
  WidgetTester tester,
  double scale,
  Brightness brightness,
  String maker,
) async {
  final background = FakeBackgroundBridge()..maker = maker;
  await pumpScreen(
    tester,
    const NotificationsHelpScreen(),
    overrides: <Override>[
      backgroundBridgeProvider.overrideWithValue(background),
      mediaBridgeProvider.overrideWithValue(FakeMediaBridge()),
    ],
    textScale: scale,
    brightness: brightness,
  );
}

Future<void> _settings(
  WidgetTester tester,
  double scale,
  Brightness brightness,
  NotificationAccess access,
) async {
  await pumpScreen(
    tester,
    const SettingsScreen(),
    overrides: <Override>[
      notificationAccessControllerProvider.overrideWith(
        () => FakeNotificationAccess(access),
      ),
      copiesSummaryProvider.overrideWith(
        (ref) => Stream.value(
          const CopiesSummary(bytes: 1800 * 1000 * 1000, reels: 3),
        ),
      ),
    ],
    textScale: scale,
    brightness: brightness,
  );
}

void main() {
  both(
    'help, Samsung open',
    'notifications_help_samsung',
    (tester, scale, brightness) => _help(tester, scale, brightness, 'samsung'),
  );

  both(
    'help, unknown phone',
    'notifications_help_unknown',
    (tester, scale, brightness) => _help(tester, scale, brightness, 'google'),
  );

  both(
    'settings, notifications allowed',
    'settings_allowed',
    (tester, scale, brightness) =>
        _settings(tester, scale, brightness, _allowed),
  );

  both(
    'settings, notifications not allowed',
    'settings_not_allowed',
    (tester, scale, brightness) =>
        _settings(tester, scale, brightness, _askable),
  );

  both('the Still shooting? dialog', 'still_shooting_dialog', (
    tester,
    scale,
    brightness,
  ) async {
    final h = VmHarness(now: DateTime.utc(2026, 6, 1, 9));
    await tester.runAsync(h.media.turnOnNow);
    h.media.clock.advance(const Duration(days: 15));
    await pumpScreen(
      tester,
      const Scaffold(body: StillShootingPromptHost()),
      overrides: h.overrides,
      textScale: scale,
      brightness: brightness,
      settle: false,
    );
    await tester.runAsync(settle);
    await tester.pump();
    await tester.pumpAndSettle();
    await tester.runAsync(settle);
    await tester.pump();
    await tester.pumpAndSettle();
  });
}
