import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:taketray/features/onboarding/view_models/onboarding_controller.dart';
import 'package:taketray/features/onboarding/views/welcome_intro.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../../../support/fixed_onboarding.dart';

/// The welcome's intro (Task 6, D-139) as screenshots at the frames the
/// hub's Motion page shows: 0.4, 1.0, 1.5, 1.95, 2.5 and 3.1 s, light and
/// dark. The final frame is `welcome_final_*` (welcome_golden_test.dart).
///
/// **macOS only, and not on CI** (D-61, D-97), like the welcome's final
/// frame. Make or update them with `tool/flutter test --update-goldens
/// test/features/onboarding/views/welcome_intro_golden_test.dart` from `app/`.
final bool _goldens =
    Platform.isMacOS && !Platform.environment.containsKey('CI');

/// The intro played to [ms] milliseconds: the controller's value is
/// `ms / 3600`.
Future<void> _pumpAt(
  WidgetTester tester, {
  required int ms,
  required Brightness brightness,
}) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [
      onboardingControllerProvider.overrideWith(FixedOnboarding.fresh),
    ],
  );
  addTearDown(container.dispose);
  await container.read(onboardingControllerProvider.future);
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, state) => const WelcomeIntro()),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
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
      ),
    ),
  );
  // Decode the three clips for real, so they show in the image. The fake
  // clock does not move meanwhile.
  final pending = <(ImageProvider, Element)>[
    for (final element in find.byType(Image).evaluate())
      ((element.widget as Image).image, element),
  ];
  await tester.runAsync(
    () => Future.wait([
      for (final (image, element) in pending)
        precacheImage(image, element, onError: (_, _) {}),
    ]),
  );
  // The ticker's first frame is the intro's 0 ms.
  await tester.pump();
  await tester.pump(Duration(milliseconds: ms));
}

void main() {
  for (final ms in const [400, 1000, 1500, 1950, 2500, 3100]) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'welcome intro at $ms ms, ${brightness.name}',
        skip: !_goldens,
        (tester) async {
          await _pumpAt(tester, ms: ms, brightness: brightness);
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
              'goldens/macos/welcome_intro_${ms}_${brightness.name}.png',
            ),
          );
        },
      );
    }
  }
}
