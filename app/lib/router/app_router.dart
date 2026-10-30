import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/features/reels/views/reel_detail_placeholder.dart';
import 'package:taketray/features/reels/views/reels_screen.dart';
import 'package:taketray/features/settings/views/settings_placeholder_screen.dart';
import 'package:taketray/features/shell/views/app_shell.dart';
import 'package:taketray/features/tagging/views/to_tag_screen.dart';
import 'package:taketray/router/routes.dart';

part 'app_router.g.dart';

final Logger _log = Logger('router');

/// The reel id of a reel location, or null when it is not a positive whole
/// number.
int? _reelId(GoRouterState state) {
  final id = int.tryParse(state.pathParameters[Routes.reelIdParameter] ?? '');
  return id != null && id > 0 ? id : null;
}

/// The app's router: three tabs, each with its own navigation stack.
///
/// Kept alive so the navigation state survives when nothing is watching for a
/// frame.
@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  final router = GoRouter(
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
                        ReelDetailPlaceholder(reelId: _reelId(state)!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.toTag,
                builder: (context, state) => const ToTagScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.settings,
                builder: (context, state) => const SettingsPlaceholderScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
}
