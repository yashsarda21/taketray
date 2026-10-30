import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:taketray/app.dart' show resolvePhoneLocale;
import 'package:taketray/data/media/thumbnail_cache.dart';
import 'package:taketray/features/shell/views/root_messenger.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray/router/routes.dart';
import 'package:taketray_ui/taketray_ui.dart';

import 'fake_media_bridge.dart';

/// A thumbnail cache on a bridge with no pictures and a folder that does not
/// exist: every tile shows its placeholder, and nothing reaches the phone.
final Override thumbnailCacheForTests = thumbnailCacheProvider.overrideWith(
  (ref) async => ThumbnailCache(FakeMediaBridge(), Directory('/nonexistent')),
);

/// What the To tag route shows in a test that only has one screen.
const toTagRouteMarker = 'the To tag route';

/// What the Reels route shows in a test that only has one screen.
const reelsRouteMarker = 'the Reels route';

/// Pumps [screen] at `/` of a small router (with a `/to-tag` route that shows
/// [toTagRouteMarker] and a `/reels` route that shows [reelsRouteMarker])
/// inside a `ProviderScope` with [overrides], the TakeTray
/// theme and the app's localizations, on a phone-sized view.
///
/// [textScale] and [brightness] are applied to the whole app; [size] is the
/// logical size (the pixel ratio is 1). The phone's "remove animations" is on
/// unless [animations] is true: the record dot of the Shooting mode card and
/// the skeleton tiles loop for ever, and `pumpAndSettle` would never settle.
/// [use24Hour] is the phone's 24-hour setting. [locale] is the phone's
/// language and region (English, United States, when null).
Future<ProviderContainer> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  List<Override> overrides = const [],
  Brightness brightness = Brightness.light,
  double textScale = 1,
  Size size = const Size(360, 800),
  bool settle = true,
  bool animations = false,
  bool use24Hour = false,
  Locale? locale,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, state) => screen),
      GoRoute(
        path: Routes.reels,
        builder: (context, state) =>
            const Scaffold(body: Text(reelsRouteMarker)),
      ),
      GoRoute(
        path: Routes.toTag,
        builder: (context, state) =>
            const Scaffold(body: Text(toTagRouteMarker)),
      ),
    ],
  );
  addTearDown(router.dispose);
  final container = ProviderContainer(overrides: overrides);
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        scaffoldMessengerKey: container.read(rootMessengerKeyProvider),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
        localeListResolutionCallback: resolvePhoneLocale,
        theme: TakeTrayTheme.light(),
        darkTheme: TakeTrayTheme.dark(),
        themeMode: brightness == Brightness.dark
            ? ThemeMode.dark
            : ThemeMode.light,
        debugShowCheckedModeBanner: false,
        builder: (context, app) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: !animations,
            alwaysUse24HourFormat: use24Hour,
          ),
          child: app!,
        ),
      ),
    ),
  );
  if (settle) await tester.pumpAndSettle();
  return container;
}

/// A [Text] showing [text], where the narrow no-break space that intl 0.20
/// writes before AM and PM counts as a plain space ("9:41 AM").
Finder findPlain(String text) => find.byWidgetPredicate(
  (widget) =>
      widget is Text &&
      (widget.data ?? widget.textSpan?.toPlainText() ?? '').replaceAll(
            '\u202f',
            ' ',
          ) ==
          text,
  description: 'a Text showing "$text"',
);
