// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'popup_route_tracker.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The one [PopupRouteTracker] of the app.

@ProviderFor(popupRouteTracker)
final popupRouteTrackerProvider = PopupRouteTrackerProvider._();

/// The one [PopupRouteTracker] of the app.

final class PopupRouteTrackerProvider
    extends
        $FunctionalProvider<
          PopupRouteTracker,
          PopupRouteTracker,
          PopupRouteTracker
        >
    with $Provider<PopupRouteTracker> {
  /// The one [PopupRouteTracker] of the app.
  PopupRouteTrackerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'popupRouteTrackerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$popupRouteTrackerHash();

  @$internal
  @override
  $ProviderElement<PopupRouteTracker> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PopupRouteTracker create(Ref ref) {
    return popupRouteTracker(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PopupRouteTracker value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PopupRouteTracker>(value),
    );
  }
}

String _$popupRouteTrackerHash() => r'cba50b1e3e4280d0358033774f49dff4e03a54e7';
