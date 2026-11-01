// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'to_tag_selection.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Choosing clips on To tag (D-98; `app.js`: `startSel`, `toggleSel`,
/// `selScene`, `clearSel`), the way the reel page chooses (`ReelSelection`,
/// D-88):
///
/// - **Only a waiting clip that is not missing can be chosen.** Before the
///   list has been read nothing can be chosen.
/// - **Choosing ends when the last clip is un-chosen** ([toggle]); [begin] is
///   the one way to be choosing with nothing chosen, and [toggleScene] may
///   leave it so (a scene's **Unselect** is not the last tap of a choice).
/// - **It follows the list.** A chosen clip that leaves To tag (a verify
///   takes it out, a scan, the tag player or a Skip tags it) is un-chosen;
///   when that empties a selection that had clips, choosing ends. The ids
///   are never kept for a clip that is gone.
///
/// Auto-disposes with the screen.

@ProviderFor(ToTagSelection)
final toTagSelectionProvider = ToTagSelectionProvider._();

/// Choosing clips on To tag (D-98; `app.js`: `startSel`, `toggleSel`,
/// `selScene`, `clearSel`), the way the reel page chooses (`ReelSelection`,
/// D-88):
///
/// - **Only a waiting clip that is not missing can be chosen.** Before the
///   list has been read nothing can be chosen.
/// - **Choosing ends when the last clip is un-chosen** ([toggle]); [begin] is
///   the one way to be choosing with nothing chosen, and [toggleScene] may
///   leave it so (a scene's **Unselect** is not the last tap of a choice).
/// - **It follows the list.** A chosen clip that leaves To tag (a verify
///   takes it out, a scan, the tag player or a Skip tags it) is un-chosen;
///   when that empties a selection that had clips, choosing ends. The ids
///   are never kept for a clip that is gone.
///
/// Auto-disposes with the screen.
final class ToTagSelectionProvider
    extends $NotifierProvider<ToTagSelection, ToTagSelectionState> {
  /// Choosing clips on To tag (D-98; `app.js`: `startSel`, `toggleSel`,
  /// `selScene`, `clearSel`), the way the reel page chooses (`ReelSelection`,
  /// D-88):
  ///
  /// - **Only a waiting clip that is not missing can be chosen.** Before the
  ///   list has been read nothing can be chosen.
  /// - **Choosing ends when the last clip is un-chosen** ([toggle]); [begin] is
  ///   the one way to be choosing with nothing chosen, and [toggleScene] may
  ///   leave it so (a scene's **Unselect** is not the last tap of a choice).
  /// - **It follows the list.** A chosen clip that leaves To tag (a verify
  ///   takes it out, a scan, the tag player or a Skip tags it) is un-chosen;
  ///   when that empties a selection that had clips, choosing ends. The ids
  ///   are never kept for a clip that is gone.
  ///
  /// Auto-disposes with the screen.
  ToTagSelectionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'toTagSelectionProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$toTagSelectionHash();

  @$internal
  @override
  ToTagSelection create() => ToTagSelection();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ToTagSelectionState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ToTagSelectionState>(value),
    );
  }
}

String _$toTagSelectionHash() => r'0cc1f944ef51f4e7957fe14fb887cba4557689b1';

/// Choosing clips on To tag (D-98; `app.js`: `startSel`, `toggleSel`,
/// `selScene`, `clearSel`), the way the reel page chooses (`ReelSelection`,
/// D-88):
///
/// - **Only a waiting clip that is not missing can be chosen.** Before the
///   list has been read nothing can be chosen.
/// - **Choosing ends when the last clip is un-chosen** ([toggle]); [begin] is
///   the one way to be choosing with nothing chosen, and [toggleScene] may
///   leave it so (a scene's **Unselect** is not the last tap of a choice).
/// - **It follows the list.** A chosen clip that leaves To tag (a verify
///   takes it out, a scan, the tag player or a Skip tags it) is un-chosen;
///   when that empties a selection that had clips, choosing ends. The ids
///   are never kept for a clip that is gone.
///
/// Auto-disposes with the screen.

abstract class _$ToTagSelection extends $Notifier<ToTagSelectionState> {
  ToTagSelectionState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ToTagSelectionState, ToTagSelectionState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ToTagSelectionState, ToTagSelectionState>,
              ToTagSelectionState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
