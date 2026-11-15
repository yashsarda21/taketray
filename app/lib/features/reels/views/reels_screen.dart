import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taketray/domain/models/editor_app.dart';
import 'package:taketray/domain/models/enums.dart';
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

/// Columns of the reel grid (proto.css: `.reelgrid`).
const int _columns = 2;

/// Home, the Reels tab (D-86). From the top:
///
/// 1. a large app bar "Reels";
/// 2. the access banner and the Shooting mode card, with its clips-waiting
///    banner (`ShootingModeSection`, D-76); once Shooting mode has been on for
///    14 days, the "Still shooting?" dialog opens over the screen
///    (`StillShootingPromptHost`, D-107);
/// 3. when at least one reel exists, the filter chips: All, Collecting, Ready
///    to edit and Published, each with how many reels it shows;
/// 4. the reels, two to a row, newest first, as a lazy grid of `TtReelCard`s;
///    a card shows the cover (the oldest clip with a picture), the status,
///    "{n} clips · {m:ss}" (the length of the clips that are not missing)
///    and "{n} missing", and opens the reel's page. A reel being edited
///    shows the pill "Editing in {editor}" ("VN", "CapCut", "Edits"; R8) and
///    is read with ". Editing in {editor}" at the end (D-128); no pill until
///    the sessions are known.
///
/// **Empty:** with no reel at all, "Plan your first reel" and a **New reel**
/// button, and no floating button. With reels but none passing the chosen
/// filter, "No reels marked {status}", what to do about it, and **Show all
/// reels**. **New reel** (the floating button, only while reels exist) opens
/// the New reel sheet.
///
/// While the first list is being read nothing below the Shooting mode card
/// is shown (neither "no reels" nor the floating button), so a phone with
/// reels never flashes the first-time screen. The scroll position is kept
/// while another tab is open (the shell keeps the tab built). A double tap
/// on a card opens one reel page.
class ReelsScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends ConsumerState<ReelsScreen> {
  /// Opens a reel's page once however fast the taps: a second tap on a card,
  /// even in the same frame, does not open a second one (a short window, not
  /// the push's future, which the delete's `go` never completes).
  final OpenOnce _reel = OpenOnce();

  void _openReel(int reelId) =>
      _reel.open(() => context.push(Routes.reel(reelId)));

  @override
  void dispose() {
    _reel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tt = context.tt;
    final home = ref.watch(homeControllerProvider).value;
    final editors =
        ref.watch(reelEditorsProvider).value ?? const <int, EditorApp>{};
    final controller = ref.read(homeControllerProvider.notifier);
    final hasReels = home != null && home.hasReels;

    // Room to scroll the last row clear of the nav pill, and of the floating
    // button above it.
    final bottomSpace = hasReels
        ? TtNavPill.fabBottom(context) + TtMetrics.fabHeight + tt.spacing.m
        : TtNavPill.reservedHeight(context);

    return Scaffold(
      appBar: TtAppBar(large: true, title: l10n.navReels),
      body: Stack(
        children: [
          // Asks "Still shooting?" when it is due (D-107); draws nothing.
          const StillShootingPromptHost(),
          CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(child: ShootingModeSection()),
              if (home != null && hasReels)
                SliverToBoxAdapter(
                  child: _FilterChips(
                    filter: home.filter,
                    counts: home.counts,
                    onChanged: controller.setFilter,
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
              else if (home != null && home.reels.isEmpty)
                SliverToBoxAdapter(
                  child: TtEmptyState(
                    illustration: TtIllustrationKind.emptyReel,
                    title: l10n.reelFilterEmptyTitle(
                      _filterName(l10n, home.filter),
                    ),
                    body: _filterEmptyBody(l10n, home.filter),
                    actions: [
                      TtButton(
                        label: l10n.reelsShowAll,
                        kind: TtButtonKind.tonal,
                        onPressed: () => controller.setFilter(ReelFilter.all),
                      ),
                    ],
                  ),
                )
              else if (home != null)
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    tt.spacing.gutter,
                    tt.spacing.xxs,
                    tt.spacing.gutter,
                    tt.spacing.none,
                  ),
                  // A grid built on demand: 25 reels build a screenful of
                  // cards, not 25.
                  sliver: SliverGrid.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: _columns,
                      mainAxisSpacing: tt.spacing.s,
                      crossAxisSpacing: tt.spacing.s,
                      childAspectRatio: TtMetrics.reelCardAspect,
                    ),
                    itemCount: home.reels.length,
                    itemBuilder: (context, index) => _ReelCard(
                      key: ValueKey(home.reels[index].reel.id),
                      summary: home.reels[index],
                      cover: home.covers[home.reels[index].reel.id],
                      editor: editors[home.reels[index].reel.id],
                      onOpen: _openReel,
                    ),
                  ),
                ),
              SliverToBoxAdapter(child: SizedBox(height: bottomSpace)),
            ],
          ),
          if (hasReels)
            PositionedDirectional(
              end: tt.spacing.gutter,
              bottom: TtNavPill.fabBottom(context),
              child: TtFab(
                label: l10n.reelsNewReel,
                icon: Symbols.add_rounded,
                onPressed: () => showReelForm(context),
              ),
            ),
        ],
      ),
    );
  }
}

/// [filter] in words, as its chip says it: All, or the status.
String _filterName(AppLocalizations l10n, ReelFilter filter) {
  final status = filter.status;
  return status == null ? l10n.reelFilterAll : statusName(l10n, status);
}

/// What to do about a filter that has no reels.
String _filterEmptyBody(AppLocalizations l10n, ReelFilter filter) =>
    switch (filter.status) {
      ReelStatus.collecting => l10n.reelFilterEmptyCollecting,
      ReelStatus.ready => l10n.reelFilterEmptyReady,
      ReelStatus.published => l10n.reelFilterEmptyPublished,
      // All has no empty state of its own: with no reels at all Home shows
      // "Plan your first reel". The first-time text is the safe answer.
      null => l10n.reelsEmptyBody,
    };

/// The filter chips (`.chips` in the prototype): single-select pill tabs
/// saying how many reels each filter shows.
class _FilterChips extends StatelessWidget {
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
    return TtPillTabs<ReelFilter>(
      value: filter,
      onChanged: onChanged,
      tabs: [
        for (final f in ReelFilter.values)
          TtPillTab(
            f,
            l10n.reelFilterChip(_filterName(l10n, f), counts[f] ?? 0),
            semanticLabel: l10n.reelFilterChipSemantics(
              _filterName(l10n, f),
              counts[f] ?? 0,
            ),
          ),
      ],
    );
  }
}

/// One reel on Home (`h.reelCard` in the prototype, without the references
/// badge, which is Phase 9).
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
        : l10n.reelEditingIn(editorShortName(l10n, editor));
    return TtReelCard(
      name: reel.name,
      status: statusKindOf(reel.status),
      statusLabel: status,
      // The length counts only the clips that are still on the phone.
      meta: summary.clipCount == 0
          ? clips
          : l10n.reelCardMeta(
              clips,
              formatClipDuration(summary.liveDurationMs),
            ),
      missingText: missing > 0 ? l10n.reelCardMissing(missing) : null,
      emptyLabel: l10n.reelCardEmptyArt,
      cover: cover,
      vnLabel: editing,
      semanticLabel: editing == null
          ? label
          : l10n.reelCardSemanticsEditing(label, editing),
      onTap: () => onOpen(reel.id),
    );
  }
}
