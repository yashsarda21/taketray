import 'package:flutter/painting.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/data/media/thumbnail_cache.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/reel_summary.dart';
import 'package:taketray/features/clips/widgets/clip_thumbnail.dart';
import 'package:taketray/features/reels/view_models/reel_filters.dart';

part 'home_controller.g.dart';

/// The side, in logical pixels, a cover picture is asked for (D-86).
///
/// A card is 4:5 and about 160 to 190 dp wide on a phone, so its height (the
/// longer side, which the picture is cropped to cover) is at most about 240
/// dp. One size for every phone and every card keeps the thumbnail cache from
/// holding a file per screen width.
const double homeCoverSize = 240;

/// What Home shows (D-86).
class HomeState {
  const HomeState({
    required this.reels,
    required this.filter,
    required this.counts,
    required this.covers,
  });

  /// The reels that pass [filter], newest first.
  final List<ReelSummary> reels;

  /// The chosen filter.
  final ReelFilter filter;

  /// How many reels each filter shows, over all reels, not only [reels].
  final Map<ReelFilter, int> counts;

  /// The cover picture of each reel in [reels], by reel id; null for a reel
  /// with no clip that has a picture.
  final Map<int, ImageProvider?> covers;

  /// Whether the phone has any reel at all, whatever the filter.
  bool get hasReels => (counts[ReelFilter.all] ?? 0) > 0;
}

/// Every reel with its counts, newest first, again after every change to
/// reels, links or clips (`ReelsRepository.watchReelSummaries`).
@riverpod
Stream<List<ReelSummary>> reelSummaries(Ref ref) =>
    ref.watch(reelsRepositoryProvider).watchReelSummaries();

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
@riverpod
class HomeController extends _$HomeController {
  ReelFilter _filter = ReelFilter.all;

  /// The last list of all reels, so a change of filter needs no new read.
  List<ReelSummary> _all = const [];

  /// The thumbnail cache, null until it is ready (the cards then show their
  /// empty art, and the covers arrive with the cache).
  ThumbnailCache? _cache;

  @override
  Future<HomeState> build() async {
    _cache = ref.watch(thumbnailCacheProvider).value;
    _all = await ref.watch(reelSummariesProvider.future);
    return _compose();
  }

  /// Shows the reels of [filter]. Before the first list is read it only
  /// remembers the filter.
  void setFilter(ReelFilter filter) {
    _filter = filter;
    if (state.hasValue) state = AsyncData(_compose());
  }

  HomeState _compose() {
    final shown = applyFilter(_all, _filter);
    return HomeState(
      reels: shown,
      filter: _filter,
      counts: filterCounts(_all),
      covers: {
        for (final summary in shown)
          summary.reel.id: summary.cover == null
              ? null
              : clipThumbnail(
                  clip: summary.cover!,
                  logicalSize: homeCoverSize,
                  cache: _cache,
                ),
      },
    );
  }
}
