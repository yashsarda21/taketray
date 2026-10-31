// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reel_form_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The create (null `reelId`) or edit sheet of one reel (D-85).
///
/// [save] checks the name and the description, both at once, then writes. The
/// name is checked against the reels as they are now (a reel made a moment
/// ago counts; when editing, the reel's own name in any case is always
/// fine, as in `ReelsRepository.rename`), and the repository's own
/// `duplicate` is the backstop if another reel took the name between that
/// check and the write. A problem is not thrown: [save] returns null and the
/// state holds `nameError` / `descriptionError`, for the view to show.
/// Anything else that goes wrong (a database error, the reel being gone) is
/// logged by type and rethrown, for the view to tell the user.
///
/// Saving is single-flight: a second call while one runs returns the first
/// call's future (a double tap on Save makes one reel).
///
/// Auto-disposes with the sheet; a save that outlives it still finishes, and
/// only the state is left alone.

@ProviderFor(ReelFormController)
final reelFormControllerProvider = ReelFormControllerFamily._();

/// The create (null `reelId`) or edit sheet of one reel (D-85).
///
/// [save] checks the name and the description, both at once, then writes. The
/// name is checked against the reels as they are now (a reel made a moment
/// ago counts; when editing, the reel's own name in any case is always
/// fine, as in `ReelsRepository.rename`), and the repository's own
/// `duplicate` is the backstop if another reel took the name between that
/// check and the write. A problem is not thrown: [save] returns null and the
/// state holds `nameError` / `descriptionError`, for the view to show.
/// Anything else that goes wrong (a database error, the reel being gone) is
/// logged by type and rethrown, for the view to tell the user.
///
/// Saving is single-flight: a second call while one runs returns the first
/// call's future (a double tap on Save makes one reel).
///
/// Auto-disposes with the sheet; a save that outlives it still finishes, and
/// only the state is left alone.
final class ReelFormControllerProvider
    extends $NotifierProvider<ReelFormController, ReelFormState> {
  /// The create (null `reelId`) or edit sheet of one reel (D-85).
  ///
  /// [save] checks the name and the description, both at once, then writes. The
  /// name is checked against the reels as they are now (a reel made a moment
  /// ago counts; when editing, the reel's own name in any case is always
  /// fine, as in `ReelsRepository.rename`), and the repository's own
  /// `duplicate` is the backstop if another reel took the name between that
  /// check and the write. A problem is not thrown: [save] returns null and the
  /// state holds `nameError` / `descriptionError`, for the view to show.
  /// Anything else that goes wrong (a database error, the reel being gone) is
  /// logged by type and rethrown, for the view to tell the user.
  ///
  /// Saving is single-flight: a second call while one runs returns the first
  /// call's future (a double tap on Save makes one reel).
  ///
  /// Auto-disposes with the sheet; a save that outlives it still finishes, and
  /// only the state is left alone.
  ReelFormControllerProvider._({
    required ReelFormControllerFamily super.from,
    required int? super.argument,
  }) : super(
         retry: noRetry,
         name: r'reelFormControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$reelFormControllerHash();

  @override
  String toString() {
    return r'reelFormControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  ReelFormController create() => ReelFormController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ReelFormState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ReelFormState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ReelFormControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$reelFormControllerHash() =>
    r'da762838350d46d92ab3119811e14a1c8de0ca6e';

/// The create (null `reelId`) or edit sheet of one reel (D-85).
///
/// [save] checks the name and the description, both at once, then writes. The
/// name is checked against the reels as they are now (a reel made a moment
/// ago counts; when editing, the reel's own name in any case is always
/// fine, as in `ReelsRepository.rename`), and the repository's own
/// `duplicate` is the backstop if another reel took the name between that
/// check and the write. A problem is not thrown: [save] returns null and the
/// state holds `nameError` / `descriptionError`, for the view to show.
/// Anything else that goes wrong (a database error, the reel being gone) is
/// logged by type and rethrown, for the view to tell the user.
///
/// Saving is single-flight: a second call while one runs returns the first
/// call's future (a double tap on Save makes one reel).
///
/// Auto-disposes with the sheet; a save that outlives it still finishes, and
/// only the state is left alone.

final class ReelFormControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          ReelFormController,
          ReelFormState,
          ReelFormState,
          ReelFormState,
          int?
        > {
  ReelFormControllerFamily._()
    : super(
        retry: noRetry,
        name: r'reelFormControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The create (null `reelId`) or edit sheet of one reel (D-85).
  ///
  /// [save] checks the name and the description, both at once, then writes. The
  /// name is checked against the reels as they are now (a reel made a moment
  /// ago counts; when editing, the reel's own name in any case is always
  /// fine, as in `ReelsRepository.rename`), and the repository's own
  /// `duplicate` is the backstop if another reel took the name between that
  /// check and the write. A problem is not thrown: [save] returns null and the
  /// state holds `nameError` / `descriptionError`, for the view to show.
  /// Anything else that goes wrong (a database error, the reel being gone) is
  /// logged by type and rethrown, for the view to tell the user.
  ///
  /// Saving is single-flight: a second call while one runs returns the first
  /// call's future (a double tap on Save makes one reel).
  ///
  /// Auto-disposes with the sheet; a save that outlives it still finishes, and
  /// only the state is left alone.

  ReelFormControllerProvider call(int? reelId) =>
      ReelFormControllerProvider._(argument: reelId, from: this);

  @override
  String toString() => r'reelFormControllerProvider';
}

/// The create (null `reelId`) or edit sheet of one reel (D-85).
///
/// [save] checks the name and the description, both at once, then writes. The
/// name is checked against the reels as they are now (a reel made a moment
/// ago counts; when editing, the reel's own name in any case is always
/// fine, as in `ReelsRepository.rename`), and the repository's own
/// `duplicate` is the backstop if another reel took the name between that
/// check and the write. A problem is not thrown: [save] returns null and the
/// state holds `nameError` / `descriptionError`, for the view to show.
/// Anything else that goes wrong (a database error, the reel being gone) is
/// logged by type and rethrown, for the view to tell the user.
///
/// Saving is single-flight: a second call while one runs returns the first
/// call's future (a double tap on Save makes one reel).
///
/// Auto-disposes with the sheet; a save that outlives it still finishes, and
/// only the state is left alone.

abstract class _$ReelFormController extends $Notifier<ReelFormState> {
  late final _$args = ref.$arg as int?;
  int? get reelId => _$args;

  ReelFormState build(int? reelId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ReelFormState, ReelFormState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ReelFormState, ReelFormState>,
              ReelFormState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
