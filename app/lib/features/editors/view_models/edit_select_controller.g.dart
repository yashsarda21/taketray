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
/// - **Add mode** (`EditSelectArgs.addMode`, owner decision 7, D-128): every
///   live clip again, by `addPicks` against the reel's session. A fresh clip
///   (neither sent nor copied) starts ticked, a sent one without a copy
///   starts unticked and can be ticked, a clip whose copy is in the folder is
///   ticked and locked ([EditSelectState.inFolder]: toggle, Clear and the
///   follow-up never un-tick it). Only the other ticked clips are to copy. It
///   follows the session too: a copy recorded meanwhile locks its clip, a
///   copy forgotten (deleted outside TakeTray) frees it, unticked.
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
/// - **Add mode** (`EditSelectArgs.addMode`, owner decision 7, D-128): every
///   live clip again, by `addPicks` against the reel's session. A fresh clip
///   (neither sent nor copied) starts ticked, a sent one without a copy
///   starts unticked and can be ticked, a clip whose copy is in the folder is
///   ticked and locked ([EditSelectState.inFolder]: toggle, Clear and the
///   follow-up never un-tick it). Only the other ticked clips are to copy. It
///   follows the session too: a copy recorded meanwhile locks its clip, a
///   copy forgotten (deleted outside TakeTray) frees it, unticked.
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
  /// - **Add mode** (`EditSelectArgs.addMode`, owner decision 7, D-128): every
  ///   live clip again, by `addPicks` against the reel's session. A fresh clip
  ///   (neither sent nor copied) starts ticked, a sent one without a copy
  ///   starts unticked and can be ticked, a clip whose copy is in the folder is
  ///   ticked and locked ([EditSelectState.inFolder]: toggle, Clear and the
  ///   follow-up never un-tick it). Only the other ticked clips are to copy. It
  ///   follows the session too: a copy recorded meanwhile locks its clip, a
  ///   copy forgotten (deleted outside TakeTray) frees it, unticked.
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
    r'83b9af8a2b805f1b712c032c35052110a72a36f4';

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
/// - **Add mode** (`EditSelectArgs.addMode`, owner decision 7, D-128): every
///   live clip again, by `addPicks` against the reel's session. A fresh clip
///   (neither sent nor copied) starts ticked, a sent one without a copy
///   starts unticked and can be ticked, a clip whose copy is in the folder is
///   ticked and locked ([EditSelectState.inFolder]: toggle, Clear and the
///   follow-up never un-tick it). Only the other ticked clips are to copy. It
///   follows the session too: a copy recorded meanwhile locks its clip, a
///   copy forgotten (deleted outside TakeTray) frees it, unticked.
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
  /// - **Add mode** (`EditSelectArgs.addMode`, owner decision 7, D-128): every
  ///   live clip again, by `addPicks` against the reel's session. A fresh clip
  ///   (neither sent nor copied) starts ticked, a sent one without a copy
  ///   starts unticked and can be ticked, a clip whose copy is in the folder is
  ///   ticked and locked ([EditSelectState.inFolder]: toggle, Clear and the
  ///   follow-up never un-tick it). Only the other ticked clips are to copy. It
  ///   follows the session too: a copy recorded meanwhile locks its clip, a
  ///   copy forgotten (deleted outside TakeTray) frees it, unticked.
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
/// - **Add mode** (`EditSelectArgs.addMode`, owner decision 7, D-128): every
///   live clip again, by `addPicks` against the reel's session. A fresh clip
///   (neither sent nor copied) starts ticked, a sent one without a copy
///   starts unticked and can be ticked, a clip whose copy is in the folder is
///   ticked and locked ([EditSelectState.inFolder]: toggle, Clear and the
///   follow-up never un-tick it). Only the other ticked clips are to copy. It
///   follows the session too: a copy recorded meanwhile locks its clip, a
///   copy forgotten (deleted outside TakeTray) frees it, unticked.
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
