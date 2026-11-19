import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taketray/domain/models/reel.dart';
import 'package:taketray/domain/models/reel_reference.dart';
import 'package:taketray/features/reels/views/reel_form_sheet.dart';
import 'package:taketray/features/reels/views/undo_snacks.dart';
import 'package:taketray/features/references/view_models/reference_actions.dart';
import 'package:taketray/features/references/views/reference_sheet.dart';
import 'package:taketray/features/references/views/reference_source_icon.dart';
import 'package:taketray/features/references/views/reference_text.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray/platform/android_sdk.dart';
import 'package:taketray_ui/taketray_ui.dart';

/// The key of the section's box: what [ReferencesSection.focus] scrolls to.
const Key referencesSectionKey = ValueKey<String>('references-section');

/// The key of the highlight behind the section while it flashes.
const Key referencesFlashKey = ValueKey<String>('references-flash');

/// How long the arrival highlight fades (D-158).
// style-check: allow a one-time highlight's length (D-158), not a token motion
const Duration _flashLength = Duration(milliseconds: 600);

/// From this Android version (13) the phone confirms a copy itself, so the
/// app does not say "Link copied" too.
const int _ownCopyConfirmationFrom = 33;

/// The size of the source icon on a card (the prototype's `srcIcon(src, 18)`).
const double _cardIconSize = 18;

/// What a reference card's ⋮ menu does.
enum _ReferenceAction { editLabel, copyLink, remove }

/// A reel page's References section (`refs.js`: `h.refsSection`, D-158), a
/// sliver under the header, above the editing banner and the clips:
///
/// - **No references:** one dashed "Add reference" row ("Save a reel you want
///   to recreate"), which opens the Add reference sheet.
/// - **One or more:** "References · {n}" with a small **Add** button, then one
///   `TtReferenceCard` per reference, newest first. A tap opens the link in
///   the app or browser the phone picks; when nothing can, "No app on this
///   phone can open this link.". The ⋮ menu has **Edit label** (the Edit
///   label sheet), **Copy link** (the stored link on the clipboard; "Link
///   copied" only before Android 13, which says it itself) and **Remove**
///   (at once, "Reference removed" with **Undo**; no dialog).
/// - **References and no shot ideas:** under the cards, "Write the shots you
///   need" with **Write shot ideas**, which opens the reel's form with the
///   shot ideas focused.
///
/// While the references are being read it draws nothing. With [focus] (the
/// Home badge, `Routes.reelReferences`), the first time the references are
/// known the section is scrolled to the top of the page and its background
/// flashes once (600 ms). With "Remove animations" it jumps there and does not
/// flash: no animation runs at all.
class ReferencesSection extends ConsumerStatefulWidget {
  const new({required this.reel, this.focus = false, super.key});

  /// The reel, as the page watches it (its shot ideas decide the prompt).
  final Reel reel;

  /// Whether to scroll the section into view and flash it on arrival.
  final bool focus;

  @override
  ConsumerState<ReferencesSection> createState() => _ReferencesSectionState();
}

