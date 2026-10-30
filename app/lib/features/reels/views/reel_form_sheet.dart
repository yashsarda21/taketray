import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/domain/models/reel.dart';
import 'package:taketray/domain/rules/text_limits.dart';
import 'package:taketray/features/reels/view_models/reel_form_controller.dart';
import 'package:taketray/features/reels/views/reel_status_menu.dart';
import 'package:taketray/features/reels/views/undo_snacks.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray_ui/taketray_ui.dart';

/// From this many characters the Shot ideas counter shows (D-85); the field
/// stops at [reelDescriptionMaxLength].
const int _descriptionCounterFrom = 900;

/// Opens the New reel sheet, or, with [reel], the Reel details sheet
/// (`screens.js`: `sheets.reelForm`, without the reference link, which is
/// Phase 9).
///
/// - **New reel:** the name and the Shot ideas. **Create reel** saves, closes
///   the sheet and shows "{name} created".
/// - **Reel details:** the same, filled in, and the status choices. **Save**
///   saves everything in one go, closes the sheet and shows "Saved".
///
/// A name that is empty, too long or another reel's is explained under the
/// field and the sheet stays open. If the save fails for another reason,
/// "Something went wrong. Try again." is shown and the sheet stays open.
///
/// The snacks are on the root messenger, so they show after the sheet has
/// closed, even if the sheet was dragged away while it saved.
Future<void> showReelForm(BuildContext context, {Reel? reel}) {
  final l10n = AppLocalizations.of(context);
  final snacks = ReelSnacks.of(context);
  return showTtSheet<void>(
    context,
    builder: (_) => _ReelFormSheet(
      reel: reel,
      onSaved: (saved) => snacks.show(
        reel == null ? l10n.reelCreatedSnack(saved.name) : l10n.reelSavedSnack,
      ),
      onFailed: () => snacks.show(l10n.reelActionFailed, done: false),
    ),
  );
}

class _ReelFormSheet extends ConsumerStatefulWidget {
  const new({
    required this.reel,
    required this.onSaved,
    required this.onFailed,
  });

  final Reel? reel;
  final ValueChanged<Reel> onSaved;
  final VoidCallback onFailed;

  @override
  ConsumerState<_ReelFormSheet> createState() => _ReelFormSheetState();
}

class _ReelFormSheetState extends ConsumerState<_ReelFormSheet> {
  late final TextEditingController _name = TextEditingController(
    text: widget.reel?.name,
  );
  late final TextEditingController _description = TextEditingController(
    text: widget.reel?.description,
  );
  late ReelStatus _status = widget.reel?.status ?? ReelStatus.collecting;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    // The controller is single-flight; this also keeps the sheet from asking
    // twice while the buttons redraw.
    final provider = reelFormControllerProvider(widget.reel?.id);
    if (ref.read(provider).saving) return;
    final controller = ref.read(provider.notifier);
    final navigator = Navigator.of(context);
    try {
      final reel = await controller.save(
        name: _name.text,
        description: _description.text,
        status: widget.reel == null ? null : _status,
      );
      if (reel == null) return; // The sheet shows why.
      if (mounted) navigator.pop();
      widget.onSaved(reel);
    } on Object {
      // The controller logged the type.
      widget.onFailed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tt = context.tt;
    final edit = widget.reel != null;
    final form = ref.watch(reelFormControllerProvider(widget.reel?.id));
    final nameError = switch (form.nameError) {
      null => null,
      ReelNameProblem.empty => l10n.reelNameEmpty,
      ReelNameProblem.tooLong => l10n.reelNameTooLong(reelNameMaxLength),
      ReelNameProblem.duplicate => l10n.reelNameDuplicate(
        form.clashingName ?? normalizeName(_name.text),
      ),
    };
    final descriptionError = switch (form.descriptionError) {
      null => null,
      ReelDescriptionProblem.tooLong => l10n.reelDescriptionTooLong(
        reelDescriptionMaxLength,
      ),
    };
    void typing(String _) => ref
        .read(reelFormControllerProvider(widget.reel?.id).notifier)
        .clearErrors();

    return TtSheet(
      title: edit ? l10n.reelFormTitleEdit : l10n.reelFormTitleNew,
      footer: TtButtonRow(
        children: [
          TtButton(
            label: l10n.cancel,
            kind: TtButtonKind.text,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          TtButton(
            label: edit ? l10n.reelSaveButton : l10n.reelCreateButton,
            onPressed: form.saving ? null : () => unawaited(_save()),
          ),
        ],
      ),
      child: ListView(
        shrinkWrap: true,
        padding: EdgeInsets.fromLTRB(
          tt.spacing.xl,
          tt.spacing.none,
          tt.spacing.xl,
          tt.spacing.s,
        ),
        children: [
          TtTextField(
            label: l10n.reelNameLabel,
            hint: l10n.reelNameHint,
            controller: _name,
            error: nameError,
            maxLength: reelNameMaxLength,
            counterText: l10n.reelCounter,
            autofocus: true,
            textInputAction: TextInputAction.next,
            onChanged: typing,
            onSubmitted: (_) => unawaited(_save()),
          ),
          TtTextField(
            label: l10n.reelDescriptionLabel,
            hint: l10n.reelDescriptionHint,
            helper: l10n.reelDescriptionHelp,
            controller: _description,
            error: descriptionError,
            multiline: true,
            maxLength: reelDescriptionMaxLength,
            // Quiet until it is nearly full.
            counterText: (length, max) => length < _descriptionCounterFrom
                ? ''
                : l10n.reelCounter(length, max),
            onChanged: typing,
          ),
          if (edit) ...[
            SizedBox(height: tt.spacing.m),
            Semantics(
              header: true,
              child: Text(
                l10n.reelStatusHeading,
                style: tt.text.material.labelLarge!.copyWith(
                  color: context.scheme.onSurfaceVariant,
                ),
              ),
            ),
            Semantics(
              container: true,
              role: SemanticsRole.radioGroup,
              label: l10n.reelStatusHeading,
              child: Column(
                children: [
                  for (final status in ReelStatus.values)
                    _StatusRadioRow(
                      status: status,
                      selected: status == _status,
                      onTap: () => setState(() => _status = status),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One status choice of the details sheet: a radio mark, the status pill and
/// what it means. A screen reader hears one radio: "Collecting, Still shooting
/// clips for it", checked or not.
class _StatusRadioRow extends StatelessWidget {
  const new({
    required this.status,
    required this.selected,
    required this.onTap,
  });

  final ReelStatus status;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tt = context.tt;
    final name = statusName(l10n, status);
    final description = statusDescription(l10n, status);
    // proto.css: .li with padding 4px 8px
    return Semantics(
      container: true,
      excludeSemantics: true,
      checked: selected,
      inMutuallyExclusiveGroup: true,
      label: '$name, $description',
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: tt.sizes.touchTarget),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: tt.spacing.xs,
              vertical: tt.spacing.xxs,
            ),
            child: Row(
              spacing: tt.spacing.s,
              children: [
                TtRadioMark(selected: selected),
                TtStatusPill(kind: statusKindOf(status), label: name),
                Expanded(
                  child: Text(
                    description,
                    style: tt.text.material.bodySmall!.copyWith(
                      color: context.scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
