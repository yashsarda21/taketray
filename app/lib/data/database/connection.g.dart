// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'connection.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The engine's database, `taketray.sqlite` in the app's private storage.
///
/// It stays open for the engine's lifetime and is closed when the provider
/// container is disposed. Tests use `testDatabase()` instead.

@ProviderFor(appDatabase)
final appDatabaseProvider = AppDatabaseProvider._();

/// The engine's database, `taketray.sqlite` in the app's private storage.
///
/// It stays open for the engine's lifetime and is closed when the provider
/// container is disposed. Tests use `testDatabase()` instead.

final class AppDatabaseProvider
    extends $FunctionalProvider<AppDatabase, AppDatabase, AppDatabase>
    with $Provider<AppDatabase> {
  /// The engine's database, `taketray.sqlite` in the app's private storage.
  ///
  /// It stays open for the engine's lifetime and is closed when the provider
  /// container is disposed. Tests use `testDatabase()` instead.
  AppDatabaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appDatabaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appDatabaseHash();

  @$internal
  @override
  $ProviderElement<AppDatabase> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppDatabase create(Ref ref) {
    return appDatabase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppDatabase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppDatabase>(value),
    );
  }
}

String _$appDatabaseHash() => r'460a807699ca70235886d5be2423e8778ee80c4c';
