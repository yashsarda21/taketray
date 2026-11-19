import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taketray/data/media/thumbnail_cache.dart';
import 'package:taketray/domain/models/reel.dart';
import 'package:taketray/domain/models/reel_reference.dart';
import 'package:taketray/features/clips/widgets/clip_thumbnail.dart';
import 'package:taketray/features/reels/view_models/home_controller.dart';
import 'package:taketray/features/reels/views/reel_form_sheet.dart';
import 'package:taketray/features/reels/views/sheet_failure.dart';
import 'package:taketray/features/references/view_models/reference_actions.dart';
import 'package:taketray/features/references/view_models/shooting_references.dart';
import 'package:taketray/features/references/views/reference_source_icon.dart';
import 'package:taketray/features/references/views/reference_text.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray/router/routes.dart';
import 'package:taketray_ui/taketray_ui.dart';

// The prototype's `.rg-name .thumb`: 30 x 40, a smaller cover than the reel
// picker's, so the header stays one line high.
// style-check: allow a header cover's size (D-160), not a token size
const double _coverWidth = 30;
// style-check: allow a header cover's size (D-160), not a token size
const double _coverHeight = 40;

/// The size of the source icon on a card (the prototype's `srcIcon(src, 18)`).
const double _cardIconSize = 18;

/// What the sheet asks of the screen under it as it closes.
sealed class _Leave {
  const new();
}

/// Open reel [reelId] at its References section.
final class _OpenReel extends _Leave {
  const new(this.reelId);

  final int reelId;
}

/// Open [reel]'s form on its shot ideas.
final class _WriteShots extends _Leave {
  const new(this.reel);

  final Reel reel;
}

/// Opens the Shooting mode **References** sheet (`refs.js`:
/// `sheets.refsList`, D-160): every reference of the Collecting reels, then
/// the Ready to edit ones, grouped by reel, each with the reel's shot ideas,
/// so the user can read them while they film.
///
/// - **Title:** "References", with "From your Collecting and Ready to edit
///   reels, with their shot ideas" under it.
/// - **A group** per reel, in Home's order inside each status: a header (the
///   reel's cover, its name, how many references, a chevron) and a button
///   that collapses the group (all start open; kept only while the sheet is
///   open). Open, a group shows the reel's **Shot ideas**, or "No shot ideas
///   yet." with **Write the shots you need**, then a `TtReferenceCard` per
///   reference (no menu: editing is on the reel's page).
/// - **A card tap** opens the link in the app or browser the phone picks. When
///   nothing can, "No app on this phone can open this link." is told in the
///   sheet, above its edge (D-85: a snack would lie behind the scrim), and
///   goes at the next try.
/// - **A header tap** closes the sheet and opens the reel at its References
///   (`Routes.reelReferences`). **Write the shots you need** closes the sheet
///   and opens that reel's form over [context]'s screen, on the shot ideas.
/// - It **updates live**: with no reference left in any group it shows "No
///   references in your Collecting or Ready to edit reels.".
Future<void> showShootingReferencesSheet(BuildContext context) async {
  final leave = await showTtSheet<_Leave>(
    context,
    builder: (_) => const _ShootingReferencesSheet(),
  );
  // The sheet is gone; [context] is the screen under it.
  if (leave == null || !context.mounted) return;
  switch (leave) {
    case _OpenReel(:final reelId):
      unawaited(context.push(Routes.reelReferences(reelId)));
    case _WriteShots(:final reel):
      unawaited(showReelForm(context, reel: reel, focusDescription: true));
  }
}

class _ShootingReferencesSheet extends ConsumerStatefulWidget {
  const new();

  @override
  ConsumerState<_ShootingReferencesSheet> createState() =>
      _ShootingReferencesSheetState();
}

