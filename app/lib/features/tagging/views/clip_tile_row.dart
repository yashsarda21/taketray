import 'package:flutter/material.dart';
import 'package:taketray/data/media/thumbnail_cache.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/models/clip_local_time.dart';
import 'package:taketray/features/clips/widgets/clip_thumbnail.dart';
import 'package:taketray/features/shooting_mode/views/shooting_time_text.dart';
import 'package:taketray/features/tagging/views/to_tag_screen.dart'
    show formatClipDuration;
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray_ui/taketray_ui.dart';

/// Columns of the clip grid on To tag and Skipped (proto.css: `.grid3`).
const int clipGridColumns = 3;

/// One row of the clip grid that To tag and Skipped show: up to
/// [clipGridColumns] clips, each a `TtClipTile` with the time it was shot
/// and its length, at the grid's gutters and gaps.
///
/// - **The time** is where the clip was shot ([times], D-83), or the
///   phone's until that is known.
/// - **A clip flagged missing** is the "Missing from phone" tile and takes no
///   taps. With [onRemoveMissing] it has the same **Remove** button as on the
///   reel page (D-87), and a row with such a tile is as tall as the tile needs
///   at the phone's text size (its neighbours keep their 3:4 shape at the
///   top). The verifier takes a missing MediaStore clip out of both lists
///   (D-72), but a picked clip that cannot be read is only flagged and stays
///   (D-116), so the user needs this to remove one that is really gone.
/// - **The caller decides the rest:** whether a tile is chosen ([selected],
///   null when not choosing), what a tap and a long press do, and what a
///   screen reader hears ([semanticLabel], given the time and the length).
///   [decorate] wraps a tile, for To tag's leaving tiles.
class ClipTileRow extends StatelessWidget {
  /// A row of [clips] (at most [clipGridColumns]).
  const new({
    required this.clips,
    required this.times,
    required this.cache,
    required this.locale,
    required this.use24Hour,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    required this.semanticLabel,
    this.decorate,
    this.onRemoveMissing,
    super.key,
  }) : assert(clips.length <= clipGridColumns, 'one row of the grid');

  final List<Clip> clips;

  /// The time where each clip was shot, by clip id.
  final Map<int, ClipLocalTime> times;
  final ThumbnailCache? cache;
  final String locale;
  final bool use24Hour;

  /// Whether a clip is chosen; null while not choosing.
  final bool? Function(Clip clip) selected;
  final void Function(Clip clip) onTap;
  final void Function(Clip clip) onLongPress;

  /// What a screen reader says for a tile showing a time and a length.
  final String Function(String time, String length) semanticLabel;

  /// Wraps a clip's tile, or returns it as it is.
  final Widget Function(Clip clip, Widget tile)? decorate;

  /// Called when **Remove** on a missing clip's tile is tapped; null for a
  /// missing tile with no Remove button.
  final void Function(Clip clip)? onRemoveMissing;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final l10n = AppLocalizations.of(context);
    final tileWidth =
        (MediaQuery.sizeOf(context).width -
            2 * tt.spacing.gutter -
            (clipGridColumns - 1) * tt.spacing.gridGap) /
        clipGridColumns;
    final natural = tileWidth / tt.sizes.clipTileAspect;
    // A row with a missing tile and a Remove button is as tall as the tile
    // needs at this text size, as on the reel page (D-87): not shrunk to fit
    // a 3:4 cell. At the normal text size that is less than 3:4, so nothing
    // grows.
    final needed = onRemoveMissing != null && clips.any((c) => c.missing)
        ? TtMissingClipTile.heightFor(
            context,
            width: tileWidth,
            label: l10n.clipMissing,
            removeLabel: l10n.clipRemove,
          )
        : 0.0;
    final grown = needed > natural;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        tt.spacing.gutter,
        tt.spacing.none,
        tt.spacing.gutter,
        tt.spacing.gridGap,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: tt.spacing.gridGap,
        children: [
          for (var i = 0; i < clipGridColumns; i++)
            Expanded(
              child: i < clips.length
                  ? (grown && clips[i].missing
                        // Fills the row; a picture tile keeps its 3:4 shape
                        // at the top of it.
                        ? SizedBox(
                            height: needed,
                            child: _tile(context, clips[i], tileWidth),
                          )
                        : AspectRatio(
                            aspectRatio: tt.sizes.clipTileAspect,
                            child: _tile(context, clips[i], tileWidth),
                          ))
                  : const SizedBox.shrink(),
            ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, Clip clip, double tileWidth) {
    final l10n = AppLocalizations.of(context);
    final tt = context.tt;
    if (clip.missing) {
      final remove = onRemoveMissing;
      return TtMissingClipTile(
        key: ValueKey(clip.id),
        label: l10n.clipMissing,
        removeLabel: remove == null ? null : l10n.clipRemove,
        onRemove: remove == null ? null : () => remove(clip),
      );
    }
    final localTime = times[clip.id];
    final time = localTime != null
        ? wallClockTimeText(
            localTime.wallClock,
            locale: locale,
            use24Hour: use24Hour,
          )
        : timeOfDayText(
            clip.fingerprint.dateTakenUtc,
            locale: locale,
            use24Hour: use24Hour,
          );
    final length = formatClipDuration(clip.fingerprint.durationMs);
    // The picture is asked for at the tile's height, the longer side.
    final tile = TtClipTile(
      key: ValueKey(clip.id),
      thumbnail: clipThumbnail(
        clip: clip,
        logicalSize: tileWidth / tt.sizes.clipTileAspect,
        cache: cache,
      ),
      timeText: time,
      durationText: length,
      semanticLabel: semanticLabel(time, length),
      selected: selected(clip),
      onTap: () => onTap(clip),
      onLongPress: () => onLongPress(clip),
    );
    return decorate?.call(clip, tile) ?? tile;
  }
}
