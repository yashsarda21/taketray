import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'choosing_reel.g.dart';

/// The reel whose page is choosing clips, if any: AppShell shows its dock in
/// place of the nav pill (D-191).
///
/// The reel's page says so: [show] while its selection is choosing, [hide]
/// when choosing ends or the page goes. Neither is called while a widget
/// builds (a provider must not change then): the page calls them from a
/// listener on its selection, and after a frame.
@Riverpod(keepAlive: true)
class ChoosingReel extends _$ChoosingReel {
  @override
  int? build() => null;

  /// Reel [reelId]'s page is choosing clips.
  // ignore: use_setters_to_change_properties, show and hide are a pair of calls
  void show(int reelId) => state = reelId;

  /// Reel [reelId]'s page is no longer choosing (or is gone). Nothing
  /// happens when another reel is the one shown, so a page that goes never
  /// takes away the dock of the page that came after it. Nothing happens
  /// either once the app is gone (the page hides after its last frame).
  void hide(int reelId) {
    if (!ref.mounted || state != reelId) return;
    state = null;
  }
}
