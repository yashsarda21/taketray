// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'copy_screens.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(openCopyScreens)
final openCopyScreensProvider = OpenCopyScreensProvider._();

final class OpenCopyScreensProvider
    extends
        $FunctionalProvider<OpenCopyScreens, OpenCopyScreens, OpenCopyScreens>
    with $Provider<OpenCopyScreens> {
  OpenCopyScreensProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'openCopyScreensProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$openCopyScreensHash();

  @$internal
  @override
  $ProviderElement<OpenCopyScreens> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  OpenCopyScreens create(Ref ref) {
    return openCopyScreens(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(OpenCopyScreens value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<OpenCopyScreens>(value),
    );
  }
}

String _$openCopyScreensHash() => r'c09548cfb83e6779e08f49cadf33b74bdca2c9f7';