class _ShootingReferencesSheetState
    extends ConsumerState<_ShootingReferencesSheet> {
  /// The reels whose groups are collapsed.
  final Set<int> _collapsed = {};

  /// A reference is being opened, so a second tap does nothing.
  bool _opening = false;

  /// The last open found nothing on the phone to open the link.
  bool _openFailed = false;

  void _toggle(int reelId) => setState(() {
    if (!_collapsed.remove(reelId)) _collapsed.add(reelId);
  });

  Future<void> _open(ReelReference reference) async {
    if (_opening) return;
    _opening = true;
    setState(() => _openFailed = false);
    try {
      final opened = await ref.read(referenceActionsProvider).open(reference);
      if (mounted) setState(() => _openFailed = !opened);
    } finally {
      _opening = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tt = context.tt;
    final loaded = ref.watch(shootingReferencesProvider);
    final groups = loaded.value;
    final cache = ref.watch(thumbnailCacheProvider).value;

    return TtSheet(
      title: l10n.shootingReferencesTitle,
      // The sheet's own failure line (D-85): the references could not be
      // read (the empty line would say "none", which is not known), or the
      // last open found nothing on the phone.
      footer: loaded.hasError
          ? SheetFailure(message: l10n.shootingReferencesLoadFailed)
          : _openFailed
          ? SheetFailure(message: l10n.referenceOpenFailed)
          : null,
      child: ListView(
        shrinkWrap: true,
        // proto.css: .sh-body padding 0 16px 16px, gap 12px
        padding: EdgeInsets.fromLTRB(
          tt.spacing.m,
          tt.spacing.none,
          tt.spacing.m,
          tt.spacing.m,
        ),
        children: [
          Padding(
            // In line with the title (24 dp from the sheet's edge).
            padding: EdgeInsets.fromLTRB(
              tt.spacing.xs,
              tt.spacing.none,
              tt.spacing.xs,
              tt.spacing.s,
            ),
            child: Text(
              l10n.shootingReferencesSubtitle,
              style: tt.text.material.bodyMedium!.copyWith(
                color: context.scheme.onSurfaceVariant,
              ),
            ),
          ),
          if (groups != null && groups.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: tt.spacing.xs),
              child: Text(
                l10n.shootingReferencesEmpty,
                style: tt.text.material.bodyMedium!.copyWith(
                  color: context.scheme.onSurfaceVariant,
                ),
              ),
            ),
          if (groups != null)
            for (final group in groups)
              Padding(
                key: ValueKey<int>(group.reel.reel.id),
                padding: EdgeInsets.only(bottom: tt.spacing.s),
                child: _Group(
                  group: group,
                  cache: cache,
                  open: !_collapsed.contains(group.reel.reel.id),
                  onToggle: () => _toggle(group.reel.reel.id),
                  onOpenReel: () =>
                      Navigator.of(context).pop(_OpenReel(group.reel.reel.id)),
                  onWriteShots: () =>
                      Navigator.of(context).pop(_WriteShots(group.reel.reel)),
                  onOpenReference: (reference) => unawaited(_open(reference)),
                ),
              ),
        ],
      ),
    );
  }
}

/// One reel: its header, and, while [open], its shot ideas and cards
/// (`.rgroup`).
class _Group extends StatelessWidget {
  const new({
    required this.group,
    required this.cache,
    required this.open,
    required this.onToggle,
    required this.onOpenReel,
    required this.onWriteShots,
    required this.onOpenReference,
  });

