import 'package:flutter/material.dart';
import 'package:taketray_ui/src/components/internal/chip_grid.dart';
import 'package:taketray_ui/src/components/internal/player_scrims.dart';
import 'package:taketray_ui/src/theme/tt_metrics.dart';
import 'package:taketray_ui/src/theme/tt_theme_data.dart';

/// The bottom of the full-screen tag player: the reels a clip can go into,
/// over the clip (D-171, D-179).
///
/// Rows, 8 dp apart, in a column on its own scrim (black, clear at the top,
/// 74 % from 26 dp down, 90 % from half way), with 28 dp above, 12 at the
/// sides and 22 below plus the gesture inset:
/// 1. [scrub], the scrub line, with 4 dp at the sides and 2 under it;
/// 2. the header, at least 40 dp high: the [title] (`titleSmall`, white, a
///    heading) and then the [actions], such as Pick several, All reels and
///    Cancel, which the caller builds as `TtButton`s;
/// 3. the grid: [emptyText] (a centred message, white at 85 %), then the
///    [chips] two to a row, 8 dp apart (164 dp each at 360 dp). A
///    `TtNewReelChip` with `fullWidth` takes a row of its own;
/// 4. [footer], 4 dp lower than the row gap would put it, such as the
///    "Add to 2 reels & next" button.
///
/// The grid is at most 260 dp high at every text scale and scrolls past it
/// (the header and the footer stay put). Pick several can hold many picked
/// reels, and the clip keeps its room. From a text scale of
/// `TtMetrics.reelDockSingleColumnTextScale` (1.5) the grid is one column of
/// full-width chips and the header is a `Wrap`, so a long title and the
/// actions fall onto a second line instead of being cut.
///
/// The chips are `TtReelChipStyle.onVideo` glass. They blur what is behind
/// them, which is this dock's scrim, and the on-video New reel chip reaches
/// AA only over it: keep the chips in the dock. The scrim is painted behind
/// the content and takes no touches. The whole dock is one semantics group
/// named [semanticLabel], with the title as a heading and every chip and
/// action a node of its own.
class TtReelDock extends StatelessWidget {
  /// A dock titled [title], named [semanticLabel], with [chips] in the grid.
  const new({
    required this.title,
    required this.semanticLabel,
    required this.chips,
    this.scrub,
    this.actions = const [],
    this.emptyText,
    this.footer,
    super.key,
  });

  /// The header text, such as "Add to reel" or "Pick reels".
  final String title;

  /// What a screen reader says for the dock as a group, such as "Reels".
  final String semanticLabel;

  /// The chips (`TtReelChip`s, then perhaps a `TtNewReelChip`), laid out two
  /// to a row, or one at large text.
  final List<Widget> chips;

  /// The scrub line over the header, or null for none.
  final Widget? scrub;

  /// The text buttons at the end of the header, in order.
  final List<Widget> actions;

  /// A message across the whole row above the chips, such as "You don't
  /// have any reels yet. Create one and this clip goes into it."; none when
  /// null.
  final String? emptyText;

  /// A widget under the grid, or null for none.
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final large = scale >= TtMetrics.largeTextScale;
    final single = scale >= TtMetrics.reelDockSingleColumnTextScale;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final scrubLine = scrub;
    final message = emptyText;
    final bottom = footer;

    final heading = Semantics(
      header: true,
      child: Text(
        title,
        style: tt.text.material.titleSmall!.copyWith(color: tt.colors.onVideo),
      ),
    );
    // player2.css:40-41: .p2-dh { display: flex; align-items: center;
    // gap: 2px; min-height: 40px; padding-left: 4px }
    final header = ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: TtMetrics.reelDockHeaderHeight,
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.only(
          start: TtMetrics.reelDockHeaderPaddingStart,
        ),
        // player2.css:57: .fs2 .p2-dh { flex-wrap: wrap }
        // A Wrap gives each child at most its own width, so a long title
        // wraps its words rather than overflow.
        child: large
            ? Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: TtMetrics.reelDockHeaderGap,
                children: [heading, ...actions],
              )
            : Row(
                spacing: TtMetrics.reelDockHeaderGap,
                children: [
                  Expanded(child: heading),
                  ...actions,
                ],
              ),
      ),
    );

    // player2.css:52: .p2-none { grid-column: 1 / -1; text-align: center;
    // padding: 8px; color: rgba(255,255,255,.85) }
    final rows = <Widget>[
      if (message != null)
        Padding(
          padding: const EdgeInsets.all(TtMetrics.reelDockEmptyPadding),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: tt.text.material.bodyMedium!.copyWith(
              color: tt.colors.onVideo.withValues(
                alpha: TtMetrics.reelDockEmptyTextOpacity,
              ),
            ),
          ),
        ),
      ...chipGridRows(chips, large: single, gap: TtMetrics.reelDockGridGap),
    ];

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: semanticLabel,
      child: CustomPaint(
        painter: DockScrimPainter(tt.colors.videoBackground),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            TtMetrics.reelDockPaddingSide,
            TtMetrics.reelDockPaddingTop,
            TtMetrics.reelDockPaddingSide,
            TtMetrics.reelDockPaddingBottom + bottomInset,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: TtMetrics.reelDockGap,
            children: [
              if (scrubLine != null)
                Padding(
                  padding: const EdgeInsets.only(
                    left: TtMetrics.reelDockScrubPaddingSide,
                    right: TtMetrics.reelDockScrubPaddingSide,
                    bottom: TtMetrics.reelDockScrubPaddingBottom,
                  ),
                  child: scrubLine,
                ),
              header,
              // player2.css:56: .fs2 .p2-grid { max-height: 260px;
              // overflow-y: auto }, at every scale here (D-179).
              ConstrainedBox(
                constraints: const BoxConstraints(
                  maxHeight: TtMetrics.reelDockGridMaxHeight,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: TtMetrics.reelDockGridGap,
                    children: rows,
                  ),
                ),
              ),
              if (bottom != null)
                Padding(
                  padding: const EdgeInsets.only(
                    top: TtMetrics.reelDockFooterGap,
                  ),
                  child: bottom,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
