import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:taketray/app.dart' show resolvePhoneLocale;
import 'package:taketray/core/midnight_tick.dart';
import 'package:taketray/data/media/thumbnail_cache.dart';
import 'package:taketray/features/shell/views/root_messenger.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray/router/app_router.dart'
    show addVideosRoute, copyRoutes;
import 'package:taketray/router/popup_route_tracker.dart';
import 'package:taketray/router/routes.dart';
import 'package:taketray_ui/taketray_ui.dart';

import 'fake_media_bridge.dart';

/// A thumbnail cache on a bridge with no pictures and a folder that does not
/// exist: every tile shows its placeholder, and nothing reaches the phone.
final Override thumbnailCacheForTests = thumbnailCacheProvider.overrideWith(
  (ref) async => ThumbnailCache(FakeMediaBridge(), Directory('/nonexistent')),
);

Stream<DateTime> _noTick(Ref ref) => const Stream.empty();

/// What the To tag route shows in a test that only has one screen.
const toTagRouteMarker = 'the To tag route';

/// What the tag player's route shows in a test that only has one screen:
/// the clip id it was opened on ("null" for none).
String tagPlayerRouteMarker(Object? from) => 'the tag player from $from';

/// What the Skipped route shows in a test that only has one screen.
const skippedRouteMarker = 'the Skipped route';

/// What the notifications help route shows in a test that only has one
/// screen.
const notificationsHelpRouteMarker = 'the notifications help route';

/// What the Reels route shows in a test that only has one screen.
const reelsRouteMarker = 'the Reels route';

/// What the Add videos route shows in a test that only has one screen: the
/// reel id of its target (`?reel=`), "null" for To tag.
String addVideosRouteMarker(Object? reel) => 'the Add videos route for $reel';

/// What the route of reel [id] shows in a test that only has one screen.
String reelRouteMarker(Object id) => 'the route of reel $id';

/// What the viewer's route on clip [clipId] of reel [reelId] shows in a test
/// that only has one screen.
String clipRouteMarker(Object reelId, Object clipId) =>
    'the viewer of clip $clipId of reel $reelId';

/// What the clip picking route shows in a test that only has one screen: the
/// reel id (`?reel=`), the preselected clips (`&clips=`, "null" for none)
/// and the add flag (`&add=`, "null" for none).
String editSelectRouteMarker(Object? reel, Object? clips, Object? add) =>
    'the picking screen of reel $reel, clips $clips, add $add';

/// What the VN space route shows in a test that only has one screen: the
/// reel id, the editor and the clips, as in its location.
String copySpaceRouteMarker(Object? reel, Object? editor, Object? clips) =>
    'the space check of reel $reel for $editor, clips $clips';

/// What the copy progress route shows in a test that only has one screen:
/// the job id (`?job=`).
String copyProgressRouteMarker(Object? job) => 'the copy progress of job $job';

/// What the ready route shows in a test that only has one screen: the reel id
/// (`?reel=`).
String copyReadyRouteMarker(Object? reel) => 'the ready screen of reel $reel';

/// The router of the app [tester] pumped with [pumpScreen] (to push a route
/// over the screen).
GoRouter routerOf(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Scaffold).first));

