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
  /// How many views match [selector] now: 0 when none match, however Patrol
  /// says so ([isNoMatch]). A screen that cannot be read at all (a dead
  /// UiAutomator) is an error, never 0: an "absent" check must not pass
  /// because nothing could be seen.
  Future<int> count(AndroidSelector selector);

  /// The top and bottom edge, in pixels, of the first view that matches
  /// [selector], or null when none does.
  Future<({double top, double bottom})?> boundsOf(AndroidSelector selector);

  /// The top edge, in pixels, of the on-screen keyboard, or null when none
  /// is shown (or none could be recognised, see [keyboardTopOf]).
  Future<double?> keyboardTop();

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
  Future<int> count(AndroidSelector selector) => countMatching(() async {
    final response = await _patrol.platform.android.getNativeViews(selector);
    var found = 0;
    void walk(AndroidNativeView view) {
      found++;
      view.children.forEach(walk);
    }

    response.roots.forEach(walk);
    return found;
  });

  @override
  Future<({double top, double bottom})?> boundsOf(
    AndroidSelector selector,
  ) async {
    final response = await _patrol.platform.android.getNativeViews(selector);
    if (response.roots.isEmpty) return null;
    final bounds = response.roots.first.visibleBounds;
    return (top: bounds.minY, bottom: bounds.maxY);
  }

  @override
  Future<double?> keyboardTop() async {
    final response = await _patrol.platform.android.getNativeViews(null);
    final nodes = <({String? package, double top})>[];
    void walk(AndroidNativeView view) {
      nodes.add((
        package: view.applicationPackage,
        top: view.visibleBounds.minY,
      ));
      view.children.forEach(walk);
    }

    response.roots.forEach(walk);
    return keyboardTopOf(nodes, appPackage: _appPackage);
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

/// The app the share screen belongs to (the debug flavour the Patrol flows
/// run, never `app.taketray`).
const String _appPackage = 'app.taketray.dev';

/// Runs [read], a count of the views that match a selector. "Nothing
/// matches" ([isNoMatch]) is 0; any other error (a dead UiAutomator, a lost
/// connection) is rethrown, so a check that something is absent can never
/// pass only because the screen could not be read.
Future<int> countMatching(Future<int> Function() read) async {
  try {
    return await read();
  } on Object catch (error) {
    if (isNoMatch(error)) return 0;
    rethrow;
  }
}

/// Whether [error] is Patrol saying that a selector found nothing, in the
/// exact words of Patrol 4.10: its automator server answers a
/// `UiObjectNotFoundException` with a 404 and the body
/// `selector <it> found nothing` (`PatrolServerFilters.kt`), and the client
/// puts the call's name and `Invalid response: 404 ` in front of it
/// (`wrapRequest`). The exception's own name never reaches Dart. Nothing
/// looser counts: a missing package, a missing instrumentation, another 404
/// or a failure whose stack trace happens to say "found nothing" is an error,
/// not an empty screen.
bool isNoMatch(Object error) =>
    error is PatrolActionException &&
    RegExp(
      r'^MobileAutomatorClientException: \w+\(\) failed with '
      r'Invalid response: 404 selector [\s\S]* found nothing$',
    ).hasMatch(error.message);

/// The top edge of the on-screen keyboard among [nodes] (every view of every
/// window, with its package and top edge), or null when none is recognised.
///
/// The keyboard is another app's window that does not start at the top of the
/// screen: not [appPackage]'s (the share screen), not the system's bars, and
/// not a full-screen app behind a see-through share (its window starts at 0).
/// Best effort, and written without a phone: when it recognises nothing the
/// flows still tap, and a tap the keyboard took shows as the sheet that never
/// saved.
double? keyboardTopOf(
  Iterable<({String? package, double top})> nodes, {
  required String appPackage,
}) {
  double? top;
  for (final node in nodes) {
    final package = node.package;
    if (package == null ||
        package == appPackage ||
        package == 'android' ||
        package == 'com.android.systemui' ||
        node.top <= 0) {
      continue;
    }
    if (top == null || node.top < top) top = node.top;
  }
  return top;
}

/// How far, in pixels, a button may reach into the keyboard's top edge and
/// still be tapped (rounding of the two windows' bounds).
const double _keyboardTolerance = 2;

/// The two ways a node can carry [words]: its text, or its content
/// description. With [contains] the words need only be part of them (a row
/// reads "{name}, {count}"); otherwise they must be all of them. With
/// [enabled] the node must also be enabled: a disabled Save button has the
/// same words as an enabled one, and a tap on it does nothing.
///
/// With [package] only nodes of that app match: another app's "Done" has the
/// same words as ours.
List<AndroidSelector> selectorsFor(
  String words, {
  bool contains = false,
  bool enabled = false,
  String? package,
}) {
  final only = enabled ? true : null;
  if (contains) {
    return [
      AndroidSelector(
        textContains: words,
        isEnabled: only,
        applicationPackage: package,
      ),
      AndroidSelector(
        contentDescriptionContains: words,
        isEnabled: only,
        applicationPackage: package,
      ),
    ];
  }
  return [
    AndroidSelector(text: words, isEnabled: only, applicationPackage: package),
    AndroidSelector(
      contentDescription: words,
      isEnabled: only,
      applicationPackage: package,
    ),
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
  ShareScreen(
    this._native, {
    this.poll = const Duration(milliseconds: 500),
    this.appPackage = _appPackage,
  });

  final NativeScreen _native;

  /// The app that owns the share screen: every lookup, wait and tap uses
  /// only nodes of this package (unless a call names another).
  final String appPackage;

  /// The pause between two looks.
  final Duration poll;

  /// How long the share screen's own engine may take to come up and draw.
  static const Duration engineStart = Duration(seconds: 40);

  /// How long a change on the screen that is already up may take.
  static const Duration change = Duration(seconds: 20);

  /// The selector (text first, then description) that finds [words] now, or
  /// null when neither does.
  ///
  /// Only nodes of [package] match, which is [appPackage] unless given: every
  /// node the flows look at, wait for or tap is the share screen's own, and
  /// another app's "Done" or "Save" has the same words. Every other lookup
  /// ([isShown], [waitFor], [waitGone], [tap], [tapSave]) goes through here.
  Future<AndroidSelector?> find(
    String words, {
    bool contains = false,
    bool enabled = false,
    String? package,
  }) async {
    for (final selector in selectorsFor(
      words,
      contains: contains,
      enabled: enabled,
      package: package ?? appPackage,
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
    String? package,
  }) async =>
      await find(
        words,
        contains: contains,
        enabled: enabled,
        package: package,
      ) !=
      null;

  /// Waits until [words] is on the screen. Fails, saying [what], when it is
  /// not there after [timeout].
  Future<AndroidSelector> waitFor(
    String words, {
    required String what,
    bool contains = false,
    bool enabled = false,
    String? package,
    Duration timeout = change,
  }) async {
    final end = DateTime.now().add(timeout);
    while (true) {
      final found = await find(
        words,
        contains: contains,
        enabled: enabled,
        package: package,
      );
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
    String? package,
    Duration timeout = change,
  }) async {
    final selector = await waitFor(
      words,
      what: what,
      contains: contains,
      enabled: enabled,
      package: package,
      timeout: timeout,
    );
    await _native.tap(selector);
  }

  /// Waits for the enabled Save button, checks that the keyboard is not over
  /// it, and taps it. The keyboard stays up while a name is typed (Back would
  /// close the sheet), and a tap on a button under it would land on the
  /// keyboard and be mistaken for a Save that did nothing: so a Save whose
  /// bottom edge is lower than the keyboard's top fails here, naming both,
  /// and nothing is tapped. When the bounds or the keyboard cannot be read it
  /// taps (the flow's next wait then tells whether it worked).
  Future<void> tapSave(
    String words, {
    required String what,
    Duration timeout = change,
  }) async {
    final selector = await waitFor(
      words,
      what: what,
      enabled: true,
      timeout: timeout,
    );
    final bounds = await _native.boundsOf(selector);
    final keyboard = await _native.keyboardTop();
    if (bounds != null &&
        keyboard != null &&
        bounds.bottom > keyboard + _keyboardTolerance) {
      throw TestFailure(
        'Not tapping $what: the keyboard is over it (its bottom edge is at '
        '${bounds.bottom.round()} px, the keyboard starts at '
        '${keyboard.round()} px). Nothing was tapped.',
      );
    }
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
  /// Only nodes of [appPackage] count, so another app's "Done" or "Close" is
  /// never tapped.
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
        if (await isShown(
          state.title,
          contains: state.titleContains,
          package: appPackage,
        )) {
          open = state;
          break;
        }
      }
      if (open == null) return closed;
      await tap(
        open.button,
        what: 'the button that closes a share screen left open',
        package: appPackage,
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
