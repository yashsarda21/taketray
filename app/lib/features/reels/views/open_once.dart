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

  /// Whether a page was opened a moment ago.
  bool get busy => _window != null;

  /// Calls [push] unless a page was opened less than the window ago.
  void open(Future<Object?> Function() push) {
    if (_window != null) return;
    _window = Timer(_settle, () => _window = null);
    unawaited(push());
  }

  /// Cancels the window.
  void dispose() {
    _window?.cancel();
    _window = null;
  }
}
