import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taketray/data/editors/edit_session_service.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/rules/shooting_order.dart';
import 'package:taketray/features/clips/widgets/media_counts.dart';
import 'package:taketray/features/editors/views/editor_sheet.dart';
import 'package:taketray/features/editors/views/editor_text.dart';
import 'package:taketray/features/editors/views/open_share.dart';
import 'package:taketray/features/reels/view_models/reel_clip_actions.dart';
import 'package:taketray/features/reels/view_models/reel_detail_controller.dart';
import 'package:taketray/features/reels/view_models/reel_edit_state.dart';
import 'package:taketray/features/reels/view_models/reel_selection.dart';
import 'package:taketray/features/reels/views/reel_picker_sheet.dart';
import 'package:taketray/features/reels/views/undo_snacks.dart';
import 'package:taketray/features/tagging/views/to_tag_screen.dart'
    show formatClipDuration;
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray_ui/taketray_ui.dart';

/// The dock for reel [reelId]'s chosen clips: Share, Add to, Move, Remove, and
/// Edit {n} clips or the editing note. It owns the actions the selection bar
/// had (share, the reel picker, remove with Undo) and their one-tap guards.
///
/// `AppShell` shows it in place of the nav pill while the reel's page is
/// choosing (`ChoosingReel`, D-191), so the floating snacks sit above it.
///
/// - **The four actions** are off with nothing chosen. **Share** opens
///   Android's share menu for the chosen clips in shooting order and keeps
///   the choice. **Add to** and **Move** open the reel picker (a failure is
///   told in the picker, D-85); **Remove** takes the clips out of the reel
///   with **Undo**. These three end choosing; a failure keeps it to try
///   again. Removing or moving clips of a reel being edited deletes their
///   copies first (R8).
/// - **Edit {n} clips**, with the live length of the chosen clips, opens the
///   editor sheet with them in shooting order. With photos chosen it reads
///   "Edit 2 clips and 1 photo" with the videos' length, or "Edit 2 photos"
///   with none (D-200). Choosing ends when an editor is picked (`Other
///   app…` too); a dismissed sheet keeps it. With nothing
///   chosen it reads "Tap the clips you want to edit" and is off, and it is
///   off while the reel's editing session is not read yet.
/// - **While the reel is being edited** (R1) a note stands in for Edit: "This
///   reel is being edited in {editor}. Tap Done editing at the top before
///   sending clips again."
///
/// Every action works once however fast the taps.
class ReelChoosingDock extends ConsumerStatefulWidget {
  const new({required this.reelId, super.key});

  final int reelId;

  @override
  ConsumerState<ReelChoosingDock> createState() => _ReelChoosingDockState();
}

class _ReelChoosingDockState extends ConsumerState<ReelChoosingDock> {
  /// A share is opening, so a second tap on Share does nothing.
  bool _sharing = false;

  /// A reel picker is open (Add to or Move), so a second tap on either does
  /// not open a second one.
  bool _picking = false;

  /// A remove is running, so a second tap on Remove does nothing.
  bool _removing = false;

  /// The editor sheet is open, so a second tap on Edit does nothing.
  bool _editing = false;

  /// The chosen clips that are in the reel, in shooting order.
  List<Clip> _chosenInOrder() {
    final chosen = ref.read(reelSelectionProvider(widget.reelId)).selected;
    final clips = ref.read(reelClipsProvider(widget.reelId)).value ?? const [];
    return inShootingOrder([
      for (final c in clips)
        if (chosen.contains(c.clip.id)) c.clip,
    ]);
  }

  List<int> _chosenIdsInOrder() => [for (final c in _chosenInOrder()) c.id];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final reelId = widget.reelId;
    final selection = ref.watch(reelSelectionProvider(reelId));
    final clips = ref.watch(reelClipsProvider(reelId)).value ?? const [];
    final editAsync = ref.watch(reelEditStateProvider(reelId));
    final edit = editAsync.value;

    final chosen = selection.selected;
    final count = chosen.length;
    final any = count > 0;
    final chosenClips = [
      for (final c in clips)
        if (chosen.contains(c.clip.id)) c.clip,
    ];
    // A chosen clip is never missing (`ReelSelection`), so this is the live
    // length of what is chosen (a photo has none).
    final length = formatClipDuration(
      chosenClips.fold(0, (sum, c) => sum + c.fingerprint.durationMs),
    );
    // With photos chosen, the videos and photos apart (D-200, R13-1): "Edit
    // 2 clips and 1 photo" with the videos' length, or "Edit 2 photos" with
    // no length. With none, as before.
    final photos = chosenClips.where((c) => c.isPhoto).length;
    final videos = count - photos;
    final counts = clipsAndPhotosText(l10n, videos: videos, photos: photos);

