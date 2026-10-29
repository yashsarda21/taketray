// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shooting_mode_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Shooting mode for the card on the Reels screen: whether it is on, the
/// switch, and the camera shortcut (D-75).
///
/// The state is the stored Shooting mode
/// (`PhoneStateRepository.watchShooting`), so it is right at app start and
/// follows every change, including one made by someone else.
///
/// Kept alive, like the access controller it calls.

@ProviderFor(ShootingModeController)
final shootingModeControllerProvider = ShootingModeControllerProvider._();

/// Shooting mode for the card on the Reels screen: whether it is on, the
/// switch, and the camera shortcut (D-75).
///
/// The state is the stored Shooting mode
/// (`PhoneStateRepository.watchShooting`), so it is right at app start and
/// follows every change, including one made by someone else.
///
/// Kept alive, like the access controller it calls.
final class ShootingModeControllerProvider
    extends $StreamNotifierProvider<ShootingModeController, ShootingState> {
  /// Shooting mode for the card on the Reels screen: whether it is on, the
  /// switch, and the camera shortcut (D-75).
  ///
  /// The state is the stored Shooting mode
  /// (`PhoneStateRepository.watchShooting`), so it is right at app start and
  /// follows every change, including one made by someone else.
  ///
  /// Kept alive, like the access controller it calls.
  ShootingModeControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: noRetry,
        name: r'shootingModeControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$shootingModeControllerHash();

  @$internal
  @override
  ShootingModeController create() => ShootingModeController();
}

String _$shootingModeControllerHash() =>
    r'91b9aac27f1e79feb97ed9bf3d6e02f0d83af1f8';

/// Shooting mode for the card on the Reels screen: whether it is on, the
/// switch, and the camera shortcut (D-75).
///
/// The state is the stored Shooting mode
/// (`PhoneStateRepository.watchShooting`), so it is right at app start and
/// follows every change, including one made by someone else.
///
/// Kept alive, like the access controller it calls.

abstract class _$ShootingModeController extends $StreamNotifier<ShootingState> {
  Stream<ShootingState> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<ShootingState>, ShootingState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<ShootingState>, ShootingState>,
              AsyncValue<ShootingState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
