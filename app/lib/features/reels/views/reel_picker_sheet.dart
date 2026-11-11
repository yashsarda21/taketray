import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taketray/data/media/thumbnail_cache.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/reel_summary.dart';
import 'package:taketray/domain/models/undo_record.dart';
import 'package:taketray/domain/rules/text_limits.dart';
import 'package:taketray/features/clips/widgets/clip_thumbnail.dart';
import 'package:taketray/features/reels/view_models/home_controller.dart';
import 'package:taketray/features/reels/view_models/reel_clip_actions.dart';
import 'package:taketray/features/reels/view_models/reel_detail_controller.dart';
import 'package:taketray/features/reels/view_models/reel_form_controller.dart';
import 'package:taketray/features/reels/view_models/reel_picker.dart';
import 'package:taketray/features/reels/views/reel_form_sheet.dart';
import 'package:taketray/features/reels/views/sheet_failure.dart';
import 'package:taketray/features/reels/views/undo_snacks.dart';
import 'package:taketray/features/tagging/view_models/last_tags.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray_ui/taketray_ui.dart';

/// What the reel picker picks reels for.
enum ReelPickerMode {
  /// Also put the clips in other reels; they stay where they are. Several
  /// reels can be picked.
  add,

  /// Take the clips out of this reel and put them in one other reel.
  move,

  /// Tag clips that are waiting in To tag (D-98): they are in no reel yet, so
  /// nothing is left out of the list. Several reels can be picked; the
  /// clips leave To tag.
  tag,
}

/// Opens the reel picker (`screens.js`: `sheets.picker`, D-88) for
/// [clipCount] clips that are in reel [excludeReelId], and returns the ids of
/// the reels picked, or null when it was cancelled or dragged away.
///
/// [excludeReelId] is the reel the clips are in, which is not listed; add and
/// move need it (asserted). **Tag mode** (D-98) passes null: the clips are in
/// To tag, so every reel is listed, and the title, the line under it and the
/// confirm button are "Tag {n} clips", "Pick one or more reels." and "Tag {n}
/// clips" / "Tag into {k} reels".
///
/// From the top: a title and a line saying whether the clips stay or leave,
/// **New reel** (a row that becomes a name field with **Create**: the reel is
/// made and picked), the **Collecting** reels, then **Other reels**; the
/// reel the clips are in is not listed. **Cancel** and a confirm button
/// (**Add** / "Add to {n} reels", or **Move**) that is disabled until a reel
/// is picked. Add picks several reels (check boxes), move one (radio
/// buttons).
///
/// **The sheet's own failure is told in the sheet** (D-85): when [perform] is
/// given, **confirm** runs it with the picked ids and closes the sheet with
/// them only when it ended well. If it throws, the sheet stays open with its
/// picks and says "Something went wrong. Try again." above its buttons, and
/// the failure goes at the next pick or confirm. Without [perform] the sheet
/// just closes with the ids and the caller does the work. Snacks are for the
/// caller, after the sheet has closed.
Future<List<int>?> showReelPicker(
  BuildContext context, {
  required ReelPickerMode mode,
  required int clipCount,
  required int? excludeReelId,
  Future<void> Function(List<int> reelIds)? perform,
}) {
  assert(
    mode == ReelPickerMode.tag || excludeReelId != null,
    'add and move need the reel the clips are in',
  );
  return showTtSheet<List<int>>(
    context,
    builder: (_) => _ReelPickerSheet(
      mode: mode,
      clipCount: clipCount,
      excludeReelId: excludeReelId,
      perform: perform,
    ),
  );
}

