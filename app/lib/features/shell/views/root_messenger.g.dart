// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'root_messenger.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The key of the app's one root `ScaffoldMessenger` (D-85): the one
/// `MaterialApp.router` creates, handed over by `TakeTrayApp`.
///
/// Snacks that must outlive the screen that raised them (the Undo after a
/// reel delete goes back to Reels; "{name} created" is shown after its sheet
/// has closed) are shown on this messenger. A snack shown on the messenger of
/// the screen's own `Scaffold` would go with that screen when it pops. A
/// provider, not a global, so that each `ProviderScope` (every test) has its
/// own key.

@ProviderFor(rootMessengerKey)
final rootMessengerKeyProvider = RootMessengerKeyProvider._();

/// The key of the app's one root `ScaffoldMessenger` (D-85): the one
/// `MaterialApp.router` creates, handed over by `TakeTrayApp`.
///
/// Snacks that must outlive the screen that raised them (the Undo after a
/// reel delete goes back to Reels; "{name} created" is shown after its sheet
/// has closed) are shown on this messenger. A snack shown on the messenger of
/// the screen's own `Scaffold` would go with that screen when it pops. A
/// provider, not a global, so that each `ProviderScope` (every test) has its
/// own key.

final class RootMessengerKeyProvider
    extends
        $FunctionalProvider<
          GlobalKey<ScaffoldMessengerState>,
          GlobalKey<ScaffoldMessengerState>,
          GlobalKey<ScaffoldMessengerState>
        >
    with $Provider<GlobalKey<ScaffoldMessengerState>> {
  /// The key of the app's one root `ScaffoldMessenger` (D-85): the one
  /// `MaterialApp.router` creates, handed over by `TakeTrayApp`.
  ///
  /// Snacks that must outlive the screen that raised them (the Undo after a
  /// reel delete goes back to Reels; "{name} created" is shown after its sheet
  /// has closed) are shown on this messenger. A snack shown on the messenger of
  /// the screen's own `Scaffold` would go with that screen when it pops. A
  /// provider, not a global, so that each `ProviderScope` (every test) has its
  /// own key.
  RootMessengerKeyProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'rootMessengerKeyProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$rootMessengerKeyHash();

  @$internal
  @override
  $ProviderElement<GlobalKey<ScaffoldMessengerState>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  GlobalKey<ScaffoldMessengerState> create(Ref ref) {
    return rootMessengerKey(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GlobalKey<ScaffoldMessengerState> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GlobalKey<ScaffoldMessengerState>>(
        value,
      ),
    );
  }
}

String _$rootMessengerKeyHash() => r'f203d5c135d2fab53b5ffd8e5ccd9b416833234f';
