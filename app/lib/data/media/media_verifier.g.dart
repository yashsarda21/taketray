// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_verifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The verifier, on the shared [mediaWorkQueueProvider].

@ProviderFor(mediaVerifier)
final mediaVerifierProvider = MediaVerifierProvider._();

/// The verifier, on the shared [mediaWorkQueueProvider].

final class MediaVerifierProvider
    extends $FunctionalProvider<MediaVerifier, MediaVerifier, MediaVerifier>
    with $Provider<MediaVerifier> {
  /// The verifier, on the shared [mediaWorkQueueProvider].
  MediaVerifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mediaVerifierProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mediaVerifierHash();

  @$internal
  @override
  $ProviderElement<MediaVerifier> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  MediaVerifier create(Ref ref) {
    return mediaVerifier(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MediaVerifier value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MediaVerifier>(value),
    );
  }
}

String _$mediaVerifierHash() => r'9f8ea33a75897807eae0ef738f72d52ef8d1d328';
