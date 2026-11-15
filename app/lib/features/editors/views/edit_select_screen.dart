import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/core/midnight_tick.dart';
import 'package:taketray/data/media/thumbnail_cache.dart';
import 'package:taketray/domain/models/editor_app.dart';
import 'package:taketray/domain/models/reel_clip.dart';
import 'package:taketray/domain/rules/shooting_days.dart';
import 'package:taketray/features/clips/widgets/clip_thumbnail.dart';
import 'package:taketray/features/editors/view_models/edit_select_controller.dart';
import 'package:taketray/features/editors/views/editor_sheet.dart';
import 'package:taketray/features/editors/views/editor_text.dart';
import 'package:taketray/features/reels/views/open_once.dart';
import 'package:taketray/features/reels/views/undo_snacks.dart';
import 'package:taketray/features/shooting_mode/views/shooting_time_text.dart';
import 'package:taketray/features/tagging/views/to_tag_screen.dart'
    show formatClipDuration;
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray/router/routes.dart';
import 'package:taketray_ui/taketray_ui.dart';

/// Columns of a day's clip grid (as on the reel's page).
const int _columns = 3;

/// The clip picking screen (prototype `edit-select`, D-126), full screen above
/// the tab shell (`Routes.editSelect`), opened from a reel's page by **Edit
/// video** or by the ⋮ menu's **Edit video** with the chosen clips ticked
/// ([clipIds]).
///
/// From the top: an app bar with a close button, "Pick clips to edit", the
/// reel's name, and **Select all** (**Clear** while every clip is ticked); a
/// note, "Clips go to your editor in the order you shot them."; the reel's
/// live clips under "Day {n} · {date}" headers, three to a row, each a
/// `TtClipTile` (the time where it was shot, its length) that a tap ticks or
/// un-ticks; and a bottom bar: "No clips picked" / "Tap the clips you want to
/// edit", or "{n} clips · {length}" / "{size} · in shooting order", and
/// **Continue**, off while nothing is ticked.
///
/// - **Only live clips are listed**, and a clip that goes missing while the
///   screen is open leaves the list and the choice.
/// - **Continue** opens the editor sheet (`showEditorSheet`) with the ticked
///   clips in shooting order, once however fast the taps.
/// - A reel that is gone (an id that names none, or one deleted while the
///   screen is open) sends the app to Reels.
///
/// **Add mode** ([addMode], `&add=1`, D-128, D-129), from the editing banner's
/// **Add more clips** and the reel page's **Copy to VN folder** / **Add to
/// your CapCut project** / **Add to your Edits project**: over every live
/// clip; the fresh ones start ticked, a clip whose copy is in the folder is
/// ticked and locked, a clip sent before without a copy can be ticked. The
/// bottom bar counts only the clips to copy and **Copy** opens the space check
/// (`Routes.copySpaceOf`) with them, in shooting order, once however fast the
/// taps. The words follow the session's editor:
/// - **VN:** "Add clips to VN folder", the mark "In VN folder", "{n} new clips
///   to copy" / "{size} · copies are added, never renamed", "Pick clips to
///   add" / "{n} already in the VN folder", and the snack "Already in the VN
///   folder. …".
/// - **CapCut and Edits** (the user adds the copies from the folder's album):
///   "Add clips to your CapCut project" (or "… Edits project"), the mark "In
///   the folder", "{n} clips to copy" / "{size} · into Movies/TakeTray/{folder}",
///   "Pick clips to add" / "{n} already in the folder", and "Already in the
///   folder. Copies are deleted when you tap Done editing.".
///
/// A reel with no session (Done editing ran meanwhile) goes back to its page.
class EditSelectScreen extends ConsumerStatefulWidget {
  const new({
    required this.reelId,
    this.clipIds = const [],
    this.addMode = false,
    super.key,
  });

  final int reelId;

  /// The clips to tick at first.
  final List<int> clipIds;

  /// Whether the screen was opened to add clips to a folder.
  final bool addMode;

  @override
  ConsumerState<EditSelectScreen> createState() => _EditSelectScreenState();
}

class _EditSelectScreenState extends ConsumerState<EditSelectScreen> {
  /// Set once the screen has sent the app to Reels, so it does so once.
  bool _leaving = false;

  /// The editor sheet is open (or opening): a second tap does nothing.
  bool _sheetOpen = false;

  late final EditSelectArgs _args = EditSelectArgs(
    widget.reelId,
    widget.clipIds,
    addMode: widget.addMode,
  );

  /// Opens the space check once however fast the taps (add mode).
  final OpenOnce _copy = OpenOnce();

  @override
  void dispose() {
    _copy.dispose();
    super.dispose();
  }

  EditSelectControllerProvider get _provider =>
      editSelectControllerProvider(_args);

