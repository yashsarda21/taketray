import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:taketray/data/repositories/references_repository.dart';
import 'package:taketray/domain/models/reel_reference.dart';
import 'package:taketray/domain/rules/reference_links.dart';
import 'package:taketray/domain/rules/text_limits.dart';
import 'package:taketray/features/reels/view_models/reel_detail_controller.dart';
import 'package:taketray/features/reels/views/sheet_failure.dart';
import 'package:taketray/features/reels/views/undo_snacks.dart';
import 'package:taketray/features/references/view_models/reference_form_controller.dart';
import 'package:taketray/features/references/views/reference_source_icon.dart';
import 'package:taketray/features/references/views/reference_text.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray_ui/taketray_ui.dart';

// The error type only, never the clipboard's text (D-10).
final Logger _log = Logger('referenceSheet');

/// Opens the **Add reference** sheet for reel [reelId], or, with [editing],
/// the **Edit label** sheet of that reference (`screens.js`:
/// `sheets.addRef`, D-157).
///
/// - **Add:** "Add reference", "to {reel}". A **Link** field with a **Paste**
///   button inside it, and a **Label (optional)** field (60 characters).
///   **Save** (or Enter in Label) saves, closes the sheet and shows
///   "Reference saved" with **Undo**, which removes it again.
/// - **Paste** is the only thing that reads the clipboard (spec 2A): not
///   opening the sheet, not Save. It takes the first link of the text there,
///   puts it in the Link field and moves to Label. With no link (empty, an
///   image, a caption with no link) it says "There's no link on your
///   clipboard."
/// - **Edit label:** "Edit label", the reel's name, the source row (the
///   phone's icon of the source app or the link symbol, what the link is and
///   the short link), and the Label field, which takes the focus. **Save**
///   saves, a blank label clears it, and "Label saved" is shown.
///
/// What is wrong with the link is told under the Link field ("That isn't a
/// link. …", "Already saved in {reel}") and goes at the next edit. A failure
/// the user cannot fix ("Couldn't save the reference.", for instance when
/// the reel was deleted while the sheet was open) is told **in the sheet**,
/// above its buttons, and the text is kept (D-85).
///
/// The snacks are on the root messenger, so they show after the sheet has
/// closed.
Future<void> showReferenceSheet(
  BuildContext context, {
  required int reelId,
  ReelReference? editing,
}) {
  assert(
    editing == null || editing.reelId == reelId,
    'the reference being edited is on the reel',
  );
  final l10n = AppLocalizations.of(context);
  final snacks = ReelSnacks.of(context);
  final references = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(referencesRepositoryProvider);
  return showTtSheet<void>(
    context,
    builder: (_) => _ReferenceSheet(
      reelId: reelId,
      editing: editing,
      onSaved: (saved) {
        if (editing != null) {
          snacks.show(l10n.referenceLabelSavedSnack);
          return;
        }
        snacks.showUndoAll(
          l10n.referenceSavedSnack,
          const [],
          // Undo of an add is a delete (R2): a reference already removed is
          // nothing to undo, and not an error.
          undo: () async {
            await references.delete(saved.id);
          },
        );
      },
      // Only used when the sheet is gone: then nothing is modal, and a snack
      // is seen.
      onFailedAfterClose: () =>
          snacks.show(l10n.referenceSaveFailed, done: false),
    ),
  );
}

class _ReferenceSheet extends ConsumerStatefulWidget {
  const new({
    required this.reelId,
    required this.editing,
    required this.onSaved,
    required this.onFailedAfterClose,
  });

  final int reelId;
  final ReelReference? editing;
  final ValueChanged<ReelReference> onSaved;
  final VoidCallback onFailedAfterClose;

  @override
  ConsumerState<_ReferenceSheet> createState() => _ReferenceSheetState();
}

class _ReferenceSheetState extends ConsumerState<_ReferenceSheet> {
  final TextEditingController _link = TextEditingController();
  late final TextEditingController _label = TextEditingController(
    text: widget.editing?.label,
  );
  final FocusNode _labelFocus = FocusNode();
  final FocusNode _linkFocus = FocusNode();

  /// What is wrong with the link, in words, until the next edit.
  String? _linkError;

  /// The last save failed for a reason the user cannot fix; shown in the
  /// sheet until the next attempt or edit.
  bool _failed = false;

  bool get _edit => widget.editing != null;

  @override
  void dispose() {
    _link.dispose();
    _label.dispose();
    _labelFocus.dispose();
    _linkFocus.dispose();
    super.dispose();
  }

  /// Forgets what was wrong (the user is typing again).
  void _typing(String _) {
    if (_linkError != null || _failed) {
      setState(() {
        _linkError = null;
        _failed = false;
      });
    }
  }

  /// Reads the clipboard (the only place that does), once, for the first
  /// link in it that Save will accept (`pastedLink`).
  Future<void> _paste() async {
    final l10n = AppLocalizations.of(context);
    String? text;
    try {
      text = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    } on Object catch (error) {
      _log.warning('Reading the clipboard failed: ${error.runtimeType}');
    }
    if (!mounted) return;
    final link = text == null ? null : pastedLink(text);
    if (link == null) {
      setState(() => _linkError = l10n.referenceNoLinkOnClipboard);
      return;
    }
    _link.value = TextEditingValue(
      text: link,
      selection: TextSelection.collapsed(offset: link.length),
    );
    setState(() {
      _linkError = null;
      _failed = false;
    });
    _labelFocus.requestFocus();
  }

