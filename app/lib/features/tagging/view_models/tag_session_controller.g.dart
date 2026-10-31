// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tag_session_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The real timer.

@ProviderFor(holdTimer)
final holdTimerProvider = HoldTimerProvider._();

/// The real timer.

final class HoldTimerProvider
    extends
        $FunctionalProvider<
          HoldTimerFactory,
          HoldTimerFactory,
          HoldTimerFactory
        >
    with $Provider<HoldTimerFactory> {
  /// The real timer.
  HoldTimerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'holdTimerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$holdTimerHash();

  @$internal
  @override
  $ProviderElement<HoldTimerFactory> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  HoldTimerFactory create(Ref ref) {
    return holdTimer(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(HoldTimerFactory value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<HoldTimerFactory>(value),
    );
  }
}

String _$holdTimerHash() => r'88563fd65b718b3c254db1da320230b546688440';

/// The tag player's session (D-96): the clips to tag, one at a time, and
/// what each tap does.
///
/// - **The session is fixed when the player opens:** the clips in To tag
///   then, in shooting order (`inShootingOrder`), starting at
///   `startClipId` (or the first). Clips that arrive later are not in it. A
///   clip that leaves To tag (tagged or skipped here or elsewhere, removed
///   by a verify) is passed over (`TagQueue`, D-95).
/// - **One action at a time, on the clip that was showing.** Every action
///   reads the clip's id and position **before** it awaits anything, and is
///   ignored while another runs (`busy`) or a chip is held. A chip tap holds
///   for [tagHold] ([tagHoldReduced] with reduced motion) and then tags; a
///   second tap in the hold does nothing, and closing the player in the
///   hold cancels it and tags nothing.
/// - **After a tag or a skip** it goes to `TagQueue.afterAction` (the next
///   waiting clip, else the first one from the start, else done), clears the
///   picks and keeps "Pick several" on.
/// - **Undo** waits for the action that is running, puts the records back in
///   one transaction and returns to that clip (owner ruling, D-91), also
///   after "All done!".
/// - **The clip showing leaving To tag** without this controller acting (a
///   verify, a tag from elsewhere, also during a hold) moves the player on,
///   as after an action. While a write runs, the action moves it instead.
/// - **A failure** leaves the clip showing, clears `busy` and is thrown to
///   the screen ("Something went wrong. Try again.").
///
/// Auto-disposes with the player's route.

@ProviderFor(TagSessionController)
final tagSessionControllerProvider = TagSessionControllerFamily._();

/// The tag player's session (D-96): the clips to tag, one at a time, and
/// what each tap does.
///
/// - **The session is fixed when the player opens:** the clips in To tag
///   then, in shooting order (`inShootingOrder`), starting at
///   `startClipId` (or the first). Clips that arrive later are not in it. A
///   clip that leaves To tag (tagged or skipped here or elsewhere, removed
///   by a verify) is passed over (`TagQueue`, D-95).
/// - **One action at a time, on the clip that was showing.** Every action
///   reads the clip's id and position **before** it awaits anything, and is
///   ignored while another runs (`busy`) or a chip is held. A chip tap holds
///   for [tagHold] ([tagHoldReduced] with reduced motion) and then tags; a
///   second tap in the hold does nothing, and closing the player in the
///   hold cancels it and tags nothing.
/// - **After a tag or a skip** it goes to `TagQueue.afterAction` (the next
///   waiting clip, else the first one from the start, else done), clears the
///   picks and keeps "Pick several" on.
/// - **Undo** waits for the action that is running, puts the records back in
///   one transaction and returns to that clip (owner ruling, D-91), also
///   after "All done!".
/// - **The clip showing leaving To tag** without this controller acting (a
///   verify, a tag from elsewhere, also during a hold) moves the player on,
///   as after an action. While a write runs, the action moves it instead.
/// - **A failure** leaves the clip showing, clears `busy` and is thrown to
///   the screen ("Something went wrong. Try again.").
///
/// Auto-disposes with the player's route.
final class TagSessionControllerProvider
    extends $AsyncNotifierProvider<TagSessionController, TagSessionState> {
  /// The tag player's session (D-96): the clips to tag, one at a time, and
  /// what each tap does.
  ///
  /// - **The session is fixed when the player opens:** the clips in To tag
  ///   then, in shooting order (`inShootingOrder`), starting at
  ///   `startClipId` (or the first). Clips that arrive later are not in it. A
  ///   clip that leaves To tag (tagged or skipped here or elsewhere, removed
  ///   by a verify) is passed over (`TagQueue`, D-95).
  /// - **One action at a time, on the clip that was showing.** Every action
  ///   reads the clip's id and position **before** it awaits anything, and is
  ///   ignored while another runs (`busy`) or a chip is held. A chip tap holds
  ///   for [tagHold] ([tagHoldReduced] with reduced motion) and then tags; a
  ///   second tap in the hold does nothing, and closing the player in the
  ///   hold cancels it and tags nothing.
  /// - **After a tag or a skip** it goes to `TagQueue.afterAction` (the next
  ///   waiting clip, else the first one from the start, else done), clears the
  ///   picks and keeps "Pick several" on.
  /// - **Undo** waits for the action that is running, puts the records back in
  ///   one transaction and returns to that clip (owner ruling, D-91), also
  ///   after "All done!".
  /// - **The clip showing leaving To tag** without this controller acting (a
  ///   verify, a tag from elsewhere, also during a hold) moves the player on,
  ///   as after an action. While a write runs, the action moves it instead.
  /// - **A failure** leaves the clip showing, clears `busy` and is thrown to
  ///   the screen ("Something went wrong. Try again.").
  ///
  /// Auto-disposes with the player's route.
  TagSessionControllerProvider._({
    required TagSessionControllerFamily super.from,
    required int? super.argument,
  }) : super(
         retry: noRetry,
         name: r'tagSessionControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$tagSessionControllerHash();

  @override
  String toString() {
    return r'tagSessionControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  TagSessionController create() => TagSessionController();

  @override
  bool operator ==(Object other) {
    return other is TagSessionControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$tagSessionControllerHash() =>
    r'b47665dd81f8bc0b7f9688f597ada82551ce4192';

/// The tag player's session (D-96): the clips to tag, one at a time, and
/// what each tap does.
///
/// - **The session is fixed when the player opens:** the clips in To tag
///   then, in shooting order (`inShootingOrder`), starting at
///   `startClipId` (or the first). Clips that arrive later are not in it. A
///   clip that leaves To tag (tagged or skipped here or elsewhere, removed
///   by a verify) is passed over (`TagQueue`, D-95).
/// - **One action at a time, on the clip that was showing.** Every action
///   reads the clip's id and position **before** it awaits anything, and is
///   ignored while another runs (`busy`) or a chip is held. A chip tap holds
///   for [tagHold] ([tagHoldReduced] with reduced motion) and then tags; a
///   second tap in the hold does nothing, and closing the player in the
///   hold cancels it and tags nothing.
/// - **After a tag or a skip** it goes to `TagQueue.afterAction` (the next
///   waiting clip, else the first one from the start, else done), clears the
///   picks and keeps "Pick several" on.
/// - **Undo** waits for the action that is running, puts the records back in
///   one transaction and returns to that clip (owner ruling, D-91), also
///   after "All done!".
/// - **The clip showing leaving To tag** without this controller acting (a
///   verify, a tag from elsewhere, also during a hold) moves the player on,
///   as after an action. While a write runs, the action moves it instead.
/// - **A failure** leaves the clip showing, clears `busy` and is thrown to
///   the screen ("Something went wrong. Try again.").
///
/// Auto-disposes with the player's route.

final class TagSessionControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          TagSessionController,
          AsyncValue<TagSessionState>,
          TagSessionState,
          FutureOr<TagSessionState>,
          int?
        > {
  TagSessionControllerFamily._()
    : super(
        retry: noRetry,
        name: r'tagSessionControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The tag player's session (D-96): the clips to tag, one at a time, and
  /// what each tap does.
  ///
  /// - **The session is fixed when the player opens:** the clips in To tag
  ///   then, in shooting order (`inShootingOrder`), starting at
  ///   `startClipId` (or the first). Clips that arrive later are not in it. A
  ///   clip that leaves To tag (tagged or skipped here or elsewhere, removed
  ///   by a verify) is passed over (`TagQueue`, D-95).
  /// - **One action at a time, on the clip that was showing.** Every action
  ///   reads the clip's id and position **before** it awaits anything, and is
  ///   ignored while another runs (`busy`) or a chip is held. A chip tap holds
  ///   for [tagHold] ([tagHoldReduced] with reduced motion) and then tags; a
  ///   second tap in the hold does nothing, and closing the player in the
  ///   hold cancels it and tags nothing.
  /// - **After a tag or a skip** it goes to `TagQueue.afterAction` (the next
  ///   waiting clip, else the first one from the start, else done), clears the
  ///   picks and keeps "Pick several" on.
  /// - **Undo** waits for the action that is running, puts the records back in
  ///   one transaction and returns to that clip (owner ruling, D-91), also
  ///   after "All done!".
  /// - **The clip showing leaving To tag** without this controller acting (a
  ///   verify, a tag from elsewhere, also during a hold) moves the player on,
  ///   as after an action. While a write runs, the action moves it instead.
  /// - **A failure** leaves the clip showing, clears `busy` and is thrown to
  ///   the screen ("Something went wrong. Try again.").
  ///
  /// Auto-disposes with the player's route.

  TagSessionControllerProvider call(int? startClipId) =>
      TagSessionControllerProvider._(argument: startClipId, from: this);

  @override
  String toString() => r'tagSessionControllerProvider';
}

/// The tag player's session (D-96): the clips to tag, one at a time, and
/// what each tap does.
///
/// - **The session is fixed when the player opens:** the clips in To tag
///   then, in shooting order (`inShootingOrder`), starting at
///   `startClipId` (or the first). Clips that arrive later are not in it. A
///   clip that leaves To tag (tagged or skipped here or elsewhere, removed
///   by a verify) is passed over (`TagQueue`, D-95).
/// - **One action at a time, on the clip that was showing.** Every action
///   reads the clip's id and position **before** it awaits anything, and is
///   ignored while another runs (`busy`) or a chip is held. A chip tap holds
///   for [tagHold] ([tagHoldReduced] with reduced motion) and then tags; a
///   second tap in the hold does nothing, and closing the player in the
///   hold cancels it and tags nothing.
/// - **After a tag or a skip** it goes to `TagQueue.afterAction` (the next
///   waiting clip, else the first one from the start, else done), clears the
///   picks and keeps "Pick several" on.
/// - **Undo** waits for the action that is running, puts the records back in
///   one transaction and returns to that clip (owner ruling, D-91), also
///   after "All done!".
/// - **The clip showing leaving To tag** without this controller acting (a
///   verify, a tag from elsewhere, also during a hold) moves the player on,
///   as after an action. While a write runs, the action moves it instead.
/// - **A failure** leaves the clip showing, clears `busy` and is thrown to
///   the screen ("Something went wrong. Try again.").
///
/// Auto-disposes with the player's route.

abstract class _$TagSessionController extends $AsyncNotifier<TagSessionState> {
  late final _$args = ref.$arg as int?;
  int? get startClipId => _$args;

  FutureOr<TagSessionState> build(int? startClipId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<TagSessionState>, TagSessionState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<TagSessionState>, TagSessionState>,
              AsyncValue<TagSessionState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