class _ReferencesSectionState extends ConsumerState<ReferencesSection>
    with SingleTickerProviderStateMixin {
  final GlobalKey _box = GlobalKey();

  /// The arrival (scroll and flash) was started, so it happens once.
  bool _arrived = false;

  /// The flash, made only when it runs.
  AnimationController? _flash;

  /// A reference is being opened, so a second tap does nothing.
  bool _opening = false;

  @override
  void dispose() {
    _flash?.dispose();
    super.dispose();
  }

  /// Scrolls the section to the top of the page, then flashes it, unless the
  /// phone asks for no animations.
  Future<void> _arrive() async {
    final box = _box.currentContext;
    if (!mounted || box == null) return;
    final still = MediaQuery.disableAnimationsOf(context);
    final motion = context.tt.motion;
    await Scrollable.ensureVisible(
      box,
      duration: still ? Duration.zero : motion.medium2,
      curve: motion.standard,
    );
    if (still || !mounted) return;
    setState(() {
      _flash = AnimationController(vsync: this, duration: _flashLength)
        ..forward();
    });
  }

  Future<void> _open(ReelReference reference) async {
    if (_opening) return;
    _opening = true;
    final snacks = ReelSnacks.of(context);
    final l10n = AppLocalizations.of(context);
    try {
      final opened = await ref.read(referenceActionsProvider).open(reference);
      if (!opened) snacks.show(l10n.referenceOpenFailed, done: false);
    } finally {
      _opening = false;
    }
  }

  Future<void> _copy(ReelReference reference) async {
    final snacks = ReelSnacks.of(context);
    final l10n = AppLocalizations.of(context);
    final actions = ref.read(referenceActionsProvider);
    // Android 13 and later confirm a copy themselves. A version that cannot
    // be read counts as newer (as onboarding's access step does, D-140). Read
    // now, while the page is surely there.
    final sdk = ref
        .read(androidSdkProvider.future)
        .then<int?>((sdk) => sdk, onError: (Object _) => null);
    try {
      await actions.copy(reference);
    } on Object {
      // The actions logged the type.
      snacks.show(l10n.reelActionFailed, done: false);
      return;
    }
    final version = await sdk;
    if (version != null && version < _ownCopyConfirmationFrom) {
      snacks.show(
        l10n.referenceLinkCopiedSnack,
        icon: Symbols.content_copy_rounded,
      );
    }
  }

  Future<void> _remove(ReelReference reference) async {
    final snacks = ReelSnacks.of(context);
    final l10n = AppLocalizations.of(context);
    try {
      final undo = await ref
          .read(referenceActionsProvider)
          .remove(reference.id);
      if (undo != null) snacks.showUndo(l10n.referenceRemovedSnack, undo);
    } on Object {
      // The actions logged the type; the card stays.
      snacks.show(l10n.reelActionFailed, done: false);
    }
  }

  void _onMenu(_ReferenceAction action, ReelReference reference) {
    switch (action) {
      case _ReferenceAction.editLabel:
        unawaited(
          showReferenceSheet(
            context,
            reelId: widget.reel.id,
            editing: reference,
          ),
        );
      case _ReferenceAction.copyLink:
        unawaited(_copy(reference));
      case _ReferenceAction.remove:
        unawaited(_remove(reference));
    }
  }

  void _add() => unawaited(showReferenceSheet(context, reelId: widget.reel.id));

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final references = ref.watch(reelReferencesProvider(widget.reel.id)).value;
    // Nothing while they are read: no Add row that turns into cards.
    if (references == null) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    if (widget.focus && !_arrived) {
      _arrived = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_arrive()));
    }
    return SliverToBoxAdapter(
      child: KeyedSubtree(
        key: referencesSectionKey,
        // proto.css: .refs, .ref-add { margin: 4px 16px 8px }
        child: Padding(
          key: _box,
          padding: EdgeInsets.fromLTRB(
            tt.spacing.gutter,
            tt.spacing.xxs,
            tt.spacing.gutter,
            tt.spacing.xs,
          ),
          child: _withFlash(
            context,
            references.isEmpty ? _addRow(context) : _list(context, references),
          ),
        ),
      ),
    );
  }

  Widget _addRow(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return TtAddReferenceTile(
      title: l10n.referencesAddRowTitle,
      subtitle: l10n.referencesAddRowSubtitle,
      semanticLabel: l10n.referencesAddRowSemantics,
      onPressed: _add,
    );
  }

  Widget _list(BuildContext context, List<ReelReference> references) {
    final l10n = AppLocalizations.of(context);
    final tt = context.tt;
    final noShotIdeas = (widget.reel.description ?? '').trim().isEmpty;
    // proto.css: .refs { gap: 8px }, .refs-h { padding-left: 4px }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: tt.spacing.xs,
      children: [
        Padding(
          padding: EdgeInsetsDirectional.only(start: tt.spacing.xxs),
          child: Row(
            spacing: tt.spacing.xs,
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    l10n.referencesHeader(references.length),
                    style: tt.text.material.titleSmall,
                  ),
                ),
              ),
              TtButton(
                label: l10n.referencesAddButton,
                semanticLabel: l10n.referencesAddButtonSemantics,
                icon: Symbols.add_rounded,
                kind: TtButtonKind.text,
                size: TtButtonSize.small,
                onPressed: _add,
              ),
            ],
          ),
        ),
        for (final reference in references) _card(context, l10n, reference),
        if (noShotIdeas)
          TtCallout(
            icon: Symbols.edit_note_rounded,
            title: l10n.referencesPromptTitle,
            body: l10n.referencesPromptBody,
            action: TtButton(
              label: l10n.referencesPromptAction,
              kind: TtButtonKind.text,
              size: TtButtonSize.small,
              onPressed: () => unawaited(
                showReelForm(
                  context,
                  reel: widget.reel,
                  focusDescription: true,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _card(
    BuildContext context,
    AppLocalizations l10n,
    ReelReference reference,
  ) {
    final text = referenceCardText(l10n, reference);
    final kind = referenceKindText(l10n, Uri.tryParse(reference.url) ?? Uri());
    return TtReferenceCard<_ReferenceAction>(
      key: ValueKey<int>(reference.id),
      title: text.title,
      subtitle: text.subtitle,
      sourceIcon: referenceSourceIcon(
        context,
        reference.source,
        size: _cardIconSize,
      ),
      openLabel: l10n.referenceOpen,
      openSemanticLabel: l10n.referenceOpenSemantics(text.title, kind),
      onOpen: () => unawaited(_open(reference)),
      moreSemanticLabel: l10n.referenceMoreSemantics(text.title),
      moreItems: [
        TtMenuItem(
          _ReferenceAction.editLabel,
          l10n.referenceMenuEditLabel,
          icon: Symbols.edit_rounded,
        ),
        TtMenuItem(
          _ReferenceAction.copyLink,
          l10n.referenceMenuCopyLink,
          icon: Symbols.content_copy_rounded,
        ),
        TtMenuItem(
          _ReferenceAction.remove,
          l10n.referenceMenuRemove,
          icon: Symbols.delete_rounded,
          destructive: true,
        ),
      ],
      onMoreSelected: (action) => _onMenu(action, reference),
    );
  }

  /// [child] with the arrival highlight behind it while it runs: the tertiary
  /// container colour fading to nothing, reaching a little past the section
  /// (proto.css: `.refs.flash`).
  Widget _withFlash(BuildContext context, Widget child) {
    final flash = _flash;
    final content = KeyedSubtree(
      key: const ValueKey<String>('references-content'),
      child: child,
    );
    if (flash == null) return content;
    final tt = context.tt;
    final colour = context.scheme.tertiaryContainer;
    return AnimatedBuilder(
      animation: flash,
      child: content,
      builder: (context, content) => Stack(
        clipBehavior: Clip.none,
        children: [
          if (flash.isAnimating)
            Positioned(
              left: -tt.spacing.xs,
              right: -tt.spacing.xs,
              top: -tt.spacing.xxs,
              bottom: -tt.spacing.xxs,
              child: DecoratedBox(
                key: referencesFlashKey,
                decoration: BoxDecoration(
                  color: Color.lerp(
                    colour,
                    colour.withValues(alpha: 0),
                    tt.motion.standard.transform(flash.value),
                  ),
                  borderRadius: BorderRadius.circular(tt.radii.xl),
                ),
              ),
            ),
          content!,
        ],
      ),
    );
  }
}
