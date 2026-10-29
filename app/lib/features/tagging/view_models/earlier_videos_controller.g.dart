// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'earlier_videos_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The "Add earlier videos" sheet (D-73, D-75): how many videos each range
/// would add, adding a range, and Undo.
///
/// The state is the count per [EarlierRange], read when the sheet opens
/// (`MediaScanner.countEarlier`), so it works with Shooting mode off. It
/// auto-disposes: closing the sheet drops it, and opening the sheet again
/// counts again. A failed count is an `AsyncError` for the sheet to show; it
/// is logged by type and not retried by itself.
///
/// [add] and [undo] **rethrow** their errors, after logging the type, so the
/// sheet can tell the user it did not work (a missing full access is a
/// `StateError`). The caller must catch. After either one succeeds the counts
/// are read again, and if that fails the old counts stay.

@ProviderFor(EarlierVideosController)
final earlierVideosControllerProvider = EarlierVideosControllerProvider._();

/// The "Add earlier videos" sheet (D-73, D-75): how many videos each range
/// would add, adding a range, and Undo.
///
/// The state is the count per [EarlierRange], read when the sheet opens
/// (`MediaScanner.countEarlier`), so it works with Shooting mode off. It
/// auto-disposes: closing the sheet drops it, and opening the sheet again
/// counts again. A failed count is an `AsyncError` for the sheet to show; it
/// is logged by type and not retried by itself.
///
/// [add] and [undo] **rethrow** their errors, after logging the type, so the
/// sheet can tell the user it did not work (a missing full access is a
/// `StateError`). The caller must catch. After either one succeeds the counts
/// are read again, and if that fails the old counts stay.
final class EarlierVideosControllerProvider
    extends
        $AsyncNotifierProvider<
          EarlierVideosController,
          Map<EarlierRange, int>
        > {
  /// The "Add earlier videos" sheet (D-73, D-75): how many videos each range
  /// would add, adding a range, and Undo.
  ///
  /// The state is the count per [EarlierRange], read when the sheet opens
  /// (`MediaScanner.countEarlier`), so it works with Shooting mode off. It
  /// auto-disposes: closing the sheet drops it, and opening the sheet again
  /// counts again. A failed count is an `AsyncError` for the sheet to show; it
  /// is logged by type and not retried by itself.
  ///
  /// [add] and [undo] **rethrow** their errors, after logging the type, so the
  /// sheet can tell the user it did not work (a missing full access is a
  /// `StateError`). The caller must catch. After either one succeeds the counts
  /// are read again, and if that fails the old counts stay.
  EarlierVideosControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: noRetry,
        name: r'earlierVideosControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$earlierVideosControllerHash();

  @$internal
  @override
  EarlierVideosController create() => EarlierVideosController();
}

String _$earlierVideosControllerHash() =>
    r'a53336a65d3b8094d54441b769808d951c5578b6';

/// The "Add earlier videos" sheet (D-73, D-75): how many videos each range
/// would add, adding a range, and Undo.
///
/// The state is the count per [EarlierRange], read when the sheet opens
/// (`MediaScanner.countEarlier`), so it works with Shooting mode off. It
/// auto-disposes: closing the sheet drops it, and opening the sheet again
/// counts again. A failed count is an `AsyncError` for the sheet to show; it
/// is logged by type and not retried by itself.
///
/// [add] and [undo] **rethrow** their errors, after logging the type, so the
/// sheet can tell the user it did not work (a missing full access is a
/// `StateError`). The caller must catch. After either one succeeds the counts
/// are read again, and if that fails the old counts stay.

abstract class _$EarlierVideosController
    extends $AsyncNotifier<Map<EarlierRange, int>> {
  FutureOr<Map<EarlierRange, int>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<Map<EarlierRange, int>>, Map<EarlierRange, int>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<Map<EarlierRange, int>>,
                Map<EarlierRange, int>
              >,
              AsyncValue<Map<EarlierRange, int>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
