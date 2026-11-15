// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'editors_bridge.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The app's [EditorsBridge]; tests override it with `FakeEditorsBridge`.

@ProviderFor(editorsBridge)
final editorsBridgeProvider = EditorsBridgeProvider._();

/// The app's [EditorsBridge]; tests override it with `FakeEditorsBridge`.

final class EditorsBridgeProvider
    extends $FunctionalProvider<EditorsBridge, EditorsBridge, EditorsBridge>
    with $Provider<EditorsBridge> {
  /// The app's [EditorsBridge]; tests override it with `FakeEditorsBridge`.
  EditorsBridgeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'editorsBridgeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$editorsBridgeHash();

  @$internal
  @override
  $ProviderElement<EditorsBridge> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  EditorsBridge create(Ref ref) {
    return editorsBridge(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EditorsBridge value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EditorsBridge>(value),
    );
  }
}

String _$editorsBridgeHash() => r'4a956ffa89e569f2afcb7ee974fde4f3d68c0a97';
