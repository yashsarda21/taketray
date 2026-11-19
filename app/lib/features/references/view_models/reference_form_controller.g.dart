// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reference_form_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The Add / edit reference sheet of reel [reelId] (D-157). The state is
/// whether a save is running, for the sheet to disable its buttons.
///
/// [saveNew] makes the link out of what the user typed or pasted
/// (`typedLink`: a caption with a link in it, or a bare address), checks the
/// label, then saves. [saveLabel] changes the label of a saved reference. A
/// problem the user can fix is a result, not a throw; anything else is logged
/// by type and told as a failure.
///
/// Saving is single-flight, as in `ReelFormController`: a second call while
/// one runs returns the first call's future (a double tap on Save makes one
/// reference).
///
/// Auto-disposes with the sheet; a save that outlives it still finishes, and
/// only the state is left alone.

@ProviderFor(ReferenceFormController)
final referenceFormControllerProvider = ReferenceFormControllerFamily._();

/// The Add / edit reference sheet of reel [reelId] (D-157). The state is
/// whether a save is running, for the sheet to disable its buttons.
///
/// [saveNew] makes the link out of what the user typed or pasted
/// (`typedLink`: a caption with a link in it, or a bare address), checks the
/// label, then saves. [saveLabel] changes the label of a saved reference. A
/// problem the user can fix is a result, not a throw; anything else is logged
/// by type and told as a failure.
///
/// Saving is single-flight, as in `ReelFormController`: a second call while
/// one runs returns the first call's future (a double tap on Save makes one
/// reference).
///
/// Auto-disposes with the sheet; a save that outlives it still finishes, and
/// only the state is left alone.
final class ReferenceFormControllerProvider
    extends $NotifierProvider<ReferenceFormController, bool> {
  /// The Add / edit reference sheet of reel [reelId] (D-157). The state is
  /// whether a save is running, for the sheet to disable its buttons.
  ///
  /// [saveNew] makes the link out of what the user typed or pasted
  /// (`typedLink`: a caption with a link in it, or a bare address), checks the
  /// label, then saves. [saveLabel] changes the label of a saved reference. A
  /// problem the user can fix is a result, not a throw; anything else is logged
  /// by type and told as a failure.
  ///
  /// Saving is single-flight, as in `ReelFormController`: a second call while
  /// one runs returns the first call's future (a double tap on Save makes one
  /// reference).
  ///
  /// Auto-disposes with the sheet; a save that outlives it still finishes, and
  /// only the state is left alone.
  ReferenceFormControllerProvider._({
    required ReferenceFormControllerFamily super.from,
    required int super.argument,
  }) : super(
         retry: noRetry,
         name: r'referenceFormControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$referenceFormControllerHash();

  @override
  String toString() {
    return r'referenceFormControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  ReferenceFormController create() => ReferenceFormController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ReferenceFormControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$referenceFormControllerHash() =>
    r'83c4b35c2a5d736e65a676e56c98c3ae97e31643';

/// The Add / edit reference sheet of reel [reelId] (D-157). The state is
/// whether a save is running, for the sheet to disable its buttons.
///
/// [saveNew] makes the link out of what the user typed or pasted
/// (`typedLink`: a caption with a link in it, or a bare address), checks the
/// label, then saves. [saveLabel] changes the label of a saved reference. A
/// problem the user can fix is a result, not a throw; anything else is logged
/// by type and told as a failure.
///
/// Saving is single-flight, as in `ReelFormController`: a second call while
/// one runs returns the first call's future (a double tap on Save makes one
/// reference).
///
/// Auto-disposes with the sheet; a save that outlives it still finishes, and
/// only the state is left alone.

final class ReferenceFormControllerFamily extends $Family
    with $ClassFamilyOverride<ReferenceFormController, bool, bool, bool, int> {
  ReferenceFormControllerFamily._()
    : super(
        retry: noRetry,
        name: r'referenceFormControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The Add / edit reference sheet of reel [reelId] (D-157). The state is
  /// whether a save is running, for the sheet to disable its buttons.
  ///
  /// [saveNew] makes the link out of what the user typed or pasted
  /// (`typedLink`: a caption with a link in it, or a bare address), checks the
  /// label, then saves. [saveLabel] changes the label of a saved reference. A
  /// problem the user can fix is a result, not a throw; anything else is logged
  /// by type and told as a failure.
  ///
  /// Saving is single-flight, as in `ReelFormController`: a second call while
  /// one runs returns the first call's future (a double tap on Save makes one
  /// reference).
  ///
  /// Auto-disposes with the sheet; a save that outlives it still finishes, and
  /// only the state is left alone.

  ReferenceFormControllerProvider call(int reelId) =>
      ReferenceFormControllerProvider._(argument: reelId, from: this);

  @override
  String toString() => r'referenceFormControllerProvider';
}

/// The Add / edit reference sheet of reel [reelId] (D-157). The state is
/// whether a save is running, for the sheet to disable its buttons.
///
/// [saveNew] makes the link out of what the user typed or pasted
/// (`typedLink`: a caption with a link in it, or a bare address), checks the
/// label, then saves. [saveLabel] changes the label of a saved reference. A
/// problem the user can fix is a result, not a throw; anything else is logged
/// by type and told as a failure.
///
/// Saving is single-flight, as in `ReelFormController`: a second call while
/// one runs returns the first call's future (a double tap on Save makes one
/// reference).
///
/// Auto-disposes with the sheet; a save that outlives it still finishes, and
/// only the state is left alone.

abstract class _$ReferenceFormController extends $Notifier<bool> {
  late final _$args = ref.$arg as int;
  int get reelId => _$args;

  bool build(int reelId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
