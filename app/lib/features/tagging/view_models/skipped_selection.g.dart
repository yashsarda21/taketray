// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'skipped_selection.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Choosing clips on the Skipped screen (D-99; `app.js`: `startSelBtn`,
/// `startSel`, `toggleSel`, `clearSel`), as To tag chooses (`ToTagSelection`,
/// D-98):
///
/// - **Only a skipped clip that is not missing can be chosen.** Before the
///   list has been read nothing can be chosen.
/// - **Choosing ends when the last clip is un-chosen** ([toggle]); [begin] is
///   the one way to be choosing with nothing chosen.
/// - **It follows the list.** A chosen clip that leaves Skipped (restored,
///   tagged elsewhere, taken out by a verify) is un-chosen; when that empties
///   a selection that had clips, choosing ends. **When the list itself
///   empties, choosing ends** even with nothing chosen: there is nothing left
///   to choose.
///
/// Auto-disposes with the screen.

@ProviderFor(SkippedSelection)
final skippedSelectionProvider = SkippedSelectionProvider._();

/// Choosing clips on the Skipped screen (D-99; `app.js`: `startSelBtn`,
/// `startSel`, `toggleSel`, `clearSel`), as To tag chooses (`ToTagSelection`,
/// D-98):
///
/// - **Only a skipped clip that is not missing can be chosen.** Before the
///   list has been read nothing can be chosen.
/// - **Choosing ends when the last clip is un-chosen** ([toggle]); [begin] is
///   the one way to be choosing with nothing chosen.
/// - **It follows the list.** A chosen clip that leaves Skipped (restored,
///   tagged elsewhere, taken out by a verify) is un-chosen; when that empties
///   a selection that had clips, choosing ends. **When the list itself
///   empties, choosing ends** even with nothing chosen: there is nothing left
///   to choose.
///
/// Auto-disposes with the screen.
final class SkippedSelectionProvider
    extends $NotifierProvider<SkippedSelection, SkippedSelectionState> {
  /// Choosing clips on the Skipped screen (D-99; `app.js`: `startSelBtn`,
  /// `startSel`, `toggleSel`, `clearSel`), as To tag chooses (`ToTagSelection`,
  /// D-98):
  ///
  /// - **Only a skipped clip that is not missing can be chosen.** Before the
  ///   list has been read nothing can be chosen.
  /// - **Choosing ends when the last clip is un-chosen** ([toggle]); [begin] is
  ///   the one way to be choosing with nothing chosen.
  /// - **It follows the list.** A chosen clip that leaves Skipped (restored,
  ///   tagged elsewhere, taken out by a verify) is un-chosen; when that empties
  ///   a selection that had clips, choosing ends. **When the list itself
  ///   empties, choosing ends** even with nothing chosen: there is nothing left
  ///   to choose.
  ///
  /// Auto-disposes with the screen.
  SkippedSelectionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'skippedSelectionProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$skippedSelectionHash();

  @$internal
  @override
  SkippedSelection create() => SkippedSelection();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SkippedSelectionState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SkippedSelectionState>(value),
    );
  }
}

String _$skippedSelectionHash() => r'4819ec61be891d5e64f7bc82def7c9ed3647a263';

/// Choosing clips on the Skipped screen (D-99; `app.js`: `startSelBtn`,
/// `startSel`, `toggleSel`, `clearSel`), as To tag chooses (`ToTagSelection`,
/// D-98):
///
/// - **Only a skipped clip that is not missing can be chosen.** Before the
///   list has been read nothing can be chosen.
/// - **Choosing ends when the last clip is un-chosen** ([toggle]); [begin] is
///   the one way to be choosing with nothing chosen.
/// - **It follows the list.** A chosen clip that leaves Skipped (restored,
///   tagged elsewhere, taken out by a verify) is un-chosen; when that empties
///   a selection that had clips, choosing ends. **When the list itself
///   empties, choosing ends** even with nothing chosen: there is nothing left
///   to choose.
///
/// Auto-disposes with the screen.

abstract class _$SkippedSelection extends $Notifier<SkippedSelectionState> {
  SkippedSelectionState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<SkippedSelectionState, SkippedSelectionState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SkippedSelectionState, SkippedSelectionState>,
              SkippedSelectionState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