/// Pumps [screen] at `/` of a small router (with a `/to-tag` route that shows
/// [toTagRouteMarker], a `/reels` route that shows [reelsRouteMarker] and a
/// `/reels/<id>` route that shows [reelRouteMarker], and a
/// `/reels/<id>/clip/<clipId>` route that shows [clipRouteMarker], and a
/// `/to-tag/play` route that shows [tagPlayerRouteMarker] and a
/// `/to-tag/skipped` route that shows [skippedRouteMarker], and a
/// `/settings/notifications-help` route that shows
/// [notificationsHelpRouteMarker], and an `/edit` route that shows
/// [editSelectRouteMarker] with an `/edit/space` route that shows
/// [copySpaceRouteMarker] (Task 10 registers the real space screen), and a
/// `/add-videos` route that shows
/// [addVideosRouteMarker], or with [addVideos] the app's own Add videos
/// screens; the three VN copy routes show [copySpaceRouteMarker],
/// [copyProgressRouteMarker] and [copyReadyRouteMarker], or with
/// [copyScreens] the app's own copy screens)
/// inside a `ProviderScope` with [overrides], the TakeTray
/// theme and the app's localizations, on a phone-sized view.
///
/// [textScale] and [brightness] are applied to the whole app; [size] is the
/// logical size (the pixel ratio is 1). The phone's "remove animations" is on
/// unless [animations] is true: the record dot of the Shooting mode card and
/// the skeleton tiles loop for ever, and `pumpAndSettle` would never settle.
/// [use24Hour] is the phone's 24-hour setting. [locale] is the phone's
/// language and region (English, United States, when null).
///
/// The midnight tick (`localDayProvider`) never fires, unless [midnightTick]
/// is true. Then the container is disposed as soon as the tree is taken down,
/// so the tick's timer is cancelled before the test binding looks for pending
/// timers; use it only with fake view models (a real database needs
/// `testApp`).
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
  bool midnightTick = false,
  bool addVideos = false,
  bool copyScreens = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [
      // The midnight tick owns a timer, and the test binding fails a test that
      // ends with one pending before any tear-down runs. Screens that watch it
      // get a tick that never comes, unless the test is about the tick.
      if (!midnightTick) localDayProvider.overrideWith(_noTick),
      ...overrides,
    ],
  );
  addTearDown(container.dispose);
  final router = GoRouter(
    // Sheets and dialogs are seen, as in the app (D-107).
    observers: [
      container.read(popupRouteTrackerProvider).observerForNavigator(),
    ],
    routes: [
      GoRoute(path: '/', builder: (context, state) => screen),
      GoRoute(
        path: Routes.reels,
        builder: (context, state) =>
            const Scaffold(body: Text(reelsRouteMarker)),
        routes: [
          GoRoute(
            path: ':${Routes.reelIdParameter}',
            builder: (context, state) => Scaffold(
              body: Text(
                reelRouteMarker(state.pathParameters[Routes.reelIdParameter]!),
              ),
            ),
            routes: [
              GoRoute(
                path: 'clip/:${Routes.clipIdParameter}',
                builder: (context, state) => Scaffold(
                  body: Text(
                    clipRouteMarker(
                      state.pathParameters[Routes.reelIdParameter]!,
                      state.pathParameters[Routes.clipIdParameter]!,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      if (addVideos)
        addVideosRoute()
      else
        GoRoute(
          path: Routes.addVideos,
          builder: (context, state) => Scaffold(
            body: Text(
              addVideosRouteMarker(
                state.uri.queryParameters[Routes.addVideosReelParameter],
              ),
            ),
          ),
        ),
      GoRoute(
        path: Routes.editSelect,
        builder: (context, state) {
          final query = state.uri.queryParameters;
          return Scaffold(
            body: Text(
              editSelectRouteMarker(
                query[Routes.editReelParameter],
                query[Routes.editClipsParameter],
                query[Routes.editAddParameter],
              ),
            ),
          );
        },
      ),
      if (copyScreens)
        ...copyRoutes()
      else ...[
        GoRoute(
          path: Routes.copySpace,
          builder: (context, state) {
            final query = state.uri.queryParameters;
            return Scaffold(
              body: Text(
                copySpaceRouteMarker(
                  query[Routes.editReelParameter],
                  query[Routes.copyEditorParameter],
                  query[Routes.editClipsParameter],
                ),
              ),
            );
          },
        ),
        GoRoute(
          path: Routes.copyProgress,
          builder: (context, state) => Scaffold(
            body: Text(
              copyProgressRouteMarker(
                state.uri.queryParameters[Routes.copyJobParameter],
              ),
            ),
          ),
        ),
        GoRoute(
          path: Routes.copyReady,
          builder: (context, state) => Scaffold(
            body: Text(
              copyReadyRouteMarker(
                state.uri.queryParameters[Routes.editReelParameter],
              ),
            ),
          ),
        ),
      ],
      GoRoute(
        path: Routes.notificationsHelp,
        builder: (context, state) =>
            const Scaffold(body: Text(notificationsHelpRouteMarker)),
      ),
      GoRoute(
        path: Routes.toTag,
        builder: (context, state) =>
            const Scaffold(body: Text(toTagRouteMarker)),
        routes: [
          GoRoute(
            path: 'play',
            builder: (context, state) => Scaffold(
              body: Text(
                tagPlayerRouteMarker(
                  state.uri.queryParameters[Routes.tagFromParameter],
                ),
              ),
            ),
          ),
          GoRoute(
            path: 'skipped',
            builder: (context, state) =>
                const Scaffold(body: Text(skippedRouteMarker)),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    _DisposeOnUnmount(
      container: midnightTick ? container : null,
      child: UncontrolledProviderScope(
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
    ),
  );
  if (settle) await tester.pumpAndSettle();
  return container;
}

/// Disposes [container], when there is one, as the tree is taken down.
///
/// The test binding fails a test that ends with a timer pending, and checks
/// right after it unmounts the tree, before any `addTearDown` runs. Riverpod
/// disposes an unused provider only later, so the midnight tick (which owns a
/// timer) would still be there. The children are unmounted first, then this.
class _DisposeOnUnmount extends StatefulWidget {
  const _DisposeOnUnmount({required this.container, required this.child});

  final ProviderContainer? container;
  final Widget child;

  @override
  State<_DisposeOnUnmount> createState() => _DisposeOnUnmountState();
}

class _DisposeOnUnmountState extends State<_DisposeOnUnmount> {
  @override
  void dispose() {
    widget.container?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
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
