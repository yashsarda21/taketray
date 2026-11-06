// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_access_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Whether TakeTray may post notifications, for the Notifications row in
/// Settings and the one question asked when Shooting mode is first turned on
/// (D-107).
///
/// Kept alive, like `MediaAccessController`: the app start, a resume and the
/// screens all use the one state. The bridge's answers are read fresh on every
/// call; only the last call to finish writes the state, so an older answer
/// arriving late never replaces a newer one. A first read that fails leaves
/// an `AsyncError` until a refresh works.
///
/// No method throws: an error is logged by type and the last view stays.

@ProviderFor(NotificationAccessController)
final notificationAccessControllerProvider =
    NotificationAccessControllerProvider._();

/// Whether TakeTray may post notifications, for the Notifications row in
/// Settings and the one question asked when Shooting mode is first turned on
/// (D-107).
///
/// Kept alive, like `MediaAccessController`: the app start, a resume and the
/// screens all use the one state. The bridge's answers are read fresh on every
/// call; only the last call to finish writes the state, so an older answer
/// arriving late never replaces a newer one. A first read that fails leaves
/// an `AsyncError` until a refresh works.
///
/// No method throws: an error is logged by type and the last view stays.
final class NotificationAccessControllerProvider
    extends
        $AsyncNotifierProvider<
          NotificationAccessController,
          NotificationAccess
        > {
  /// Whether TakeTray may post notifications, for the Notifications row in
  /// Settings and the one question asked when Shooting mode is first turned on
  /// (D-107).
  ///
  /// Kept alive, like `MediaAccessController`: the app start, a resume and the
  /// screens all use the one state. The bridge's answers are read fresh on every
  /// call; only the last call to finish writes the state, so an older answer
  /// arriving late never replaces a newer one. A first read that fails leaves
  /// an `AsyncError` until a refresh works.
  ///
  /// No method throws: an error is logged by type and the last view stays.
  NotificationAccessControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: noRetry,
        name: r'notificationAccessControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notificationAccessControllerHash();

  @$internal
  @override
  NotificationAccessController create() => NotificationAccessController();
}

String _$notificationAccessControllerHash() =>
    r'5f9b8d168b7c942285088a2040f6534ad87cac81';

/// Whether TakeTray may post notifications, for the Notifications row in
/// Settings and the one question asked when Shooting mode is first turned on
/// (D-107).
///
/// Kept alive, like `MediaAccessController`: the app start, a resume and the
/// screens all use the one state. The bridge's answers are read fresh on every
/// call; only the last call to finish writes the state, so an older answer
/// arriving late never replaces a newer one. A first read that fails leaves
/// an `AsyncError` until a refresh works.
///
/// No method throws: an error is logged by type and the last view stays.

abstract class _$NotificationAccessController
    extends $AsyncNotifier<NotificationAccess> {
  FutureOr<NotificationAccess> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<NotificationAccess>, NotificationAccess>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<NotificationAccess>, NotificationAccess>,
              AsyncValue<NotificationAccess>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
