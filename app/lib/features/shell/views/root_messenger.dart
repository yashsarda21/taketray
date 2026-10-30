import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'root_messenger.g.dart';

/// The key of the app's one root `ScaffoldMessenger` (D-85): the one
/// `MaterialApp.router` creates, handed over by `TakeTrayApp`.
///
/// Snacks that must outlive the screen that raised them (the Undo after a
/// reel delete goes back to Reels; "{name} created" is shown after its sheet
/// has closed) are shown on this messenger. A snack shown on the messenger of
/// the screen's own `Scaffold` would go with that screen when it pops. A
/// provider, not a global, so that each `ProviderScope` (every test) has its
/// own key.
@Riverpod(keepAlive: true)
GlobalKey<ScaffoldMessengerState> rootMessengerKey(Ref ref) =>
    GlobalKey<ScaffoldMessengerState>(debugLabel: 'root messenger');

/// The root messenger, looked up now so that it can be used after [context]
/// is gone. Falls back to the `ScaffoldMessenger` above [context] when the
/// app was not given the key (a test app that builds its own `MaterialApp`).
ScaffoldMessengerState rootMessengerOf(BuildContext context) {
  final key = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(rootMessengerKeyProvider);
  return key.currentState ?? ScaffoldMessenger.of(context);
}
