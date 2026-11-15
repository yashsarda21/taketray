// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'copy_space_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The VN space check (D-127): what copying [CopySpaceArgs.clipIds] would take
/// (`EditSessionService.planCopy`) and the start of the copy.
///
/// - **Data:** `null` once the reel is gone (deleted meanwhile, or an id that
///   names none); the screen then goes to Reels. An error (the phone's free
///   space cannot be read, the reel is in another editor) is shown as
///   "Couldn't start copying. Try again.".
/// - The plan is made again when the reel changes (a clip goes missing), so
///   the numbers are never older than the reel.
///
/// Auto-disposes with the screen.

@ProviderFor(CopySpaceController)
final copySpaceControllerProvider = CopySpaceControllerFamily._();

/// The VN space check (D-127): what copying [CopySpaceArgs.clipIds] would take
/// (`EditSessionService.planCopy`) and the start of the copy.
///
/// - **Data:** `null` once the reel is gone (deleted meanwhile, or an id that
///   names none); the screen then goes to Reels. An error (the phone's free
///   space cannot be read, the reel is in another editor) is shown as
///   "Couldn't start copying. Try again.".
/// - The plan is made again when the reel changes (a clip goes missing), so
///   the numbers are never older than the reel.
///
/// Auto-disposes with the screen.
final class CopySpaceControllerProvider
    extends $AsyncNotifierProvider<CopySpaceController, CopySpaceState?> {
  /// The VN space check (D-127): what copying [CopySpaceArgs.clipIds] would take
  /// (`EditSessionService.planCopy`) and the start of the copy.
  ///
  /// - **Data:** `null` once the reel is gone (deleted meanwhile, or an id that
  ///   names none); the screen then goes to Reels. An error (the phone's free
  ///   space cannot be read, the reel is in another editor) is shown as
  ///   "Couldn't start copying. Try again.".
  /// - The plan is made again when the reel changes (a clip goes missing), so
  ///   the numbers are never older than the reel.
  ///
  /// Auto-disposes with the screen.
  CopySpaceControllerProvider._({
    required CopySpaceControllerFamily super.from,
    required CopySpaceArgs super.argument,
  }) : super(
         retry: noRetry,
         name: r'copySpaceControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$copySpaceControllerHash();

  @override
  String toString() {
    return r'copySpaceControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  CopySpaceController create() => CopySpaceController();

  @override
  bool operator ==(Object other) {
    return other is CopySpaceControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$copySpaceControllerHash() =>
    r'e44985303b5706062948f13e2d51e8a17bc57b2a';

/// The VN space check (D-127): what copying [CopySpaceArgs.clipIds] would take
/// (`EditSessionService.planCopy`) and the start of the copy.
///
/// - **Data:** `null` once the reel is gone (deleted meanwhile, or an id that
///   names none); the screen then goes to Reels. An error (the phone's free
///   space cannot be read, the reel is in another editor) is shown as
///   "Couldn't start copying. Try again.".
/// - The plan is made again when the reel changes (a clip goes missing), so
///   the numbers are never older than the reel.
///
/// Auto-disposes with the screen.

final class CopySpaceControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          CopySpaceController,
          AsyncValue<CopySpaceState?>,
          CopySpaceState?,
          FutureOr<CopySpaceState?>,
          CopySpaceArgs
        > {
  CopySpaceControllerFamily._()
    : super(
        retry: noRetry,
        name: r'copySpaceControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The VN space check (D-127): what copying [CopySpaceArgs.clipIds] would take
  /// (`EditSessionService.planCopy`) and the start of the copy.
  ///
  /// - **Data:** `null` once the reel is gone (deleted meanwhile, or an id that
  ///   names none); the screen then goes to Reels. An error (the phone's free
  ///   space cannot be read, the reel is in another editor) is shown as
  ///   "Couldn't start copying. Try again.".
  /// - The plan is made again when the reel changes (a clip goes missing), so
  ///   the numbers are never older than the reel.
  ///
  /// Auto-disposes with the screen.

  CopySpaceControllerProvider call(CopySpaceArgs args) =>
      CopySpaceControllerProvider._(argument: args, from: this);

  @override
  String toString() => r'copySpaceControllerProvider';
}

/// The VN space check (D-127): what copying [CopySpaceArgs.clipIds] would take
/// (`EditSessionService.planCopy`) and the start of the copy.
///
/// - **Data:** `null` once the reel is gone (deleted meanwhile, or an id that
///   names none); the screen then goes to Reels. An error (the phone's free
///   space cannot be read, the reel is in another editor) is shown as
///   "Couldn't start copying. Try again.".
/// - The plan is made again when the reel changes (a clip goes missing), so
///   the numbers are never older than the reel.
///
/// Auto-disposes with the screen.

abstract class _$CopySpaceController extends $AsyncNotifier<CopySpaceState?> {
  late final _$args = ref.$arg as CopySpaceArgs;
  CopySpaceArgs get args => _$args;

  FutureOr<CopySpaceState?> build(CopySpaceArgs args);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<CopySpaceState?>, CopySpaceState?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<CopySpaceState?>, CopySpaceState?>,
              AsyncValue<CopySpaceState?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
