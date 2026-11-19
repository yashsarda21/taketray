import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/features/media_access/view_models/media_access_controller.dart';
import 'package:taketray/features/notifications/view_models/notification_access_controller.dart';
import 'package:taketray/features/onboarding/views/access_step_screen.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray/platform/android_sdk.dart';
import 'package:taketray/platform/background_bridge.dart';
import 'package:taketray_ui/taketray_ui.dart';

/// The video access step's four states as screenshots (Task 7, D-140), light
/// and dark, and the denied state at 2x text.
///
/// **macOS only, and not on CI** (D-61, D-97): see `welcome_golden_test.dart`.
/// Make or update them with `tool/flutter test --update-goldens
/// test/features/onboarding/views/access_step_golden_test.dart` from `app/`.
final bool _goldens =
    Platform.isMacOS && !Platform.environment.containsKey('CI');

class _Access extends MediaAccessController {
  _Access(this.view);

  final MediaAccessView view;

  @override
  Future<MediaAccessView> build() async => view;
}

class _Notif extends NotificationAccessController {
  @override
  Future<NotificationAccess> build() async =>
      const NotificationAccess(granted: false, canAsk: true, sdkInt: 34);
}

Future<void> _pump(
  WidgetTester tester,
  MediaAccessView view, {
  required Brightness brightness,
  double textScale = 1,
}) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, state) => const AccessStepScreen()),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mediaAccessControllerProvider.overrideWith(() => _Access(view)),
        notificationAccessControllerProvider.overrideWith(_Notif.new),
        androidSdkProvider.overrideWith((ref) async => 34),
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
  await tester.pumpAndSettle();
}

MediaAccessView _v(MediaAccessLevel level, {bool canAsk = true}) =>
    MediaAccessView(
      level: level,
      banner: AccessBanner.none,
      canAskAgain: canAsk,
    );

void main() {
  final states = <(String, MediaAccessView)>[
    ('before', _v(MediaAccessLevel.denied)),
    ('some', _v(MediaAccessLevel.limited)),
    ('denied', _v(MediaAccessLevel.denied, canAsk: false)),
    ('all_set', _v(MediaAccessLevel.full)),
  ];
  for (final brightness in Brightness.values) {
    for (final (name, view) in states) {
      testWidgets('access step, $name, ${brightness.name}', skip: !_goldens, (
        tester,
      ) async {
        await _pump(tester, view, brightness: brightness);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'goldens/macos/access_${name}_${brightness.name}.png',
          ),
        );
      });
    }
  }

  testWidgets('access step, denied, light, text 2x', skip: !_goldens, (
    tester,
  ) async {
    await _pump(
      tester,
      _v(MediaAccessLevel.denied, canAsk: false),
      brightness: Brightness.light,
      textScale: 2,
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/macos/access_denied_light_2x.png'),
    );
  });
}
