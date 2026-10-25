import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/features/reels/views/reels_placeholder_screen.dart';
import 'package:taketray/features/settings/views/settings_placeholder_screen.dart';
import 'package:taketray/features/shell/views/app_shell.dart';
import 'package:taketray/features/tagging/views/to_tag_placeholder_screen.dart';
import 'package:taketray/router/routes.dart';

part 'app_router.g.dart';

const List<String> _tabRoots = [Routes.reels, Routes.toTag, Routes.settings];

/// The app's router: three tabs, each with its own navigation stack.
///
/// Kept alive so the navigation state survives when nothing is watching for a
/// frame.
@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  final router = GoRouter(
    initialLocation: Routes.reels,
    redirect: (context, state) {
      final path = state.uri.path;
      final known = _tabRoots.any(
        (root) => path == root || path.startsWith('$root/'),
      );
      return known ? null : Routes.reels;
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
                builder: (context, state) => const ReelsPlaceholderScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.toTag,
                builder: (context, state) => const ToTagPlaceholderScreen(),
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
