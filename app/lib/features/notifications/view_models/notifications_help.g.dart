// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notifications_help.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The brand of this phone, or null when TakeTray has no steps for its maker
/// or the maker cannot be read (the help screen then opens no card). The
/// maker itself is neither kept nor logged.

@ProviderFor(phoneBrand)
final phoneBrandProvider = PhoneBrandProvider._();

/// The brand of this phone, or null when TakeTray has no steps for its maker
/// or the maker cannot be read (the help screen then opens no card). The
/// maker itself is neither kept nor logged.

final class PhoneBrandProvider
    extends
        $FunctionalProvider<
          AsyncValue<PhoneBrand?>,
          PhoneBrand?,
          FutureOr<PhoneBrand?>
        >
    with $FutureModifier<PhoneBrand?>, $FutureProvider<PhoneBrand?> {
  /// The brand of this phone, or null when TakeTray has no steps for its maker
  /// or the maker cannot be read (the help screen then opens no card). The
  /// maker itself is neither kept nor logged.
  PhoneBrandProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'phoneBrandProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$phoneBrandHash();

  @$internal
  @override
  $FutureProviderElement<PhoneBrand?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<PhoneBrand?> create(Ref ref) {
    return phoneBrand(ref);
  }
}

String _$phoneBrandHash() => r'440322def3d303c020049db974a35ff1735f4105';

@ProviderFor(notificationsHelpActions)
final notificationsHelpActionsProvider = NotificationsHelpActionsProvider._();

final class NotificationsHelpActionsProvider
    extends
        $FunctionalProvider<
          NotificationsHelpActions,
          NotificationsHelpActions,
          NotificationsHelpActions
        >
    with $Provider<NotificationsHelpActions> {
  NotificationsHelpActionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'notificationsHelpActionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notificationsHelpActionsHash();

  @$internal
  @override
  $ProviderElement<NotificationsHelpActions> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  NotificationsHelpActions create(Ref ref) {
    return notificationsHelpActions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NotificationsHelpActions value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NotificationsHelpActions>(value),
    );
  }
}

String _$notificationsHelpActionsHash() =>
    r'b12d5cde699278a7061fa7b5dc78f67fb24a9ffb';
