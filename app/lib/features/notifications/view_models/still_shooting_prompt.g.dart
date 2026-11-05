// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'still_shooting_prompt.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The one [StillShootingPrompt], for the whole app session: it remembers
/// that the question was asked.

@ProviderFor(stillShootingPrompt)
final stillShootingPromptProvider = StillShootingPromptProvider._();

/// The one [StillShootingPrompt], for the whole app session: it remembers
/// that the question was asked.

final class StillShootingPromptProvider
    extends
        $FunctionalProvider<
          StillShootingPrompt,
          StillShootingPrompt,
          StillShootingPrompt
        >
    with $Provider<StillShootingPrompt> {
  /// The one [StillShootingPrompt], for the whole app session: it remembers
  /// that the question was asked.
  StillShootingPromptProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'stillShootingPromptProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$stillShootingPromptHash();

  @$internal
  @override
  $ProviderElement<StillShootingPrompt> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  StillShootingPrompt create(Ref ref) {
    return stillShootingPrompt(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(StillShootingPrompt value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<StillShootingPrompt>(value),
    );
  }
}

String _$stillShootingPromptHash() =>
    r'2a98430fa43deb39b36a29070e279d8ab1a3c7d2';
