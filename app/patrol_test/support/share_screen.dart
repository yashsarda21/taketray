import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'system_dialogs.dart';

/// Driving the share screen (Phase 9B Task 8, D-169).
///
/// The share screen runs in a **second Flutter engine** (`shareMain`, D-163),
/// so Patrol's widget finders (`$(...)`), which look inside the app's own
/// engine, cannot see it. What can is Android's own accessibility tree
/// (UiAutomator), where Flutter publishes each widget's words. This file finds
/// and taps those nodes **by their words**, nothing else: no coordinates, no
/// Back (Back closes the sheet), no tap on a view the test did not name.
///
/// Flutter puts a widget's words in a node's `text` on some Android versions
/// and in its `contentDescription` on others, so every lookup tries both. The
/// words are the app's own strings (`AppLocalizations`) and the names of the
/// test's own reels, never a shared link or caption (D-10): they are printed
/// in failure messages, and nothing else from the screen is.
///
/// **Fragile on purpose-built ground.** Whether UiAutomator sees the second
/// engine's nodes, and under which of the two attributes, is first known on
/// the S24. Every wait therefore fails with a description of what it was
/// waiting for and the resource ids and classes on the screen (never text).
///
/// The Android side is behind [NativeScreen], so the waits, the tries and the
/// rule about what [ShareScreen.closeIfOpen] may tap are unit-tested without a
/// phone (`test/patrol_support/share_screen_test.dart`).
abstract interface class NativeScreen {
  /// How many views match [selector] now (0 when none, or when the screen
  /// cannot answer: Patrol reports "nothing matches" in different ways).
  Future<int> count(AndroidSelector selector);

  /// Taps the first view that matches [selector].
  Future<void> tap(AndroidSelector selector);

  /// Puts [text] in the [index]-th visible text field, without showing or
  /// dismissing the keyboard (see [PatrolNativeScreen.enterTextByIndex]).
  Future<void> enterTextByIndex(String text, {required int index});

  /// The resource ids and classes on the screen, for a failure message. No
  /// text, no content descriptions.
  Future<String> describe();
}

/// [NativeScreen] over Patrol's Android automator.
class PatrolNativeScreen implements NativeScreen {
  /// Drives the phone through [_patrol].
  PatrolNativeScreen(this._patrol);

  final PatrolIntegrationTester _patrol;

  @override
  Future<int> count(AndroidSelector selector) async {
    try {
      final response = await _patrol.platform.android.getNativeViews(selector);
      var found = 0;
      void walk(AndroidNativeView view) {
        found++;
        view.children.forEach(walk);
      }

      response.roots.forEach(walk);
      return found;
    } on Object {
      // "Nothing matches" is reported as an error by some Patrol versions; a
      // screen that cannot be read at all fails in the wait, with its ids.
      return 0;
    }
  }

  @override
  Future<void> tap(AndroidSelector selector) =>
      _patrol.platform.android.tap(selector, timeout: _tapTimeout);

  /// `KeyboardBehavior.alternative`, never the default: the default closes
  /// the keyboard afterwards by pressing Back, and Back, with no keyboard up,
  /// reaches the share screen and closes it.
  @override
  Future<void> enterTextByIndex(String text, {required int index}) =>
      _patrol.platform.android.enterTextByIndex(
        text,
        index: index,
        keyboardBehavior: KeyboardBehavior.alternative,
        timeout: _tapTimeout,
      );

  @override
  Future<String> describe() => describeNativeScreen(_patrol);
}

const Duration _tapTimeout = Duration(seconds: 10);

/// The two ways a node can carry [words]: its text, or its content
/// description. With [contains] the words need only be part of them (a row
/// reads "{name}, {count}"); otherwise they must be all of them. With
/// [enabled] the node must also be enabled: a disabled Save button has the
/// same words as an enabled one, and a tap on it does nothing.
List<AndroidSelector> selectorsFor(
  String words, {
  bool contains = false,
  bool enabled = false,
}) {
  final only = enabled ? true : null;
  if (contains) {
    return [
      AndroidSelector(textContains: words, isEnabled: only),
      AndroidSelector(contentDescriptionContains: words, isEnabled: only),
    ];
  }
  return [
    AndroidSelector(text: words, isEnabled: only),
    AndroidSelector(contentDescription: words, isEnabled: only),
  ];
}

/// The class Flutter gives a text field's node.
const AndroidSelector textFieldSelector = AndroidSelector(
  className: 'android.widget.EditText',
);

/// The share screen, as UiAutomator sees it.
class ShareScreen {
  /// A share screen driven through [_native]. [poll] is the pause between
  /// looks.
  ShareScreen(this._native, {this.poll = const Duration(milliseconds: 500)});

  final NativeScreen _native;

  /// The pause between two looks.
  final Duration poll;

  /// How long the share screen's own engine may take to come up and draw.
  static const Duration engineStart = Duration(seconds: 40);

