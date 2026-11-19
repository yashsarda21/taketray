import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/features/media_access/view_models/media_access_controller.dart';
import 'package:taketray/features/onboarding/view_models/onboarding_controller.dart';
import 'package:taketray/features/shooting_mode/view_models/shooting_mode_controller.dart';
import 'package:taketray/features/shooting_mode/views/shooting_mode_section.dart';
import 'package:taketray/features/tagging/view_models/pending_clips.dart';

import '../../../support/fixed_clock.dart';
import '../../../support/fixed_onboarding.dart';
import '../../../support/pump_screen.dart';
import '../../../support/view_model_fakes.dart';

/// The Shooting mode card with the one-time Home tip as screenshots (Task 9,
/// D-142): light, dark and at 2x text.
///
/// **macOS only, and not on CI** (D-61, D-97): see `welcome_golden_test.dart`.
/// Make or update them with `tool/flutter test --update-goldens
/// test/features/shooting_mode/views/shooting_tip_golden_test.dart` from
/// `app/`.
final bool _goldens =
    Platform.isMacOS && !Platform.environment.containsKey('CI');

Future<void> _pump(
  WidgetTester tester, {
  required Brightness brightness,
  double textScale = 1,
}) async {
  await pumpScreen(
    tester,
    const Scaffold(body: SingleChildScrollView(child: ShootingModeSection())),
    overrides: <Override>[
      shootingModeControllerProvider.overrideWith(
        () => FakeShooting(ShootingState.off),
      ),
      mediaAccessControllerProvider.overrideWith(
        () => FakeAccess(MediaAccessLevel.full),
      ),
      pendingClipsProvider.overrideWith((ref) => Stream.value(const [])),
      firstShowableClipProvider.overrideWith((ref) => Stream.value(null)),
      clockProvider.overrideWithValue(FixedClock(DateTime(2026, 10, 28, 15))),
      onboardingControllerProvider.overrideWith(
        () =>
            FixedOnboarding(done: true, introPlayed: true, homeTipSeen: false),
      ),
      thumbnailCacheForTests,
    ],
    brightness: brightness,
    textScale: textScale,
    // Tall enough to show the whole tip at 2x text.
    size: Size(360, textScale > 1 ? 1100 : 800),
  );
}

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('Shooting mode tip, ${brightness.name}', skip: !_goldens, (
      tester,
    ) async {
      await _pump(tester, brightness: brightness);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/macos/shooting_tip_${brightness.name}.png'),
      );
    });
  }

  testWidgets('Shooting mode tip, light, text 2x', skip: !_goldens, (
    tester,
  ) async {
    await _pump(tester, brightness: Brightness.light, textScale: 2);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/macos/shooting_tip_light_2x.png'),
    );
  });
}