  Future<void> _save() async {
    // The controller is single-flight; this also keeps the sheet from asking
    // twice while the buttons redraw.
    final provider = referenceFormControllerProvider(widget.reelId);
    if (ref.read(provider)) return;
    final l10n = AppLocalizations.of(context);
    setState(() {
      _linkError = null;
      _failed = false;
    });
    final controller = ref.read(provider.notifier);
    final navigator = Navigator.of(context);
    final editing = widget.editing;

    final ReelReference saved;
    if (editing != null) {
      if (!await controller.saveLabel(editing.id, _label.text)) {
        return _failedSave();
      }
      saved = editing;
    } else {
      switch (await controller.saveNew(_link.text, _label.text)) {
        case ReferenceSaved(:final reference):
          saved = reference;
        case ReferenceNotALink():
          return _linkProblem(l10n.referenceNotALink);
        case ReferenceAlreadyIn(:final reelName):
          return _linkProblem(l10n.referenceAlreadyIn(reelName));
        // The field stops at 60 characters, so this is a bug, told as one.
        case ReferenceLabelTooLong() || ReferenceSaveFailed():
          return _failedSave();
      }
    }
    if (mounted) navigator.pop();
    widget.onSaved(saved);
  }

  /// Says what is wrong with the link, under its field, and goes back to it.
  void _linkProblem(String message) {
    if (!mounted) return;
    setState(() => _linkError = message);
    _linkFocus.requestFocus();
  }

  /// Tells the user the save failed, in the sheet, or in a snack if the sheet
  /// was dragged away meanwhile.
  void _failedSave() {
    if (mounted) {
      setState(() => _failed = true);
    } else {
      widget.onFailedAfterClose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tt = context.tt;
    final saving = ref.watch(referenceFormControllerProvider(widget.reelId));
    final reelName = ref.watch(reelByIdProvider(widget.reelId)).value?.name;
    final editing = widget.editing;

    return TtSheet(
      title: _edit ? l10n.referenceSheetTitleEdit : l10n.referenceSheetTitleAdd,
      footer: SheetFooter(
        failure: _failed ? l10n.referenceSaveFailed : null,
        buttons: TtButtonRow(
          children: [
            TtButton(
              label: l10n.cancel,
              kind: TtButtonKind.text,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            TtButton(
              label: l10n.referenceSaveButton,
              onPressed: saving ? null : () => unawaited(_save()),
            ),
          ],
        ),
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
          if (reelName != null)
            Padding(
              padding: EdgeInsets.only(bottom: tt.spacing.xs),
              child: Text(
                _edit
                    ? l10n.referenceSheetSubtitleEdit(reelName)
                    : l10n.referenceSheetSubtitleAdd(reelName),
                style: tt.text.material.bodyMedium!.copyWith(
                  color: context.scheme.onSurfaceVariant,
                ),
              ),
            ),
          if (editing != null)
            _SourceRow(reference: editing)
          else
            TtTextField(
              label: l10n.referenceLinkLabel,
              hint: l10n.referenceLinkHint,
              helper: l10n.referenceLinkHelp,
              controller: _link,
              focusNode: _linkFocus,
              error: _linkError,
              autofocus: true,
              textInputAction: TextInputAction.next,
              onChanged: _typing,
              trailing: Padding(
                padding: EdgeInsetsDirectional.only(end: tt.spacing.xs),
                child: TtButton(
                  label: l10n.referencePasteButton,
                  kind: TtButtonKind.tonal,
                  size: TtButtonSize.small,
                  onPressed: () => unawaited(_paste()),
                ),
              ),
            ),
          TtTextField(
            label: l10n.referenceLabelLabel,
            hint: l10n.referenceLabelHint,
            controller: _label,
            focusNode: _labelFocus,
            maxLength: referenceLabelMaxLength,
            counterText: l10n.reelCounter,
            autofocus: _edit,
            textInputAction: TextInputAction.done,
            onChanged: _typing,
            onSubmitted: (_) => unawaited(_save()),
          ),
        ],
      ),
    );
  }
}

/// What the Edit label sheet is about: the source's icon, what the link is
/// and the short link (`.srcrow`). A screen reader hears the two lines as
/// one.
class _SourceRow extends StatelessWidget {
  const new({required this.reference});

  final ReelReference reference;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tt = context.tt;
    final scheme = context.scheme;
    final kind = referenceKindText(l10n, Uri.tryParse(reference.url) ?? Uri());
    return MergeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(tt.radii.m),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: tt.spacing.s,
            vertical: tt.spacing.xs,
          ),
          child: Row(
            spacing: tt.spacing.s,
            children: [
              referenceSourceIcon(context, reference.source),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kind,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.text.material.titleSmall,
                    ),
                    Text(
                      shortLink(reference.url),
                      // Two lines: at large text the link is what the user
                      // came to see, and a long one still ends in a clip.
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: tt.text.material.bodySmall!.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
