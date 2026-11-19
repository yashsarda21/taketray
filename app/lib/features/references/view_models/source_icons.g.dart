// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'source_icons.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Each source's own app icon as PNG bytes, for the sources whose app is
/// installed (D-155). Never a drawn logo: a source with no installed app is
/// left out, and the card shows the generic link symbol.
///
/// Asks the phone once for the life of the app. A source maps to the icon of
/// its first installed package (in [sourceAppPackages] order) that gave one.
/// When asking fails the map is empty, and the error type is logged.

@ProviderFor(sourceIcons)
final sourceIconsProvider = SourceIconsProvider._();

/// Each source's own app icon as PNG bytes, for the sources whose app is
/// installed (D-155). Never a drawn logo: a source with no installed app is
/// left out, and the card shows the generic link symbol.
///
/// Asks the phone once for the life of the app. A source maps to the icon of
/// its first installed package (in [sourceAppPackages] order) that gave one.
/// When asking fails the map is empty, and the error type is logged.

final class SourceIconsProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<ReferenceSource, Uint8List>>,
          Map<ReferenceSource, Uint8List>,
          FutureOr<Map<ReferenceSource, Uint8List>>
        >
    with
        $FutureModifier<Map<ReferenceSource, Uint8List>>,
        $FutureProvider<Map<ReferenceSource, Uint8List>> {
  /// Each source's own app icon as PNG bytes, for the sources whose app is
  /// installed (D-155). Never a drawn logo: a source with no installed app is
  /// left out, and the card shows the generic link symbol.
  ///
  /// Asks the phone once for the life of the app. A source maps to the icon of
  /// its first installed package (in [sourceAppPackages] order) that gave one.
  /// When asking fails the map is empty, and the error type is logged.
  SourceIconsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sourceIconsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sourceIconsHash();

  @$internal
  @override
  $FutureProviderElement<Map<ReferenceSource, Uint8List>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<ReferenceSource, Uint8List>> create(Ref ref) {
    return sourceIcons(ref);
  }
}

String _$sourceIconsHash() => r'288b42876e1e038c4ba2a22c4df14f6a5453492d';
