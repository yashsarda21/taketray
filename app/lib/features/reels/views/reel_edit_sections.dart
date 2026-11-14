import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:taketray/data/media/thumbnail_cache.dart';
import 'package:taketray/domain/models/clip_local_time.dart';
import 'package:taketray/domain/models/editor_app.dart';
import 'package:taketray/domain/models/reel_clip.dart';
import 'package:taketray/domain/rules/shooting_days.dart';
import 'package:taketray/features/clips/widgets/clip_thumbnail.dart';
import 'package:taketray/features/editors/views/editor_text.dart';
import 'package:taketray/features/reels/view_models/reel_edit_state.dart';
import 'package:taketray/features/reels/view_models/reel_selection.dart';
import 'package:taketray/features/shooting_mode/views/shooting_time_text.dart';
import 'package:taketray/features/tagging/views/to_tag_screen.dart'
    show formatClipDuration;
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray_ui/taketray_ui.dart';

/// Columns of a day's clip grid (proto.css: `.grid3`).
const int reelGridColumns = 3;

/// Skeleton tiles shown while the reel loads (the prototype shows 9).
const int _skeletonTiles = 9;

/// How wide the skeleton day header is, of the width it has.
const double _skeletonDayWidth = 0.35;

/// What a reel's page shows while it loads (also if the first read fails:
/// the design has no error state): a skeleton day header and nine skeleton
/// tiles, read as "Loading".
List<Widget> reelLoadingSlivers(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  final tt = context.tt;
  return [
    SliverToBoxAdapter(
      child: Semantics(
        container: true,
        label: l10n.loading,
        child: Padding(
          // The same room as a day header (`TtDayHeader`).
          padding: EdgeInsets.fromLTRB(
            tt.spacing.gutter,
            tt.spacing.l,
            tt.spacing.gutter,
            tt.spacing.xxs,
          ),
          child: const TtSkeletonLine(widthFactor: _skeletonDayWidth),
        ),
      ),
    ),
    SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: tt.spacing.gutter),
      sliver: SliverGrid.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: reelGridColumns,
          mainAxisSpacing: tt.spacing.gridGap,
          crossAxisSpacing: tt.spacing.gridGap,
          childAspectRatio: tt.sizes.clipTileAspect,
        ),
        itemCount: _skeletonTiles,
        itemBuilder: (_, _) => const TtClipTileSkeleton(),
      ),
    ),
  ];
}

/// What the tiles of a reel's page need: the clips' times, the thumbnail
/// cache, the phone's language and 24-hour setting, the choice of clips, and
/// what a tap, a long press and a missing tile's **Remove** do (by clip id).
@immutable
class ReelTiles {
  const ReelTiles({
    required this.times,
    required this.cache,
    required this.locale,
    required this.use24Hour,
    required this.selection,
    required this.onTap,
    required this.onLongPress,
    required this.onRemoveMissing,
  });

  final Map<int, ClipLocalTime> times;
  final ThumbnailCache? cache;
  final String locale;
  final bool use24Hour;
  final ReelSelectionState selection;
  final ValueChanged<int> onTap;
  final ValueChanged<int> onLongPress;
  final ValueChanged<int> onRemoveMissing;
}

/// The slivers of [days] (D-87): for each day a `TtDayHeader` "Day {n} ·
/// {date}" with "{k} clips", and its clips three to a row, built on demand.
/// [today] decides whether a date shows its year.
List<Widget> reelDaySlivers(
  BuildContext context,
  List<ShootingDay<ReelClip>> days, {
  required ReelTiles tiles,
  required DateTime today,
}) {
  final l10n = AppLocalizations.of(context);
  final tt = context.tt;
  return [
    for (final day in days) ...[
      SliverToBoxAdapter(
        child: TtDayHeader(
          title: l10n.reelDayTitle(
            day.number,
            ttDayWeekdayText(context, day.date, today: today),
          ),
          trailing: l10n.reelDayClips(day.clips.length),
        ),
      ),
      SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: tt.spacing.gutter),
        sliver: _DayGrid(day: day, tiles: tiles),
      ),
    ],
  ];
}

