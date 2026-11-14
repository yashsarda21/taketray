// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'copies_storage_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Every editing session, now and after every change to sessions, copies or
/// reels (`EditSessionsRepository.watchSummaries`).

@ProviderFor(editSessionSummaries)
final editSessionSummariesProvider = EditSessionSummariesProvider._();

/// Every editing session, now and after every change to sessions, copies or
/// reels (`EditSessionsRepository.watchSummaries`).

final class EditSessionSummariesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<EditSessionSummary>>,
          List<EditSessionSummary>,
          Stream<List<EditSessionSummary>>
        >
    with
        $FutureModifier<List<EditSessionSummary>>,
        $StreamProvider<List<EditSessionSummary>> {
  /// Every editing session, now and after every change to sessions, copies or
  /// reels (`EditSessionsRepository.watchSummaries`).
  EditSessionSummariesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'editSessionSummariesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$editSessionSummariesHash();

  @$internal
  @override
  $StreamProviderElement<List<EditSessionSummary>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<EditSessionSummary>> create(Ref ref) {
    return editSessionSummaries(ref);
  }
}

String _$editSessionSummariesHash() =>
    r'5f62ad4c491608ae71a44e41d10597ea103424d7';

/// The summary of the sessions' copies, for Settings. It reads the database
/// only (no MediaStore), so the Settings tab stays cheap.

@ProviderFor(copiesSummary)
final copiesSummaryProvider = CopiesSummaryProvider._();

/// The summary of the sessions' copies, for Settings. It reads the database
/// only (no MediaStore), so the Settings tab stays cheap.

final class CopiesSummaryProvider
    extends
        $FunctionalProvider<
          AsyncValue<CopiesSummary>,
          CopiesSummary,
          Stream<CopiesSummary>
        >
    with $FutureModifier<CopiesSummary>, $StreamProvider<CopiesSummary> {
  /// The summary of the sessions' copies, for Settings. It reads the database
  /// only (no MediaStore), so the Settings tab stays cheap.
  CopiesSummaryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'copiesSummaryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$copiesSummaryHash();

  @$internal
  @override
  $StreamProviderElement<CopiesSummary> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<CopiesSummary> create(Ref ref) {
    return copiesSummary(ref);
  }
}

String _$copiesSummaryHash() => r'ef31290815e01fb8ccc8c9d033dc06e5bd94328d';

/// The VN copies screen's data (D-130): `EditSessionService.storage()` (every
/// session and the files no session records), the sessions that hold copies
/// newest first, and each reel's cover joined by reel id from
/// `ReelSummary.cover` (the movie icon when it has none or the covers cannot
/// be read).
///
/// It reads again when a session, a copy or a reel changes (so a Done editing
/// from anywhere shows at once) and on [refresh] (the screen calls it when the
/// app comes back to the front: the folders may have changed outside
/// TakeTray). While it reads again the last state stays. An error is the
/// state when `storage()` fails; **Try again** is [refresh].
///
/// Auto-disposes with the screen.

@ProviderFor(CopiesStorageController)
final copiesStorageControllerProvider = CopiesStorageControllerProvider._();

/// The VN copies screen's data (D-130): `EditSessionService.storage()` (every
/// session and the files no session records), the sessions that hold copies
/// newest first, and each reel's cover joined by reel id from
/// `ReelSummary.cover` (the movie icon when it has none or the covers cannot
/// be read).
///
/// It reads again when a session, a copy or a reel changes (so a Done editing
/// from anywhere shows at once) and on [refresh] (the screen calls it when the
/// app comes back to the front: the folders may have changed outside
/// TakeTray). While it reads again the last state stays. An error is the
/// state when `storage()` fails; **Try again** is [refresh].
///
/// Auto-disposes with the screen.
final class CopiesStorageControllerProvider
    extends
        $AsyncNotifierProvider<CopiesStorageController, CopiesStorageState> {
  /// The VN copies screen's data (D-130): `EditSessionService.storage()` (every
  /// session and the files no session records), the sessions that hold copies
  /// newest first, and each reel's cover joined by reel id from
  /// `ReelSummary.cover` (the movie icon when it has none or the covers cannot
  /// be read).
  ///
  /// It reads again when a session, a copy or a reel changes (so a Done editing
  /// from anywhere shows at once) and on [refresh] (the screen calls it when the
  /// app comes back to the front: the folders may have changed outside
  /// TakeTray). While it reads again the last state stays. An error is the
  /// state when `storage()` fails; **Try again** is [refresh].
  ///
  /// Auto-disposes with the screen.
  CopiesStorageControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: noRetry,
        name: r'copiesStorageControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$copiesStorageControllerHash();

  @$internal
  @override
  CopiesStorageController create() => CopiesStorageController();
}

String _$copiesStorageControllerHash() =>
    r'b4eee03c740f2070bbb2262dbf5b69555b47b75b';

/// The VN copies screen's data (D-130): `EditSessionService.storage()` (every
/// session and the files no session records), the sessions that hold copies
/// newest first, and each reel's cover joined by reel id from
/// `ReelSummary.cover` (the movie icon when it has none or the covers cannot
/// be read).
///
/// It reads again when a session, a copy or a reel changes (so a Done editing
/// from anywhere shows at once) and on [refresh] (the screen calls it when the
/// app comes back to the front: the folders may have changed outside
/// TakeTray). While it reads again the last state stays. An error is the
/// state when `storage()` fails; **Try again** is [refresh].
///
/// Auto-disposes with the screen.

abstract class _$CopiesStorageController
    extends $AsyncNotifier<CopiesStorageState> {
  FutureOr<CopiesStorageState> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<CopiesStorageState>, CopiesStorageState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<CopiesStorageState>, CopiesStorageState>,
              AsyncValue<CopiesStorageState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
