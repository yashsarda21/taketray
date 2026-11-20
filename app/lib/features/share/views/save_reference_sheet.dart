import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:taketray/core/guarded.dart';
import 'package:taketray/data/repositories/phone_state_repository.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/domain/models/reel_summary.dart';
import 'package:taketray/domain/rules/reference_links.dart';
import 'package:taketray/domain/rules/reference_url.dart';
import 'package:taketray/domain/rules/shared_link_kind.dart';
import 'package:taketray/domain/rules/text_limits.dart';
import 'package:taketray/features/reels/view_models/home_controller.dart';
import 'package:taketray/features/reels/view_models/reel_picker.dart';
import 'package:taketray/features/reels/views/reel_form_sheet.dart';
import 'package:taketray/features/reels/views/sheet_failure.dart';
import 'package:taketray/features/references/views/reference_source_icon.dart';
import 'package:taketray/features/references/views/reference_text.dart';
import 'package:taketray/features/share/view_models/save_reference_controller.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray_ui/taketray_ui.dart';

// The error type only, never a link or a reel name (D-10).
final Logger _log = Logger('saveReferenceSheet');

// proto.css: .srcrow { margin: 0 24px 12px; padding: 10px 12px;
// border-radius: 14px; gap: 12px }, .segbtn { margin: 0 24px 8px;
// min-height: 40px }, .quote { padding: 10px 14px; border-left: 3px }

/// The side margin of the source row, the switch and the fields (the
/// prototype's 24 dp).
const double _side = 24;

/// The 3 dp bar at the quote's start.
const double _quoteBar = 3;

/// How many lines of the shared caption the "not a link" state quotes.
const int _quoteLines = 4;

/// How many characters of the shared text are laid out for the quote: a
/// caption can be 20,000 long and only four lines of it show.
const int _quoteCharacters = 600;

/// The size of the check circle after saving (`.okc`).
const double _okCircle = 64;

/// The Save reference sheet of the share screen (D-166): the form that saves
/// a shared link to a reel (a new one or one the user has), the "not a link"
/// state, and the saved state. It is a [TtSheet] panel, to be put at the
/// bottom of a dimmed see-through page (the share screen does, Task 6); it
/// shows what [SaveReferenceController] holds, so the share screen calls
/// `start` with the shared text first.
///
/// - **Form.** Title "Save reference"; the source row (the app's icon, what
///   the link is, the short link); "Label (optional)"; "Save to" with a switch
///   **Existing reel** / **New reel**. Existing: a radio list, Collecting
///   first, then the others in Home's order, each with how many references it
///   has; nothing is picked at first and **Save** waits for a pick. New: the
///   "New reel name" field. With no reels there is no switch: it opens in New
///   with the name focused. A picked reel that has the link shows the "Already
///   saved in {reel}" banner with **Open reel**, and Save waits. A failure
///   shows "Couldn't save the reference." above the buttons. Enter in the name
///   or the label saves.
/// - **Not a link.** The shared text quoted (four lines at most) and how to
///   share a reel; **Close**.
/// - **Saved.** "Saved to {reel}", the label or what the link is; **Open
///   reel** and **Done**. Before onboarding is done, a "Welcome to TakeTray"
///   note. The flag is read once, through `PhoneStateRepository`, and never
///   written.
///
/// [onDone] is called by Cancel, Close and Done: the share screen finishes.
/// [onOpenReel] is called with a reel id by Open reel (the banner's and the
/// saved state's): the share screen asks the app to open it.
///
/// The reels in the list come from `reelSummariesProvider`, so a reel made
/// meanwhile appears. They show no cover: the share engine has no media
/// bridge (D-163), so the list never asks for a thumbnail.
class SaveReferenceSheet extends ConsumerStatefulWidget {
  /// A sheet that calls [onDone] and [onOpenReel] as described above.
  const SaveReferenceSheet({
    required this.onDone,
    required this.onOpenReel,
    super.key,
  });

  /// Called when the user is finished: Cancel, Close or Done.
  final VoidCallback onDone;

  /// Called with the reel to open: Open reel.
  final ValueChanged<int> onOpenReel;