/// The slivers of a reel's clips while it is being edited (D-128): at the
/// top "New since you started editing" ("{n} clips · not in your edit yet")
/// when there are new clips, then "In your edit" ("{n} clips · in the VN
/// folder", or "· sent to {editor} on {date}") when the editor has any. Each
/// part has its own day headers, with the reel's own Day numbers.
///
/// The new part's button is **Copy to VN folder** for VN, **Add to your
/// CapCut project** or **Add to your Edits project** for the others
/// ([onCopyNew], off when it is null or when every new clip is missing); each
/// opens the picker in add mode.
List<Widget> reelEditSlivers(
  BuildContext context,
  ReelEditState edit, {
  required ReelTiles tiles,
  required DateTime today,
  required VoidCallback? onCopyNew,
}) {
  final l10n = AppLocalizations.of(context);
  final vn = edit.editor == EditorApp.vn;
  final editor = editorShortName(l10n, edit.editor);
  return [
    if (edit.newCount > 0) ...[
      SliverToBoxAdapter(
        child: ReelEditSectionHeader(
          key: const ValueKey<String>('reel-new-section'),
          title: l10n.reelNewSinceTitle,
          subtitle: l10n.reelNewSinceSubtitle(edit.newCount),
          action: TtButton(
            label: vn
                ? l10n.reelCopyToFolder(editor)
                : l10n.reelAddToProject(editor),
            icon: Symbols.folder_copy_rounded,
            kind: TtButtonKind.tonal,
            size: TtButtonSize.small,
            onPressed: edit.newLiveCount == 0 ? null : onCopyNew,
          ),
        ),
      ),
      ...reelDaySlivers(context, edit.newDays, tiles: tiles, today: today),
    ],
    if (edit.inEditCount > 0) ...[
      SliverToBoxAdapter(
        child: ReelEditSectionHeader(
          key: const ValueKey<String>('reel-in-edit-section'),
          title: l10n.reelInEditTitle,
          subtitle: vn
              ? l10n.reelInEditFolder(edit.inEditCount, editor)
              : l10n.reelInEditSent(
                  edit.inEditCount,
                  editor,
                  ttDayText(
                    context,
                    edit.session.createdAt.toLocal(),
                    today: today,
                  ),
                ),
        ),
      ),
      ...reelDaySlivers(context, edit.inEditDays, tiles: tiles, today: today),
    ],
  ];
}

/// The header of a part of a reel's page while it is being edited: a
/// [title], a [subtitle] and an optional [action] (D-128).
///
/// The scene header's look (`TtSceneHeader`, prototype `.sec-h`: its room,
/// type, colours and 48 dp height, the title a heading), with two changes so
/// nothing is cut: the title and the subtitle wrap over as many lines as they
/// need, and the [action] sits at the end of the row while it fits beside
/// the text and moves under it when it does not (a narrow phone, large
/// text). `TtSceneHeader` itself keeps its subtitle to one line and its
/// action in the row, which cuts "{n} clips · sent to Edits on {date}" at
/// large text.
class ReelEditSectionHeader extends StatelessWidget {
  /// A header saying [title] and [subtitle], with [action] when given.
  const ReelEditSectionHeader({
    required this.title,
    required this.subtitle,
    this.action,
    super.key,
  });

  final String title;
  final String subtitle;

  /// A button for the part, or null for none.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final action = this.action;
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          header: true,
          child: Text(title, style: tt.text.material.titleSmall),
        ),
        Text(
          subtitle,
          style: tt.text
              .numeric(tt.text.material.bodySmall!)
              .copyWith(color: context.scheme.onSurfaceVariant),
        ),
      ],
    );
    // proto.css: .sec-h, as `TtSceneHeader`.
    return Padding(
      padding: EdgeInsets.fromLTRB(
        tt.spacing.gutter,
        tt.spacing.m,
        tt.spacing.gutter,
        tt.spacing.xs,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: tt.sizes.touchTarget),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          heightFactor: 1,
          // The whole width, so a button that fits sits at the end.
          child: SizedBox(
            width: double.infinity,
            child: action == null
                ? text
                : Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: tt.spacing.xs,
                    runSpacing: tt.spacing.xs,
                    children: [text, action],
                  ),
          ),
        ),
      ),
    );
  }
}

