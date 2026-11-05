import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'popup_route_tracker.g.dart';

/// Which popup routes are open anywhere in the app: a bottom sheet
/// (`showTtSheet`), a dialog (`showTtDialog`), or any other `PopupRoute`.
///
/// A popup is pushed on a `Navigator` and does not cover the screen under
/// it: that screen's route is still the current one of its own navigator, and
/// its tickers stay on. The only way to know a popup is open is to watch the
/// navigators, so every navigator of the app gets an observer from
/// [observerForNavigator] (the root one and each tab's). [isOpen] is true
/// while at least one popup route is open, and listeners hear each change.
///
/// Used by the "Still shooting?" dialog (D-107), which must never open over a
/// sheet or a dialog. A menu (`TtMenuButton`, a `MenuAnchor`) is an overlay,
/// not a route, and is not seen here; the menus that exist are on pages that
/// cover Reels (To tag, a reel's page), which the route checks already catch.
class PopupRouteTracker extends ChangeNotifier {
  final Set<Route<dynamic>> _open = {};

  /// Whether a popup route is open on any observed navigator.
  bool get isOpen => _open.isNotEmpty;

  /// An observer for one navigator. A navigator needs its own: Flutter does
  /// not let one observer watch two.
  // Each call makes a new observer; it is not a conversion of the tracker.
  // ignore: use_to_and_as_if_applicable
  NavigatorObserver observerForNavigator() => _PopupObserver(this);

  void _add(Route<dynamic>? route) {
    if (route is PopupRoute && _open.add(route)) notifyListeners();
  }

  void _remove(Route<dynamic>? route) {
    if (route != null && _open.remove(route)) notifyListeners();
  }
}

class _PopupObserver extends NavigatorObserver {
  _PopupObserver(this._tracker);

  final PopupRouteTracker _tracker;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _tracker._add(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _tracker._remove(route);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _tracker._remove(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _tracker
      .._remove(oldRoute)
      .._add(newRoute);
  }
}

/// The one [PopupRouteTracker] of the app.
@Riverpod(keepAlive: true)
PopupRouteTracker popupRouteTracker(Ref ref) {
  final tracker = PopupRouteTracker();
  ref.onDispose(tracker.dispose);
  return tracker;
}
