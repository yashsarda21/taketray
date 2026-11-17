// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'files_bridge.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(filesBridge)
final filesBridgeProvider = FilesBridgeProvider._();

final class FilesBridgeProvider
    extends $FunctionalProvider<FilesBridge, FilesBridge, FilesBridge>
    with $Provider<FilesBridge> {
  FilesBridgeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'filesBridgeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$filesBridgeHash();

  @$internal
  @override
  $ProviderElement<FilesBridge> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  FilesBridge create(Ref ref) {
    return filesBridge(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FilesBridge value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FilesBridge>(value),
    );
  }
}

String _$filesBridgeHash() => r'50ec083af22a5055375d0e508116f949e498b41a';
