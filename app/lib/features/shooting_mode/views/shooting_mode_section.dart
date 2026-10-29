import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/data/media/thumbnail_cache.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/features/clips/widgets/clip_thumbnail.dart';
import 'package:taketray/features/media_access/view_models/media_access_controller.dart';
import 'package:taketray/features/media_access/views/media_access_banner.dart';
import 'package:taketray/features/shooting_mode/view_models/shooting_mode_controller.dart';
import 'package:taketray/features/shooting_mode/views/shooting_time_text.dart';
import 'package:taketray/features/tagging/view_models/pending_clips.dart';
import 'package:taketray/features/tagging/views/add_earlier_videos.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray/router/routes.dart';
import 'package:taketray_ui/taketray_ui.dart';

/// The top of the Reels tab: the access banner, then the Shooting mode card
/// (D-75, D-76).
///
/// - **Off:** the hairline card with the switch.
/// - **On:** the dark card with "On since {time}" (and, when access is not
///   full, " · Manual mode: add clips yourself"), the **Open camera** button,
///   the latest waiting clip's thumbnail behind it (none when nothing
///   waits), and two rows at the bottom:
///   - **Add earlier videos**, only while access is full and the session
///     has not used it yet (`earlierAdded`, D-73); it opens the sheet;
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
    final cache = ref.watch(thumbnailCacheProvider).value;
    final now = ref.watch(clockProvider).now();
    final locale = Localizations.localeOf(context).toString();
    final controller = ref.read(shootingModeControllerProvider.notifier);

    final Widget card;
    if (shooting == null) {
      card = const SizedBox.shrink();
    } else if (!shooting.on) {
      card = TtShootingModeCard(
        on: false,
        title: l10n.shootingOffTitle,
        subtitle: l10n.shootingOffSubtitle,
        switchSemanticLabel: l10n.shootingSwitchLabel,
        onChanged: controller.setOn,
      );
    } else {
      final time = shootingTimeText(
        since: shooting.since ?? now,
        now: now,
        locale: locale,
      );
      final full = access?.level == MediaAccessLevel.full;
      // Unknown access (not read yet, or the read failed) says nothing about
      // Manual mode.
      final limited = access != null && !full;
      final latest = latestPending(pending);
      card = TtShootingModeCard(
        on: true,
        title: l10n.shootingOnTitle,
        subtitle: limited
            ? l10n.shootingOnSubtitleManual(time)
            : l10n.shootingOnSubtitle(time),
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
        referencesRow: full && !shooting.earlierAdded
            ? TtCardRow(
                icon: Symbols.history_rounded,
                title: l10n.addEarlierVideos,
                onPressed: () => showAddEarlierVideos(context),
              )
            : null,
        toTagStrip: pending.isEmpty
            ? null
            : TtCardRow(
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
      ],
    );
  }

  /// "Off" when the stored state could not be read; null while it is being
  /// read.
  ShootingState? _off(AsyncValue<ShootingState> state) =>
      state.hasError ? ShootingState.off : null;
}
