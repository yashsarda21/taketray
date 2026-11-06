// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'background_sync.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The one [BackgroundSync]. Kept alive: it follows the database for the
/// app's lifetime once `TakeTrayApp` starts it.

@ProviderFor(backgroundSync)
final backgroundSyncProvider = BackgroundSyncProvider._();

/// The one [BackgroundSync]. Kept alive: it follows the database for the
/// app's lifetime once `TakeTrayApp` starts it.

final class BackgroundSyncProvider
    extends $FunctionalProvider<BackgroundSync, BackgroundSync, BackgroundSync>
    with $Provider<BackgroundSync> {
  /// The one [BackgroundSync]. Kept alive: it follows the database for the
  /// app's lifetime once `TakeTrayApp` starts it.
  BackgroundSyncProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'backgroundSyncProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$backgroundSyncHash();

  @$internal
  @override
  $ProviderElement<BackgroundSync> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  BackgroundSync create(Ref ref) {
    return backgroundSync(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BackgroundSync value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BackgroundSync>(value),
    );
  }
}

String _$backgroundSyncHash() => r'72bb259e37eaf2b154948c9ed28dd36ecafa0534';
