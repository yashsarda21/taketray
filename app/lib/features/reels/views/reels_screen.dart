import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taketray/domain/models/editor_app.dart';
import 'package:taketray/domain/models/reel_summary.dart';
import 'package:taketray/features/editors/views/editor_text.dart';
import 'package:taketray/features/notifications/views/still_shooting_dialog.dart';
import 'package:taketray/features/reels/view_models/home_controller.dart';
import 'package:taketray/features/reels/view_models/reel_edit_state.dart';
import 'package:taketray/features/reels/view_models/reel_filters.dart';
import 'package:taketray/features/reels/views/open_once.dart';
import 'package:taketray/features/reels/views/reel_form_sheet.dart';
import 'package:taketray/features/reels/views/reel_status_menu.dart';
import 'package:taketray/features/shooting_mode/views/shooting_mode_section.dart';
import 'package:taketray/features/tagging/views/to_tag_screen.dart'
    show formatClipDuration;
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray/router/routes.dart';
import 'package:taketray_ui/taketray_ui.dart';

/// Home, the Reels tab: the calm grid (D-86, D-187, D-196; `home2.js:56-68`).
/// One scrolling page, from the top:
///
/// 1. the large header "Reels" (`TtLargeSliverAppBar`), which shrinks into a
///    pinned bar as the page scrolls, with **+ New** at its end (read "New
///    reel"; it opens the New reel sheet), with or without reels;
/// 2. the access banner and the compact Shooting mode card
///    (`ShootingModeSection`, D-196); once Shooting mode has been on for 14
///    days, the "Still shooting?" dialog opens over the screen
///    (`StillShootingPromptHost`, D-107);
/// 3. when at least one reel exists, the quiet tabs: All, Collecting, Ready
///    and Published, each with how many reels it shows (a group read "Show
///    reels"; each tab read "{status}, {n} reels");
/// 4. the reels, newest first, two to a row (one from a text scale of
///    `TtMetrics.largeTextScale`), built as they scroll into view: 16 dp at
///    the sides, 12 between the columns and 16 between the rows, each card
///    as tall as its own text (the rows are aligned to the top,
///    `home2.css:55`).
///    A card (`TtReelCard`) is the cover alone, then the name, the status,
///    "{n} clips · {m:ss}" (or "No clips yet") and a line of notes only when
///    they apply: "In {editor}" while the reel has an editing session (none
///    until the sessions are known), "{n} missing", and the number of
///    references. It is one button, read as the name, the status and the
///    clips, then ". Editing in {editor}", then ". {n} references". It opens
///    the reel's page (a double tap opens one);
/// 5. room for the nav pill (`TtNavPill.reservedHeight`).
///
/// **Empty:** with no reel at all, "Plan your first reel" and a **New reel**
/// button. A tab with no reels says "No reels marked {status} yet." over a
/// tonal **Show all reels**.
///
/// **Switching tabs** fades the reels in over `short4` (nothing slides). With
/// "remove animations" on, the fade stays (only movement goes, F6).
///
/// While the first list is being read nothing below the Shooting mode card
/// is shown, so a phone with reels never flashes the first-time screen. The
/// scroll position is kept while another tab is open (the shell keeps the
/// tab built).
class ReelsScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends ConsumerState<ReelsScreen>
    with SingleTickerProviderStateMixin {
  /// Opens a reel's page once however fast the taps: a second tap on a card,
  /// even in the same frame, does not open a second one (a short window, not
  /// the push's future, which the delete's `go` never completes).
  final OpenOnce _reel = OpenOnce();

  /// The reels' fade after a change of tab. It is over (1) until the first
  /// change. The handoff's crossfade is a fade, not a movement, so it keeps
  /// the token's `short4` with "remove animations" on, where `tt.motion` is
  /// zero (F6).
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: TtMotion.standardSet.short4,
    value: 1,
  );

  late final CurvedAnimation _fadeCurve = CurvedAnimation(
    parent: _fade,
    curve: TtMotion.standardSet.standard,
  );

  void _openReel(int reelId) =>
      _reel.open(() => context.push(Routes.reel(reelId)));

  /// Shows [filter]'s reels, fading them in.
  void _setFilter(ReelFilter filter) {
    final controller = ref.read(homeControllerProvider.notifier);
    if (ref.read(homeControllerProvider).value?.filter == filter) return;
    _fade.forward(from: 0);
    controller.setFilter(filter);
  }

  @override
  void dispose() {
    _fadeCurve.dispose();
    _fade.dispose();
    _reel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final home = ref.watch(homeControllerProvider).value;
    final editors =
        ref.watch(reelEditorsProvider).value ?? const <int, EditorApp>{};
    final hasReels = home != null && home.hasReels;

    return Scaffold(
      body: Stack(
        children: [
          // Asks "Still shooting?" when it is due (D-107); draws nothing.
          const StillShootingPromptHost(),
          CustomScrollView(
            slivers: [
              TtLargeSliverAppBar(
                title: l10n.navReels,
                actions: [
                  TtHeaderPill(
                    icon: Symbols.add_rounded,
                    label: l10n.reelsNew,
                    semanticLabel: l10n.reelsNewReel,
                    onPressed: () => showReelForm(context),
                  ),
                ],
              ),
              const SliverToBoxAdapter(child: ShootingModeSection()),
              if (home != null && hasReels)
                SliverToBoxAdapter(
                  child: _Tabs(
                    filter: home.filter,
                    counts: home.counts,
                    onChanged: _setFilter,
                  ),
                ),
              if (home != null && !hasReels)
                SliverToBoxAdapter(
                  child: TtEmptyState(
                    illustration: TtIllustrationKind.noReels,
                    title: l10n.reelsEmptyTitle,
                    body: l10n.reelsEmptyBody,
                    actions: [
                      TtButton(
                        label: l10n.reelsNewReel,
                        icon: Symbols.add_rounded,
                        onPressed: () => showReelForm(context),
                      ),
                    ],
                  ),
                )
              else if (home != null)
                SliverFadeTransition(
                  opacity: _fadeCurve,
                  sliver: home.reels.isEmpty
                      ? SliverToBoxAdapter(
                          child: _EmptyTab(
                            filter: home.filter,
                            onShowAll: () => _setFilter(ReelFilter.all),
                          ),
                        )
                      : _Grid(
                          reels: home.reels,
                          covers: home.covers,
                          editors: editors,
                          onOpen: _openReel,
                        ),
                ),
              SliverToBoxAdapter(
                child: SizedBox(height: TtNavPill.reservedHeight(context)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// [filter] in words, as a screen reader says it: All, or the status in
/// full.
String _filterName(AppLocalizations l10n, ReelFilter filter) {
  final status = filter.status;
  return status == null ? l10n.reelFilterAll : statusName(l10n, status);
}

/// [filter] as its tab shows it: Ready to edit is shortened to "Ready".
String _tabLabel(AppLocalizations l10n, ReelFilter filter) =>
    filter == ReelFilter.ready ? l10n.reelTabReady : _filterName(l10n, filter);

/// The quiet tabs (`.h2-tabs` in the prototype): the chosen one filled, each
/// with how many reels it shows.
class _Tabs extends StatelessWidget {
  const new({
    required this.filter,
    required this.counts,
    required this.onChanged,
  });

  final ReelFilter filter;
  final Map<ReelFilter, int> counts;
  final ValueChanged<ReelFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return TtQuietTabs<ReelFilter>(
      value: filter,
      onChanged: onChanged,
      semanticLabel: l10n.reelTabsLabel,
      tabs: [
        for (final f in ReelFilter.values)
          TtQuietTab(
            f,
            _tabLabel(l10n, f),
            counts[f] ?? 0,
            semanticLabel: l10n.reelFilterChipSemantics(
              _filterName(l10n, f),
              counts[f] ?? 0,
            ),
          ),
      ],
    );
  }
}

/// A tab with no reels (`.h2-none`): "No reels marked {status} yet." over
/// **Show all reels**.
class _EmptyTab extends StatelessWidget {
  const new({required this.filter, required this.onShowAll});

  final ReelFilter filter;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tt = context.tt;
    // home2.css:46: .h2-none { margin: 24px 16px; gap: 8px;
    //   text-align: center; color: on-surface-variant }
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: TtMetrics.homeEmptyTabMarginVertical,
        horizontal: TtMetrics.homeEmptyTabMarginHorizontal,
      ),
      child: Column(
        spacing: TtMetrics.homeEmptyTabGap,
        children: [
          Text(
            l10n.reelTabEmpty(_filterName(l10n, filter)),
            textAlign: TextAlign.center,
            style: tt.text.material.bodyMedium!.copyWith(
              color: context.scheme.onSurfaceVariant,
            ),
          ),
          TtButton(
            label: l10n.reelsShowAll,
            kind: TtButtonKind.tonal,
            onPressed: onShowAll,
          ),
        ],
      ),
    );
  }
}

/// The reels in rows (`.h2-grid`): two columns, one at large text.
///
/// Rows are built as they scroll into view, so 25 reels build a screenful of
/// cards, not 25. Each row is aligned to the top and each card is as tall as
/// its own text, so a two-line name does not stretch the card beside it (a
/// grid with a fixed aspect ratio would).
class _Grid extends StatelessWidget {
  const new({
    required this.reels,
    required this.covers,
    required this.editors,
    required this.onOpen,
  });

  final List<ReelSummary> reels;
  final Map<int, ImageProvider?> covers;
  final Map<int, EditorApp> editors;
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) {
    // home2.css:64: .fs2 .h2-grid { grid-template-columns: minmax(0, 1fr) }
    final columns =
        MediaQuery.textScalerOf(context).scale(1) >= TtMetrics.largeTextScale
        ? 1
        : 2;
    final rows = (reels.length + columns - 1) ~/ columns;
    return SliverPadding(
      padding: const EdgeInsets.symmetric(
        horizontal: TtMetrics.homeGridPaddingHorizontal,
      ),
      sliver: SliverList.builder(
        itemCount: rows,
        itemBuilder: (context, row) => Padding(
          padding: EdgeInsets.only(
            top: row == 0 ? 0 : TtMetrics.homeGridRowGap,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: TtMetrics.homeGridColumnGap,
            children: [
              for (var i = row * columns; i < (row + 1) * columns; i++)
                Expanded(
                  child: i < reels.length
                      ? _ReelCard(
                          key: ValueKey(reels[i].reel.id),
                          summary: reels[i],
                          cover: covers[reels[i].reel.id],
                          editor: editors[reels[i].reel.id],
                          onOpen: onOpen,
                        )
                      : const SizedBox.shrink(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One reel on Home (`h.reelCard` in the prototype): the calm card, with its
/// notes (In {editor}, missing, references) when they apply.
class _ReelCard extends StatelessWidget {
  const new({
    required this.summary,
    required this.cover,
    required this.editor,
    required this.onOpen,
    super.key,
  });

  final ReelSummary summary;
  final ImageProvider? cover;

  /// The editor the reel is being edited in, or null.
  final EditorApp? editor;

  /// Opens the reel's page (once, however fast the taps).
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final reel = summary.reel;
    final status = statusName(l10n, reel.status);
    final clips = l10n.reelCardClips(summary.clipCount);
    final missing = summary.missingCount;
    final references = summary.referenceCount;
    final label = missing > 0
        ? l10n.reelCardSemanticsMissing(
            reel.name,
            status,
            summary.clipCount,
            missing,
          )
        : l10n.reelCardSemantics(reel.name, status, summary.clipCount);
    final editor = this.editor;
    final editing = editor == null
        ? null
        : l10n.reelCardInEditor(editorShortName(l10n, editor));
    var semanticLabel = label;
    if (editor != null) {
      semanticLabel = l10n.reelCardSemanticsEditing(
        semanticLabel,
        l10n.reelEditingIn(editorShortName(l10n, editor)),
      );
    }
    if (references > 0) {
      semanticLabel = l10n.reelCardSemanticsReferences(
        semanticLabel,
        references,
      );
    }
    return TtReelCard(
      name: reel.name,
      status: statusKindOf(reel.status),
      statusLabel: status,
      // The length counts only the clips that are still on the phone.
      meta: summary.clipCount == 0
          ? l10n.reelCardEmptyArt
          : l10n.reelCardMeta(
              clips,
              formatClipDuration(summary.liveDurationMs),
            ),
      cover: cover,
      notes: [
        if (editing != null)
          TtReelCardNote(TtReelCardNoteKind.editing, editing),
        if (missing > 0)
          TtReelCardNote(
            TtReelCardNoteKind.missing,
            l10n.reelCardMissing(missing),
          ),
        if (references > 0)
          TtReelCardNote(TtReelCardNoteKind.references, '$references'),
      ],
      semanticLabel: semanticLabel,
      onTap: () => onOpen(reel.id),
    );
  }
}
