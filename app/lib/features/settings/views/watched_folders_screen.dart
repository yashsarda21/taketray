import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:taketray/core/guarded.dart';
import 'package:taketray/features/media_access/view_models/media_access_controller.dart';
import 'package:taketray/features/reels/views/open_once.dart';
import 'package:taketray/features/settings/view_models/watched_folders_controller.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray/router/routes.dart';
import 'package:taketray_ui/taketray_ui.dart';

// Names the step only, never a folder (D-10).
final Logger _log = Logger('watchedFoldersScreen');

/// The Watched folders screen (`Routes.watchedFolders`, from the Watched
/// folders row in Settings; `screens.js`: `routes.watched`; Phase 10B,
/// D-149), full screen above the tab shell.
///
/// - The info bar "While Shooting mode is on, new videos saved in these
///   folders go to To tag.", and, while no folder is on, a second one: "No
///   folder is watched, so Shooting mode finds no new videos."
/// - Without full video access, a banner "Allow all videos to see your other
///   folders" with **Allow all**; the list is then only the watched folders.
/// - One tall row for each folder (`WatchedFoldersController`): a boxed icon
///   (a camera for `DCIM/Camera`, a folder for the others), the folder's
///   name, then "path · {n} videos" (or "path · No videos found here"), and
///   a switch. A chat app's folder adds "Clips from chat apps are dated when
///   they arrived. Busy groups and forwards land in To tag too."
/// - **Add a folder** opens Android's folder picker. A cancel says nothing;
///   a folder that cannot be watched, TakeTray's own copies, or a failure
///   each say so in a snack. A second tap while the picker is open does
///   nothing.
/// - The tip about pro camera apps.
///
/// Until the list is known only the fixed parts show. A failed save of a
/// switch is logged by type and the switch keeps the saved value.
class WatchedFoldersScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<WatchedFoldersScreen> createState() =>
      _WatchedFoldersScreenState();
}

class _WatchedFoldersScreenState extends ConsumerState<WatchedFoldersScreen> {
  /// Lets one **Allow all** through however fast the taps.
  final OpenOnce _allow = OpenOnce();

  /// Whether the folder picker is open (or its answer is being saved).
  bool _adding = false;

  @override
  void dispose() {
    _allow.dispose();
    super.dispose();
  }

  void _allowAll() {
    final controller = ref.read(mediaAccessControllerProvider.notifier);
    _allow.openSlow((pushing) async {
      await controller.allow();
      pushing();
    });
  }

  void _toggle(String path, bool on) => unawaited(
    guarded(
      _log,
      'Saving a watched folder',
      () => ref
          .read(watchedFoldersControllerProvider.notifier)
          .setWatched(path, on),
    ),
  );

