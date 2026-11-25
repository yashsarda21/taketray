// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'edit_select_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The clips ticked on the picking screen of one reel [reelId] (D-126, D-128,
/// D-129), which since D-192 is only for adding clips to the reel's editing
/// folder.
///
/// - **Only live clips can be ticked.** A missing clip is not listed, and a
///   clip of another reel or an unknown id cannot be ticked.
/// - **It follows the reel's clips.** A ticked clip that goes missing or
///   leaves the reel is un-ticked; the rest stays ticked when the list
///   changes (a clip joins, the times arrive).
/// - **`null` once the reel is gone** (deleted, or an id that names none);
///   the screen then goes to Reels.
/// - **Add mode** (owner decision 7, D-128, D-129; any editor's session):
///   every live clip, by `addPicks` against the reel's session. A fresh clip
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

/// The clips ticked on the picking screen of one reel [reelId] (D-126, D-128,
/// D-129), which since D-192 is only for adding clips to the reel's editing
/// folder.
///
/// - **Only live clips can be ticked.** A missing clip is not listed, and a
///   clip of another reel or an unknown id cannot be ticked.
/// - **It follows the reel's clips.** A ticked clip that goes missing or
///   leaves the reel is un-ticked; the rest stays ticked when the list
///   changes (a clip joins, the times arrive).
/// - **`null` once the reel is gone** (deleted, or an id that names none);
///   the screen then goes to Reels.
/// - **Add mode** (owner decision 7, D-128, D-129; any editor's session):
///   every live clip, by `addPicks` against the reel's session. A fresh clip
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
  /// The clips ticked on the picking screen of one reel [reelId] (D-126, D-128,
  /// D-129), which since D-192 is only for adding clips to the reel's editing
  /// folder.
  ///
  /// - **Only live clips can be ticked.** A missing clip is not listed, and a
  ///   clip of another reel or an unknown id cannot be ticked.
  /// - **It follows the reel's clips.** A ticked clip that goes missing or
  ///   leaves the reel is un-ticked; the rest stays ticked when the list
  ///   changes (a clip joins, the times arrive).
  /// - **`null` once the reel is gone** (deleted, or an id that names none);
  ///   the screen then goes to Reels.
  /// - **Add mode** (owner decision 7, D-128, D-129; any editor's session):
  ///   every live clip, by `addPicks` against the reel's session. A fresh clip
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
    required int super.argument,
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
    r'85b18a20f43e6172d1a4ac21da3a494c8155a0e4';

/// The clips ticked on the picking screen of one reel [reelId] (D-126, D-128,
/// D-129), which since D-192 is only for adding clips to the reel's editing
/// folder.
///
/// - **Only live clips can be ticked.** A missing clip is not listed, and a
///   clip of another reel or an unknown id cannot be ticked.
/// - **It follows the reel's clips.** A ticked clip that goes missing or
///   leaves the reel is un-ticked; the rest stays ticked when the list
///   changes (a clip joins, the times arrive).
/// - **`null` once the reel is gone** (deleted, or an id that names none);
///   the screen then goes to Reels.
/// - **Add mode** (owner decision 7, D-128, D-129; any editor's session):
///   every live clip, by `addPicks` against the reel's session. A fresh clip
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
          int
        > {
  EditSelectControllerFamily._()
    : super(
        retry: noRetry,
        name: r'editSelectControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The clips ticked on the picking screen of one reel [reelId] (D-126, D-128,
  /// D-129), which since D-192 is only for adding clips to the reel's editing
  /// folder.
  ///
  /// - **Only live clips can be ticked.** A missing clip is not listed, and a
  ///   clip of another reel or an unknown id cannot be ticked.
  /// - **It follows the reel's clips.** A ticked clip that goes missing or
  ///   leaves the reel is un-ticked; the rest stays ticked when the list
  ///   changes (a clip joins, the times arrive).
  /// - **`null` once the reel is gone** (deleted, or an id that names none);
  ///   the screen then goes to Reels.
  /// - **Add mode** (owner decision 7, D-128, D-129; any editor's session):
  ///   every live clip, by `addPicks` against the reel's session. A fresh clip
  ///   (neither sent nor copied) starts ticked, a sent one without a copy
  ///   starts unticked and can be ticked, a clip whose copy is in the folder is
  ///   ticked and locked ([EditSelectState.inFolder]: toggle, Clear and the
  ///   follow-up never un-tick it). Only the other ticked clips are to copy. It
  ///   follows the session too: a copy recorded meanwhile locks its clip, a
  ///   copy forgotten (deleted outside TakeTray) frees it, unticked.
  ///
  /// Auto-disposes with the screen.

  EditSelectControllerProvider call(int reelId) =>
      EditSelectControllerProvider._(argument: reelId, from: this);

  @override
  String toString() => r'editSelectControllerProvider';
}

/// The clips ticked on the picking screen of one reel [reelId] (D-126, D-128,
/// D-129), which since D-192 is only for adding clips to the reel's editing
/// folder.
///
/// - **Only live clips can be ticked.** A missing clip is not listed, and a
///   clip of another reel or an unknown id cannot be ticked.
/// - **It follows the reel's clips.** A ticked clip that goes missing or
///   leaves the reel is un-ticked; the rest stays ticked when the list
///   changes (a clip joins, the times arrive).
/// - **`null` once the reel is gone** (deleted, or an id that names none);
///   the screen then goes to Reels.
/// - **Add mode** (owner decision 7, D-128, D-129; any editor's session):
///   every live clip, by `addPicks` against the reel's session. A fresh clip
///   (neither sent nor copied) starts ticked, a sent one without a copy
///   starts unticked and can be ticked, a clip whose copy is in the folder is
///   ticked and locked ([EditSelectState.inFolder]: toggle, Clear and the
///   follow-up never un-tick it). Only the other ticked clips are to copy. It
///   follows the session too: a copy recorded meanwhile locks its clip, a
///   copy forgotten (deleted outside TakeTray) frees it, unticked.
///
/// Auto-disposes with the screen.

abstract class _$EditSelectController extends $AsyncNotifier<EditSelectState?> {
  late final _$args = ref.$arg as int;
  int get reelId => _$args;

  FutureOr<EditSelectState?> build(int reelId);
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