/// **Add to reel** / **Move** for [clipIds], which are in reel [fromReelId]:
/// opens the picker, does the work inside it, and shows the snack once it has
/// closed (D-88, D-89). Returns what the action did, or null when it did not
/// run (cancelled, or it failed).
///
/// **Tag** (D-98) is for clips waiting in To tag, so [fromReelId] is null
/// (asserted for add and move). Confirm adds them to every picked reel in one
/// transaction (`ReelClipActions.addToReels`; they leave To tag), remembers
/// the picked reels as the last tag (`LastTags`, so the player's **Same as
/// previous** follows it) and the snack says "{n} clips added to {names}"
/// ({n}: the clips that got a new place, from the records) with
/// **Undo**, which takes the tag back and puts `LastTags` back to what
/// it was unless another tag has been remembered since.
///
/// - **Confirm runs the action** (`ReelClipActions.addToReels` / `moveToReel`)
///   through the picker's `perform`, so a failure is told in the sheet and
///   the sheet stays open (D-85).
/// - **The snack comes after the sheet closes**, with **Undo** for everything
///   the action changed (`ReelSnacks.showUndoAll`); an add that changed
///   nothing (the clips were there already) shows the plain snack, and a
///   move that moved nothing (every chosen clip had left the reel meanwhile)
///   shows none, as a remove of nothing does. If the
///   sheet was dragged away while the action ran, nothing is modal any more,
///   so `perform` shows the snack itself when it finishes (or the failure
///   snack). [onSnack] is called after a success (also when no snack was
///   shown), for the caller to end what it was doing (the reel page ends
///   choosing).
///
/// Everything the snack needs ([actions], [snacks], and the words from
/// [l10n]) is passed in, looked up by the caller before this awaits, so it
/// works after the caller's screen has gone.
Future<ClipActionOutcome?> pickAndPerform(
  BuildContext context, {
  required ReelPickerMode mode,
  required Set<int> clipIds,
  required int? fromReelId,
  required ReelClipActions actions,
  required ReelSnacks snacks,
  required AppLocalizations l10n,
  VoidCallback? onSnack,
}) async {
  assert(
    mode == ReelPickerMode.tag || fromReelId != null,
    'add and move need the reel the clips are in',
  );
  // Looked up now, before anything is awaited: the snack's Undo outlives the
  // screen that raised it.
  final container = ProviderScope.containerOf(context, listen: false);
  final lastTags = mode == ReelPickerMode.tag
      ? container.read(lastTagsProvider.notifier)
      : null;
  ClipActionOutcome? outcome;
  // What `LastTags` held before this tag set it, and what it set, for Undo.
  List<int>? tagBefore;
  List<int>? tagSet;
  var closed = false;
  void tell(ClipActionOutcome done) {
    // Every chosen clip was gone by the confirm (or, for a move, had left the
    // reel): nothing happened, so nothing is said, as for a remove of
    // nothing.
    if (done.clipCount == 0) {
      onSnack?.call();
      return;
    }
    final message = switch (mode) {
      ReelPickerMode.add => addedToText(l10n, done.reelNames),
      ReelPickerMode.move => l10n.movedToSnack(done.reelNames.single),
      // The clips really added (a clip a picked reel had already is not
      // counted), as the skip snacks count what moved.
      ReelPickerMode.tag => l10n.tagClipsAddedSnack(
        {
          for (final record in done.records)
            if (record is AddUndo)
              for (final link in record.createdLinks) link.clipId,
        }.length,
        joinedNamesText(l10n, done.reelNames),
      ),
    };
    if (!done.isEmpty) {
      if (mode == ReelPickerMode.tag) {
        final before = tagBefore;
        final set = tagSet;
        snacks.showUndoAll(
          message,
          done.records,
          undo: () async {
            await container.read(reelsRepositoryProvider).undoAll(done.records);
            if (lastTags != null && before != null && set != null) {
              lastTags.undo(current: set, previous: before);
            }
          },
        );
      } else {
        snacks.showUndoAll(message, done.records);
      }
    } else if (mode != ReelPickerMode.move) {
      // Nothing changed (the clips were there already): nothing to undo.
      snacks.show(message);
    }
    // A move that moved nothing (every chosen clip had left the reel
    // meanwhile) says nothing, as a remove that removed nothing does.
    onSnack?.call();
  }

  await showReelPicker(
    context,
    mode: mode,
    clipCount: clipIds.length,
    excludeReelId: fromReelId,
    perform: (reelIds) async {
      try {
        final done = mode == ReelPickerMode.move
            ? await actions.moveToReel(
                fromReelId: fromReelId!,
                toReelId: reelIds.single,
                clipIds: clipIds,
              )
            : await actions.addToReels(clipIds: clipIds, reelIds: reelIds);
        // A tag of nothing (every clip gone) is not remembered.
        if (lastTags != null && done.clipCount > 0) {
          tagBefore = lastTags.current;
          tagSet = lastTags.set(reelIds);
        }
        outcome = done;
        // The sheet was dragged away while this ran: it is not modal any
        // more, so the snack is seen now.
        if (closed) tell(done);
      } on Object {
        // The actions logged the type. In the sheet it tells the user
        // itself; after it closed, a snack does.
        if (!closed) rethrow;
        snacks.show(l10n.reelActionFailed, done: false);
      }
    },
  );
  closed = true;
  final done = outcome;
  if (done != null) tell(done);
  return done;
}

