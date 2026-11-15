// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'copy_ready_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Reel [reelId]'s editing session with its copies, now and after every
/// change; null while it has none.

@ProviderFor(editStateOf)
final editStateOfProvider = EditStateOfFamily._();

/// Reel [reelId]'s editing session with its copies, now and after every
/// change; null while it has none.

final class EditStateOfProvider
    extends
        $FunctionalProvider<
          AsyncValue<EditState?>,
          EditState?,
          Stream<EditState?>
        >
    with $FutureModifier<EditState?>, $StreamProvider<EditState?> {
  /// Reel [reelId]'s editing session with its copies, now and after every
  /// change; null while it has none.
  EditStateOfProvider._({
    required EditStateOfFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'editStateOfProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$editStateOfHash();

  @override
  String toString() {
    return r'editStateOfProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<EditState?> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<EditState?> create(Ref ref) {
    final argument = this.argument as int;
    return editStateOf(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is EditStateOfProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$editStateOfHash() => r'836305680ee484ee1037b1207bc8aaa980074b16';

/// Reel [reelId]'s editing session with its copies, now and after every
/// change; null while it has none.

final class EditStateOfFamily extends $Family
    with $FunctionalFamilyOverride<Stream<EditState?>, int> {
  EditStateOfFamily._()
    : super(
        retry: null,
        name: r'editStateOfProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Reel [reelId]'s editing session with its copies, now and after every
  /// change; null while it has none.

  EditStateOfProvider call(int reelId) =>
      EditStateOfProvider._(argument: reelId, from: this);

  @override
  String toString() => r'editStateOfProvider';
}

/// The data of the ready screen for reel [reelId]. Auto-disposes with it.

@ProviderFor(CopyReadyController)
final copyReadyControllerProvider = CopyReadyControllerFamily._();

/// The data of the ready screen for reel [reelId]. Auto-disposes with it.
final class CopyReadyControllerProvider
    extends $AsyncNotifierProvider<CopyReadyController, CopyReadyState> {
  /// The data of the ready screen for reel [reelId]. Auto-disposes with it.
  CopyReadyControllerProvider._({
    required CopyReadyControllerFamily super.from,
    required int super.argument,
  }) : super(
         retry: noRetry,
         name: r'copyReadyControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$copyReadyControllerHash();

  @override
  String toString() {
    return r'copyReadyControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  CopyReadyController create() => CopyReadyController();

  @override
  bool operator ==(Object other) {
    return other is CopyReadyControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$copyReadyControllerHash() =>
    r'1fddc88c60a0aa070bbea1c19ade388836be324a';

/// The data of the ready screen for reel [reelId]. Auto-disposes with it.

final class CopyReadyControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          CopyReadyController,
          AsyncValue<CopyReadyState>,
          CopyReadyState,
          FutureOr<CopyReadyState>,
          int
        > {
  CopyReadyControllerFamily._()
    : super(
        retry: noRetry,
        name: r'copyReadyControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The data of the ready screen for reel [reelId]. Auto-disposes with it.

  CopyReadyControllerProvider call(int reelId) =>
      CopyReadyControllerProvider._(argument: reelId, from: this);

  @override
  String toString() => r'copyReadyControllerProvider';
}

/// The data of the ready screen for reel [reelId]. Auto-disposes with it.

abstract class _$CopyReadyController extends $AsyncNotifier<CopyReadyState> {
  late final _$args = ref.$arg as int;
  int get reelId => _$args;

  FutureOr<CopyReadyState> build(int reelId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<CopyReadyState>, CopyReadyState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<CopyReadyState>, CopyReadyState>,
              AsyncValue<CopyReadyState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}

/// The wall-clock time where clip [clipId] was shot (`ClipLocalTime`, D-83;
/// the fields of a UTC DateTime), or null when there is no such clip. For
/// the line "The clip from {time} may have been deleted or moved."

@ProviderFor(failedClipTime)
final failedClipTimeProvider = FailedClipTimeFamily._();

/// The wall-clock time where clip [clipId] was shot (`ClipLocalTime`, D-83;
/// the fields of a UTC DateTime), or null when there is no such clip. For
/// the line "The clip from {time} may have been deleted or moved."

final class FailedClipTimeProvider
    extends
        $FunctionalProvider<
          AsyncValue<DateTime?>,
          DateTime?,
          FutureOr<DateTime?>
        >
    with $FutureModifier<DateTime?>, $FutureProvider<DateTime?> {
  /// The wall-clock time where clip [clipId] was shot (`ClipLocalTime`, D-83;
  /// the fields of a UTC DateTime), or null when there is no such clip. For
  /// the line "The clip from {time} may have been deleted or moved."
  FailedClipTimeProvider._({
    required FailedClipTimeFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'failedClipTimeProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$failedClipTimeHash();

  @override
  String toString() {
    return r'failedClipTimeProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<DateTime?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<DateTime?> create(Ref ref) {
    final argument = this.argument as int;
    return failedClipTime(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is FailedClipTimeProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$failedClipTimeHash() => r'dacfa4e8d71c99ee6b35173bb2b83d96abf87e24';

/// The wall-clock time where clip [clipId] was shot (`ClipLocalTime`, D-83;
/// the fields of a UTC DateTime), or null when there is no such clip. For
/// the line "The clip from {time} may have been deleted or moved."

final class FailedClipTimeFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<DateTime?>, int> {
  FailedClipTimeFamily._()
    : super(
        retry: null,
        name: r'failedClipTimeProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The wall-clock time where clip [clipId] was shot (`ClipLocalTime`, D-83;
  /// the fields of a UTC DateTime), or null when there is no such clip. For
  /// the line "The clip from {time} may have been deleted or moved."

  FailedClipTimeProvider call(int clipId) =>
      FailedClipTimeProvider._(argument: clipId, from: this);

  @override
  String toString() => r'failedClipTimeProvider';
}