  /// The key of the quoted caption, for tests.
  @visibleForTesting
  static const Key quoteKey = ValueKey<String>('shareQuote');

  @override
  ConsumerState<SaveReferenceSheet> createState() => _SaveReferenceSheetState();
}

class _SaveReferenceSheetState extends ConsumerState<SaveReferenceSheet> {
  final TextEditingController _label = TextEditingController();
  final TextEditingController _name = TextEditingController();

  /// Whether onboarding is done, null until read (or when it could not be);
  /// read once, for the welcome note.
  bool? _onboardingDone;

  @override
  void initState() {
    super.initState();
    unawaited(_readOnboarding());
  }

  @override
  void dispose() {
    _label.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _readOnboarding() async {
    final phone = ref.read(phoneStateRepositoryProvider);
    final done = await guarded(
      _log,
      'Reading onboarding',
      phone.onboardingDone,
    );
    if (mounted && done != null) setState(() => _onboardingDone = done);
  }

  SaveReferenceController get _controller =>
      ref.read(saveReferenceControllerProvider.notifier);

  /// Whether Save would do something now.
  bool _canSave(SaveReferenceState form, {required bool hasReels}) {
    if (form.step != SaveStep.form || form.saving) return false;
    final mode = hasReels ? form.mode : SaveMode.newReel;
    return mode == SaveMode.newReel ||
        (form.pickedReelId != null && form.alreadyIn == null);
  }

  void _save({required bool hasReels}) {
    final form = ref.read(saveReferenceControllerProvider);
    if (!_canSave(form, hasReels: hasReels)) return;
    // With no reels left the form is New reel, whatever the state says.
    if (!hasReels && form.mode != SaveMode.newReel) {
      _controller.setMode(SaveMode.newReel);
    }
    unawaited(_controller.save(name: _name.text, label: _label.text));
  }

  @override
  Widget build(BuildContext context) {
    final form = ref.watch(saveReferenceControllerProvider);
    return switch (form.step) {
      SaveStep.notALink => _NotALink(text: form.text, onDone: widget.onDone),
      SaveStep.saved => _Saved(
        form: form,
        showWelcome: _onboardingDone == false,
        onDone: widget.onDone,
        onOpenReel: widget.onOpenReel,
      ),
      SaveStep.form => _buildForm(context, form),
    };
  }

  Widget _buildForm(BuildContext context, SaveReferenceState form) {
    final l10n = AppLocalizations.of(context);
    final tt = context.tt;
    final summaries = ref.watch(reelSummariesProvider);
    final counts = ref.watch(referenceCountsProvider).value ?? const {};
    final loaded = summaries.value;
    // Until the reels are read, the switch follows what the controller
    // found; once read, an empty list means no switch.
    final hasReels = loaded == null
        ? form.mode == SaveMode.existing
        : loaded.isNotEmpty;
    final mode = hasReels ? form.mode : SaveMode.newReel;
    final url = Uri.parse(form.url);
    final kind = _kindText(l10n, form.kind, url);
    final canSave = _canSave(form, hasReels: hasReels);

    void typing(String _) => _controller.clearErrors();

    Widget banner() {
      final picked = form.pickedReelId;
      final reelName = form.alreadyIn;
      if (mode != SaveMode.existing || picked == null || reelName == null) {
        return const SizedBox.shrink();
      }
      return TtBanner(
        kind: TtBannerKind.warning,
        icon: Symbols.info_rounded,
        title: l10n.referenceAlreadyIn(reelName),
        body: l10n.saveReferenceAlreadyHint,
        // proto: .banner.warn { margin: 0 16px 8px }
        margin: EdgeInsets.fromLTRB(
          tt.spacing.gutter,
          tt.spacing.none,
          tt.spacing.gutter,
          tt.spacing.xs,
        ),
        action: TtButton(
          label: l10n.saveReferenceOpenReel,
          kind: TtButtonKind.text,
          onPressed: () => widget.onOpenReel(picked),
        ),
      );
    }

    final sections = pickerSections(loaded ?? const [], excludeReelId: null);

    Widget row(ReelSummary summary) {
      final id = summary.reel.id;
      final name = summary.reel.name;
      final count = l10n.saveReferenceReelReferences(counts[id] ?? 0);
      return TtReelPickRow(
        key: ValueKey(id),
        name: name,
        countText: count,
        semanticLabel: l10n.pickerRowSemantics(name, count),
        selected: form.pickedReelId == id,
        multi: false,
        onTap: form.saving ? null : () => unawaited(_controller.pick(id)),
      );
    }

    return TtSheet(
      title: l10n.saveReferenceTitle,
      footer: SheetFooter(
        failure: form.failed ? l10n.referenceSaveFailed : null,
        buttons: TtButtonRow(
          children: [
            TtButton(
              label: l10n.cancel,
              kind: TtButtonKind.text,
              onPressed: widget.onDone,
            ),
            TtButton(
              label: l10n.referenceSaveButton,
              onPressed: canSave ? () => _save(hasReels: hasReels) : null,
            ),
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.only(bottom: tt.spacing.s),
              children: [
                _SourceRow(
                  source: referenceSourceOf(url),
                  kind: kind,
                  link: shortLink(form.url),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    _side,
                    tt.spacing.none,
                    _side,
                    tt.spacing.xxs,
                  ),
                  child: TtTextField(
                    label: l10n.referenceLabelLabel,
                    hint: l10n.referenceLabelHint,
                    controller: _label,
                    maxLength: referenceLabelMaxLength,
                    counterText: l10n.reelCounter,
                    textInputAction: TextInputAction.done,
                    onChanged: typing,
                    onSubmitted: (_) => _save(hasReels: hasReels),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    _side,
                    tt.spacing.xxs,
                    _side,
                    tt.spacing.xs,
                  ),
                  child: Semantics(
                    header: true,
                    child: Text(
                      l10n.saveReferenceSaveTo,
                      style: tt.text.material.titleSmall,
                    ),
                  ),
                ),
                if (hasReels)
                  _ModeSwitch(mode: mode, onChanged: _controller.setMode),
                if (mode == SaveMode.newReel)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: _side),
                    child: TtTextField(
                      label: l10n.pickerNewReelName,
                      hint: l10n.reelNameHint,
                      controller: _name,
                      error: reelNameProblemText(
                        l10n,
                        form.nameError,
                        form.clashingName,
                        _name.text,
                      ),
                      maxLength: reelNameMaxLength,
                      counterText: l10n.reelCounter,
                      autofocus: true,
                      textInputAction: TextInputAction.done,
                      onChanged: typing,
                      onSubmitted: (_) => _save(hasReels: hasReels),
                    ),
                  )
                else ...[
                  if (sections.collecting.isNotEmpty) ...[
                    TtGroupLabel(l10n.statusCollecting),
                    for (final summary in sections.collecting) row(summary),
                  ],
                  if (sections.other.isNotEmpty) ...[
                    TtGroupLabel(l10n.pickerOtherReels),
                    for (final summary in sections.other) row(summary),
                  ],
                ],
              ],
            ),
          ),
          banner(),
        ],
      ),
    );
  }
}

