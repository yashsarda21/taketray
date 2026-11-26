import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/core/midnight_tick.dart';
import 'package:taketray/data/media/thumbnail_cache.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/features/clips/widgets/clip_thumbnail.dart';
import 'package:taketray/features/media_access/view_models/media_access_controller.dart';
import 'package:taketray/features/media_access/views/media_access_banner.dart';
import 'package:taketray/features/onboarding/view_models/onboarding_controller.dart';
import 'package:taketray/features/references/view_models/shooting_references.dart';
import 'package:taketray/features/references/views/shooting_references_sheet.dart';
import 'package:taketray/features/shooting_mode/view_models/earlier_added.dart';
import 'package:taketray/features/shooting_mode/view_models/shooting_mode_controller.dart';
import 'package:taketray/features/shooting_mode/views/open_camera.dart';
import 'package:taketray/features/shooting_mode/views/shooting_time_text.dart';
import 'package:taketray/features/shooting_mode/views/shooting_tip.dart';
import 'package:taketray/features/tagging/view_models/pending_clips.dart';
import 'package:taketray/features/tagging/views/add_earlier_videos.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray_ui/taketray_ui.dart';

/// The top of the Reels tab: the access banner, then the compact Shooting
/// mode card (D-75, D-187, D-196).
///
/// - **Off:** one row, "Shooting mode" over a line that counts the clips
///   waiting in To tag: "Off · {n} clips still to tag", or "Off · turn it on
///   before you film" when none wait (also while they are read, or when the
///   read failed). The count is `pendingClipsProvider`'s, the same stream as
///   the To tag tab's badge (D-184), so the two always agree; skipped clips
///   are in neither. No chips, no Add earlier videos (To tag's ⋮ menu keeps
///   it, ruling R12B-3), and no banner under the card (D-186).
/// - **On:** "Shooting" over "Since {time}" (and " · Manual mode" when access
///   is not full), the **Open camera** pill, the latest waiting clip's
///   thumbnail behind it (when nothing waits, the first stored clip that is
///   not missing, as the prototype does; none if there is no such clip), and
///   up to two glass chips, in this order:
///   - **References · N** (link glyph), when the Collecting and Ready to edit
///     reels have N references (D-160); read "References, N, from your
///     Collecting and Ready to edit reels" (R12B-4); it opens the References
///     sheet (`showShootingReferencesSheet`). The references are not read
///     while Shooting mode is off, and a failed or pending read shows no chip;
///   - **Earlier videos** (history glyph), while access is full and nothing
///     was added this session (`EarlierAddedThisSession`, ruling R12B-2,
///     over D-90's "stays after an add"); read "Add earlier videos, shot
///     before Shooting mode was on"; it opens Add earlier videos. Not while
///     the access level loads or after its read failed, never in Manual
///     mode (and, like the whole on card, not while the Shooting state
///     loads or after its read failed).
///
/// The card sits 4 dp under the banner, 16 dp from the sides and 12 dp above
/// what follows (`home2.css:8`). It is not drawn until the stored Shooting
/// mode has been read, so it never flashes "off" first. If that read fails
/// it shows "off", and the switch still works.
///
/// **Open camera** tells the user when the camera cannot open
/// (`openCameraOrSay`, D-86). The card watches `localDayProvider`, so "Since
/// {time}" gains its date at midnight. The one-time tip (`ShootingTip`,
/// D-142) shows under an off card, with its ring round the card.
///
/// This tab only reads the waiting clips (`pendingClipsProvider`); it does
/// not scan or verify them, which opening To tag does.
class ShootingModeSection extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tt = context.tt;
    final shootingState = ref.watch(shootingModeControllerProvider);
    final shooting = shootingState.value ?? _off(shootingState);
    final access = ref.watch(mediaAccessControllerProvider).value;
    final pending = ref.watch(pendingClipsProvider).value ?? const [];
    final fallback = ref.watch(firstShowableClipProvider).value;
    final cache = ref.watch(thumbnailCacheProvider).value;
    // Rebuilt at each local midnight, so "Since" gets its date then.
    ref.watch(localDayProvider);
    final now = ref.watch(clockProvider).now();
    final locale = Localizations.localeOf(context).toString();
    final use24Hour = MediaQuery.alwaysUse24HourFormatOf(context);
    final controller = ref.read(shootingModeControllerProvider.notifier);
    final full = access?.level == MediaAccessLevel.full;
    // The one-time tip (D-142): after onboarding, until Got it or the first
    // time Shooting mode is on. An unread flag is "not due".
    final flags = ref.watch(onboardingControllerProvider).value;
    final tipDue = flags != null && flags.done && !flags.homeTipSeen;
    final showTip = tipDue && shooting != null && !shooting.on;
    // Shooting mode is on: the tip has done its job (`_MarkTipSeen`).
    final markTipSeen = tipDue && shooting != null && shooting.on;
    final Widget card;
    if (shooting == null) {
      card = const SizedBox.shrink();
    } else if (!shooting.on) {
      card = TtShootingModeCard(
        on: false,
        title: l10n.shootingOffTitle,
        // D-184's stream, as the To tag badge counts it.
        subtitle: pending.isEmpty
            ? l10n.shootingOffIdle
            : l10n.shootingOffWaiting(pending.length),
        semanticLabel: l10n.shootingModeCardSemantics('off'),
        switchSemanticLabel: l10n.shootingSwitchLabel,
        onChanged: controller.setOn,
      );
    } else {
      final time = shootingTimeText(
        since: shooting.since ?? now,
        now: now,
        locale: locale,
        use24Hour: use24Hour,
      );
      // Unknown access (not read yet, or the read failed) says nothing about
      // Manual mode.
      final limited = access != null && !full;
      // The prototype: the latest waiting clip, else the first clip that is
      // not missing.
      final latest = latestPending(pending) ?? fallback;
      // D-160: the References of the Collecting and Ready to edit reels, read
      // only while Shooting mode is on. A failed or pending read is none.
      final referenceCount = shootingReferenceCount(
        ref.watch(shootingReferencesProvider).value ?? const [],
      );
      // R12B-2: while access is full and nothing was added since this
      // session began.
      final earlier = full && !ref.watch(earlierAddedThisSessionProvider);
      card = TtShootingModeCard(
        on: true,
        title: l10n.shootingOnTitle,
        subtitle: limited
            ? l10n.shootingOnSubtitleManual(time)
            : l10n.shootingOnSubtitle(time),
        semanticLabel: l10n.shootingModeCardSemantics('on'),
        switchSemanticLabel: l10n.shootingSwitchLabel,
        onChanged: controller.setOn,
        backdrop: latest == null
            ? null
            : clipThumbnail(
                clip: latest,
                // As wide as the card; the picture is cropped to cover it.
                logicalSize: MediaQuery.sizeOf(context).width,
                cache: cache,
              ),
        cameraLabel: l10n.shootingOpenCamera,
        onOpenCamera: () => unawaited(openCameraOrSay(context, ref)),
        chips: [
          if (referenceCount > 0)
            TtShootingCardChip(
              icon: Symbols.link_rounded,
              label: l10n.referencesHeader(referenceCount),
              semanticLabel: l10n.shootingReferencesChipLabel(referenceCount),
              onPressed: () => unawaited(showShootingReferencesSheet(context)),
            ),
          if (earlier)
            TtShootingCardChip(
              icon: Symbols.history_rounded,
              label: l10n.shootingEarlierChip,
              semanticLabel: l10n.earlierCardRowLabel,
              onPressed: () => unawaited(showAddEarlierVideos(context)),
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const MediaAccessBanner(),
        // home2.css:8: .h2-shoot { margin: 4px 16px 12px }
        Padding(
          padding: EdgeInsets.fromLTRB(
            TtMetrics.shootingCardMarginSide,
            // The tip's ring reaches 6 dp out: room for it above the card.
            showTip ? tt.spacing.xs : TtMetrics.shootingCardMarginTop,
            TtMetrics.shootingCardMarginSide,
            TtMetrics.shootingCardMarginBottom,
          ),
          // Always the same wrapper, so the card (and its switch) is not
          // remounted when the tip comes or goes.
          child: ShootingCardHighlight(active: showTip, child: card),
        ),
        if (showTip)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: tt.spacing.gutter),
            child: ShootingTip(
              onGotIt: () => unawaited(
                ref
                    .read(onboardingControllerProvider.notifier)
                    .markHomeTipSeen(),
              ),
            ),
          ),
        // Last, so it moves nothing above it when it comes or goes.
        if (markTipSeen) const _MarkTipSeen(),
      ],
    );
  }

  /// "Off" when the stored state could not be read; null while it is being
  /// read.
  ShootingState? _off(AsyncValue<ShootingState> state) =>
      state.hasError ? ShootingState.off : null;
}

/// Marks the Home tip seen once, when it is mounted, after the frame (a
/// provider never changes while the tree builds). It is in the tree only
/// while Shooting mode is on and the tip is still due, so it queues one mark
/// per transition, not one per rebuild of the section.
class _MarkTipSeen extends ConsumerStatefulWidget {
  const new();

  @override
  ConsumerState<_MarkTipSeen> createState() => _MarkTipSeenState();
}

class _MarkTipSeenState extends ConsumerState<_MarkTipSeen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        ref.read(onboardingControllerProvider.notifier).markHomeTipSeen(),
      );
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
