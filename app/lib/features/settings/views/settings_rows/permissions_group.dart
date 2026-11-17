import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/features/media_access/view_models/media_access_controller.dart';
import 'package:taketray/features/notifications/view_models/notification_access_controller.dart';
import 'package:taketray/features/reels/views/open_once.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray_ui/taketray_ui.dart';

/// The Permissions group: "Video access" and "Notifications".
///
/// - **Video access:** "All videos" with a check; "Some videos only · Manual
///   mode" with a tonal **Allow all**; or "Not allowed" with a tonal
///   **Allow**. The buttons call `MediaAccessController.allow` (one call
///   however fast the taps). While the first read runs the row is left out;
///   if it failed, the row says "Not allowed" with **Allow** (the permission
///   is unknown, and the button reads it again).
/// - **Notifications (D-107):** "Allowed" with a check, or "Not allowed" with
///   a tonal **Allow**. **Allow** asks when Android will show its dialog and
///   opens the phone's notification settings otherwise
///   (`NotificationAccessController.allow`); if that page cannot be opened,
///   "Couldn't open settings on this phone." Same rules for the first read.
///
/// Both follow their state, which is read again on every resume, so the rows
/// are right after the user comes back from the phone's settings. A row
/// whose first read is running is left out, and the group with it when both
/// are.
class PermissionsGroup extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<PermissionsGroup> createState() => _PermissionsGroupState();
}

class _PermissionsGroupState extends ConsumerState<PermissionsGroup> {
  /// Lets one Allow of the video access through however fast the taps.
  final OpenOnce _video = OpenOnce();

  @override
  void dispose() {
    _video.dispose();
    super.dispose();
  }

  /// Asks for the videos; the window stays shut while the question is open
  /// and for a moment after it.
  void _allowVideo() {
    final controller = ref.read(mediaAccessControllerProvider.notifier);
    _video.openSlow((pushing) async {
      await controller.allow();
      pushing();
    });
  }

  Future<void> _allowNotifications() async {
    final l10n = AppLocalizations.of(context);
    final worked = await ref
        .read(notificationAccessControllerProvider.notifier)
        .allow();
    if (worked || !mounted) return;
    showTtSnack(context, message: l10n.notificationsHelpOpenFailed);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final video = ref.watch(mediaAccessControllerProvider);
    final notifications = ref.watch(notificationAccessControllerProvider);
    // Running the first read: unknown, nothing to show yet. A failed first
    // read is shown as not allowed, so the user can still reach Allow.
    final showVideo = video.hasValue || video.hasError;
    final showNotifications = notifications.hasValue || notifications.hasError;
    if (!showVideo && !showNotifications) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TtGroupLabel(l10n.settingsGroupPermissions),
        TtGroupedRows(
          children: [
            if (showVideo) _videoRow(l10n, video.value?.level),
            if (showNotifications)
              _notificationsRow(
                l10n,
                granted: notifications.value?.granted ?? false,
              ),
          ],
        ),
      ],
    );
  }

  Widget _videoRow(AppLocalizations l10n, MediaAccessLevel? level) {
    return TtListRow(
      leading: const TtRowIcon(
        icon: Symbols.photo_library_rounded,
        boxed: false,
      ),
      title: l10n.settingsVideoTitle,
      subtitle: switch (level) {
        MediaAccessLevel.full => l10n.settingsVideoAll,
        MediaAccessLevel.limited => l10n.settingsVideoSome,
        _ => l10n.settingsVideoNone,
      },
      stackTrailingAtLargeText: true,
      trailing: level == MediaAccessLevel.full
          ? Icon(
              Symbols.check_circle_rounded,
              fill: 1,
              color: context.scheme.primary,
            )
          : TtButton(
              label: level == MediaAccessLevel.limited
                  ? l10n.settingsVideoAllowAll
                  : l10n.settingsVideoAllow,
              semanticLabel: level == MediaAccessLevel.limited
                  ? l10n.settingsVideoAllowAllSemantics
                  : l10n.settingsVideoAllowSemantics,
              kind: TtButtonKind.tonal,
              size: TtButtonSize.small,
              onPressed: _allowVideo,
            ),
    );
  }

  Widget _notificationsRow(AppLocalizations l10n, {required bool granted}) {
    return TtListRow(
      leading: const TtRowIcon(
        icon: Symbols.notifications_rounded,
        boxed: false,
      ),
      title: l10n.settingsNotificationsTitle,
      subtitle: granted
          ? l10n.settingsNotificationsAllowed
          : l10n.settingsNotificationsNotAllowed,
      stackTrailingAtLargeText: true,
      trailing: granted
          ? Icon(
              Symbols.check_circle_rounded,
              fill: 1,
              color: context.scheme.primary,
            )
          : TtButton(
              label: l10n.settingsNotificationsAllow,
              semanticLabel: l10n.settingsNotificationsAllowSemantics,
              kind: TtButtonKind.tonal,
              size: TtButtonSize.small,
              onPressed: _allowNotifications,
            ),
    );
  }
}
