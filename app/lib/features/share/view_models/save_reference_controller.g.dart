// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'save_reference_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The Save reference sheet of the share screen (D-166): the shared text
/// becomes a link, a reel is picked or named, and one Save writes it.
///
/// [start] reads the shared text once per share. [pick] and [setMode] change
/// the form; [save] writes. **Nothing here changes an onboarding flag**: the
/// share engine only saves a reel and a reference (D-162).
///
/// Saving is single-flight, as in `ReelFormController`: a second call while
/// one runs returns the first call's future (a double tap on Save makes one
/// reel or one reference). Whatever goes wrong that the user cannot fix (a
/// busy database, the picked reel deleted meanwhile) ends in
/// [SaveReferenceState.failed], with the error type logged and nothing else.
///
/// Auto-disposes with the sheet; a save that outlives it still finishes, and
/// only the state is left alone.

@ProviderFor(SaveReferenceController)
final saveReferenceControllerProvider = SaveReferenceControllerProvider._();

/// The Save reference sheet of the share screen (D-166): the shared text
/// becomes a link, a reel is picked or named, and one Save writes it.
///
/// [start] reads the shared text once per share. [pick] and [setMode] change
/// the form; [save] writes. **Nothing here changes an onboarding flag**: the
/// share engine only saves a reel and a reference (D-162).
///
/// Saving is single-flight, as in `ReelFormController`: a second call while
/// one runs returns the first call's future (a double tap on Save makes one
/// reel or one reference). Whatever goes wrong that the user cannot fix (a
/// busy database, the picked reel deleted meanwhile) ends in
/// [SaveReferenceState.failed], with the error type logged and nothing else.
///
/// Auto-disposes with the sheet; a save that outlives it still finishes, and
/// only the state is left alone.
final class SaveReferenceControllerProvider
    extends $NotifierProvider<SaveReferenceController, SaveReferenceState> {
  /// The Save reference sheet of the share screen (D-166): the shared text
  /// becomes a link, a reel is picked or named, and one Save writes it.
  ///
  /// [start] reads the shared text once per share. [pick] and [setMode] change
  /// the form; [save] writes. **Nothing here changes an onboarding flag**: the
  /// share engine only saves a reel and a reference (D-162).
  ///
  /// Saving is single-flight, as in `ReelFormController`: a second call while
  /// one runs returns the first call's future (a double tap on Save makes one
  /// reel or one reference). Whatever goes wrong that the user cannot fix (a
  /// busy database, the picked reel deleted meanwhile) ends in
  /// [SaveReferenceState.failed], with the error type logged and nothing else.
  ///
  /// Auto-disposes with the sheet; a save that outlives it still finishes, and
  /// only the state is left alone.
  SaveReferenceControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: noRetry,
        name: r'saveReferenceControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$saveReferenceControllerHash();

  @$internal
  @override
  SaveReferenceController create() => SaveReferenceController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SaveReferenceState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SaveReferenceState>(value),
    );
  }
}

String _$saveReferenceControllerHash() =>
    r'2d944f2e24517c437224986516e864b277fd6f32';

/// The Save reference sheet of the share screen (D-166): the shared text
/// becomes a link, a reel is picked or named, and one Save writes it.
///
/// [start] reads the shared text once per share. [pick] and [setMode] change
/// the form; [save] writes. **Nothing here changes an onboarding flag**: the
/// share engine only saves a reel and a reference (D-162).
///
/// Saving is single-flight, as in `ReelFormController`: a second call while
/// one runs returns the first call's future (a double tap on Save makes one
/// reel or one reference). Whatever goes wrong that the user cannot fix (a
/// busy database, the picked reel deleted meanwhile) ends in
/// [SaveReferenceState.failed], with the error type logged and nothing else.
///
/// Auto-disposes with the sheet; a save that outlives it still finishes, and
/// only the state is left alone.

abstract class _$SaveReferenceController extends $Notifier<SaveReferenceState> {
  SaveReferenceState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<SaveReferenceState, SaveReferenceState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SaveReferenceState, SaveReferenceState>,
              SaveReferenceState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
