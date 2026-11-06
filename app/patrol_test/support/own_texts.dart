/// The only texts the on-device tests look for in the notification shade:
/// TakeTray's own notification copy, word for word as `strings.xml` writes
/// it (the phone rule: only TakeTray's own notifications, by their own text).
///
/// The shade helpers (`shade.dart`) take an [OwnText], never a free string,
/// and match it exactly ([matches]), never as a part of a longer text: a
/// loose "new clip" could match another app's notification. `shade_test.dart`
/// checks every value against `strings.xml`.
final class OwnText {
  const OwnText._(this.value);

  /// The new-clips title, "{n} new clips to tag" (one: "1 new clip to tag").
  factory OwnText.newClips(int n) {
    _checkCount(n);
    return OwnText._(n == 1 ? '1 new clip to tag' : '$n new clips to tag');
  }

  /// The evening reminder's title, "You shot {n} clips today. Tag them?"
  /// (one: "You shot 1 clip today. Tag it?").
  factory OwnText.evening(int n) {
    _checkCount(n);
    return OwnText._(
      n == 1
          ? 'You shot 1 clip today. Tag it?'
          : 'You shot $n clips today. Tag them?',
    );
  }

  /// The whole text of the Still shooting? notification.
  static const stillBody = OwnText._(
    'Shooting mode has been on for 14 days. Turn it off?',
  );

  /// The exact text.
  final String value;

  /// Whether a view's [text] is exactly this text.
  bool matches(String? text) => text == value;

  static void _checkCount(int n) {
    if (n < 1) {
      throw ArgumentError.value(n, 'n', 'a notification counts 1 or more');
    }
  }
}

/// The two buttons of TakeTray's Still shooting? notification. Their labels
/// are not TakeTray's alone, so they are only ever tapped through the
/// geometry guard (`shade_geometry.dart`), next to each other ([sibling]).
enum StillButton {
  turnOff('Turn off'),
  keepOn('Keep on');

  StillButton(this.label);

  /// The exact label.
  final String label;

  /// The other button on the same row.
  StillButton get sibling => this == turnOff ? keepOn : turnOff;
}
