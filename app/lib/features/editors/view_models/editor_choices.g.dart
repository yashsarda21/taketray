// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'editor_choices.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The editors for the editor sheet, in [EditorApp] order, installed or not
/// (`EditSessionService.editorChoices`).
///
/// When asking the phone fails, all three are shown as installed and with no
/// icon, so the sheet is never stuck: a tap on one that is missing ends in
/// the share's own "not installed" answer. Refresh it with `ref.invalidate`
/// (after such an answer). Auto-disposes with the sheet.

@ProviderFor(editorChoices)
final editorChoicesProvider = EditorChoicesProvider._();

/// The editors for the editor sheet, in [EditorApp] order, installed or not
/// (`EditSessionService.editorChoices`).
///
/// When asking the phone fails, all three are shown as installed and with no
/// icon, so the sheet is never stuck: a tap on one that is missing ends in
/// the share's own "not installed" answer. Refresh it with `ref.invalidate`
/// (after such an answer). Auto-disposes with the sheet.

final class EditorChoicesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<EditorChoice>>,
          List<EditorChoice>,
          FutureOr<List<EditorChoice>>
        >
    with
        $FutureModifier<List<EditorChoice>>,
        $FutureProvider<List<EditorChoice>> {
  /// The editors for the editor sheet, in [EditorApp] order, installed or not
  /// (`EditSessionService.editorChoices`).
  ///
  /// When asking the phone fails, all three are shown as installed and with no
  /// icon, so the sheet is never stuck: a tap on one that is missing ends in
  /// the share's own "not installed" answer. Refresh it with `ref.invalidate`
  /// (after such an answer). Auto-disposes with the sheet.
  EditorChoicesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'editorChoicesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$editorChoicesHash();

  @$internal
  @override
  $FutureProviderElement<List<EditorChoice>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<EditorChoice>> create(Ref ref) {
    return editorChoices(ref);
  }
}

String _$editorChoicesHash() => r'85e507fd997a0ac8624a46cbe99bd88d8683dfb3';

/// The row of the editor sheet used last on this phone (`lastEditor`, D-189),
/// or null when none was, or when it cannot be read: a failed read is logged
/// by the error's type and the sheet shows its default order. The sheet is
/// opened only after this is read (`showEditorSheet`), so its first frame has
/// the order; the provider auto-disposes, so each opening reads it again.

@ProviderFor(lastEditor)
final lastEditorProvider = LastEditorProvider._();

/// The row of the editor sheet used last on this phone (`lastEditor`, D-189),
/// or null when none was, or when it cannot be read: a failed read is logged
/// by the error's type and the sheet shows its default order. The sheet is
/// opened only after this is read (`showEditorSheet`), so its first frame has
/// the order; the provider auto-disposes, so each opening reads it again.

final class LastEditorProvider
    extends
        $FunctionalProvider<
          AsyncValue<EditorPick?>,
          EditorPick?,
          FutureOr<EditorPick?>
        >
    with $FutureModifier<EditorPick?>, $FutureProvider<EditorPick?> {
  /// The row of the editor sheet used last on this phone (`lastEditor`, D-189),
  /// or null when none was, or when it cannot be read: a failed read is logged
  /// by the error's type and the sheet shows its default order. The sheet is
  /// opened only after this is read (`showEditorSheet`), so its first frame has
  /// the order; the provider auto-disposes, so each opening reads it again.
  LastEditorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'lastEditorProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$lastEditorHash();

  @$internal
  @override
  $FutureProviderElement<EditorPick?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<EditorPick?> create(Ref ref) {
    return lastEditor(ref);
  }
}

String _$lastEditorHash() => r'565aa47386b274995f091de2353247f387b9cbe9';