    return TtSelectionDock(
      semanticLabel: l10n.selectionDockLabel,
      actions: [
        TtSelectionDockAction(
          icon: Symbols.share_rounded,
          label: l10n.selectionDockShare,
          semanticLabel: l10n.reelMenuShare,
          onPressed: any ? () => unawaited(_share()) : null,
        ),
        TtSelectionDockAction(
          icon: Symbols.library_add_rounded,
          label: l10n.selectionDockAddTo,
          semanticLabel: l10n.selectionAddTo,
          onPressed: any
              ? () => unawaited(_pickReels(ReelPickerMode.add))
              : null,
        ),
        TtSelectionDockAction(
          icon: Symbols.drive_file_move_rounded,
          label: l10n.selectionDockMove,
          semanticLabel: l10n.selectionMoveTo,
          onPressed: any
              ? () => unawaited(_pickReels(ReelPickerMode.move))
              : null,
        ),
        TtSelectionDockAction(
          icon: Symbols.playlist_remove_rounded,
          label: l10n.selectionDockRemove,
          semanticLabel: l10n.selectionRemove,
          onPressed: any ? () => unawaited(_removeChosen()) : null,
        ),
      ],
      // A reel that is being edited finishes that edit first (R1).
      note: edit == null
          ? null
          : l10n.selectionDockEditingNote(editorShortName(l10n, edit.editor)),
      edit: edit != null
          ? null
          : TtSelectionDockEdit(
              label: !any
                  ? l10n.chooseClipsHintTitle
                  : photos == 0
                  ? l10n.selectionDockEdit(count)
                  : l10n.selectionDockEditWith(counts),
              detail: any && videos > 0 ? length : null,
              semanticLabel: !any
                  ? l10n.selectionDockEditNoneSemantics
                  : photos == 0
                  ? l10n.selectionDockEditSemantics(count, length)
                  : videos == 0
                  ? l10n.selectionDockEditWith(counts)
                  : l10n.selectionDockEditWithSemantics(counts, length),
              // Until the session is known, Edit waits.
              onPressed: any && editAsync.hasValue
                  ? () => unawaited(_edit())
                  : null,
            ),
    );
  }

  /// **Edit {n} clips**: the editor sheet with the chosen clips in shooting
  /// order. Picking an editor ends choosing; a dismissed sheet keeps it.
  Future<void> _edit() async {
    if (_editing) return;
    final chosen = _chosenInOrder();
    if (chosen.isEmpty) return;
    final notifier = ref.read(reelSelectionProvider(widget.reelId).notifier);
    _editing = true;
    try {
      final outcome = await showEditorSheet(
        context,
        reelId: widget.reelId,
        clipIds: [for (final c in chosen) c.id],
        photoCount: chosen.where((c) => c.isPhoto).length,
      );
      if (outcome.isPicked && mounted) notifier.clear();
    } finally {
      _editing = false;
    }
  }

  /// **Share**: Android's share menu for the chosen clips. The choice stays.
  Future<void> _share() async {
    if (_sharing) return;
    _sharing = true;
    try {
      await openShare(context, ref, _chosenIdsInOrder());
    } finally {
      _sharing = false;
    }
  }

  /// **Add to** / **Move**: opens the picker; **confirm** does the work
  /// inside the sheet (a failure stays in the sheet), and the snack with
  /// **Undo** is shown once the sheet has closed.
  Future<void> _pickReels(ReelPickerMode mode) async {
    if (_picking) return;
    final reelId = widget.reelId;
    final chosen = {...ref.read(reelSelectionProvider(reelId)).selected};
    if (chosen.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    final snacks = ReelSnacks.of(context);
    final actions = ref.read(reelClipActionsProvider);
    final notifier = ref.read(reelSelectionProvider(reelId).notifier);

    _picking = true;
    try {
      await pickAndPerform(
        context,
        mode: mode,
        clipIds: chosen,
        fromReelId: reelId,
        actions: actions,
        snacks: snacks,
        l10n: l10n,
        onSnack: () {
          if (mounted) notifier.clear();
        },
      );
    } finally {
      _picking = false;
    }
  }

  /// **Remove**: takes the chosen clips out of the reel and says so, with
  /// **Undo**. The videos and photos stay in the gallery.
  Future<void> _removeChosen() async {
    if (_removing) return;
    final reelId = widget.reelId;
    final chosen = {...ref.read(reelSelectionProvider(reelId)).selected};
    if (chosen.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    final snacks = ReelSnacks.of(context);
    final actions = ref.read(reelClipActionsProvider);
    final notifier = ref.read(reelSelectionProvider(reelId).notifier);
    _removing = true;
    try {
      final done = await actions.removeFromReel(
        reelId: reelId,
        clipIds: chosen,
      );
      if (!done.isEmpty) {
        final reel = done.reelNames.single;
        final photos = done.photoCount;
        final videos = done.clipCount - photos;
        // With photos (D-200, R13-5): "1 clip and 1 photo removed from Goa.
        // They're still in your gallery."; one photo alone reads as the
        // viewer's "Removed from Goa. The photo is still in your gallery.".
        final removed = photos == 0
            ? l10n.clipsRemovedSnack(done.clipCount, reel)
            : photos == 1 && videos == 0
            ? l10n.viewerPhotoRemovedSnack(reel)
            : l10n.clipsRemovedSnackWithPhotos(
                clipsAndPhotosText(l10n, videos: videos, photos: photos),
                reel,
              );
        snacks.showUndoAll(
          done.copiesDeleted > 0
              ? l10n.removedWithCopies(
                  removed,
                  l10n.copiesDeletedSuffix(done.copiesDeleted),
                )
              : removed,
          done.records,
        );
      }
      if (mounted) notifier.clear();
    } on CopiesNotDeleted {
      // Nothing was removed (R8); the choice is kept to try again.
      snacks.show(l10n.copiesNotDeleted, done: false);
    } on Object {
      // The actions logged the type; the choice is kept to try again.
      snacks.show(l10n.reelActionFailed, done: false);
    } finally {
      _removing = false;
    }
  }
}