/// One day's tiles, three to a row, built on demand (D-87).
///
/// In a day with a missing tile the rows are as tall as that tile needs at
/// the phone's text scale (`TtMissingClipTile.heightFor`); the other tiles
/// keep their 3:4 shape at the top of the row.
class _DayGrid extends StatelessWidget {
  const _DayGrid({required this.day, required this.tiles});

  final ShootingDay<ReelClip> day;
  final ReelTiles tiles;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tt = context.tt;
    final hasMissing = day.clips.any((c) => c.clip.missing);
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final tileWidth =
            (constraints.crossAxisExtent -
                (reelGridColumns - 1) * tt.spacing.gridGap) /
            reelGridColumns;
        final natural = tileWidth / tt.sizes.clipTileAspect;
        final needed = hasMissing
            ? TtMissingClipTile.heightFor(
                context,
                width: tileWidth,
                label: l10n.clipMissing,
                removeLabel: l10n.clipRemove,
              )
            : 0.0;
        final extent = math.max(natural, needed);
        final grown = extent > natural;
        return SliverGrid.builder(
          gridDelegate: grown
              ? SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: reelGridColumns,
                  mainAxisSpacing: tt.spacing.gridGap,
                  crossAxisSpacing: tt.spacing.gridGap,
                  mainAxisExtent: extent,
                )
              : SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: reelGridColumns,
                  mainAxisSpacing: tt.spacing.gridGap,
                  crossAxisSpacing: tt.spacing.gridGap,
                  childAspectRatio: tt.sizes.clipTileAspect,
                ),
          itemCount: day.clips.length,
          itemBuilder: (context, index) {
            final item = day.clips[index];
            final tile = _tile(context, item, tileHeight: natural);
            // Under a tall row a picture tile stays 3:4; a missing tile fills
            // the row.
            return grown && !item.clip.missing
                ? Align(alignment: Alignment.topCenter, child: tile)
                : tile;
          },
        );
      },
    );
  }

  Widget _tile(
    BuildContext context,
    ReelClip item, {
    required double tileHeight,
  }) {
    final l10n = AppLocalizations.of(context);
    final clip = item.clip;
    if (clip.missing) {
      return TtMissingClipTile(
        key: ValueKey(clip.id),
        label: l10n.clipMissing,
        removeLabel: l10n.clipRemove,
        onRemove: () => tiles.onRemoveMissing(clip.id),
      );
    }
    // Where it was shot (D-83); the phone's time until that is known.
    final localTime = tiles.times[clip.id];
    final time = localTime != null
        ? wallClockTimeText(
            localTime.wallClock,
            locale: tiles.locale,
            use24Hour: tiles.use24Hour,
          )
        : timeOfDayText(
            clip.fingerprint.dateTakenUtc,
            locale: tiles.locale,
            use24Hour: tiles.use24Hour,
          );
    final length = formatClipDuration(clip.fingerprint.durationMs);
    final selection = tiles.selection;
    return TtClipTile(
      key: ValueKey(clip.id),
      thumbnail: clipThumbnail(
        clip: clip,
        logicalSize: tileHeight,
        cache: tiles.cache,
      ),
      timeText: time,
      durationText: length,
      reelCount: item.reelCount,
      horizontal: clip.width > clip.height,
      semanticLabel: item.reelCount > 1
          ? l10n.clipTileSemanticsInReels(time, length, item.reelCount)
          : l10n.clipTileSemantics(time, length),
      selected: selection.selecting
          ? selection.selected.contains(clip.id)
          : null,
      onTap: () => tiles.onTap(clip.id),
      onLongPress: () => tiles.onLongPress(clip.id),
    );
  }
}
