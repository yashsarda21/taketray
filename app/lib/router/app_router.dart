import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/data/media/add_videos_service.dart';
import 'package:taketray/features/add_videos/views/add_folders_screen.dart';
import 'package:taketray/features/add_videos/views/add_grid_screen.dart';
import 'package:taketray/features/notifications/views/notifications_help_screen.dart';
import 'package:taketray/features/reels/views/clip_viewer_screen.dart';
import 'package:taketray/features/reels/views/reel_detail_screen.dart';
import 'package:taketray/features/reels/views/reels_screen.dart';
import 'package:taketray/features/settings/views/settings_screen.dart';
import 'package:taketray/features/shell/views/app_shell.dart';
import 'package:taketray/features/tagging/views/skipped_screen.dart';
import 'package:taketray/features/tagging/views/tag_player_screen.dart';
import 'package:taketray/features/tagging/views/to_tag_screen.dart';
import 'package:taketray/router/popup_route_tracker.dart';
import 'package:taketray/router/routes.dart';

part 'app_router.g.dart';

final Logger _log = Logger('router');

/// The id in the path parameter [name], or null when it is not a positive
/// whole number.
int? _id(GoRouterState state, String name) {
  final id = int.tryParse(state.pathParameters[name] ?? '');
  return id != null && id > 0 ? id : null;
}

/// [text] as a positive whole number, or null.
int? _positive(String? text) {
  final id = int.tryParse(text ?? '');
  return id != null && id > 0 ? id : null;
}

/// The reel id of a reel location, or null when it is not a positive whole
/// number.
int? _reelId(GoRouterState state) => _id(state, Routes.reelIdParameter);

/// The app's router: three tabs, each with its own navigation stack.
///
/// Kept alive so the navigation state survives when nothing is watching for a
/// frame.
@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  // The navigator above the tab shell. A full-screen route (the clip viewer)
  // names it as its `parentNavigatorKey` to be drawn over the shell, with no
  // nav pill. One key for each router, so two apps never share one.
  final rootNavigatorKey = GlobalKey<NavigatorState>(
    debugLabel: 'root navigator',
  );
  // Sheets and dialogs are pushed on the root navigator, a `PopupRoute`
  // inside a tab on that tab's own; every navigator gets its own observer.
  final popups = ref.read(popupRouteTrackerProvider);
  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    observers: [popups.observerForNavigator()],
    initialLocation: Routes.reels,
    // Any location no route matches (an old deep link, `/reels/stale`, a
    // typo) goes to Reels instead of go_router's error page. The location is
    // not logged: it can carry user data.
    onException: (context, state, router) {
      _log.warning('Unknown location; showing Reels');
      router.go(Routes.reels);
    },
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            observers: [popups.observerForNavigator()],
            routes: [
              GoRoute(
                path: Routes.reels,
                builder: (context, state) => const ReelsScreen(),
                routes: [
                  GoRoute(
                    path: ':${Routes.reelIdParameter}',
                    // A reel's id is a positive whole number; anything else
                    // is as unknown as a location no route matches.
                    redirect: (context, state) {
                      if (_reelId(state) != null) return null;
                      _log.warning('Unknown location; showing Reels');
                      return Routes.reels;
                    },
                    builder: (context, state) =>
                        ReelDetailScreen(reelId: _reelId(state)!),
                    routes: [
                      GoRoute(
                        path: 'clip/:${Routes.clipIdParameter}',
                        // Full screen, above the shell and its nav pill (D-89).
                        // The reel's page stays under it in the tab, so Back
                        // returns to it.
                        parentNavigatorKey: rootNavigatorKey,
                        // Like a reel's id, a clip's is a positive whole
                        // number; anything else is unknown.
                        redirect: (context, state) {
                          if (_id(state, Routes.clipIdParameter) != null) {
                            return null;
                          }
                          _log.warning('Unknown location; showing Reels');
                          return Routes.reels;
                        },
                        builder: (context, state) => ClipViewerScreen(
                          reelId: _reelId(state)!,
                          clipId: _id(state, Routes.clipIdParameter)!,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            observers: [popups.observerForNavigator()],
            routes: [
              GoRoute(
                path: Routes.toTag,
                builder: (context, state) => const ToTagScreen(),
                routes: [
                  GoRoute(
                    path: 'skipped',
                    builder: (context, state) => const SkippedScreen(),
                  ),
                  GoRoute(
                    path: 'play',
                    // Full screen, above the shell and its nav pill, like
                    // the clip viewer (D-89, D-97). To tag stays under it in
                    // the tab, so Back returns to it.
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => TagPlayerScreen(
                      // A start that is not a positive whole number is as
                      // good as none: the first waiting clip.
                      startClipId: _positive(
                        state.uri.queryParameters[Routes.tagFromParameter],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            observers: [popups.observerForNavigator()],
            routes: [
              GoRoute(
                path: Routes.settings,
                builder: (context, state) => const SettingsScreen(),
                routes: [
                  GoRoute(
                    path: 'notifications-help',
                    // Full screen, above the shell and its nav pill, like the
                    // tag player (D-107); Settings stays under it in the tab,
                    // so Back returns to it.
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) =>
                        const NotificationsHelpScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      addVideosRoute(),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
}

/// The target of an Add videos location: To tag without
/// [Routes.addVideosReelParameter], the reel it names otherwise. Null when it
/// names no reel (not a positive whole number), which is as unknown as a
/// location no route matches.
AddTarget? _addTarget(GoRouterState state) {
  final reel = state.uri.queryParameters[Routes.addVideosReelParameter];
  if (reel == null) return const AddToToTag();
  final id = _positive(reel);
  return id == null ? null : AddToReel(id);
}

/// Sends a bad Add videos location to Reels. The location is not logged: it
/// can carry a folder's path (D-10).
String? _badAddVideos(GoRouterState state) {
  final grid = state.matchedLocation == Routes.addVideosFolder;
  final volume = state.uri.queryParameters[Routes.addVideosVolumeParameter];
  if (_addTarget(state) != null &&
      (!grid || (volume != null && volume.isNotEmpty))) {
    return null;
  }
  _log.warning('Unknown location; showing Reels');
  return Routes.reels;
}

/// Add videos (Phase 7, D-114): the folder list at [Routes.addVideos] and
/// the grid of one folder at [Routes.addVideosFolder] above it. Both are
/// full screen, on the root navigator (a top-level route), above the tab
/// shell and its nav pill; the page that opened them stays under them, so
/// Back, and an add, return there.
GoRoute addVideosRoute() => GoRoute(
  path: Routes.addVideos,
  redirect: (context, state) => _badAddVideos(state),
  builder: (context, state) => AddFoldersScreen(target: _addTarget(state)!),
  routes: [
    GoRoute(
      path: 'folder',
      redirect: (context, state) => _badAddVideos(state),
      builder: (context, state) => AddGridScreen(
        target: _addTarget(state)!,
        volumeName: state.uri.queryParameters[Routes.addVideosVolumeParameter]!,
        relativePath:
            state.uri.queryParameters[Routes.addVideosPathParameter] ?? '',
      ),
    ),
  ],
);
