import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taketray/data/media/thumbnail_cache.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/domain/models/reel_summary.dart';
import 'package:taketray/features/clips/widgets/clip_thumbnail.dart';
import 'package:taketray/features/reels/view_models/home_controller.dart';
import 'package:taketray/features/tagging/view_models/tag_session_controller.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray_ui/taketray_ui.dart';

/// **All reels** (D-181, the handoff's "All reels (sheet)"): every reel, for
/// the clip the tag player shows, opened from the dock.
///
/// A `TtSheet` in the video theme, titled "Add to reel" ("Pick reels for this
/// clip" while picking), holding "Collecting" with its chips, New reel, then
/// "Other reels" with the Ready and Published ones (a heading only when it
/// has reels). The chips are the surface ones, two to a row (one from a text
/// scale of `TtMetrics.reelDockSingleColumnTextScale`). The sheet watches the
/// session of [startClipId] and the reels itself, so a pick or a new reel
/// shows at once.
///
/// - **Not picking:** a tap on a reel closes the sheet, then calls [onTag]
///   with it, which tags as a tap in the dock does (the check, the hold, the
///   next clip). A long press starts Pick several with that reel, and the
///   sheet stays.
/// - **Picking:** a tap picks or unpicks the reel, and the sheet stays; a
///   full-width **Done** closes it with the picks kept (a reel picked here
///   joins the dock).
/// - **New reel** closes the sheet, then calls [onNewReel].
///
/// Only the first tap that closes the sheet counts: a second one while it
/// slides away does nothing (it would pop the player).
Future<void> showAllReelsSheet(
  BuildContext context, {
  required int? startClipId,
  required ValueChanged<int> onTag,
  required VoidCallback onNewReel,
}) => showTtSheet<void>(
  context,
  builder: (_) => Theme(
    data: TakeTrayTheme.video(),
    child: _AllReelsSheet(
      startClipId: startClipId,
      onTag: onTag,
      onNewReel: onNewReel,
    ),
  ),
);

class _AllReelsSheet extends ConsumerStatefulWidget {
  const new({
    required this.startClipId,
    required this.onTag,
    required this.onNewReel,
  });

  final int? startClipId;
  final ValueChanged<int> onTag;
  final VoidCallback onNewReel;

  @override
  ConsumerState<_AllReelsSheet> createState() => _AllReelsSheetState();
}

class _AllReelsSheetState extends ConsumerState<_AllReelsSheet> {
  /// The sheet is going: a tap that closed it has been taken.
  bool _closing = false;

  /// Closes the sheet once, then calls [then].
  void _closeThen(VoidCallback then) {
    if (_closing) return;
    _closing = true;
    Navigator.of(context).pop();
    then();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tt = context.tt;
    final provider = tagSessionControllerProvider(widget.startClipId);
    final state = ref.watch(provider).value;
    final controller = ref.read(provider.notifier);
    final summaries =
        ref.watch(reelSummariesProvider).value ?? const <ReelSummary>[];
    final cache = ref.watch(thumbnailCacheProvider).value;
    final multi = state?.multi ?? false;
    final picked = state?.picked ?? const <int>[];
    final large =
        MediaQuery.textScalerOf(context).scale(1) >=
        TtMetrics.reelDockSingleColumnTextScale;

    Widget chip(ReelSummary summary) {
      final id = summary.reel.id;
      final name = summary.reel.name;
      return TtReelChip(
        key: ValueKey(id),
        name: name,
        countText: l10n.reelCardClips(summary.clipCount),
        semanticLabel: multi
            ? l10n.tagChipPickSemantics(name, summary.clipCount)
            : l10n.tagChipSemantics(name, summary.clipCount),
        cover: summary.cover == null
            ? null
            : clipThumbnail(
                clip: summary.cover!,
                logicalSize: homeCoverSize,
                cache: cache,
              ),
        state: multi && picked.contains(id)
            ? TtReelChipState.picked
            : TtReelChipState.idle,
        multiSelect: multi,
        onTap: multi
            ? () => controller.togglePick(id)
            : () => _closeThen(() => widget.onTag(id)),
        onLongPress: multi ? null : () => controller.longPressReel(id),
      );
    }

    final collecting = [
      for (final s in summaries)
        if (s.reel.status == ReelStatus.collecting) chip(s),
    ];
    final others = [
      for (final s in summaries)
        if (s.reel.status != ReelStatus.collecting) chip(s),
    ];
    final fresh = TtNewReelChip(
      title: l10n.tagNewReel,
      subtitle: l10n.tagNewReelSubtitle,
      onTap: () => _closeThen(widget.onNewReel),
    );

    return TtSheet(
      title: multi ? l10n.tagPickTitle : l10n.tagPanelTitle,
      footer: multi
          ? TtButton(
              label: l10n.tagAllReelsDone,
              expand: true,
              onPressed: () => _closeThen(() {}),
            )
          : null,
      child: ListView(
        shrinkWrap: true,
        padding: EdgeInsets.only(
          left: tt.spacing.m,
          right: tt.spacing.m,
          bottom: tt.spacing.s,
        ),
        children: [
          if (collecting.isNotEmpty) _Label(l10n.statusCollecting),
          ..._grid([...collecting, fresh], large: large, gap: tt.spacing.xs),
          if (others.isNotEmpty) ...[
            _Label(l10n.tagOtherReels),
            ..._grid(others, large: large, gap: tt.spacing.xs),
          ],
        ],
      ),
    );
  }
}

/// [cells] two to a row, [gap] apart, or one to a row at [large] text; a
/// lone cell at the end keeps its half width (`proto.css:724`, `.chipgrid`).
List<Widget> _grid(
  List<Widget> cells, {
  required bool large,
  required double gap,
}) {
  final perRow = large ? 1 : 2;
  return [
    for (var i = 0; i < cells.length; i += perRow)
      Padding(
        padding: EdgeInsets.only(bottom: gap),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: gap,
          children: [
            for (var j = i; j < i + perRow; j++)
              Expanded(
                child: j < cells.length ? cells[j] : const SizedBox.shrink(),
              ),
          ],
        ),
      ),
  ];
}

/// A section's heading in the sheet ("Collecting", "Other reels"):
/// `labelMedium` in the quiet colour, a heading for a screen reader
/// (`proto.css:726`, `.chipgrid .lbl`).
class _Label extends StatelessWidget {
  const new(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        tt.spacing.xs,
        TtMetrics.allReelsLabelPaddingTop,
        tt.spacing.xs,
        tt.spacing.xs,
      ),
      child: Semantics(
        header: true,
        child: Text(
          text,
          style: tt.text.material.labelMedium!.copyWith(
            color: context.scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