  Future<void> _add() async {
    if (_adding) return;
    _adding = true;
    final l10n = AppLocalizations.of(context);
    final AddFolderResult? result;
    try {
      result = await guarded(
        _log,
        'Adding a folder',
        ref.read(watchedFoldersControllerProvider.notifier).addFolder,
      );
    } finally {
      _adding = false;
    }
    if (!mounted) return;
    final message = switch (result) {
      AddFolderResult.unsupportedFolder => l10n.watchedUnsupported,
      AddFolderResult.ownCopyFolder => l10n.watchedOwnFolder,
      AddFolderResult.failed || null => l10n.watchedAddFailed,
      AddFolderResult.watched || AddFolderResult.cancelled => null,
    };
    if (message != null) showTtSnack(context, message: message);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tt = context.tt;
    final view = ref.watch(watchedFoldersControllerProvider).value;
    return Scaffold(
      appBar: TtAppBar(
        title: l10n.settingsWatchedTitle,
        leading: TtIconButton(
          icon: Symbols.arrow_back_rounded,
          semanticLabel: l10n.navBack,
          style: TtIconButtonStyle.circle,
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(Routes.settings),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: tt.spacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TtInfoBar(icon: Symbols.info_rounded, text: l10n.watchedInfo),
            if (view != null && !view.rows.any((r) => r.watched))
              TtInfoBar(
                icon: Symbols.visibility_off_rounded,
                text: l10n.watchedNoneWatched,
              ),
            if (view != null && !view.fullAccess)
              TtBanner(
                kind: TtBannerKind.info,
                icon: Symbols.lock_rounded,
                iconFilled: false,
                title: l10n.watchedAccessBanner,
                action: TtButton(
                  label: l10n.settingsVideoAllowAll,
                  semanticLabel: l10n.settingsVideoAllowAllSemantics,
                  kind: TtButtonKind.text,
                  onPressed: _allowAll,
                ),
              ),
            if (view != null)
              TtGroupedRows(
                children: [
                  for (final row in view.rows)
                    _FolderRow(
                      key: ValueKey('watched-row:${row.relativePath}'),
                      row: row,
                      onChanged: (on) => _toggle(row.relativePath, on),
                    ),
                  _AddFolderRow(onTap: _add),
                ],
              ),
            Padding(
              padding: EdgeInsets.only(
                left: tt.spacing.gutter,
                top: tt.spacing.s,
                right: tt.spacing.gutter,
              ),
              child: TtCallout(
                icon: Symbols.lightbulb_rounded,
                body: l10n.watchedTip,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One folder: a tall row with its switch, and, for a chat app's folder, the
/// warning under it inside the same card.
class _FolderRow extends StatelessWidget {
  const _FolderRow({required this.row, required this.onChanged, super.key});

  final WatchedRow row;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tt = context.tt;
    final scheme = context.scheme;
    final name = row.name.isEmpty ? l10n.addFoldersMainFolder : row.name;
    final count = row.videoCount;
    final detail = row.noVideos
        ? l10n.watchedNoVideos
        : count == null
        ? null
        : l10n.addFoldersCount(count);
    final path = row.relativePath;
    final camera = path.toLowerCase() == 'dcim/camera';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TtListRow(
          tall: true,
          leading: TtRowIcon(
            icon: camera
                ? Symbols.photo_camera_rounded
                : Symbols.folder_rounded,
          ),
          title: name,
          subtitle: detail == null
              ? path
              : l10n.watchedRowSubtitle(path, detail),
          trailing: TtSwitch(
            value: row.watched,
            onChanged: onChanged,
            semanticLabel: l10n.watchedSwitchSemantics(name),
          ),
        ),
        if (row.chat)
          Padding(
            // Under the text: the row's gutter, its icon box and the gap.
            padding: EdgeInsetsDirectional.only(
              start: tt.spacing.m + TtMetrics.rowIconBoxSize + tt.spacing.m,
              end: tt.spacing.m,
              bottom: tt.spacing.s,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: tt.spacing.xs,
              children: [
                ExcludeSemantics(
                  child: Icon(
                    Symbols.warning_rounded,
                    size: tt.sizes.iconSmall,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                Expanded(
                  child: Text(
                    l10n.watchedChatWarning,
                    style: tt.text.material.bodySmall!.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// **Add a folder**: the row of the prototype's `.li.tap`, with the accent
/// colour on the icon and the title.
class _AddFolderRow extends StatelessWidget {
  const _AddFolderRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = context.scheme;
    // The row draws its title in `onSurface`; the accent colour is given to
    // the row by a theme, so no colour is picked here.
    return Theme(
      data: Theme.of(context)
          .copyWith(colorScheme: scheme.copyWith(onSurface: scheme.primary)),
      child: TtListRow(
        leading: SizedBox.square(
          dimension: context.tt.sizes.icon,
          child: ExcludeSemantics(
            child: Icon(
              Symbols.create_new_folder_rounded,
              size: context.tt.sizes.icon,
              color: scheme.primary,
            ),
          ),
        ),
        title: l10n.watchedAdd,
        onTap: onTap,
      ),
    );
  }
}
