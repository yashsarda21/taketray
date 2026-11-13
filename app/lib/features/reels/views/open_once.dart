import 'dart:async';

import 'package:flutter/material.dart';

/// How long a tap that opened a page keeps the others out: long enough for
/// the new page to be built and to cover the old one (after that the old
/// page cannot be tapped), short enough that nothing waits on it.
final Duration _settle = kThemeAnimationDuration * 2;

/// Opens one page at a time from a screen (D-86, D-87): a second tap in the
/// same frame, or while the page that the first one opened is arriving, does
/// nothing, so a double tap pushes one route.
///
/// The guard is a short window, **not** the push's future: go_router
/// completes that future only on a pop, and a `go` that takes the page away
/// (deleting a reel goes to Reels; the viewer's fallback goes back to the
/// reel) never completes it, which would block every later tap. Call
/// [dispose] from the owner's `dispose`, so no timer outlives the screen.
class OpenOnce {
  Timer? _window;

  /// A slow open ([openSlow]) has not reached its push yet.
  bool _waiting = false;

  /// Whether a page was opened a moment ago, or one is being prepared.
  bool get busy => _window != null || _waiting;

  /// Calls [push] unless a page was opened less than the window ago.
  void open(Future<Object?> Function() push) {
    if (busy) return;
    _window = Timer(_settle, () => _window = null);
    unawaited(push());
  }

  /// Like [open], for an open that waits on something slow (a call to the
  /// phone) before it pushes the page: the window is shut for the whole wait,
  /// and then for the usual window from the push, so a second tap while the
  /// call runs, or while the page arrives, does nothing.
  ///
  /// [open] is given `pushing`, which it calls just before it pushes the
  /// page; a later call does nothing. If [open] ends or throws without
  /// having called it (nothing opened), the window is released then, at once.
  void openSlow(Future<void> Function(VoidCallback pushing) open) {
    if (busy) return;
    _waiting = true;
    void pushing() {
      if (!_waiting) return;
      _waiting = false;
      _window = Timer(_settle, () => _window = null);
    }

    unawaited(open(pushing).whenComplete(() => _waiting = false));
  }

  /// Cancels the window.
  void dispose() {
    _waiting = false;
    _window?.cancel();
    _window = null;
  }
}
