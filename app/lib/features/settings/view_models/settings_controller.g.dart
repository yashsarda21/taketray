// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The user's settings for the Settings screen (Phase 10B, D-148): the
/// settings now, and again each time they change (`SettingsRepository.watch`).
/// While the first read runs the state is loading; if it fails, an error.
///
/// Every setter is `SettingsRepository.update`: a read-modify-save of the
/// **latest stored** settings in one database transaction, not of the state,
/// which may not have heard of a save made a moment ago. The database runs
/// the updates one after the other, so two quick changes (two switches
/// tapped in the same frame) never overwrite each other, and neither does a
/// change made at the same moment by another screen, such as Watched folders
/// (D-149, ruling R3). A save that fails reaches the caller of that setter
/// only; the calls after it still run.
///
/// The background jobs read the stored settings each time they run, so what
/// is saved here is what they use, even when the app is not opened again
/// (D-145).

@ProviderFor(SettingsController)
final settingsControllerProvider = SettingsControllerProvider._();

/// The user's settings for the Settings screen (Phase 10B, D-148): the
/// settings now, and again each time they change (`SettingsRepository.watch`).
/// While the first read runs the state is loading; if it fails, an error.
///
/// Every setter is `SettingsRepository.update`: a read-modify-save of the
/// **latest stored** settings in one database transaction, not of the state,
/// which may not have heard of a save made a moment ago. The database runs
/// the updates one after the other, so two quick changes (two switches
/// tapped in the same frame) never overwrite each other, and neither does a
/// change made at the same moment by another screen, such as Watched folders
/// (D-149, ruling R3). A save that fails reaches the caller of that setter
/// only; the calls after it still run.
///
/// The background jobs read the stored settings each time they run, so what
/// is saved here is what they use, even when the app is not opened again
/// (D-145).
final class SettingsControllerProvider
    extends $StreamNotifierProvider<SettingsController, AppSettings> {
  /// The user's settings for the Settings screen (Phase 10B, D-148): the
  /// settings now, and again each time they change (`SettingsRepository.watch`).
  /// While the first read runs the state is loading; if it fails, an error.
  ///
  /// Every setter is `SettingsRepository.update`: a read-modify-save of the
  /// **latest stored** settings in one database transaction, not of the state,
  /// which may not have heard of a save made a moment ago. The database runs
  /// the updates one after the other, so two quick changes (two switches
  /// tapped in the same frame) never overwrite each other, and neither does a
  /// change made at the same moment by another screen, such as Watched folders
  /// (D-149, ruling R3). A save that fails reaches the caller of that setter
  /// only; the calls after it still run.
  ///
  /// The background jobs read the stored settings each time they run, so what
  /// is saved here is what they use, even when the app is not opened again
  /// (D-145).
  SettingsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: noRetry,
        name: r'settingsControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$settingsControllerHash();

  @$internal
  @override
  SettingsController create() => SettingsController();
}

String _$settingsControllerHash() =>
    r'a414442ccebe1a68b286b395869803402e479aa0';

/// The user's settings for the Settings screen (Phase 10B, D-148): the
/// settings now, and again each time they change (`SettingsRepository.watch`).
/// While the first read runs the state is loading; if it fails, an error.
///
/// Every setter is `SettingsRepository.update`: a read-modify-save of the
/// **latest stored** settings in one database transaction, not of the state,
/// which may not have heard of a save made a moment ago. The database runs
/// the updates one after the other, so two quick changes (two switches
/// tapped in the same frame) never overwrite each other, and neither does a
/// change made at the same moment by another screen, such as Watched folders
/// (D-149, ruling R3). A save that fails reaches the caller of that setter
/// only; the calls after it still run.
///
/// The background jobs read the stored settings each time they run, so what
/// is saved here is what they use, even when the app is not opened again
/// (D-145).

abstract class _$SettingsController extends $StreamNotifier<AppSettings> {
  Stream<AppSettings> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<AppSettings>, AppSettings>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<AppSettings>, AppSettings>,
              AsyncValue<AppSettings>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// When a backup file was last saved on this phone, or null (none, or not
/// readable), for the Export and import row. Read again when the backup
/// screen is left (`ref.invalidate`).

@ProviderFor(lastExport)
final lastExportProvider = LastExportProvider._();

/// When a backup file was last saved on this phone, or null (none, or not
/// readable), for the Export and import row. Read again when the backup
/// screen is left (`ref.invalidate`).

final class LastExportProvider
    extends
        $FunctionalProvider<
          AsyncValue<DateTime?>,
          DateTime?,
          FutureOr<DateTime?>
        >
    with $FutureModifier<DateTime?>, $FutureProvider<DateTime?> {
  /// When a backup file was last saved on this phone, or null (none, or not
  /// readable), for the Export and import row. Read again when the backup
  /// screen is left (`ref.invalidate`).
  LastExportProvider._()
    : super(
        from: null,
        argument: null,
        retry: noRetry,
        name: r'lastExportProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$lastExportHash();

  @$internal
  @override
  $FutureProviderElement<DateTime?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<DateTime?> create(Ref ref) {
    return lastExport(ref);
  }
}

String _$lastExportHash() => r'47030d8e03abc81f1d7c7bf5b1dbc3e21ec57c45';

/// The app's version and Android's release, for the About row. Read once; an
/// error is the state ("Version" alone is shown).

@ProviderFor(appInfo)
final appInfoProvider = AppInfoProvider._();

/// The app's version and Android's release, for the About row. Read once; an
/// error is the state ("Version" alone is shown).

final class AppInfoProvider
    extends $FunctionalProvider<AsyncValue<AppInfo>, AppInfo, FutureOr<AppInfo>>
    with $FutureModifier<AppInfo>, $FutureProvider<AppInfo> {
  /// The app's version and Android's release, for the About row. Read once; an
  /// error is the state ("Version" alone is shown).
  AppInfoProvider._()
    : super(
        from: null,
        argument: null,
        retry: noRetry,
        name: r'appInfoProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appInfoHash();

  @$internal
  @override
  $FutureProviderElement<AppInfo> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<AppInfo> create(Ref ref) {
    return appInfo(ref);
  }
}

String _$appInfoHash() => r'3d4d88222ae8d6218548cee1d4ebf9c98efe0a32';