  /// How long a change on the screen that is already up may take.
  static const Duration change = Duration(seconds: 20);

  /// The selector (text first, then description) that finds [words] now, or
  /// null when neither does.
  Future<AndroidSelector?> find(
    String words, {
    bool contains = false,
    bool enabled = false,
  }) async {
    for (final selector in selectorsFor(
      words,
      contains: contains,
      enabled: enabled,
    )) {
      if (await _native.count(selector) > 0) return selector;
    }
    return null;
  }

  /// Whether [words] is on the screen now.
  Future<bool> isShown(
    String words, {
    bool contains = false,
    bool enabled = false,
  }) async => await find(words, contains: contains, enabled: enabled) != null;

  /// Waits until [words] is on the screen. Fails, saying [what], when it is
  /// not there after [timeout].
  Future<AndroidSelector> waitFor(
    String words, {
    required String what,
    bool contains = false,
    bool enabled = false,
    Duration timeout = change,
  }) async {
    final end = DateTime.now().add(timeout);
    while (true) {
      final found = await find(words, contains: contains, enabled: enabled);
      if (found != null) return found;
      if (DateTime.now().isAfter(end)) {
        throw TestFailure(
          await _timedOut(timeout, 'the share screen to show', what),
        );
      }
      await Future<void>.delayed(poll);
    }
  }

  /// Waits until [words] is **not** on the screen. For use after something
  /// that proves the screen was there (a [waitFor] on it), so the wait ends
  /// because it went and not because it never came.
  Future<void> waitGone(
    String words, {
    required String what,
    bool contains = false,
    Duration timeout = change,
  }) async {
    final end = DateTime.now().add(timeout);
    while (await find(words, contains: contains) != null) {
      if (DateTime.now().isAfter(end)) {
        throw TestFailure(
          await _timedOut(timeout, 'the share screen to lose', what),
        );
      }
      await Future<void>.delayed(poll);
    }
  }

  /// Waits for [words], then taps it. Fails, saying [what], when it never
  /// shows.
  Future<void> tap(
    String words, {
    required String what,
    bool contains = false,
    bool enabled = false,
    Duration timeout = change,
  }) async {
    final selector = await waitFor(
      words,
      what: what,
      contains: contains,
      enabled: enabled,
      timeout: timeout,
    );
    await _native.tap(selector);
  }

  /// Types [text] in the text field at [index] (0 is the first on the
  /// screen), once at least `index + 1` fields are there.
  Future<void> enterText(
    String text, {
    required int index,
    required String what,
    Duration timeout = change,
  }) async {
    final end = DateTime.now().add(timeout);
    while (await _native.count(textFieldSelector) <= index) {
      if (DateTime.now().isAfter(end)) {
        throw TestFailure(
          await _timedOut(
            timeout,
            'the share screen to show a text field',
            what,
          ),
        );
      }
      await Future<void>.delayed(poll);
    }
    await _native.enterTextByIndex(text, index: index);
  }

  /// Closes the share screen if one is open, for a flow's tear-down. [states]
  /// are the screen's three states, each with the words that only it shows
  /// and the button that closes it (the form's Cancel, "not a link"'s Close,
  /// the saved state's Done).
  ///
  /// Taps nothing when none of the titles is on the screen: the app's own
  /// screens have buttons with the same names, and they are never touched.
  /// Returns whether it closed one.
  Future<bool> closeIfOpen(
    List<ShareState> states, {
    Duration buttonTimeout = const Duration(seconds: 10),
  }) async {
    var closed = false;
    // Never more rounds than states: one share can show them one after the
    // other (a form that was saved while the tear-down looked).
    for (var round = 0; round < states.length; round++) {
      ShareState? open;
      for (final state in states) {
        if (await isShown(state.title, contains: state.titleContains)) {
          open = state;
          break;
        }
      }
      if (open == null) return closed;
      await tap(
        open.button,
        what: 'the button that closes a share screen left open',
        timeout: buttonTimeout,
      );
      closed = true;
      await Future<void>.delayed(poll);
    }
    return closed;
  }

  Future<String> _timedOut(
    Duration timeout,
    String waiting,
    String what,
  ) async {
    var ids = '(not readable)';
    try {
      ids = await _native.describe();
    } on Object {
      // The message is for a person; it needs no more than this.
    }
    return 'Timed out after ${timeout.inSeconds} s waiting for $waiting: '
        '$what. Resource ids and classes on the screen: $ids';
  }
}

/// One state of the share screen: [title] is on the screen only in this
/// state (a part of it with [titleContains]), and [button] closes it.
class ShareState {
  /// A state with its title and its closing button.
  const ShareState({
    required this.title,
    required this.button,
    this.titleContains = false,
  });

  /// The words only this state shows.
  final String title;

  /// Whether [title] is only part of the node's words.
  final bool titleContains;

  /// The words of the button that closes this state.
  final String button;
}
