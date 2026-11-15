import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:taketray/features/notifications/view_models/notification_access_controller.dart';
import 'package:taketray/features/onboarding/views/notifications_step_screen.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray/platform/background_bridge.dart';
import 'package:taketray_ui/taketray_ui.dart';

/// The notifications step as screenshots (Task 7, D-140), light and dark.
///
/// **macOS only, and not on CI** (D-61, D-97): see `welcome_golden_test.dart`.
/// Make or update them with `tool/flutter test --update-goldens
/// test/features/onboarding/views/notifications_step_golden_test.dart` from
/// `app/`.
final bool _goldens =
    Platform.isMacOS && !Platform.environment.containsKey('CI');

class _Notif extends NotificationAccessController {
  @override
  Future<NotificationAccess> build() async =>
      const NotificationAccess(granted: false, canAsk: true, sdkInt: 34);
}

Future<void> _pump(
  WidgetTester tester, {
  required Brightness brightness,
  double textScale = 1,
}) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const NotificationsStepScreen(),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        notificationAccessControllerProvider.overrideWith(_Notif.new),
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
  // Decode the four pictures for real, so they show in the image.
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
    testWidgets('notifications step, ${brightness.name}', skip: !_goldens, (
      tester,
    ) async {
      await _pump(tester, brightness: brightness);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/macos/notifications_step_${brightness.name}.png',
        ),
      );
    });
  }

  testWidgets('notifications step, light, text 2x', skip: !_goldens, (
    tester,
  ) async {
    await _pump(tester, brightness: Brightness.light, textScale: 2);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/macos/notifications_step_light_2x.png'),
    );
  });
}
