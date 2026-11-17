import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/domain/models/app_settings.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/features/editors/view_models/copies_storage_controller.dart';
import 'package:taketray/features/media_access/view_models/media_access_controller.dart';
import 'package:taketray/features/notifications/view_models/notification_access_controller.dart';
import 'package:taketray/features/settings/view_models/settings_controller.dart';
import 'package:taketray/features/settings/views/settings_screen.dart';
import 'package:taketray/platform/background_bridge.dart';
import 'package:taketray/platform/files_bridge.dart';

import '../../../support/fake_files_bridge.dart';
import '../../../support/fake_settings.dart';
import '../../../support/fixed_clock.dart';
import '../../../support/pump_screen.dart';
import '../../../support/view_model_fakes.dart';

/// The whole Settings screen as screenshots (Phase 10B, Task 5, D-148): the
/// three looks of Video access, the evening reminder on and off, light and
/// dark, and at 2x text. The view is tall enough to hold every row.
///
/// **macOS only, and not on CI** (D-61, D-97): see `welcome_golden_test.dart`.
/// Make or update them with `tool/flutter test --update-goldens
/// test/features/settings/views/settings_golden_test.dart` from `app/`.
final bool _goldens =
    Platform.isMacOS && !Platform.environment.containsKey('CI');

Future<void> _pump(
  WidgetTester tester, {
  required MediaAccessLevel level,
  required Brightness brightness,
  bool evening = true,
  double textScale = 1,
}) async {
  await pumpScreen(
    tester,
    const SettingsScreen(),
    overrides: <Override>[
      settingsControllerProvider.overrideWith(
        () => FakeSettings(
          AppSettings(
            eveningReminderEnabled: evening,
            watchedFolders: const [
              'DCIM/Camera',
              'WhatsApp/Media/WhatsApp Video',
            ],
          ),
        ),
      ),
      mediaAccessControllerProvider.overrideWith(() => FakeAccess(level)),
      notificationAccessControllerProvider.overrideWith(
        () => FakeNotificationAccess(
          const NotificationAccess(granted: true, canAsk: false, sdkInt: 34),
        ),
      ),
      copiesSummaryProvider.overrideWith(
        (ref) => Stream.value(
          const CopiesSummary(bytes: 1800 * 1000 * 1000, reels: 3),
        ),
      ),
      lastExportProvider.overrideWith(
        (ref) async => DateTime.utc(2026, 11, 12, 12),
      ),
      filesBridgeProvider.overrideWithValue(FakeFilesBridge()),
      clockProvider.overrideWithValue(
        FixedClock(DateTime.utc(2026, 11, 17, 12)),
      ),
    ],
    brightness: brightness,
    textScale: textScale,
    use24Hour: true,
    size: Size(360, textScale > 1 ? 3350 : 1420),
  );
}

void main() {
  for (final brightness in Brightness.values) {
    for (final (name, level) in [
      ('access_full', MediaAccessLevel.full),
      ('access_manual', MediaAccessLevel.limited),
      ('access_denied', MediaAccessLevel.denied),
    ]) {
      testWidgets('settings, $name, ${brightness.name}', skip: !_goldens, (
        tester,
      ) async {
        await _pump(tester, level: level, brightness: brightness);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'goldens/macos/settings_${name}_${brightness.name}.png',
          ),
        );
      });
    }

    testWidgets('settings, evening off, ${brightness.name}', skip: !_goldens, (
      tester,
    ) async {
      await _pump(
        tester,
        level: MediaAccessLevel.full,
        brightness: brightness,
        evening: false,
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/macos/settings_evening_off_${brightness.name}.png',
        ),
      );
    });

    testWidgets(
      'settings, denied, ${brightness.name}, text 2x',
      skip: !_goldens,
      (tester) async {
        await _pump(
          tester,
          level: MediaAccessLevel.denied,
          brightness: brightness,
          textScale: 2,
        );
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'goldens/macos/settings_denied_${brightness.name}_2x.png',
          ),
        );
      },
    );
  }
}
