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
