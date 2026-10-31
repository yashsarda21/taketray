// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'clip_time.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The app's one [ClipTimeService], kept for the whole run so its cache is.

@ProviderFor(clipTimeService)
final clipTimeServiceProvider = ClipTimeServiceProvider._();

/// The app's one [ClipTimeService], kept for the whole run so its cache is.

final class ClipTimeServiceProvider
    extends
        $FunctionalProvider<ClipTimeService, ClipTimeService, ClipTimeService>
    with $Provider<ClipTimeService> {
  /// The app's one [ClipTimeService], kept for the whole run so its cache is.
  ClipTimeServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'clipTimeServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$clipTimeServiceHash();

  @$internal
  @override
  $ProviderElement<ClipTimeService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ClipTimeService create(Ref ref) {
    return clipTimeService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ClipTimeService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ClipTimeService>(value),
    );
  }
}

String _$clipTimeServiceHash() => r'9dd219b29fd92e6676f99d001440ad7e27a96a55';
