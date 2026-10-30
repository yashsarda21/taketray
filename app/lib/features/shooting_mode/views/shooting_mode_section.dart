import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/data/media/thumbnail_cache.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/features/clips/widgets/clip_thumbnail.dart';
import 'package:taketray/features/media_access/view_models/media_access_controller.dart';
import 'package:taketray/features/media_access/views/media_access_banner.dart';
import 'package:taketray/features/shooting_mode/view_models/shooting_mode_controller.dart';
import 'package:taketray/features/shooting_mode/views/shooting_time_text.dart';
import 'package:taketray/features/shooting_mode/views/waiting_duration_text.dart';
import 'package:taketray/features/tagging/view_models/pending_clips.dart';
import 'package:taketray/features/tagging/views/add_earlier_videos.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray/router/routes.dart';
import 'package:taketray_ui/taketray_ui.dart';

/// The top of the Reels tab: the access banner, then the Shooting mode card
/// (D-75, D-76).
///
/// - **Off:** the hairline card with the switch, and, when clips wait, the
///   attention banner below it ("N clips to tag", "M min of video waiting";
///   it opens To tag). The on card has its own strip instead, so the two are
///   never shown together.
/// - **On:** the dark card with "On since {time}" (and, when access is not
///   full, " · Manual mode: add clips yourself"), the **Open camera** button,
///   the latest waiting clip's thumbnail behind it (when nothing waits, the
///   first stored clip that is not missing, as the prototype does; none if
///   there is no such clip), and rows at the bottom (D-79: the card's `rows`
///   slot holds References first, then Add earlier videos, then the strip):
///   - **Add earlier videos** (history icon, "Shot before Shooting mode was
///     on", a chevron), only while access is full and the session has not
///     used it yet (`earlierAdded`, D-73); it opens the sheet;
///   - "N clips to tag · Tag now", when any wait; it opens To tag.
///
/// The card is not drawn until the stored Shooting mode has been read, so it
/// never flashes "off" first. If that read fails it shows "off", and the
/// switch still works.
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
    final now = ref.watch(clockProvider).now();
    final locale = Localizations.localeOf(context).toString();
    final use24Hour = MediaQuery.alwaysUse24HourFormatOf(context);
    final controller = ref.read(shootingModeControllerProvider.notifier);

    final Widget card;
    if (shooting == null) {
      card = const SizedBox.shrink();
    } else if (!shooting.on) {
      card = TtShootingModeCard(
        on: false,
        title: l10n.shootingOffTitle,
        subtitle: l10n.shootingOffSubtitle,
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
      final full = access?.level == MediaAccessLevel.full;
      // Unknown access (not read yet, or the read failed) says nothing about
      // Manual mode.
      final limited = access != null && !full;
      // The prototype: the latest waiting clip, else the first clip that is
      // not missing.
      final latest = latestPending(pending) ?? fallback;
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
        onOpenCamera: controller.openCamera,
        // References (Phase 4/5) will come first in this list.
        rows: [
          if (full && !shooting.earlierAdded)
            TtCardRow(
              kind: TtCardRowKind.link,
              icon: Symbols.history_rounded,
              title: l10n.addEarlierVideos,
              subtitle: l10n.earlierCardRowSubtitle,
              semanticLabel: l10n.earlierCardRowLabel,
              onPressed: () => showAddEarlierVideos(context),
            ),
        ],
        toTagStrip: pending.isEmpty
            ? null
            : TtCardRow(
                kind: TtCardRowKind.strip,
                icon: Symbols.sell_rounded,
                title: l10n.shootingStripTitle(pending.length),
                trailingText: l10n.shootingStripAction,
                onPressed: () => context.go(Routes.toTag),
              ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const MediaAccessBanner(),
        // proto.css: .shoot { margin: 4px 16px 8px }
        Padding(
          padding: EdgeInsets.fromLTRB(
            tt.spacing.gutter,
            tt.spacing.xxs,
            tt.spacing.gutter,
            tt.spacing.xs,
          ),
          child: card,
        ),
        // The prototype's `banner attn`: only while Shooting mode is off (the
        // on card has its own "N clips to tag" strip) and a clip waits.
        if (shooting != null && !shooting.on && pending.isNotEmpty)
          TtBanner(
            kind: TtBannerKind.attention,
            icon: Symbols.sell_rounded,
            title: l10n.clipsWaitingTitle(pending.length),
            body: l10n.clipsWaitingBody(
              waitingDurationText(l10n, _totalMs(pending)),
            ),
            onTap: () => context.go(Routes.toTag),
          ),
      ],
    );
  }

  /// The summed length of [clips], as `q.total` sums them in the prototype
  /// (every waiting clip counts, as it does in the title's number).
  int _totalMs(List<Clip> clips) =>
      clips.fold(0, (sum, c) => sum + c.fingerprint.durationMs);

  /// "Off" when the stored state could not be read; null while it is being
  /// read.
  ShootingState? _off(AsyncValue<ShootingState> state) =>
      state.hasError ? ShootingState.off : null;
}
