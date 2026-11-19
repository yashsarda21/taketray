// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'android_sdk.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The phone's Android version (`Build.VERSION.SDK_INT`), as the media bridge
/// reports it with the access level. Onboarding's video access step reads it
/// to say which choice Android's dialog has: "Allow all" from Android 14
/// (34), "Allow" before (D-140).
///
/// Read once and kept: the version never changes while the app runs. A read
/// that fails is an error; the screen then shows the newer wording rather
/// than a guess presented as fact.

@ProviderFor(androidSdk)
final androidSdkProvider = AndroidSdkProvider._();

/// The phone's Android version (`Build.VERSION.SDK_INT`), as the media bridge
/// reports it with the access level. Onboarding's video access step reads it
/// to say which choice Android's dialog has: "Allow all" from Android 14
/// (34), "Allow" before (D-140).
///
/// Read once and kept: the version never changes while the app runs. A read
/// that fails is an error; the screen then shows the newer wording rather
/// than a guess presented as fact.

final class AndroidSdkProvider
    extends $FunctionalProvider<AsyncValue<int>, int, FutureOr<int>>
    with $FutureModifier<int>, $FutureProvider<int> {
  /// The phone's Android version (`Build.VERSION.SDK_INT`), as the media bridge
  /// reports it with the access level. Onboarding's video access step reads it
  /// to say which choice Android's dialog has: "Allow all" from Android 14
  /// (34), "Allow" before (D-140).
  ///
  /// Read once and kept: the version never changes while the app runs. A read
  /// that fails is an error; the screen then shows the newer wording rather
  /// than a guess presented as fact.
  AndroidSdkProvider._()
    : super(
        from: null,
        argument: null,
        retry: noRetry,
        name: r'androidSdkProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$androidSdkHash();

  @$internal
  @override
  $FutureProviderElement<int> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<int> create(Ref ref) {
    return androidSdk(ref);
  }
}

String _$androidSdkHash() => r'4208685ff997d12432fa8b19e69253bf339d446f';
