// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'send_log.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Where the log files are: the folder `main` gave `runAppWithLogging`
/// (`getApplicationSupportDirectory`).

@ProviderFor(logDirectory)
final logDirectoryProvider = LogDirectoryProvider._();

/// Where the log files are: the folder `main` gave `runAppWithLogging`
/// (`getApplicationSupportDirectory`).

final class LogDirectoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<Directory>,
          Directory,
          FutureOr<Directory>
        >
    with $FutureModifier<Directory>, $FutureProvider<Directory> {
  /// Where the log files are: the folder `main` gave `runAppWithLogging`
  /// (`getApplicationSupportDirectory`).
  LogDirectoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: noRetry,
        name: r'logDirectoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$logDirectoryHash();

  @$internal
  @override
  $FutureProviderElement<Directory> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Directory> create(Ref ref) {
    return logDirectory(ref);
  }
}

String _$logDirectoryHash() => r'3a1a72e92a8330d287a017b6e266bbce788d8abb';

/// The phone's cache folder. `getTemporaryDirectory` is
/// `Context.getCacheDir()` on Android, the folder the files bridge shares
/// from (`<cacheDir>/shared/`, D-147).

@ProviderFor(cacheDirectory)
final cacheDirectoryProvider = CacheDirectoryProvider._();

/// The phone's cache folder. `getTemporaryDirectory` is
/// `Context.getCacheDir()` on Android, the folder the files bridge shares
/// from (`<cacheDir>/shared/`, D-147).

final class CacheDirectoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<Directory>,
          Directory,
          FutureOr<Directory>
        >
    with $FutureModifier<Directory>, $FutureProvider<Directory> {
  /// The phone's cache folder. `getTemporaryDirectory` is
  /// `Context.getCacheDir()` on Android, the folder the files bridge shares
  /// from (`<cacheDir>/shared/`, D-147).
  CacheDirectoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: noRetry,
        name: r'cacheDirectoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cacheDirectoryHash();

  @$internal
  @override
  $FutureProviderElement<Directory> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Directory> create(Ref ref) {
    return cacheDirectory(ref);
  }
}

String _$cacheDirectoryHash() => r'4e92fa8b0dee1892cd3376f20dd9a5f90b51b6e1';

@ProviderFor(sendLog)
final sendLogProvider = SendLogProvider._();

final class SendLogProvider
    extends $FunctionalProvider<SendLog, SendLog, SendLog>
    with $Provider<SendLog> {
  SendLogProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sendLogProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sendLogHash();

  @$internal
  @override
  $ProviderElement<SendLog> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SendLog create(Ref ref) {
    return sendLog(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SendLog value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SendLog>(value),
    );
  }
}

String _$sendLogHash() => r'611a4c7b8258b71a52ef479259c05370ac88214c';
