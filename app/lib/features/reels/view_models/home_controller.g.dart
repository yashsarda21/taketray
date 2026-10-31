// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'home_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Every reel with its counts, newest first, again after every change to
/// reels, links or clips (`ReelsRepository.watchReelSummaries`).

@ProviderFor(reelSummaries)
final reelSummariesProvider = ReelSummariesProvider._();

/// Every reel with its counts, newest first, again after every change to
/// reels, links or clips (`ReelsRepository.watchReelSummaries`).

final class ReelSummariesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ReelSummary>>,
          List<ReelSummary>,
          Stream<List<ReelSummary>>
        >
    with
        $FutureModifier<List<ReelSummary>>,
        $StreamProvider<List<ReelSummary>> {
  /// Every reel with its counts, newest first, again after every change to
  /// reels, links or clips (`ReelsRepository.watchReelSummaries`).
  ReelSummariesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'reelSummariesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$reelSummariesHash();

  @$internal
  @override
  $StreamProviderElement<List<ReelSummary>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<ReelSummary>> create(Ref ref) {
    return reelSummaries(ref);
  }
}

String _$reelSummariesHash() => r'4cfa20decaa5c6fea18a677f86ddc39db8c7873f';

/// The state of Home: the reels, the chosen filter and each card's cover.
///
/// The filter lives here, not in the widget, so it survives the screen being
/// rebuilt; it starts at All. It is not stored: a restart starts at All.
///
/// While the first list is being read the state is loading; Home then shows
/// neither "no reels" nor cards. A later list (a reel was added) keeps the
/// previous state visible until it arrives. If the stream itself fails the
/// state is an error and Home shows nothing below the Shooting mode card (the
/// design has no error state).

@ProviderFor(HomeController)
final homeControllerProvider = HomeControllerProvider._();

/// The state of Home: the reels, the chosen filter and each card's cover.
///
/// The filter lives here, not in the widget, so it survives the screen being
/// rebuilt; it starts at All. It is not stored: a restart starts at All.
///
/// While the first list is being read the state is loading; Home then shows
/// neither "no reels" nor cards. A later list (a reel was added) keeps the
/// previous state visible until it arrives. If the stream itself fails the
/// state is an error and Home shows nothing below the Shooting mode card (the
/// design has no error state).
final class HomeControllerProvider
    extends $AsyncNotifierProvider<HomeController, HomeState> {
  /// The state of Home: the reels, the chosen filter and each card's cover.
  ///
  /// The filter lives here, not in the widget, so it survives the screen being
  /// rebuilt; it starts at All. It is not stored: a restart starts at All.
  ///
  /// While the first list is being read the state is loading; Home then shows
  /// neither "no reels" nor cards. A later list (a reel was added) keeps the
  /// previous state visible until it arrives. If the stream itself fails the
  /// state is an error and Home shows nothing below the Shooting mode card (the
  /// design has no error state).
  HomeControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'homeControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$homeControllerHash();

  @$internal
  @override
  HomeController create() => HomeController();
}

String _$homeControllerHash() => r'd8f8416bcbec674dae35e6bc27a5e7f2e9f83c61';

/// The state of Home: the reels, the chosen filter and each card's cover.
///
/// The filter lives here, not in the widget, so it survives the screen being
/// rebuilt; it starts at All. It is not stored: a restart starts at All.
///
/// While the first list is being read the state is loading; Home then shows
/// neither "no reels" nor cards. A later list (a reel was added) keeps the
/// previous state visible until it arrives. If the stream itself fails the
/// state is an error and Home shows nothing below the Shooting mode card (the
/// design has no error state).

abstract class _$HomeController extends $AsyncNotifier<HomeState> {
  FutureOr<HomeState> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<HomeState>, HomeState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<HomeState>, HomeState>,
              AsyncValue<HomeState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