/// The snack after an add: "Added to {A}", "Added to {A} and {B}" or "Added
/// to {A}, {B} and {n} more" (owner-approved, 2026-10-30), for the names of
/// the reels in the order they were picked.
String addedToText(AppLocalizations l10n, List<String> names) =>
    switch (names.length) {
      0 => throw ArgumentError.value(names, 'names', 'must not be empty'),
      1 => l10n.addedToOneSnack(names[0]),
      2 => l10n.addedToTwoSnack(names[0], names[1]),
      _ => l10n.addedToMoreSnack(names[0], names[1], names.length - 2),
    };

/// The reel names of a tag, joined as [addedToText] joins them: "A", "A and
/// B", "A, B and {k} more" (D-98), for "{n} clips added to {names}".
String joinedNamesText(AppLocalizations l10n, List<String> names) =>
    switch (names.length) {
      0 => throw ArgumentError.value(names, 'names', 'must not be empty'),
      1 => names[0],
      2 => l10n.reelNamesTwo(names[0], names[1]),
      _ => l10n.reelNamesMore(names[0], names[1], names.length - 2),
    };

class _ReelPickerSheet extends ConsumerStatefulWidget {
  const new({
    required this.mode,
    required this.clipCount,
    required this.excludeReelId,
    required this.perform,
  });

  final ReelPickerMode mode;
  final int clipCount;
  final int? excludeReelId;
  final Future<void> Function(List<int> reelIds)? perform;

  @override
  ConsumerState<_ReelPickerSheet> createState() => _ReelPickerSheetState();
}

class _ReelPickerSheetState extends ConsumerState<_ReelPickerSheet> {
  final TextEditingController _name = TextEditingController();

  List<int> _picked = const [];

  /// Whether the New reel row has become the name field.
  bool _newOpen = false;

  /// The last confirm or create failed for a reason the user cannot fix.
  bool _failed = false;

  /// A confirm is running; the buttons wait.
  bool _busy = false;

  /// Add and tag pick several reels (check boxes); move picks one.
  bool get _multi => widget.mode != ReelPickerMode.move;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _pick(int id) => setState(() {
    _picked = togglePick(_picked, id, multi: _multi);
    _failed = false;
  });

