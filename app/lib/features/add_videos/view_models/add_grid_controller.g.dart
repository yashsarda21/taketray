// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'add_grid_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// One folder of one volume in Add videos' grid, for an add to [target]
/// (D-114, Review Focus 1).
///
/// - **Pages.** The first [addGridPageSize] videos are read when the grid
///   opens; [loadMore] reads the next page (the screen asks near the end of
///   what is shown). Only one page is read at a time. A page that repeats a
///   video already shown (a video arrived meanwhile and pushed the rest down)
///   adds it once. A page with fewer than [addGridPageSize] is the last.
/// - **Marks** are read with each page (`AddVideosService.marks`), before its
///   videos show, so a video is never pickable and then marked. Marks that
///   cannot be read leave the page unmarked (logged by type): the add decides
///   each video again.
/// - **The choice** ([toggle]) survives paging; a marked video, or one not
///   in the grid, cannot be picked; nothing changes while an add runs.
/// - **[refresh]** (the app comes back to the front) reads again as many
///   rows as were read, keeps what is still picked, and drops a picked video
///   that is gone or now marked. A page that was being read when a refresh
///   started is dropped when it arrives.
/// - **[add]** adds the picked videos, oldest first, once: a second call
///   while one runs does nothing.

@ProviderFor(AddGridController)
final addGridControllerProvider = AddGridControllerFamily._();

