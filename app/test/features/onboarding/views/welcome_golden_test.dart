import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:taketray/features/onboarding/views/welcome_screen.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray_ui/taketray_ui.dart';

/// The welcome's final frame, as screenshots (Task 5, D-138), at text 1x and
/// 2x, light and dark.
///
/// **macOS only, and not on CI** (D-61, D-97): the images are made with real
/// text on the owner's Mac (`goldens/macos/`); CI has no set for the app's
/// screens, so there the tests are registered but skipped. Make or update
/// them with `tool/flutter test --update-goldens
/// test/features/onboarding/views/welcome_golden_test.dart` from `app/`.
final bool _goldens =
    Platform.isMacOS && !Platform.environment.containsKey('CI');

Future<void> _pump(
  WidgetTester tester, {
  required Brightness brightness,
  required double textScale,
}) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, state) => const WelcomeScreen()),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
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
  );
  await tester.pump();
  // Decode the three clips for real, so they show in the image.
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
  await tester.pumpAndSettle();
}

void main() {
  for (final brightness in Brightness.values) {
    for (final (scale, suffix) in [(1.0, ''), (2.0, '_2x')]) {
      testWidgets(
        'welcome, final frame, ${brightness.name}, text ${scale}x',
        skip: !_goldens,
        (tester) async {
          await _pump(tester, brightness: brightness, textScale: scale);
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
              'goldens/macos/welcome_final_${brightness.name}$suffix.png',
            ),
          );
        },
      );
    }
  }
}
