// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'phone_state_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(phoneStateRepository)
final phoneStateRepositoryProvider = PhoneStateRepositoryProvider._();

final class PhoneStateRepositoryProvider
    extends
        $FunctionalProvider<
          PhoneStateRepository,
          PhoneStateRepository,
          PhoneStateRepository
        >
    with $Provider<PhoneStateRepository> {
  PhoneStateRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'phoneStateRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$phoneStateRepositoryHash();

  @$internal
  @override
  $ProviderElement<PhoneStateRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PhoneStateRepository create(Ref ref) {
    return phoneStateRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PhoneStateRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PhoneStateRepository>(value),
    );
  }
}

String _$phoneStateRepositoryHash() =>
    r'848c21bbff252fc2ab0cf1c982b0bb56605c1c66';
