// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'earlier_videos_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The "Add earlier videos" sheet (D-73, D-75, D-78): how many videos Today
/// would add, counting the videos of a chosen date range, adding a range, and
/// Undo.
///
/// The state is Today's count, read when the sheet opens
/// (`MediaScanner.countEarlier`), so it works with Shooting mode off. It
/// auto-disposes: closing the sheet drops it, and opening the sheet again
/// counts again. A failed count is an `AsyncError` for the sheet to show; it
/// is logged by type and not retried by itself.
///
/// [countIn], [add] and [undo] **rethrow** their errors, after logging the
/// type, so the sheet can tell the user it did not work (a missing full
/// access is a `StateError`). The caller must catch. After [add] or [undo]
/// succeeds Today's count is read again, and if that fails the old count
/// stays.

@ProviderFor(EarlierVideosController)
final earlierVideosControllerProvider = EarlierVideosControllerProvider._();

/// The "Add earlier videos" sheet (D-73, D-75, D-78): how many videos Today
/// would add, counting the videos of a chosen date range, adding a range, and
/// Undo.
///
/// The state is Today's count, read when the sheet opens
/// (`MediaScanner.countEarlier`), so it works with Shooting mode off. It
/// auto-disposes: closing the sheet drops it, and opening the sheet again
/// counts again. A failed count is an `AsyncError` for the sheet to show; it
/// is logged by type and not retried by itself.
///
/// [countIn], [add] and [undo] **rethrow** their errors, after logging the
/// type, so the sheet can tell the user it did not work (a missing full
/// access is a `StateError`). The caller must catch. After [add] or [undo]
/// succeeds Today's count is read again, and if that fails the old count
/// stays.
final class EarlierVideosControllerProvider
    extends $AsyncNotifierProvider<EarlierVideosController, int> {
  /// The "Add earlier videos" sheet (D-73, D-75, D-78): how many videos Today
  /// would add, counting the videos of a chosen date range, adding a range, and
  /// Undo.
  ///
  /// The state is Today's count, read when the sheet opens
  /// (`MediaScanner.countEarlier`), so it works with Shooting mode off. It
  /// auto-disposes: closing the sheet drops it, and opening the sheet again
  /// counts again. A failed count is an `AsyncError` for the sheet to show; it
  /// is logged by type and not retried by itself.
  ///
  /// [countIn], [add] and [undo] **rethrow** their errors, after logging the
  /// type, so the sheet can tell the user it did not work (a missing full
  /// access is a `StateError`). The caller must catch. After [add] or [undo]
  /// succeeds Today's count is read again, and if that fails the old count
  /// stays.
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
    r'1852eab4220f18b8f5693d471ee4bdf059361d66';

/// The "Add earlier videos" sheet (D-73, D-75, D-78): how many videos Today
/// would add, counting the videos of a chosen date range, adding a range, and
/// Undo.
///
/// The state is Today's count, read when the sheet opens
/// (`MediaScanner.countEarlier`), so it works with Shooting mode off. It
/// auto-disposes: closing the sheet drops it, and opening the sheet again
/// counts again. A failed count is an `AsyncError` for the sheet to show; it
/// is logged by type and not retried by itself.
///
/// [countIn], [add] and [undo] **rethrow** their errors, after logging the
/// type, so the sheet can tell the user it did not work (a missing full
/// access is a `StateError`). The caller must catch. After [add] or [undo]
/// succeeds Today's count is read again, and if that fails the old count
/// stays.

abstract class _$EarlierVideosController extends $AsyncNotifier<int> {
  FutureOr<int> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<int>, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<int>, int>,
              AsyncValue<int>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
