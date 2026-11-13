// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reel_edit_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Reel [reelId]'s editing session with its copies and sent clips, now and
/// after every change; null while the reel has none (D-120). No value until
/// the database has answered.

@ProviderFor(reelEditSession)
final reelEditSessionProvider = ReelEditSessionFamily._();

/// Reel [reelId]'s editing session with its copies and sent clips, now and
/// after every change; null while the reel has none (D-120). No value until
/// the database has answered.

final class ReelEditSessionProvider
    extends
        $FunctionalProvider<
          AsyncValue<EditState?>,
          EditState?,
          Stream<EditState?>
        >
    with $FutureModifier<EditState?>, $StreamProvider<EditState?> {
  /// Reel [reelId]'s editing session with its copies and sent clips, now and
  /// after every change; null while the reel has none (D-120). No value until
  /// the database has answered.
  ReelEditSessionProvider._({
    required ReelEditSessionFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'reelEditSessionProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$reelEditSessionHash();

  @override
  String toString() {
    return r'reelEditSessionProvider'
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
    return reelEditSession(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ReelEditSessionProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$reelEditSessionHash() => r'99e2253fe785e5e3ba7547b7dde4a3d6a90ac725';

/// Reel [reelId]'s editing session with its copies and sent clips, now and
/// after every change; null while the reel has none (D-120). No value until
/// the database has answered.

final class ReelEditSessionFamily extends $Family
    with $FunctionalFamilyOverride<Stream<EditState?>, int> {
  ReelEditSessionFamily._()
    : super(
        retry: null,
        name: r'reelEditSessionProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Reel [reelId]'s editing session with its copies and sent clips, now and
  /// after every change; null while the reel has none (D-120). No value until
  /// the database has answered.

  ReelEditSessionProvider call(int reelId) =>
      ReelEditSessionProvider._(argument: reelId, from: this);

  @override
  String toString() => r'reelEditSessionProvider';
}

/// The editor of every reel that is being edited (reel id to editor), for
/// the pills of Home's cards.

@ProviderFor(reelEditors)
final reelEditorsProvider = ReelEditorsProvider._();

/// The editor of every reel that is being edited (reel id to editor), for
/// the pills of Home's cards.

final class ReelEditorsProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<int, EditorApp>>,
          Map<int, EditorApp>,
          Stream<Map<int, EditorApp>>
        >
    with
        $FutureModifier<Map<int, EditorApp>>,
        $StreamProvider<Map<int, EditorApp>> {
  /// The editor of every reel that is being edited (reel id to editor), for
  /// the pills of Home's cards.
  ReelEditorsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'reelEditorsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$reelEditorsHash();

  @$internal
  @override
  $StreamProviderElement<Map<int, EditorApp>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<Map<int, EditorApp>> create(Ref ref) {
    return reelEditors(ref);
  }
}

String _$reelEditorsHash() => r'98e0e7667ec114e942fc6c0e8703c0bcab7ea262';

/// Reel [reelId]'s page while it is being edited; null while it has no
/// session (D-128).
///
/// It follows the session (a copy recorded, a copy the copy check found gone,
/// Done editing), the reel's clips (a clip tagged in meanwhile is new at
/// once) and their times, like the page itself (`ReelDetailController`).
/// The split is `splitForEditing` over every clip of the reel, with the sent
/// clips and the clips whose copy is recorded: the copy check that runs when
/// the page opens removes the records of copies deleted outside TakeTray, so
/// a recorded copy is a live one.

@ProviderFor(reelEditState)
final reelEditStateProvider = ReelEditStateFamily._();

/// Reel [reelId]'s page while it is being edited; null while it has no
/// session (D-128).
///
/// It follows the session (a copy recorded, a copy the copy check found gone,
/// Done editing), the reel's clips (a clip tagged in meanwhile is new at
/// once) and their times, like the page itself (`ReelDetailController`).
/// The split is `splitForEditing` over every clip of the reel, with the sent
/// clips and the clips whose copy is recorded: the copy check that runs when
/// the page opens removes the records of copies deleted outside TakeTray, so
/// a recorded copy is a live one.

final class ReelEditStateProvider
    extends
        $FunctionalProvider<
          AsyncValue<ReelEditState?>,
          ReelEditState?,
          FutureOr<ReelEditState?>
        >
    with $FutureModifier<ReelEditState?>, $FutureProvider<ReelEditState?> {
  /// Reel [reelId]'s page while it is being edited; null while it has no
  /// session (D-128).
  ///
  /// It follows the session (a copy recorded, a copy the copy check found gone,
  /// Done editing), the reel's clips (a clip tagged in meanwhile is new at
  /// once) and their times, like the page itself (`ReelDetailController`).
  /// The split is `splitForEditing` over every clip of the reel, with the sent
  /// clips and the clips whose copy is recorded: the copy check that runs when
  /// the page opens removes the records of copies deleted outside TakeTray, so
  /// a recorded copy is a live one.
  ReelEditStateProvider._({
    required ReelEditStateFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'reelEditStateProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$reelEditStateHash();

  @override
  String toString() {
    return r'reelEditStateProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<ReelEditState?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ReelEditState?> create(Ref ref) {
    final argument = this.argument as int;
    return reelEditState(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ReelEditStateProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$reelEditStateHash() => r'735b1a7f22f85eac5bf77669651f707a62d6be27';

/// Reel [reelId]'s page while it is being edited; null while it has no
/// session (D-128).
///
/// It follows the session (a copy recorded, a copy the copy check found gone,
/// Done editing), the reel's clips (a clip tagged in meanwhile is new at
/// once) and their times, like the page itself (`ReelDetailController`).
/// The split is `splitForEditing` over every clip of the reel, with the sent
/// clips and the clips whose copy is recorded: the copy check that runs when
/// the page opens removes the records of copies deleted outside TakeTray, so
/// a recorded copy is a live one.

final class ReelEditStateFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<ReelEditState?>, int> {
  ReelEditStateFamily._()
    : super(
        retry: null,
        name: r'reelEditStateProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Reel [reelId]'s page while it is being edited; null while it has no
  /// session (D-128).
  ///
  /// It follows the session (a copy recorded, a copy the copy check found gone,
  /// Done editing), the reel's clips (a clip tagged in meanwhile is new at
  /// once) and their times, like the page itself (`ReelDetailController`).
  /// The split is `splitForEditing` over every clip of the reel, with the sent
  /// clips and the clips whose copy is recorded: the copy check that runs when
  /// the page opens removes the records of copies deleted outside TakeTray, so
  /// a recorded copy is a live one.

  ReelEditStateProvider call(int reelId) =>
      ReelEditStateProvider._(argument: reelId, from: this);

  @override
  String toString() => r'reelEditStateProvider';
}
