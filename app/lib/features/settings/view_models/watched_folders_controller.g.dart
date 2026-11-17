// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'watched_folders_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The folders on the phone, read once for each access level and not again
/// for each switch (a toggle changes the settings, not the phone). Read only
/// with full access (`MediaAccessController`); a failed read is logged by
/// type and leaves [PhoneFolders.folders] null. A first access read that
/// failed counts as no full access.

@ProviderFor(phoneFolders)
final phoneFoldersProvider = PhoneFoldersProvider._();

/// The folders on the phone, read once for each access level and not again
/// for each switch (a toggle changes the settings, not the phone). Read only
/// with full access (`MediaAccessController`); a failed read is logged by
/// type and leaves [PhoneFolders.folders] null. A first access read that
/// failed counts as no full access.

final class PhoneFoldersProvider
    extends
        $FunctionalProvider<
          AsyncValue<PhoneFolders>,
          PhoneFolders,
          FutureOr<PhoneFolders>
        >
    with $FutureModifier<PhoneFolders>, $FutureProvider<PhoneFolders> {
  /// The folders on the phone, read once for each access level and not again
  /// for each switch (a toggle changes the settings, not the phone). Read only
  /// with full access (`MediaAccessController`); a failed read is logged by
  /// type and leaves [PhoneFolders.folders] null. A first access read that
  /// failed counts as no full access.
  PhoneFoldersProvider._()
    : super(
        from: null,
        argument: null,
        retry: noRetry,
        name: r'phoneFoldersProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$phoneFoldersHash();

  @$internal
  @override
  $FutureProviderElement<PhoneFolders> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<PhoneFolders> create(Ref ref) {
    return phoneFolders(ref);
  }
}

String _$phoneFoldersHash() => r'58d58b52688a636b421a8e6e798238048930c41a';

/// The Watched folders screen (D-149): every folder on the phone with
/// videos, with its switch, plus every watched path that is not on the phone
/// now. The state follows the settings and the access.
///
/// - **With full access:** the rows are the Add videos list
///   (`browseFolders`: no empty folder, no WhatsApp Sent folder, no
///   `Movies/TakeTray/`), in its order; then each watched folder that the
///   list does not show, in the order they are watched: one that is on the
///   phone but hidden shows with its count, one that is not is
///   [WatchedRow.gone] with an unknown count, so it can still be turned
///   off. A volume root is never listed: its videos have no folder, so
///   watching it finds none.
/// - **Without it** (limited, denied, or the read failed): only the watched
///   paths, with no count, none of them gone: TakeTray cannot tell.
/// - **One folder, one row, however it is spelled:** a path is compared
///   without slashes at either end and ignoring A to Z case, and the phone's
///   storage and its SD card, which a relative path cannot tell apart, give
///   one row with their counts added.
///
/// Changes go through `SettingsRepository.update`, so a folder turned on here
/// and a switch turned off in Settings in the same frame both stay (D-149,
/// ruling R3).

@ProviderFor(WatchedFoldersController)
final watchedFoldersControllerProvider = WatchedFoldersControllerProvider._();

/// The Watched folders screen (D-149): every folder on the phone with
/// videos, with its switch, plus every watched path that is not on the phone
/// now. The state follows the settings and the access.
///
/// - **With full access:** the rows are the Add videos list
///   (`browseFolders`: no empty folder, no WhatsApp Sent folder, no
///   `Movies/TakeTray/`), in its order; then each watched folder that the
///   list does not show, in the order they are watched: one that is on the
///   phone but hidden shows with its count, one that is not is
///   [WatchedRow.gone] with an unknown count, so it can still be turned
///   off. A volume root is never listed: its videos have no folder, so
///   watching it finds none.
/// - **Without it** (limited, denied, or the read failed): only the watched
///   paths, with no count, none of them gone: TakeTray cannot tell.
/// - **One folder, one row, however it is spelled:** a path is compared
///   without slashes at either end and ignoring A to Z case, and the phone's
///   storage and its SD card, which a relative path cannot tell apart, give
///   one row with their counts added.
///
/// Changes go through `SettingsRepository.update`, so a folder turned on here
/// and a switch turned off in Settings in the same frame both stay (D-149,
/// ruling R3).
final class WatchedFoldersControllerProvider
    extends
        $AsyncNotifierProvider<WatchedFoldersController, WatchedFoldersView> {
  /// The Watched folders screen (D-149): every folder on the phone with
  /// videos, with its switch, plus every watched path that is not on the phone
  /// now. The state follows the settings and the access.
  ///
  /// - **With full access:** the rows are the Add videos list
  ///   (`browseFolders`: no empty folder, no WhatsApp Sent folder, no
  ///   `Movies/TakeTray/`), in its order; then each watched folder that the
  ///   list does not show, in the order they are watched: one that is on the
  ///   phone but hidden shows with its count, one that is not is
  ///   [WatchedRow.gone] with an unknown count, so it can still be turned
  ///   off. A volume root is never listed: its videos have no folder, so
  ///   watching it finds none.
  /// - **Without it** (limited, denied, or the read failed): only the watched
  ///   paths, with no count, none of them gone: TakeTray cannot tell.
  /// - **One folder, one row, however it is spelled:** a path is compared
  ///   without slashes at either end and ignoring A to Z case, and the phone's
  ///   storage and its SD card, which a relative path cannot tell apart, give
  ///   one row with their counts added.
  ///
  /// Changes go through `SettingsRepository.update`, so a folder turned on here
  /// and a switch turned off in Settings in the same frame both stay (D-149,
  /// ruling R3).
  WatchedFoldersControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: noRetry,
        name: r'watchedFoldersControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$watchedFoldersControllerHash();

  @$internal
  @override
  WatchedFoldersController create() => WatchedFoldersController();
}

String _$watchedFoldersControllerHash() =>
    r'fc0ff3cb31cde1d7e23ebc168cb37b2e00b5cd8a';

/// The Watched folders screen (D-149): every folder on the phone with
/// videos, with its switch, plus every watched path that is not on the phone
/// now. The state follows the settings and the access.
///
/// - **With full access:** the rows are the Add videos list
///   (`browseFolders`: no empty folder, no WhatsApp Sent folder, no
///   `Movies/TakeTray/`), in its order; then each watched folder that the
///   list does not show, in the order they are watched: one that is on the
///   phone but hidden shows with its count, one that is not is
///   [WatchedRow.gone] with an unknown count, so it can still be turned
///   off. A volume root is never listed: its videos have no folder, so
///   watching it finds none.
/// - **Without it** (limited, denied, or the read failed): only the watched
///   paths, with no count, none of them gone: TakeTray cannot tell.
/// - **One folder, one row, however it is spelled:** a path is compared
///   without slashes at either end and ignoring A to Z case, and the phone's
///   storage and its SD card, which a relative path cannot tell apart, give
///   one row with their counts added.
///
/// Changes go through `SettingsRepository.update`, so a folder turned on here
/// and a switch turned off in Settings in the same frame both stay (D-149,
/// ruling R3).

abstract class _$WatchedFoldersController
    extends $AsyncNotifier<WatchedFoldersView> {
  FutureOr<WatchedFoldersView> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<WatchedFoldersView>, WatchedFoldersView>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<WatchedFoldersView>, WatchedFoldersView>,
              AsyncValue<WatchedFoldersView>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