  void _leave() {
    if (_leaving) return;
    _leaving = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go(Routes.reels);
    });
  }

  void _close() =>
      context.canPop() ? context.pop() : context.go(Routes.reel(widget.reelId));

  /// Add mode with no VN session to add to: back to the reel's page, once,
  /// after this frame.
  void _leaveToReel() {
    if (_leaving) return;
    _leaving = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _close();
    });
  }

  /// **Copy** (add mode): the space check for the clips to copy.
  void _copyPicked(EditSelectState state) {
    final editor = state.addEditor;
    if (editor == null || state.toCopyInOrder.isEmpty) return;
    final ids = state.toCopyInOrder;
    _copy.open(
      () => context.push(Routes.copySpaceOf(widget.reelId, editor, ids)),
    );
  }

  Future<void> _continue(EditSelectState state) async {
    if (_sheetOpen || state.pickedInOrder.isEmpty) return;
    _sheetOpen = true;
    try {
      await showEditorSheet(
        context,
        reelId: widget.reelId,
        clipIds: state.pickedInOrder,
      );
    } finally {
      _sheetOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tt = context.tt;
    final select = ref.watch(_provider);
    final state = select.value;
    if (select.hasValue && state == null) _leave();
    // Add mode needs the reel's editing session, of any editor.
    if (state != null && state.addMode && state.addEditor == null) {
      _leaveToReel();
    }
    final adding = state?.addMode ?? widget.addMode;
    final addEditor = state?.addEditor;
    final notifier = ref.read(_provider.notifier);
    final cache = ref.watch(thumbnailCacheProvider).value;
    final today =
        ref.watch(localDayProvider).value ??
        ref.watch(clockProvider).now().toLocal();
    final locale = Localizations.localeOf(context).toString();
    final use24Hour = MediaQuery.alwaysUse24HourFormatOf(context);

    // A long title wraps and grows the bar rather than be cut ("Add clips to
    // your CapCut project", or any title at large text). The
    // `Scaffold.appBar` slot has a fixed height, so then the bar is the first
    // child of the body (as on the notifications help screen). In add mode
    // the bar is always in the body, from the first frame: the editor, so the
    // title, is known only once the session is read, and the bar must not
    // jump from the slot to the body then (T12-m3).
    final largeText = MediaQuery.textScalerOf(context).scale(16) / 16 >= 1.5;
    final wrapTitle =
        (addEditor != null && addEditor != EditorApp.vn) ||
        (!adding && largeText);
    final barInBody = adding || wrapTitle;
    // At large text the long title and **Select all** do not fit side by
    // side (the title would break inside words), so the button goes under the
    // bar, at its end.
    final selectAllBelow = wrapTitle && largeText;
    final selectAll = TtButton(
      label: state?.allPicked ?? false
          ? l10n.editSelectClear
          : l10n.selectionSelectAll,
      kind: TtButtonKind.text,
      onPressed: state == null || state.liveCount <= state.inFolder.length
          ? null
          : state.allPicked
          ? notifier.clear
          : notifier.selectAll,
    );
    final bar = TtAppBar(
      // The words of add mode follow the session's editor, so they wait
      // until it is known.
      title: !adding
          ? l10n.editSelectTitle
          : addEditor == null
          ? ''
          : addEditor == EditorApp.vn
          ? l10n.editAddTitle(l10n.editorNameVn)
          : l10n.editAddProjectTitle(editorShortName(l10n, addEditor)),
      subtitle: state?.reel.name,
      wrapTitle: wrapTitle,
      leading: TtIconButton(
        icon: Symbols.close_rounded,
        semanticLabel: l10n.selectionClose,
        style: TtIconButtonStyle.circle,
        onPressed: _close,
      ),
      actions: [if (!selectAllBelow) selectAll],
    );
    final scroll = CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: TtInfoBar(
            icon: Symbols.sort_rounded,
            text: l10n.editSelectInfo,
          ),
        ),
        if (state != null)
          for (final day in state.days) ...[
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
              sliver: _dayGrid(
                context,
                day,
                state: state,
                cache: cache,
                locale: locale,
                use24Hour: use24Hour,
              ),
            ),
          ],
        // proto: `.end-space` (24 px) above the bottom bar.
        SliverToBoxAdapter(child: SizedBox(height: tt.spacing.xl)),
      ],
    );

    return Scaffold(
      appBar: barInBody ? null : bar,
      body: barInBody
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                bar,
                if (selectAllBelow)
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Padding(
                      padding: EdgeInsetsDirectional.only(end: tt.spacing.xxs),
                      child: selectAll,
                    ),
                  ),
                Expanded(child: scroll),
              ],
            )
          : scroll,
      bottomNavigationBar: _bottomBar(context, state),
    );
  }

  /// One day's tiles, three to a row, built on demand.
  Widget _dayGrid(
    BuildContext context,
    ShootingDay<ReelClip> day, {
    required EditSelectState state,
    required ThumbnailCache? cache,
    required String locale,
    required bool use24Hour,
  }) {
    final l10n = AppLocalizations.of(context);
    final tt = context.tt;
    final notifier = ref.read(_provider.notifier);
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final tileWidth =
            (constraints.crossAxisExtent -
                (_columns - 1) * tt.spacing.gridGap) /
            _columns;
        // The picture is asked for at the tile's height, the longer side.
        final tileHeight = tileWidth / tt.sizes.clipTileAspect;
        return SliverGrid.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _columns,
            mainAxisSpacing: tt.spacing.gridGap,
            crossAxisSpacing: tt.spacing.gridGap,
            childAspectRatio: tt.sizes.clipTileAspect,
          ),
          itemCount: day.clips.length,
          itemBuilder: (context, index) {
            final clip = day.clips[index].clip;
            final shot = state.times[clip.id];
            // Where it was shot (D-83); the phone's time until that is known.
            final time = shot != null
                ? wallClockTimeText(
                    shot.wallClock,
                    locale: locale,
                    use24Hour: use24Hour,
                  )
                : timeOfDayText(
                    clip.fingerprint.dateTakenUtc,
                    locale: locale,
                    use24Hour: use24Hour,
                  );
            final length = formatClipDuration(clip.fingerprint.durationMs);
            final label = l10n.clipTileSemantics(time, length);
            // Add mode: its copy is in the folder; ticked, locked, marked.
            final locked = state.inFolder.contains(clip.id);
            final vn = state.addEditor == EditorApp.vn;
            final editor = l10n.editorNameVn;
            void onTap() => locked
                ? _alreadyInFolder(context, state.addEditor)
                : notifier.toggle(clip.id);
            return TtClipTile(
              key: ValueKey<int>(clip.id),
              thumbnail: clipThumbnail(
                clip: clip,
                logicalSize: math.max(tileHeight, 0),
                cache: cache,
              ),
              timeText: time,
              durationText: length,
              horizontal: clip.width > clip.height,
              semanticLabel: !locked
                  ? label
                  : vn
                  ? l10n.clipTileSemanticsInFolder(label, editor)
                  : l10n.clipTileSemanticsInTheFolder(label),
              vnLabel: !locked
                  ? null
                  : vn
                  ? l10n.editInFolderMark(editor)
                  : l10n.editInTheFolderMark,
              // Always picking: every tile shows its check circle.
              selected: state.selected.contains(clip.id),
              onTap: onTap,
              onLongPress: onTap,
            );
          },
        );
      },
    );
  }

  /// "Already in the VN folder. …" (or "Already in the folder. …" for CapCut
  /// and Edits), for a tap on a locked tile.
  void _alreadyInFolder(BuildContext context, EditorApp? editor) {
    final l10n = AppLocalizations.of(context);
    ReelSnacks.of(context).show(
      editor == EditorApp.vn
          ? l10n.editAlreadyInFolderSnack(l10n.editorNameVn)
          : l10n.editAlreadyInTheFolderSnack,
      done: false,
    );
  }

  /// Add mode's bar: only the clips to copy count.
  Widget _addBar(BuildContext context, EditSelectState? state) {
    final l10n = AppLocalizations.of(context);
    final count = state?.toCopyInOrder.length ?? 0;
    final inFolder = state?.inFolder.length ?? 0;
    // Until the session is known the bar has VN's words, like the old one.
    final vn = (state?.addEditor ?? EditorApp.vn) == EditorApp.vn;
    final editor = l10n.editorNameVn;
    final size = count == 0 ? '' : byteSizeText(l10n, state!.toCopyBytes);
    return TtBottomBar(
      key: const ValueKey<String>('edit-select-bottom-bar'),
      title: count == 0
          ? l10n.editAddBarNone
          : vn
          ? l10n.editAddBarCount(count)
          : l10n.editAddFolderBarCount(count),
      subtitle: count == 0
          ? vn
                ? l10n.editAddBarInFolder(inFolder, editor)
                : l10n.editAddBarInTheFolder(inFolder)
          : vn
          ? l10n.editAddBarDetail(size)
          : l10n.editAddFolderBarDetail(size, state?.addFolder ?? ''),
      action: TtButton(
        key: const ValueKey<String>('edit-select-continue'),
        label: l10n.editAddCopy,
        onPressed: count == 0 ? null : () => _copyPicked(state!),
      ),
    );
  }

  Widget _bottomBar(BuildContext context, EditSelectState? state) {
    if (state?.addMode ?? widget.addMode) return _addBar(context, state);
    final l10n = AppLocalizations.of(context);
    final picked = state?.selected.length ?? 0;
    return TtBottomBar(
      key: const ValueKey<String>('edit-select-bottom-bar'),
      title: picked == 0
          ? l10n.editBarNone
          : l10n.editBarPicked(
              picked,
              formatClipDuration(state!.pickedDurationMs),
            ),
      subtitle: picked == 0
          ? l10n.editBarNoneHint
          : l10n.editBarPickedDetail(byteSizeText(l10n, state!.pickedBytes)),
      action: TtButton(
        key: const ValueKey<String>('edit-select-continue'),
        label: l10n.editContinue,
        onPressed: picked == 0 ? null : () => unawaited(_continue(state!)),
      ),
    );
  }
}
