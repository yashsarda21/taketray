import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'tag_player_muted.g.dart';

/// Whether the tag player's sound is off (D-96). It **starts muted** (the
/// design prompt, §6.3: "muted by default, with an unmute control"), and the
/// choice is kept for the app session: the next clip, and the next time the
/// player opens, sound the same. Not stored; a restart starts
/// muted again. The clip viewer has its own switch (`ViewerMuted`, D-89).
@Riverpod(keepAlive: true)
class TagPlayerMuted extends _$TagPlayerMuted {
  @override
  bool build() => true;

  /// Mutes, or unmutes.
  void toggle() => state = !state;
}
