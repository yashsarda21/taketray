import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:taketray_ui/src/components/internal/blur_barrier.dart';
import 'package:taketray_ui/src/theme/tt_metrics.dart';

/// The route of an open `TtMenuButton` menu (D-176): a popup route whose
/// barrier blurs the whole page behind the menu by [TtMetrics.scrimBlur]
/// without dimming it, and whose page is the menu panel placed at the
/// [anchor] by [TtMenuLayout].
///
/// It pops `({T value})` when an item is chosen (a record, so a chosen value
/// of null is still told from a dismissal) and null when it is dismissed by
/// a tap outside the panel, Back, Escape or a change of the window's size.
///
/// Not exported: `TtMenuButton` pushes it on the root navigator.
class TtMenuRoute<T> extends PopupRoute<({T value})> {
  /// A menu route showing what [builder] builds next to [anchor], the menu
  /// button's rectangle in the navigator's overlay.
  new({
    required this.anchor,
    required this.textDirection,
    required this.themes,
    required this.barrierLabel,
    required this.builder,
  });

  /// The menu button's rectangle, in the navigator's coordinates.
  final Rect anchor;

  /// The text direction at the menu button: the panel opens towards the end
  /// of the button's line.
  final TextDirection textDirection;

  /// The themes of the menu button, so the panel is drawn with them (the
  /// navigator sits above them).
  final CapturedThemes themes;

  /// What the barrier says to a screen reader: "Dismiss menu".
  @override
  final String barrierLabel;

  /// The panel.
  final WidgetBuilder builder;

  // No dim: the design blurs the page behind an open menu and leaves its
  // light alone.
  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  // The menu appears and goes with no motion, as `MenuAnchor` had it, so the
  // blur is there from the first frame to the last (D-172).
  // style-check: allow MenuAnchor opened with no motion (D-176)
  @override
  Duration get transitionDuration => Duration.zero;

  // style-check: allow MenuAnchor opened with no motion (D-176)
  @override
  Duration get reverseTransitionDuration => Duration.zero;

  @override
  Widget buildModalBarrier() =>
      ttBlurredBarrier(barrier: super.buildModalBarrier());

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return Directionality(
      textDirection: textDirection,
      child: themes.wrap(
        _CloseOnResize(
          route: this,
          // The page is built once; the layout reads the media query inside
          // a Builder, so it follows the keyboard and the status bar.
          child: Builder(
            builder: (context) => FocusTraversalGroup(
              child: Shortcuts(
                shortcuts: const <ShortcutActivator, Intent>{
                  SingleActivator(LogicalKeyboardKey.arrowDown):
                      DirectionalFocusIntent(TraversalDirection.down),
                  SingleActivator(LogicalKeyboardKey.arrowUp):
                      DirectionalFocusIntent(TraversalDirection.up),
                },
                child: CustomSingleChildLayout(
                  delegate: TtMenuLayout(
                    anchor: anchor,
                    textDirection: textDirection,
                    mediaQuery: MediaQuery.of(context),
                  ),
                  // Named and scoped like Flutter's own popup menu, so TalkBack
                  // announces the menu and moves into it: the barrier hides the
                  // button it had focus on.
                  child: Semantics(
                    role: SemanticsRole.menu,
                    scopesRoute: true,
                    namesRoute: true,
                    explicitChildNodes: true,
                    label: MaterialLocalizations.of(context).popupMenuLabel,
                    child: builder(context),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Closes [route] without a selection when the window changes size (a turn of
/// the phone, a split screen), as `MenuAnchor` did: the anchor's rectangle is
/// no longer where it was.
class _CloseOnResize extends StatefulWidget {
  const new({required this.route, required this.child});

  final Route<dynamic> route;
  final Widget child;

  @override
  State<_CloseOnResize> createState() => _CloseOnResizeState();
}

class _CloseOnResizeState extends State<_CloseOnResize> {
  Size? _size;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final size = MediaQuery.sizeOf(context);
    final before = _size;
    _size = size;
    if (before != null && before != size) {
      final route = widget.route;
      // Not while building: the navigator cannot change in a build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (route.isActive) route.navigator?.removeRoute(route);
      });
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Where a menu opens: the same placement `MenuAnchor` gave a menu at
/// `AlignmentDirectional.bottomStart` (D-176).
///
/// - The panel's top-start corner sits at the anchor's bottom-start corner.
/// - When it does not fit below it flips above the anchor; when it fits
///   neither way it sits at the bottom of the safe area.
/// - Sideways it is moved just far enough to be inside the safe area.
/// - The safe area is the screen less the view padding (the status bar), the
///   keyboard, and any display feature (a fold), and the panel is at most
///   [TtMetrics.menuEdgeInset] smaller than it on each side.
class TtMenuLayout extends SingleChildLayoutDelegate {
  /// A layout for a panel next to [anchor].
  const new({
    required this.anchor,
    required this.textDirection,
    required this.mediaQuery,
  });

  /// The menu button's rectangle, in the overlay's coordinates.
  final Rect anchor;

  /// The side the panel opens towards: its start edge meets the anchor's.
  final TextDirection textDirection;

  /// The screen's padding, insets and display features.
  final MediaQueryData mediaQuery;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final inset = BoxConstraints.loose(constraints.biggest)
        .deflate(const EdgeInsets.all(TtMetrics.menuEdgeInset));
    // A panel taller than the safe area (large text, a phone turned
    // sideways) is as tall as the safe area, so it is on the screen all the
    // way down and scrolls (`TtMenuPanel`).
    final safe = mediaQuery.padding.deflateRect(
      mediaQuery.viewInsets.deflateRect(Offset.zero & constraints.biggest),
    );
    return inset.copyWith(
      maxHeight: inset.maxHeight < safe.height ? inset.maxHeight : safe.height,
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final overlay = mediaQuery.padding.deflateRect(
      mediaQuery.viewInsets.deflateRect(Offset.zero & size),
    );
    final screens = DisplayFeatureSubScreen.subScreensInBounds(
      overlay,
      DisplayFeatureSubScreen.avoidBounds(mediaQuery).toSet(),
    );
    var allowed = screens.first;
    for (final screen in screens) {
      if ((screen.center - anchor.center).distance <
          (allowed.center - anchor.center).distance) {
        allowed = screen;
      }
    }

    // The start edge of the panel on the start edge of the anchor.
    var x = switch (textDirection) {
      TextDirection.ltr => anchor.left,
      TextDirection.rtl => anchor.right - childSize.width,
    };
    var y = anchor.bottom;

    if (childSize.width >= allowed.width) {
      x = allowed.left;
    } else if (x < allowed.left) {
      x = allowed.left;
    } else if (x + childSize.width > allowed.right) {
      x = allowed.right - childSize.width;
    }

    bool offBottom(double y) => y + childSize.height > allowed.bottom;
    if (childSize.height >= allowed.height) {
      y = allowed.top;
    } else if (y < allowed.top) {
      y = offBottom(anchor.bottom) ? allowed.top : anchor.bottom;
    } else if (offBottom(y)) {
      final above = anchor.top - childSize.height;
      y = above >= allowed.top ? above : allowed.bottom - childSize.height;
    }
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(TtMenuLayout oldDelegate) =>
      anchor != oldDelegate.anchor ||
      textDirection != oldDelegate.textDirection ||
      mediaQuery != oldDelegate.mediaQuery;
}
