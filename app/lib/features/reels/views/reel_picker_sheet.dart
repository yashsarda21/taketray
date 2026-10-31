import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taketray/data/media/thumbnail_cache.dart';
import 'package:taketray/domain/models/reel_summary.dart';
import 'package:taketray/domain/rules/text_limits.dart';
import 'package:taketray/features/clips/widgets/clip_thumbnail.dart';
import 'package:taketray/features/reels/view_models/home_controller.dart';
import 'package:taketray/features/reels/view_models/reel_detail_controller.dart';
import 'package:taketray/features/reels/view_models/reel_form_controller.dart';
import 'package:taketray/features/reels/view_models/reel_picker.dart';
import 'package:taketray/features/reels/views/reel_form_sheet.dart';
import 'package:taketray/features/reels/views/sheet_failure.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray_ui/taketray_ui.dart';

/// What the reel picker picks reels for. Tag mode is Phase 5.
enum ReelPickerMode {
  /// Also put the clips in other reels; they stay where they are. Several
  /// reels can be picked.
  add,

  /// Take the clips out of this reel and put them in one other reel.
  move,
}

/// Opens the reel picker (`screens.js`: `sheets.picker`, D-88) for
/// [clipCount] clips that are in reel [excludeReelId], and returns the ids of
/// the reels picked, or null when it was cancelled or dragged away.
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
  required int excludeReelId,
  Future<void> Function(List<int> reelIds)? perform,
}) => showTtSheet<List<int>>(
  context,
  builder: (_) => _ReelPickerSheet(
    mode: mode,
    clipCount: clipCount,
    excludeReelId: excludeReelId,
    perform: perform,
  ),
);

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

class _ReelPickerSheet extends ConsumerStatefulWidget {
  const new({
    required this.mode,
    required this.clipCount,
    required this.excludeReelId,
    required this.perform,
  });

  final ReelPickerMode mode;
  final int clipCount;
  final int excludeReelId;
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

  bool get _multi => widget.mode == ReelPickerMode.add;

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
    final current = ref.watch(reelByIdProvider(widget.excludeReelId)).value;
    final form = ref.watch(reelFormControllerProvider(null));
    final sections = pickerSections(
      summaries,
      excludeReelId: widget.excludeReelId,
    );
    final count = widget.clipCount;
    final title = _multi
        ? l10n.pickerTitleAdd(count)
        : l10n.pickerTitleMove(count);
    final subtitle = _multi
        ? l10n.pickerSubtitleAdd(count)
        : l10n.pickerSubtitleMove(count, current?.name ?? l10n.pickerThisReel);
    final confirmLabel = _multi
        ? (_picked.isEmpty
              ? l10n.pickerAdd
              : l10n.pickerAddToReels(_picked.length))
        : l10n.pickerMove;

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