  final ReferenceGroup group;
  final ThumbnailCache? cache;
  final bool open;
  final VoidCallback onToggle;
  final VoidCallback onOpenReel;
  final VoidCallback onWriteShots;
  final ValueChanged<ReelReference> onOpenReference;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tt = context.tt;
    final reel = group.reel.reel;
    final hasShots = (reel.description ?? '').trim().isNotEmpty;
    // proto.css: .rgroup { border-radius: 18px; padding: 4px 4px 8px }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(tt.radii.l),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          tt.spacing.xxs,
          tt.spacing.xxs,
          tt.spacing.xxs,
          tt.spacing.xs,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              group: group,
              cache: cache,
              open: open,
              onToggle: onToggle,
              onOpenReel: onOpenReel,
            ),
            if (open) ...[
              Padding(
                padding: EdgeInsets.fromLTRB(
                  tt.spacing.xs,
                  tt.spacing.none,
                  tt.spacing.xs,
                  tt.spacing.xs,
                ),
                child: hasShots
                    ? _ShotIdeas(text: reel.description!)
                    : _NoShotIdeas(
                        label: l10n.shootingReferencesNoShots,
                        action: l10n.shootingReferencesWriteShots,
                        onWriteShots: onWriteShots,
                      ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: tt.spacing.xxs),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  // proto.css: .rg-refs { gap: 6px }
                  spacing: tt.spacing.xs,
                  children: [
                    for (final reference in group.references)
                      _card(context, l10n, reference),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _card(
    BuildContext context,
    AppLocalizations l10n,
    ReelReference reference,
  ) {
    final text = referenceCardText(l10n, reference);
    final kind = referenceKindText(l10n, Uri.tryParse(reference.url) ?? Uri());
    return TtReferenceCard<void>(
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
      onOpen: () => onOpenReference(reference),
    );
  }
}

/// A group's header: the reel's cover, name and count (one button to the
/// reel) and the collapse button (`.rg-h`).
class _Header extends StatelessWidget {
  const new({
    required this.group,
    required this.cache,
    required this.open,
    required this.onToggle,
    required this.onOpenReel,
  });

  final ReferenceGroup group;
  final ThumbnailCache? cache;
  final bool open;
  final VoidCallback onToggle;
  final VoidCallback onOpenReel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tt = context.tt;
    final scheme = context.scheme;
    final reel = group.reel.reel;
    final count = group.references.length;
    final cover = group.reel.cover;
    final film = Icon(
      Symbols.movie_rounded,
      size: tt.sizes.icon,
      color: scheme.onSurfaceVariant,
    );
    return Row(
      children: [
        Expanded(
          child: Semantics(
            container: true,
            excludeSemantics: true,
            button: true,
            enabled: true,
            label: l10n.shootingReferencesGroupSemantics(reel.name, count),
            onTap: onOpenReel,
            child: InkWell(
              borderRadius: BorderRadius.circular(tt.radii.m),
              onTap: onOpenReel,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: tt.sizes.touchTarget),
                child: Padding(
                  padding: EdgeInsets.all(tt.spacing.xs),
                  child: Row(
                    spacing: tt.spacing.s,
                    children: [
                      SizedBox(
                        width: _coverWidth,
                        height: _coverHeight,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(tt.radii.s),
                          child: ColoredBox(
                            color: scheme.surfaceContainerHighest,
                            child: Center(
                              child: cover == null
                                  ? film
                                  : Image(
                                      image: clipThumbnail(
                                        clip: cover,
                                        logicalSize: homeCoverSize,
                                        cache: cache,
                                      ),
                                      width: _coverWidth,
                                      height: _coverHeight,
                                      fit: BoxFit.cover,
                                      excludeFromSemantics: true,
                                      errorBuilder: (_, _, _) => film,
                                    ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              reel.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tt.text.material.titleSmall,
                            ),
                            Text(
                              l10n.shootingReferencesGroupCount(count),
                              style: tt.text.material.bodySmall!.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Symbols.chevron_right_rounded,
                        color: scheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        TtIconButton(
          icon: open
              ? Symbols.expand_less_rounded
              : Symbols.expand_more_rounded,
          semanticLabel: open
              ? l10n.shootingReferencesHide(reel.name)
              : l10n.shootingReferencesShow(reel.name),
          onPressed: onToggle,
        ),
      ],
    );
  }
}

/// A reel's shot ideas (`.rg-shots`): a "Shot ideas" label over the text.
class _ShotIdeas extends StatelessWidget {
  const new({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tt = context.tt;
    final scheme = context.scheme;
    return _ShotsBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: tt.spacing.xxs,
        children: [
          Row(
            spacing: tt.spacing.xxs,
            children: [
              Icon(
                Symbols.lightbulb_rounded,
                size: tt.sizes.iconSmall,
                color: scheme.onSurfaceVariant,
              ),
              Expanded(
                child: Text(
                  l10n.shotIdeasTitle,
                  style: tt.text.material.labelMedium!.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          Text(text, style: tt.text.material.bodyMedium),
        ],
      ),
    );
  }
}

/// The line for a reel with references and no shot ideas, with the button
/// that opens its form (`.rg-shots.none`).
class _NoShotIdeas extends StatelessWidget {
  const new({
    required this.label,
    required this.action,
    required this.onWriteShots,
  });

  final String label;
  final String action;
  final VoidCallback onWriteShots;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    return _ShotsBox(
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: tt.spacing.xs,
        children: [
          Text(
            label,
            style: tt.text.material.bodyMedium!.copyWith(
              color: context.scheme.onSurfaceVariant,
            ),
          ),
          TtButton(
            label: action,
            kind: TtButtonKind.text,
            size: TtButtonSize.small,
            onPressed: onWriteShots,
          ),
        ],
      ),
    );
  }
}

/// The rounded box behind a group's shot ideas.
class _ShotsBox extends StatelessWidget {
  const new({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    // proto.css: .rg-shots { padding: 8px 12px; border-radius: 12px }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(tt.radii.m),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tt.spacing.s,
          vertical: tt.spacing.xs,
        ),
        child: SizedBox(width: double.infinity, child: child),
      ),
    );
  }
}
