import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/data/repositories/references_repository.dart';
import 'package:taketray/features/onboarding/view_models/onboarding_controller.dart';
import 'package:taketray/features/onboarding/views/reels_step_screen.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../../../support/fixed_onboarding.dart';
import '../../../support/test_app.dart';
import '../../../support/vm_harness.dart';

/// The reels step as screenshots (Task 8, D-141; D-168), light and dark:
/// empty, three names, with reels that exist, one existing and two typed, an
/// error, and 2x text with the
/// keyboard up.
///
/// **macOS only, and not on CI** (D-61, D-97): see `welcome_golden_test.dart`.
/// Make or update them with `tool/flutter test --update-goldens
/// test/features/onboarding/views/reels_step_golden_test.dart` from `app/`.
final bool _goldens =
    Platform.isMacOS && !Platform.environment.containsKey('CI');

enum _Look { empty, threeNames, existing, existingAndTyped, error }

Future<void> _pump(
  WidgetTester tester, {
  required _Look look,
  required Brightness brightness,
  double textScale = 1,
  double keyboard = 0,
}) async {
  tester.view
    ..physicalSize = const Size(360, 800)
    ..devicePixelRatio = 1
    ..viewInsets = FakeViewPadding(bottom: keyboard);
  addTearDown(tester.view.reset);
  final h = VmHarness();
  if (look == _Look.existing) {
    await ReelsRepository(h.media.db, h.media.clock).create('London Food');
  }
  if (look == _Look.existingAndTyped) {
    // A reel a share made before onboarding, with two references (D-168).
    final reel = await ReelsRepository(
      h.media.db,
      h.media.clock,
    ).create('Tokyo Street Food');
    final refs = ReferencesRepository(h.media.db, h.media.clock);
    await refs.add(reel.id, 'https://www.instagram.com/p/AAA/');
    await refs.add(reel.id, 'https://www.instagram.com/p/BBB/');
  }
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const ReelsStepScreen()),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...h.overrides,
        onboardingControllerProvider.overrideWith(FixedOnboarding.fresh),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        debugShowCheckedModeBanner: false,
        theme: TakeTrayTheme.light(),
        darkTheme: TakeTrayTheme.dark(),
        themeMode: brightness == Brightness.dark
            ? ThemeMode.dark
            : ThemeMode.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, app) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: app!,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.runAsync(settle);
  await tester.pumpAndSettle();
  Future<void> enter(String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
  }

  switch (look) {
    case _Look.empty || _Look.existing:
      break;
    case _Look.existingAndTyped:
      await enter('London Food');
      await enter('Day 1 Vlog');
    case _Look.threeNames:
      await enter('London Food');
      await enter('Day 1 Vlog');
      await enter('Cinematic');
    case _Look.error:
      await enter('London Food');
      await enter('london food');
  }
  await tester.pumpAndSettle();
}

void main() {
  for (final look in _Look.values) {
    for (final brightness in Brightness.values) {
      testApp('reels step, ${look.name}, ${brightness.name}', skip: !_goldens, (
        tester,
      ) async {
        await _pump(tester, look: look, brightness: brightness);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'goldens/macos/reels_step_${look.name}_${brightness.name}.png',
          ),
        );
      });
    }
  }

  for (final brightness in Brightness.values) {
    testApp(
      'reels step, three names, ${brightness.name}, text 2x, keyboard up',
      skip: !_goldens,
      (tester) async {
        await _pump(
          tester,
          look: _Look.threeNames,
          brightness: brightness,
          textScale: 2,
          keyboard: 300,
        );
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'goldens/macos/reels_step_keyboard_2x_${brightness.name}.png',
          ),
        );
      },
    );
  }

  for (final brightness in Brightness.values) {
    testApp(
      'reels step, one existing and two typed, ${brightness.name}, text 2x',
      skip: !_goldens,
      (tester) async {
        await _pump(
          tester,
          look: _Look.existingAndTyped,
          brightness: brightness,
          textScale: 2,
        );
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'goldens/macos/reels_step_existingAndTyped_2x_${brightness.name}.png',
          ),
        );
      },
    );
  }
}
