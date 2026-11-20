import 'package:flutter/material.dart';
import 'package:taketray/domain/rules/shared_link_kind.dart';
import 'package:taketray/features/references/views/reference_text.dart';
import 'package:taketray/features/share/view_models/save_reference_controller.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray_ui/taketray_ui.dart';

// proto.css: .quote { padding: 10px 14px; border-left: 3px }

/// The 3 dp bar at the quote's start.
const double _quoteBar = 3;

/// How many lines of the shared caption the "not a link" state quotes.
const int _quoteLines = 4;

/// How many characters of the shared text are laid out for the quote: a
/// caption can be 20,000 long and only four lines of it show.
const int _quoteCharacters = 600;

/// The key of the quoted caption (`saveReferenceQuoteKey`).
const Key saveReferenceQuoteKey = ValueKey<String>('shareQuote');

/// What the shared link is, in words: "Instagram reel", "YouTube Short" ...
/// For any other link, its host without a leading `www.` or `m.`
/// ("example.com", a percent-encoded host decoded).
String saveReferenceKindText(
  AppLocalizations l10n,
  SharedLinkKind kind,
  Uri url,
) => switch (kind) {
  SharedLinkKind.instagramReel => l10n.saveReferenceKindInstagramReel,
  SharedLinkKind.instagramPost => l10n.saveReferenceKindInstagramPost,
  SharedLinkKind.instagramVideo => l10n.saveReferenceKindInstagramVideo,
  SharedLinkKind.instagramProfile => l10n.saveReferenceKindInstagramProfile,
  SharedLinkKind.youtubeShort => l10n.saveReferenceKindYoutubeShort,
  SharedLinkKind.youtubeVideo => l10n.saveReferenceKindYoutubeVideo,
  SharedLinkKind.tiktokVideo => l10n.saveReferenceKindTiktokVideo,
  SharedLinkKind.link => referenceKindText(l10n, url),
};

/// The state for text with no link in it (D-166): what to do instead, and
/// the text quoted. [onDone] is Close.
class SaveReferenceNotALink extends StatelessWidget {
  /// Shows [text] (null for none) in the "not a link" state.
  const SaveReferenceNotALink({
    required this.text,
    required this.onDone,
    super.key,
  });

  /// The shared text, or null when there was none.
  final String? text;

  /// Called by Close.
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
          tt.spacing.xl,
          tt.spacing.none,
          tt.spacing.xl,
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
            _Quote(key: saveReferenceQuoteKey, text: quoted),
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

/// The saved state (D-166): a check, where it went, what it is, and (before
/// onboarding is done) the welcome note.
class SaveReferenceSaved extends StatelessWidget {
  /// Shows the saved [form], with the welcome note when [showWelcome].
  const SaveReferenceSaved({
    required this.form,
    required this.showWelcome,
    required this.onDone,
    required this.onOpenReel,
    super.key,
  });

  /// What was saved, in the [SaveStep.saved] state.
  final SaveReferenceState form;

  /// Whether the "Welcome to TakeTray" note shows (onboarding not done).
  final bool showWelcome;

  /// Called by Done.
  final VoidCallback onDone;

  /// Called with the reel's id by Open reel.
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
        : saveReferenceKindText(l10n, form.kind, Uri.parse(form.url));
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
          tt.spacing.xl,
          tt.spacing.none,
          tt.spacing.xl,
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
                  dimension: tt.spacing.x5l,
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
