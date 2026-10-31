// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reel_selection.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Choosing clips on reel [reelId]'s page (D-88; `app.js`: `startSel`,
/// `toggleSel`, `selAll`, `clearSel`).
///
/// - **Only a clip that is in this reel and not missing can be chosen.** A
///   missing tile is not selectable, and [selectAll] skips them. Before the
///   reel's clips have been read nothing can be chosen.
/// - **Choosing ends when the last clip is un-chosen** ([toggle]), as
///   `toggleSel` does; [begin] is the one way to be choosing with nothing
///   chosen.
/// - **It follows the reel's clips.** A chosen clip that goes missing, or
///   leaves the reel, is un-chosen; when that empties a selection that had
///   clips, choosing ends.
///
/// Auto-disposes with the page.

@ProviderFor(ReelSelection)
final reelSelectionProvider = ReelSelectionFamily._();

/// Choosing clips on reel [reelId]'s page (D-88; `app.js`: `startSel`,
/// `toggleSel`, `selAll`, `clearSel`).
///
/// - **Only a clip that is in this reel and not missing can be chosen.** A
///   missing tile is not selectable, and [selectAll] skips them. Before the
///   reel's clips have been read nothing can be chosen.
/// - **Choosing ends when the last clip is un-chosen** ([toggle]), as
///   `toggleSel` does; [begin] is the one way to be choosing with nothing
///   chosen.
/// - **It follows the reel's clips.** A chosen clip that goes missing, or
///   leaves the reel, is un-chosen; when that empties a selection that had
///   clips, choosing ends.
///
/// Auto-disposes with the page.
final class ReelSelectionProvider
    extends $NotifierProvider<ReelSelection, ReelSelectionState> {
  /// Choosing clips on reel [reelId]'s page (D-88; `app.js`: `startSel`,
  /// `toggleSel`, `selAll`, `clearSel`).
  ///
  /// - **Only a clip that is in this reel and not missing can be chosen.** A
  ///   missing tile is not selectable, and [selectAll] skips them. Before the
  ///   reel's clips have been read nothing can be chosen.
  /// - **Choosing ends when the last clip is un-chosen** ([toggle]), as
  ///   `toggleSel` does; [begin] is the one way to be choosing with nothing
  ///   chosen.
  /// - **It follows the reel's clips.** A chosen clip that goes missing, or
  ///   leaves the reel, is un-chosen; when that empties a selection that had
  ///   clips, choosing ends.
  ///
  /// Auto-disposes with the page.
  ReelSelectionProvider._({
    required ReelSelectionFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'reelSelectionProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$reelSelectionHash();

  @override
  String toString() {
    return r'reelSelectionProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  ReelSelection create() => ReelSelection();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ReelSelectionState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ReelSelectionState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ReelSelectionProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$reelSelectionHash() => r'26b1e5c250f212fc284a834b9f74bda1e35a940e';

/// Choosing clips on reel [reelId]'s page (D-88; `app.js`: `startSel`,
/// `toggleSel`, `selAll`, `clearSel`).
///
/// - **Only a clip that is in this reel and not missing can be chosen.** A
///   missing tile is not selectable, and [selectAll] skips them. Before the
///   reel's clips have been read nothing can be chosen.
/// - **Choosing ends when the last clip is un-chosen** ([toggle]), as
///   `toggleSel` does; [begin] is the one way to be choosing with nothing
///   chosen.
/// - **It follows the reel's clips.** A chosen clip that goes missing, or
///   leaves the reel, is un-chosen; when that empties a selection that had
///   clips, choosing ends.
///
/// Auto-disposes with the page.

final class ReelSelectionFamily extends $Family
    with
        $ClassFamilyOverride<
          ReelSelection,
          ReelSelectionState,
          ReelSelectionState,
          ReelSelectionState,
          int
        > {
  ReelSelectionFamily._()
    : super(
        retry: null,
        name: r'reelSelectionProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Choosing clips on reel [reelId]'s page (D-88; `app.js`: `startSel`,
  /// `toggleSel`, `selAll`, `clearSel`).
  ///
  /// - **Only a clip that is in this reel and not missing can be chosen.** A
  ///   missing tile is not selectable, and [selectAll] skips them. Before the
  ///   reel's clips have been read nothing can be chosen.
  /// - **Choosing ends when the last clip is un-chosen** ([toggle]), as
  ///   `toggleSel` does; [begin] is the one way to be choosing with nothing
  ///   chosen.
  /// - **It follows the reel's clips.** A chosen clip that goes missing, or
  ///   leaves the reel, is un-chosen; when that empties a selection that had
  ///   clips, choosing ends.
  ///
  /// Auto-disposes with the page.

  ReelSelectionProvider call(int reelId) =>
      ReelSelectionProvider._(argument: reelId, from: this);

  @override
  String toString() => r'reelSelectionProvider';
}

/// Choosing clips on reel [reelId]'s page (D-88; `app.js`: `startSel`,
/// `toggleSel`, `selAll`, `clearSel`).
///
/// - **Only a clip that is in this reel and not missing can be chosen.** A
///   missing tile is not selectable, and [selectAll] skips them. Before the
///   reel's clips have been read nothing can be chosen.
/// - **Choosing ends when the last clip is un-chosen** ([toggle]), as
///   `toggleSel` does; [begin] is the one way to be choosing with nothing
///   chosen.
/// - **It follows the reel's clips.** A chosen clip that goes missing, or
///   leaves the reel, is un-chosen; when that empties a selection that had
///   clips, choosing ends.
///
/// Auto-disposes with the page.

abstract class _$ReelSelection extends $Notifier<ReelSelectionState> {
  late final _$args = ref.$arg as int;
  int get reelId => _$args;

  ReelSelectionState build(int reelId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ReelSelectionState, ReelSelectionState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ReelSelectionState, ReelSelectionState>,
              ReelSelectionState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