/// What the shared link is, in words: "Instagram reel", "YouTube Short" ...
/// For any other link, its host without a leading `www.` or `m.`
/// ("example.com", a percent-encoded host decoded).
String _kindText(AppLocalizations l10n, SharedLinkKind kind, Uri url) =>
    switch (kind) {
      SharedLinkKind.instagramReel => l10n.saveReferenceKindInstagramReel,
      SharedLinkKind.instagramPost => l10n.saveReferenceKindInstagramPost,
      SharedLinkKind.instagramVideo => l10n.saveReferenceKindInstagramVideo,
      SharedLinkKind.instagramProfile => l10n.saveReferenceKindInstagramProfile,
      SharedLinkKind.youtubeShort => l10n.saveReferenceKindYoutubeShort,
      SharedLinkKind.youtubeVideo => l10n.saveReferenceKindYoutubeVideo,
      SharedLinkKind.tiktokVideo => l10n.saveReferenceKindTiktokVideo,
      SharedLinkKind.link => referenceKindText(l10n, url),
    };

/// The source row (`.srcrow`): the source app's icon, what the link is and
/// the short link.
class _SourceRow extends StatelessWidget {
  const _SourceRow({
    required this.source,
    required this.kind,
    required this.link,
  });

  final ReferenceSource source;
  final String kind;
  final String link;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final scheme = context.scheme;
    final text = tt.text.material;
    final large =
        MediaQuery.textScalerOf(context).scale(1) >= TtMetrics.largeTextScale;
    return Padding(
      padding: EdgeInsets.fromLTRB(_side, tt.spacing.none, _side, tt.spacing.s),
      child: Semantics(
        container: true,
        label: '$kind, $link',
        excludeSemantics: true,
        child: Material(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(tt.radii.m),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: tt.spacing.s,
              vertical: tt.spacing.s,
            ),
            child: Row(
              spacing: tt.spacing.s,
              children: [
                referenceSourceIcon(context, source),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(kind, style: text.titleSmall),
                      Text(
                        link,
                        // One line, as the prototype's `.clamp1`; at large
                        // text two, so the link can still be read.
                        maxLines: large ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall!.copyWith(
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
      ),
    );
  }
}

/// The two-way switch **Existing reel** / **New reel** (`.segbtn`): a pill
/// with a 1 dp outline, the chosen half on the secondary container with a
/// check.
class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.mode, required this.onChanged});

