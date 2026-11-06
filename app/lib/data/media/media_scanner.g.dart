// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_scanner.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The scanner, on the shared [mediaWorkQueueProvider]. Kept alive: the
/// queued scan that calls share lives in it.

@ProviderFor(mediaScanner)
final mediaScannerProvider = MediaScannerProvider._();

/// The scanner, on the shared [mediaWorkQueueProvider]. Kept alive: the
/// queued scan that calls share lives in it.

final class MediaScannerProvider
    extends $FunctionalProvider<MediaScanner, MediaScanner, MediaScanner>
    with $Provider<MediaScanner> {
  /// The scanner, on the shared [mediaWorkQueueProvider]. Kept alive: the
  /// queued scan that calls share lives in it.
  MediaScannerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mediaScannerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mediaScannerHash();

  @$internal
  @override
  $ProviderElement<MediaScanner> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  MediaScanner create(Ref ref) {
    return mediaScanner(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MediaScanner value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MediaScanner>(value),
    );
  }
}

String _$mediaScannerHash() => r'331207dc6cd5cf7b2cc850bab501295c3322eaf0';