  Future<void> _create() async {
    final provider = reelFormControllerProvider(null);
    if (ref.read(provider).saving) return;
    if (_failed) setState(() => _failed = false);
    final controller = ref.read(provider.notifier);
    try {
      final reel = await controller.save(name: _name.text);
      // A refused name is shown under the field by the controller's state.
      if (reel == null || !mounted) return;
      setState(() {
        _picked = pickedAfterCreate(_picked, reel.id, multi: _multi);
        _newOpen = false;
        _name.clear();
      });
    } on Object {
      // The controller logged the type.
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _confirm() async {
    if (_picked.isEmpty || _busy) return;
    final navigator = Navigator.of(context);
    final picked = List<int>.of(_picked);
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      await widget.perform?.call(picked);
      if (mounted) navigator.pop(picked);
    } on Object {
      // The caller logged the type. The sheet stays open with its picks; if
      // it was dragged away meanwhile, the caller tells the user itself.
      if (mounted) {
        setState(() {
          _busy = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tt = context.tt;
    final summaries = ref.watch(reelSummariesProvider).value ?? const [];
    final cache = ref.watch(thumbnailCacheProvider).value;
    final excluded = widget.excludeReelId;
    final current = excluded == null
        ? null
        : ref.watch(reelByIdProvider(excluded)).value;
    final form = ref.watch(reelFormControllerProvider(null));
    final sections = pickerSections(
      summaries,
      excludeReelId: widget.excludeReelId,
    );
    final count = widget.clipCount;
    final title = switch (widget.mode) {
      ReelPickerMode.add => l10n.pickerTitleAdd(count),
      ReelPickerMode.move => l10n.pickerTitleMove(count),
      ReelPickerMode.tag => l10n.pickerTitleTag(count),
    };
    final subtitle = switch (widget.mode) {
      ReelPickerMode.add => l10n.pickerSubtitleAdd(count),
      ReelPickerMode.move => l10n.pickerSubtitleMove(
        count,
        current?.name ?? l10n.pickerThisReel,
      ),
      ReelPickerMode.tag => l10n.pickerSubtitleTag,
    };
    final confirmLabel = switch (widget.mode) {
      ReelPickerMode.add =>
        _picked.isEmpty
            ? l10n.pickerAdd
            : l10n.pickerAddToReels(_picked.length),
      ReelPickerMode.move => l10n.pickerMove,
      // One reel (or none yet): "Tag 5 clips"; more: "Tag into 2 reels".
      ReelPickerMode.tag =>
        _picked.length > 1
            ? l10n.pickerTagIntoReels(_picked.length)
            : l10n.pickerTitleTag(count),
    };

    Widget row(ReelSummary summary) {
      final clips = l10n.reelCardClips(summary.clipCount);
      return TtReelPickRow(
        key: ValueKey(summary.reel.id),
        name: summary.reel.name,
        countText: clips,
        semanticLabel: l10n.pickerRowSemantics(summary.reel.name, clips),
        selected: _picked.contains(summary.reel.id),
        multi: _multi,
        onTap: () => _pick(summary.reel.id),
        cover: summary.cover == null
            ? null
            : clipThumbnail(
                clip: summary.cover!,
                logicalSize: homeCoverSize,
                cache: cache,
              ),
      );
    }

    return TtSheet(
      title: title,
      footer: SheetFooter(
        failure: _failed ? l10n.reelActionFailed : null,
        buttons: TtButtonRow(
          children: [
            TtButton(
              label: l10n.cancel,
              kind: TtButtonKind.text,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            TtButton(
              label: confirmLabel,
              onPressed: _picked.isEmpty || _busy
                  ? null
                  : () => unawaited(_confirm()),
            ),
          ],
        ),
      ),
      child: ListView(
        shrinkWrap: true,
        padding: EdgeInsets.only(bottom: tt.spacing.s),
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: tt.spacing.xl),
            child: Text(
              subtitle,
              style: tt.text.material.bodyMedium!.copyWith(
                color: context.scheme.onSurfaceVariant,
              ),
            ),
          ),
          if (_newOpen)
            Padding(
              padding: EdgeInsets.fromLTRB(
                tt.spacing.m,
                tt.spacing.xs,
                tt.spacing.m,
                tt.spacing.s,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: tt.spacing.s,
                children: [
                  Expanded(
                    child: TtTextField(
                      label: l10n.pickerNewReelName,
                      hint: l10n.reelNameHint,
                      controller: _name,
                      error: reelNameErrorText(l10n, form, _name.text),
                      maxLength: reelNameMaxLength,
                      counterText: l10n.reelCounter,
                      autofocus: true,
                      textInputAction: TextInputAction.done,
                      onChanged: (_) {
                        ref
                            .read(reelFormControllerProvider(null).notifier)
                            .clearErrors();
                        if (_failed) setState(() => _failed = false);
                      },
                      onSubmitted: (_) => unawaited(_create()),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: tt.spacing.s),
                    child: TtButton(
                      label: l10n.pickerCreate,
                      kind: TtButtonKind.tonal,
                      onPressed: form.saving
                          ? null
                          : () => unawaited(_create()),
                    ),
                  ),
                ],
              ),
            )
          else
            TtReelPickNewRow(
              label: l10n.pickerNewReel,
              onTap: () => setState(() => _newOpen = true),
            ),
          if (sections.collecting.isNotEmpty) ...[
            TtGroupLabel(l10n.statusCollecting),
            for (final summary in sections.collecting) row(summary),
          ],
          if (sections.other.isNotEmpty) ...[
            TtGroupLabel(l10n.pickerOtherReels),
            for (final summary in sections.other) row(summary),
          ],
        ],
      ),
    );
  }
}
