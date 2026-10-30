// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_access_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Whether TakeTray may read the videos, for the Shooting mode card's banner
/// and its "Allow" button (D-68, D-75).
///
/// Kept alive: the app start, resume and the screens all use the one state.
/// A call that sees full access remembers it (`markAccessWasFull`), which is
/// what lets a later loss be told from "never had it". The bridge's answers
/// are read fresh on every call; only the last call to finish writes the
/// state, so an older answer arriving late never replaces a newer one.
///
/// No method throws: an error is logged by type and the last view stays. If
/// the first read failed, the state is an `AsyncError` until a refresh works.

@ProviderFor(MediaAccessController)
final mediaAccessControllerProvider = MediaAccessControllerProvider._();

/// Whether TakeTray may read the videos, for the Shooting mode card's banner
/// and its "Allow" button (D-68, D-75).
///
/// Kept alive: the app start, resume and the screens all use the one state.
/// A call that sees full access remembers it (`markAccessWasFull`), which is
/// what lets a later loss be told from "never had it". The bridge's answers
/// are read fresh on every call; only the last call to finish writes the
/// state, so an older answer arriving late never replaces a newer one.
///
/// No method throws: an error is logged by type and the last view stays. If
/// the first read failed, the state is an `AsyncError` until a refresh works.
final class MediaAccessControllerProvider
    extends $AsyncNotifierProvider<MediaAccessController, MediaAccessView> {
  /// Whether TakeTray may read the videos, for the Shooting mode card's banner
  /// and its "Allow" button (D-68, D-75).
  ///
  /// Kept alive: the app start, resume and the screens all use the one state.
  /// A call that sees full access remembers it (`markAccessWasFull`), which is
  /// what lets a later loss be told from "never had it". The bridge's answers
  /// are read fresh on every call; only the last call to finish writes the
  /// state, so an older answer arriving late never replaces a newer one.
  ///
  /// No method throws: an error is logged by type and the last view stays. If
  /// the first read failed, the state is an `AsyncError` until a refresh works.
  MediaAccessControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: noRetry,
        name: r'mediaAccessControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mediaAccessControllerHash();

  @$internal
  @override
  MediaAccessController create() => MediaAccessController();
}

String _$mediaAccessControllerHash() =>
    r'1d2cd8dd8bc6f623cbd606f6330c6e06e6f4e12b';

/// Whether TakeTray may read the videos, for the Shooting mode card's banner
/// and its "Allow" button (D-68, D-75).
///
/// Kept alive: the app start, resume and the screens all use the one state.
/// A call that sees full access remembers it (`markAccessWasFull`), which is
/// what lets a later loss be told from "never had it". The bridge's answers
/// are read fresh on every call; only the last call to finish writes the
/// state, so an older answer arriving late never replaces a newer one.
///
/// No method throws: an error is logged by type and the last view stays. If
/// the first read failed, the state is an `AsyncError` until a refresh works.

abstract class _$MediaAccessController extends $AsyncNotifier<MediaAccessView> {
  FutureOr<MediaAccessView> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<MediaAccessView>, MediaAccessView>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<MediaAccessView>, MediaAccessView>,
              AsyncValue<MediaAccessView>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
