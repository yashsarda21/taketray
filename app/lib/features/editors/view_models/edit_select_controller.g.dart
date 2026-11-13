// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'edit_select_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The clips ticked on the picking screen of one reel (D-126).
///
/// - **Only live clips can be ticked.** A missing clip is not listed, a clip
///   of another reel or an unknown id cannot be ticked, and the preselected
///   ids are cut down the same way.
/// - **It follows the reel's clips.** A ticked clip that goes missing or
///   leaves the reel is un-ticked; the rest stays ticked when the list
///   changes (a clip joins, the times arrive).
/// - **`null` once the reel is gone** (deleted, or an id that names none);
///   the screen then goes to Reels.
///
/// Auto-disposes with the screen.

@ProviderFor(EditSelectController)
final editSelectControllerProvider = EditSelectControllerFamily._();

/// The clips ticked on the picking screen of one reel (D-126).
///
/// - **Only live clips can be ticked.** A missing clip is not listed, a clip
///   of another reel or an unknown id cannot be ticked, and the preselected
///   ids are cut down the same way.
/// - **It follows the reel's clips.** A ticked clip that goes missing or
///   leaves the reel is un-ticked; the rest stays ticked when the list
///   changes (a clip joins, the times arrive).
/// - **`null` once the reel is gone** (deleted, or an id that names none);
///   the screen then goes to Reels.
///
/// Auto-disposes with the screen.
final class EditSelectControllerProvider
    extends $AsyncNotifierProvider<EditSelectController, EditSelectState?> {
  /// The clips ticked on the picking screen of one reel (D-126).
  ///
  /// - **Only live clips can be ticked.** A missing clip is not listed, a clip
  ///   of another reel or an unknown id cannot be ticked, and the preselected
  ///   ids are cut down the same way.
  /// - **It follows the reel's clips.** A ticked clip that goes missing or
  ///   leaves the reel is un-ticked; the rest stays ticked when the list
  ///   changes (a clip joins, the times arrive).
  /// - **`null` once the reel is gone** (deleted, or an id that names none);
  ///   the screen then goes to Reels.
  ///
  /// Auto-disposes with the screen.
  EditSelectControllerProvider._({
    required EditSelectControllerFamily super.from,
    required EditSelectArgs super.argument,
  }) : super(
         retry: noRetry,
         name: r'editSelectControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$editSelectControllerHash();

  @override
  String toString() {
    return r'editSelectControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  EditSelectController create() => EditSelectController();

  @override
  bool operator ==(Object other) {
    return other is EditSelectControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$editSelectControllerHash() =>
    r'6e823b1becc16a379e36eff397632031e01a13eb';

/// The clips ticked on the picking screen of one reel (D-126).
///
/// - **Only live clips can be ticked.** A missing clip is not listed, a clip
///   of another reel or an unknown id cannot be ticked, and the preselected
///   ids are cut down the same way.
/// - **It follows the reel's clips.** A ticked clip that goes missing or
///   leaves the reel is un-ticked; the rest stays ticked when the list
///   changes (a clip joins, the times arrive).
/// - **`null` once the reel is gone** (deleted, or an id that names none);
///   the screen then goes to Reels.
///
/// Auto-disposes with the screen.

final class EditSelectControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          EditSelectController,
          AsyncValue<EditSelectState?>,
          EditSelectState?,
          FutureOr<EditSelectState?>,
          EditSelectArgs
        > {
  EditSelectControllerFamily._()
    : super(
        retry: noRetry,
        name: r'editSelectControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The clips ticked on the picking screen of one reel (D-126).
  ///
  /// - **Only live clips can be ticked.** A missing clip is not listed, a clip
  ///   of another reel or an unknown id cannot be ticked, and the preselected
  ///   ids are cut down the same way.
  /// - **It follows the reel's clips.** A ticked clip that goes missing or
  ///   leaves the reel is un-ticked; the rest stays ticked when the list
  ///   changes (a clip joins, the times arrive).
  /// - **`null` once the reel is gone** (deleted, or an id that names none);
  ///   the screen then goes to Reels.
  ///
  /// Auto-disposes with the screen.

  EditSelectControllerProvider call(EditSelectArgs args) =>
      EditSelectControllerProvider._(argument: args, from: this);

  @override
  String toString() => r'editSelectControllerProvider';
}

/// The clips ticked on the picking screen of one reel (D-126).
///
/// - **Only live clips can be ticked.** A missing clip is not listed, a clip
///   of another reel or an unknown id cannot be ticked, and the preselected
///   ids are cut down the same way.
/// - **It follows the reel's clips.** A ticked clip that goes missing or
///   leaves the reel is un-ticked; the rest stays ticked when the list
///   changes (a clip joins, the times arrive).
/// - **`null` once the reel is gone** (deleted, or an id that names none);
///   the screen then goes to Reels.
///
/// Auto-disposes with the screen.

abstract class _$EditSelectController extends $AsyncNotifier<EditSelectState?> {
  late final _$args = ref.$arg as EditSelectArgs;
  EditSelectArgs get args => _$args;

  FutureOr<EditSelectState?> build(EditSelectArgs args);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<EditSelectState?>, EditSelectState?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<EditSelectState?>, EditSelectState?>,
              AsyncValue<EditSelectState?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}

/// Whether reel [reelId] has an editing session (D-120); no value until the
/// database has answered. A reel being edited cannot start another edit
/// (R1).

@ProviderFor(reelInEditingSession)
final reelInEditingSessionProvider = ReelInEditingSessionFamily._();

/// Whether reel [reelId] has an editing session (D-120); no value until the
/// database has answered. A reel being edited cannot start another edit
/// (R1).

final class ReelInEditingSessionProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, Stream<bool>>
    with $FutureModifier<bool>, $StreamProvider<bool> {
  /// Whether reel [reelId] has an editing session (D-120); no value until the
  /// database has answered. A reel being edited cannot start another edit
  /// (R1).
  ReelInEditingSessionProvider._({
    required ReelInEditingSessionFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'reelInEditingSessionProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$reelInEditingSessionHash();

  @override
  String toString() {
    return r'reelInEditingSessionProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<bool> create(Ref ref) {
    final argument = this.argument as int;
    return reelInEditingSession(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ReelInEditingSessionProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$reelInEditingSessionHash() =>
    r'151413a1b1b7b97e7465fa7c7f44a6fb8e7a173b';

/// Whether reel [reelId] has an editing session (D-120); no value until the
/// database has answered. A reel being edited cannot start another edit
/// (R1).

final class ReelInEditingSessionFamily extends $Family
    with $FunctionalFamilyOverride<Stream<bool>, int> {
  ReelInEditingSessionFamily._()
    : super(
        retry: null,
        name: r'reelInEditingSessionProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Whether reel [reelId] has an editing session (D-120); no value until the
  /// database has answered. A reel being edited cannot start another edit
  /// (R1).

  ReelInEditingSessionProvider call(int reelId) =>
      ReelInEditingSessionProvider._(argument: reelId, from: this);

  @override
  String toString() => r'reelInEditingSessionProvider';
}