/// One folder of one volume in Add videos' grid, for an add to [target]
/// (D-114, Review Focus 1).
///
/// - **Pages.** The first [addGridPageSize] videos are read when the grid
///   opens; [loadMore] reads the next page (the screen asks near the end of
///   what is shown). Only one page is read at a time. A page that repeats a
///   video already shown (a video arrived meanwhile and pushed the rest down)
///   adds it once. A page with fewer than [addGridPageSize] is the last.
/// - **Marks** are read with each page (`AddVideosService.marks`), before its
///   videos show, so a video is never pickable and then marked. Marks that
///   cannot be read leave the page unmarked (logged by type): the add decides
///   each video again.
/// - **The choice** ([toggle]) survives paging; a marked video, or one not
///   in the grid, cannot be picked; nothing changes while an add runs.
/// - **[refresh]** (the app comes back to the front) reads again as many
///   rows as were read, keeps what is still picked, and drops a picked video
///   that is gone or now marked. A page that was being read when a refresh
///   started is dropped when it arrives.
/// - **[add]** adds the picked videos, oldest first, once: a second call
///   while one runs does nothing.
final class AddGridControllerProvider
    extends $AsyncNotifierProvider<AddGridController, AddGridState> {
  /// One folder of one volume in Add videos' grid, for an add to [target]
  /// (D-114, Review Focus 1).
  ///
  /// - **Pages.** The first [addGridPageSize] videos are read when the grid
  ///   opens; [loadMore] reads the next page (the screen asks near the end of
  ///   what is shown). Only one page is read at a time. A page that repeats a
  ///   video already shown (a video arrived meanwhile and pushed the rest down)
  ///   adds it once. A page with fewer than [addGridPageSize] is the last.
  /// - **Marks** are read with each page (`AddVideosService.marks`), before its
  ///   videos show, so a video is never pickable and then marked. Marks that
  ///   cannot be read leave the page unmarked (logged by type): the add decides
  ///   each video again.
  /// - **The choice** ([toggle]) survives paging; a marked video, or one not
  ///   in the grid, cannot be picked; nothing changes while an add runs.
  /// - **[refresh]** (the app comes back to the front) reads again as many
  ///   rows as were read, keeps what is still picked, and drops a picked video
  ///   that is gone or now marked. A page that was being read when a refresh
  ///   started is dropped when it arrives.
  /// - **[add]** adds the picked videos, oldest first, once: a second call
  ///   while one runs does nothing.
  AddGridControllerProvider._({
    required AddGridControllerFamily super.from,
    required (AddTarget, String, String) super.argument,
  }) : super(
         retry: noRetry,
         name: r'addGridControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$addGridControllerHash();

  @override
  String toString() {
    return r'addGridControllerProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  AddGridController create() => AddGridController();

  @override
  bool operator ==(Object other) {
    return other is AddGridControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$addGridControllerHash() => r'667b20ab87d719643fdd1d4d87b77c8cbbeeb9e7';

/// One folder of one volume in Add videos' grid, for an add to [target]
/// (D-114, Review Focus 1).
///
/// - **Pages.** The first [addGridPageSize] videos are read when the grid
///   opens; [loadMore] reads the next page (the screen asks near the end of
///   what is shown). Only one page is read at a time. A page that repeats a
///   video already shown (a video arrived meanwhile and pushed the rest down)
///   adds it once. A page with fewer than [addGridPageSize] is the last.
/// - **Marks** are read with each page (`AddVideosService.marks`), before its
///   videos show, so a video is never pickable and then marked. Marks that
///   cannot be read leave the page unmarked (logged by type): the add decides
///   each video again.
/// - **The choice** ([toggle]) survives paging; a marked video, or one not
///   in the grid, cannot be picked; nothing changes while an add runs.
/// - **[refresh]** (the app comes back to the front) reads again as many
///   rows as were read, keeps what is still picked, and drops a picked video
///   that is gone or now marked. A page that was being read when a refresh
///   started is dropped when it arrives.
/// - **[add]** adds the picked videos, oldest first, once: a second call
///   while one runs does nothing.

final class AddGridControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          AddGridController,
          AsyncValue<AddGridState>,
          AddGridState,
          FutureOr<AddGridState>,
          (AddTarget, String, String)
        > {
  AddGridControllerFamily._()
    : super(
        retry: noRetry,
        name: r'addGridControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// One folder of one volume in Add videos' grid, for an add to [target]
  /// (D-114, Review Focus 1).
  ///
  /// - **Pages.** The first [addGridPageSize] videos are read when the grid
  ///   opens; [loadMore] reads the next page (the screen asks near the end of
  ///   what is shown). Only one page is read at a time. A page that repeats a
  ///   video already shown (a video arrived meanwhile and pushed the rest down)
  ///   adds it once. A page with fewer than [addGridPageSize] is the last.
  /// - **Marks** are read with each page (`AddVideosService.marks`), before its
  ///   videos show, so a video is never pickable and then marked. Marks that
  ///   cannot be read leave the page unmarked (logged by type): the add decides
  ///   each video again.
  /// - **The choice** ([toggle]) survives paging; a marked video, or one not
  ///   in the grid, cannot be picked; nothing changes while an add runs.
  /// - **[refresh]** (the app comes back to the front) reads again as many
  ///   rows as were read, keeps what is still picked, and drops a picked video
  ///   that is gone or now marked. A page that was being read when a refresh
  ///   started is dropped when it arrives.
  /// - **[add]** adds the picked videos, oldest first, once: a second call
  ///   while one runs does nothing.

  AddGridControllerProvider call(
    AddTarget target,
    String volumeName,
    String relativePath,
  ) => AddGridControllerProvider._(
    argument: (target, volumeName, relativePath),
    from: this,
  );

  @override
  String toString() => r'addGridControllerProvider';
}

/// One folder of one volume in Add videos' grid, for an add to [target]
/// (D-114, Review Focus 1).
///
/// - **Pages.** The first [addGridPageSize] videos are read when the grid
///   opens; [loadMore] reads the next page (the screen asks near the end of
///   what is shown). Only one page is read at a time. A page that repeats a
///   video already shown (a video arrived meanwhile and pushed the rest down)
///   adds it once. A page with fewer than [addGridPageSize] is the last.
/// - **Marks** are read with each page (`AddVideosService.marks`), before its
///   videos show, so a video is never pickable and then marked. Marks that
///   cannot be read leave the page unmarked (logged by type): the add decides
///   each video again.
/// - **The choice** ([toggle]) survives paging; a marked video, or one not
///   in the grid, cannot be picked; nothing changes while an add runs.
/// - **[refresh]** (the app comes back to the front) reads again as many
///   rows as were read, keeps what is still picked, and drops a picked video
///   that is gone or now marked. A page that was being read when a refresh
///   started is dropped when it arrives.
/// - **[add]** adds the picked videos, oldest first, once: a second call
///   while one runs does nothing.

abstract class _$AddGridController extends $AsyncNotifier<AddGridState> {
  late final _$args = ref.$arg as (AddTarget, String, String);
  AddTarget get target => _$args.$1;
  String get volumeName => _$args.$2;
  String get relativePath => _$args.$3;

  FutureOr<AddGridState> build(
    AddTarget target,
    String volumeName,
    String relativePath,
  );
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<AddGridState>, AddGridState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<AddGridState>, AddGridState>,
              AsyncValue<AddGridState>,
              Object?,
              Object?
            >;
    return element.handleCreate(
      ref,
      () => build(_$args.$1, _$args.$2, _$args.$3),
    );
  }
}