  final SaveMode mode;
  final ValueChanged<SaveMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tt = context.tt;
    final scheme = context.scheme;
    // From a text scale of 1.5 the two halves are stacked, so neither label
    // breaks in the middle of a word.
    final stacked =
        MediaQuery.textScalerOf(context).scale(1) >= TtMetrics.largeTextScale;
    final radius = BorderRadius.circular(stacked ? tt.radii.xl : tt.radii.full);
    Widget half(SaveMode value, String label) {
      final on = mode == value;
      final content = on ? scheme.onSecondaryContainer : scheme.onSurface;
      final tile = Semantics(
        button: true,
        selected: on,
        inMutuallyExclusiveGroup: true,
        child: Material(
          type: on ? MaterialType.canvas : MaterialType.transparency,
          color: on ? scheme.secondaryContainer : null,
          child: InkWell(
            onTap: () => onChanged(value),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: tt.sizes.touchTarget),
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: tt.spacing.xs,
                    vertical: tt.spacing.xs,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: tt.spacing.xs,
                    children: [
                      if (on)
                        ExcludeSemantics(
                          child: Icon(
                            Symbols.check_rounded,
                            size: tt.sizes.iconSmall,
                            color: content,
                          ),
                        ),
                      Flexible(
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: tt.text.material.labelLarge!.copyWith(
                            color: content,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      return stacked ? tile : Expanded(child: tile);
    }

    final existing = half(SaveMode.existing, l10n.saveReferenceModeExisting);
    final fresh = half(SaveMode.newReel, l10n.saveReferenceModeNew);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        _side,
        tt.spacing.none,
        _side,
        tt.spacing.xs,
      ),
      child: Semantics(
        container: true,
        label: l10n.saveReferenceModeSemantics,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: scheme.outline),
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: stacked
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      existing,
                      Divider(height: 1, thickness: 1, color: scheme.outline),
                      fresh,
                    ],
                  )
                : IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        existing,
                        VerticalDivider(
                          width: 1,
                          thickness: 1,
                          color: scheme.outline,
                        ),
                        fresh,
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// The state for text with no link in it: what to do instead, and the text
/// quoted.
class _NotALink extends StatelessWidget {
  const _NotALink({required this.text, required this.onDone});

  final String? text;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tt = context.tt;
    final scheme = context.scheme;
    final body = tt.text.material.bodyMedium!.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final shared = text?.trim() ?? '';
    // A caption can be 20,000 characters and four lines of it show.
    final quoted = String.fromCharCodes(shared.runes.take(_quoteCharacters));
    return TtSheet(
      footer: TtButtonRow(
        children: [TtButton(label: l10n.saveReferenceClose, onPressed: onDone)],
      ),
      child: ListView(
        shrinkWrap: true,
        padding: EdgeInsets.fromLTRB(
          _side,
          tt.spacing.none,
          _side,
          tt.spacing.s,
        ),
        children: [
          ExcludeSemantics(
            child: Icon(
              Symbols.link_off_rounded,
              size: tt.sizes.iconLarge,
              color: scheme.tertiary,
            ),
          ),
          SizedBox(height: tt.spacing.s),
          Semantics(
            header: true,
            child: Text(
              l10n.saveReferenceNotALinkTitle,
              style: tt.text.material.titleLarge,
            ),
          ),
          SizedBox(height: tt.spacing.s),
          Text(l10n.saveReferenceNotALinkBody, style: body),
          if (quoted.isNotEmpty) ...[
            SizedBox(height: tt.spacing.s),
            _Quote(key: SaveReferenceSheet.quoteKey, text: quoted),
          ],
          SizedBox(height: tt.spacing.s),
          Text(l10n.saveReferenceNotALinkHint, style: body),
        ],
      ),
    );
  }
}

/// The shared caption in a quote block (`.quote`): a 3 dp bar at the start,
/// the high surface container, four lines at most.
class _Quote extends StatelessWidget {
  const _Quote({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final scheme = context.scheme;
    return ClipRRect(
      borderRadius: BorderRadiusDirectional.horizontal(
        end: Radius.circular(tt.radii.m),
      ).resolve(Directionality.of(context)),
      child: ColoredBox(
        color: scheme.surfaceContainerHigh,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ColoredBox(
                color: scheme.outline,
                child: const SizedBox(width: _quoteBar),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: tt.spacing.m,
                    vertical: tt.spacing.s,
                  ),
                  child: Text(
                    text,
                    maxLines: _quoteLines,
                    overflow: TextOverflow.ellipsis,
                    style: tt.text.material.bodyMedium!.copyWith(
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The saved state: a check, where it went, what it is, and (before
/// onboarding is done) the welcome note.
class _Saved extends StatelessWidget {
  const _Saved({
    required this.form,
    required this.showWelcome,
    required this.onDone,
    required this.onOpenReel,
  });

  final SaveReferenceState form;
  final bool showWelcome;
  final VoidCallback onDone;
  final ValueChanged<int> onOpenReel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tt = context.tt;
    final scheme = context.scheme;
    final reelId = form.savedReelId;
    final label = form.savedLabel;
    final what = label != null && label.isNotEmpty
        ? label
        : _kindText(l10n, form.kind, Uri.parse(form.url));
    return TtSheet(
      footer: TtButtonRow(
        children: [
          TtButton(
            label: l10n.saveReferenceOpenReel,
            kind: TtButtonKind.tonal,
            onPressed: reelId == null ? null : () => onOpenReel(reelId),
          ),
          TtButton(label: l10n.saveReferenceDone, onPressed: onDone),
        ],
      ),
      child: ListView(
        shrinkWrap: true,
        padding: EdgeInsets.fromLTRB(
          _side,
          tt.spacing.none,
          _side,
          tt.spacing.s,
        ),
        children: [
          Center(
            child: ExcludeSemantics(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: tt.colors.successContainer,
                  shape: BoxShape.circle,
                ),
                child: SizedBox.square(
                  dimension: _okCircle,
                  child: Icon(
                    Symbols.check_rounded,
                    size: tt.sizes.iconLarge,
                    color: tt.colors.onSuccessContainer,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: tt.spacing.s),
          Semantics(
            header: true,
            child: Text(
              l10n.saveReferenceSavedTitle(form.savedReelName ?? ''),
              textAlign: TextAlign.center,
              style: tt.text.material.headlineSmall,
            ),
          ),
          SizedBox(height: tt.spacing.xs),
          Text(
            what,
            textAlign: TextAlign.center,
            style: tt.text.material.bodyMedium!.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          if (showWelcome) ...[
            SizedBox(height: tt.spacing.m),
            TtCallout(
              icon: Symbols.waving_hand_rounded,
              title: l10n.saveReferenceWelcomeTitle,
              body: l10n.saveReferenceWelcomeBody,
            ),
          ],
        ],
      ),
    );
  }
}
