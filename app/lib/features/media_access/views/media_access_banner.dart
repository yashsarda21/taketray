import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taketray/features/media_access/view_models/media_access_controller.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray_ui/taketray_ui.dart';

/// The banner under the app bar that tells the user TakeTray cannot see all
/// their videos (D-75, D-76).
///
/// - [AccessBanner.manual]: an info banner, "Manual mode", with "Allow full
///   access";
/// - [AccessBanner.lost]: a warning banner, "TakeTray can't see your
///   videos", with "Allow";
/// - [AccessBanner.none], and while the first read is running or if it
///   failed: nothing. A failed read shows no banner rather than a wrong one.
///
/// The button calls `MediaAccessController.allow()`, which asks for the
/// permission or opens the phone's settings. The banner follows the state,
/// so it goes away by itself when access becomes full.
class MediaAccessBanner extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final banner = ref.watch(mediaAccessControllerProvider).value?.banner;
    final l10n = AppLocalizations.of(context);
    void allow() => ref.read(mediaAccessControllerProvider.notifier).allow();
    return switch (banner) {
      null || AccessBanner.none => const SizedBox.shrink(),
      // The prototype's `accessBanner`: a lock for Manual mode,
      // `no_photography` for a loss, both outlined (status, not an action).
      AccessBanner.manual => TtBanner(
        kind: TtBannerKind.info,
        icon: Symbols.lock_rounded,
        iconFilled: false,
        title: l10n.accessManualTitle,
        body: l10n.accessManualBody,
        action: TtButton(
          label: l10n.accessManualAction,
          kind: TtButtonKind.text,
          onPressed: allow,
        ),
      ),
      AccessBanner.lost => TtBanner(
        kind: TtBannerKind.warning,
        icon: Symbols.no_photography_rounded,
        iconFilled: false,
        title: l10n.accessLostTitle,
        body: l10n.accessLostBody,
        action: TtButton(
          label: l10n.accessLostAction,
          kind: TtButtonKind.text,
          onPressed: allow,
        ),
      ),
    };
  }
}
