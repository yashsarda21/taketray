// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'last_tags.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The reels of the last tag, in the order they were chosen (D-96): what
/// "Same as previous" in the tag player offers next.
///
/// Set by every tag of the player and of the reel picker's tag mode. Kept for
/// the app session, never stored: a restart starts with none. A reel deleted
/// since stays in the list; whoever uses it keeps only the ids that still
/// exist (`TagSessionController.sameAsPrevious` does).

@ProviderFor(LastTags)
final lastTagsProvider = LastTagsProvider._();

/// The reels of the last tag, in the order they were chosen (D-96): what
/// "Same as previous" in the tag player offers next.
///
/// Set by every tag of the player and of the reel picker's tag mode. Kept for
/// the app session, never stored: a restart starts with none. A reel deleted
/// since stays in the list; whoever uses it keeps only the ids that still
/// exist (`TagSessionController.sameAsPrevious` does).
final class LastTagsProvider extends $NotifierProvider<LastTags, List<int>> {
  /// The reels of the last tag, in the order they were chosen (D-96): what
  /// "Same as previous" in the tag player offers next.
  ///
  /// Set by every tag of the player and of the reel picker's tag mode. Kept for
  /// the app session, never stored: a restart starts with none. A reel deleted
  /// since stays in the list; whoever uses it keeps only the ids that still
  /// exist (`TagSessionController.sameAsPrevious` does).
  LastTagsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'lastTagsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$lastTagsHash();

  @$internal
  @override
  LastTags create() => LastTags();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<int> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<int>>(value),
    );
  }
}

String _$lastTagsHash() => r'0a1d441b25a333f6ee3122df0b8f734e2a4f7ae5';

/// The reels of the last tag, in the order they were chosen (D-96): what
/// "Same as previous" in the tag player offers next.
///
/// Set by every tag of the player and of the reel picker's tag mode. Kept for
/// the app session, never stored: a restart starts with none. A reel deleted
/// since stays in the list; whoever uses it keeps only the ids that still
/// exist (`TagSessionController.sameAsPrevious` does).

abstract class _$LastTags extends $Notifier<List<int>> {
  List<int> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<List<int>, List<int>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<List<int>, List<int>>,
              List<int>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
