import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/core/midnight_tick.dart';
import 'package:taketray/data/editors/edit_session_service.dart';
import 'package:taketray/domain/models/editor_app.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/features/editors/view_models/copies_storage_controller.dart';
import 'package:taketray/features/editors/views/done_editing_dialog.dart';
import 'package:taketray/features/editors/views/editor_text.dart';
import 'package:taketray/features/media_access/view_models/media_access_controller.dart';
import 'package:taketray/features/reels/views/undo_snacks.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray/router/routes.dart';
import 'package:taketray_ui/taketray_ui.dart';

/// The VN copies screen (`screens.js`: `routes['vn-storage']`, D-130), from
/// the "Storage used by VN copies" row in Settings (`Routes.copiesStorage`),
/// full screen above the tab shell. It also lists the copies for CapCut and
/// Instagram Edits (R7).
///
/// - **With copies:** the total ("{size}" over "used by VN copies in {n}
///   reels"), then one row per session that holds copies, newest first: the
///   reel's cover (the movie icon when it has none), its name and "{n} copies
///   · {size} · since {date}" ("{n} copies for {editor} · …" for CapCut and
///   Edits), with **Delete**; then "Copies are only for VN. Deleting them
///   never touches your original clips."
/// - **Delete** on a reel runs the same "Have you exported your video?" as
///   Done editing (`showDoneEditingDialog`), with no Published question
///   after it. When it is done the row is gone; when it failed the row stays
///   and "Couldn't delete the copies. Try again." says so.
/// - **Not linked to a reel:** the files in the copy folders that no session
///   records (an earlier install, a backup import, or files the guard
///   refused to delete), by folder: the folder's name, "{n} files · {size}"
///   and **Delete**, which asks Android's own consent dialog. Allowed: "Copies
///   deleted · {size} freed" and the folder leaves; declined: nothing is said
///   and the folder stays. A second tap while the question is open does
///   nothing.
/// - Without **full video access** a callout says TakeTray cannot find files
///   left from an earlier install.
/// - **Nothing to list:** "No VN copies" and what will show up here. **The
///   copies cannot be read:** "Couldn't read the VN copies" with **Try
///   again**.
///
/// Everything is read again when the app comes back to the front.
class CopiesStorageScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<CopiesStorageScreen> createState() =>
      _CopiesStorageScreenState();
}

class _CopiesStorageScreenState extends ConsumerState<CopiesStorageScreen> {
  late final AppLifecycleListener _lifecycle;

  /// The files' folders whose consent dialog is open (by name): a second
  /// tap does nothing.
  final Set<String> _asking = {};

  @override
  void initState() {
    super.initState();
    // The folders may have changed while TakeTray was away (the VN app, a
    // file manager, the delete dialog of another screen).
    _lifecycle = AppLifecycleListener(onResume: _resumed);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _resumed() {
    if (!mounted) return;
    ref.read(copiesStorageControllerProvider.notifier).refresh();
  }

  void _back() =>
      context.canPop() ? context.pop() : context.go(Routes.settings);

  Future<void> _deleteReel(int reelId) =>
      showDoneEditingDialog(context, ref, reelId, suggestPublished: false);

  Future<void> _deleteFolder(OrphanFolder folder) async {
    if (!_asking.add(folder.folderName)) return;
    final l10n = AppLocalizations.of(context);
    final snacks = ReelSnacks.of(context);
    try {
      final freed = await ref
          .read(copiesStorageControllerProvider.notifier)
          .deleteOrphans(folder);
      // Declined: nothing is said.
      if (freed > 0) {
        snacks.show(l10n.doneEditingFreedSnack(byteSizeText(l10n, freed)));
      }
    } on Object {
      // Logged by type in the controller.
      snacks.show(l10n.reelActionFailed, done: false);
    } finally {
      _asking.remove(folder.folderName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(copiesStorageControllerProvider);
    final access = ref.watch(mediaAccessControllerProvider).value;
    // Rebuilt at each local midnight, so a day's date gains its year when
    // the year turns.
    final today =
        ref.watch(localDayProvider).value ??
        ref.watch(clockProvider).now().toLocal();
    final state = async.value;
    final failed = async.hasError && !async.isLoading;
    // The bar is the first child of the body, not the Scaffold's `appBar`:
    // the title wraps at large text and grows the bar (`wrapTitle`).
    final bar = TtAppBar(
      title: l10n.copiesStorageTitle,
      wrapTitle: true,
      leading: TtIconButton(
        icon: Symbols.arrow_back_rounded,
        semanticLabel: l10n.navBack,
        style: TtIconButtonStyle.circle,
        onPressed: _back,
      ),
    );
    final needsAccess = access != null && access.level != MediaAccessLevel.full;
    final tt = context.tt;
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          bar,
          Expanded(
            child: ListView(
              padding: EdgeInsets.only(
                bottom: MediaQuery.paddingOf(context).bottom + tt.spacing.xl,
              ),
              children: [
                if (failed)
                  TtEmptyState(
                    illustration: TtIllustrationKind.folder,
                    title: l10n.copiesStorageLoadFailed,
                    body: l10n.doneEditingSafe,
                    actions: [
                      TtButton(
                        label: l10n.tryAgain,
                        kind: TtButtonKind.tonal,
                        onPressed: ref
                            .read(copiesStorageControllerProvider.notifier)
                            .refresh,
                      ),
                    ],
                  )
                else if (state != null) ...[
                  if (state.isEmpty)
                    TtEmptyState(
                      illustration: TtIllustrationKind.folder,
                      title: l10n.copiesStorageEmptyTitle,
                      body: l10n.copiesStorageEmptyBody,
                    )
                  else ...[
                    if (state.rows.isNotEmpty) ..._reelRows(l10n, state, today),
                    if (state.orphans.isNotEmpty) ..._orphanRows(l10n, state),
                  ],
                  if (needsAccess)
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        tt.spacing.gutter,
                        tt.spacing.m,
                        tt.spacing.gutter,
                        tt.spacing.none,
                      ),
                      child: TtCallout(
                        icon: Symbols.photo_library_rounded,
                        body: l10n.copiesStorageNeedsAccess,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The total, one row per reel and the reassurance.
  List<Widget> _reelRows(
    AppLocalizations l10n,
    CopiesStorageState state,
    DateTime today,
  ) {
    final tt = context.tt;
    final text = tt.text.material;
    return [
      // proto: padding 8px 16px 4px, .t-hs over .t-bm.v
      Padding(
        padding: EdgeInsets.fromLTRB(
          tt.spacing.gutter,
          tt.spacing.xs,
          tt.spacing.gutter,
          tt.spacing.xxs,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              byteSizeText(l10n, state.totalBytes),
              style: text.headlineSmall!.copyWith(
                color: context.scheme.onSurface,
              ),
            ),
            Text(
              l10n.copiesStorageUsed(state.rows.length),
              style: text.bodyMedium!.copyWith(
                color: context.scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      TtGroupedRows(
        children: [
          for (final row in state.rows)
            TtListRow(
              key: ValueKey('copies-row-${row.reelId}'),
              tall: true,
              leading: _Cover(
                key: ValueKey('copies-cover-${row.reelId}'),
                row.cover,
              ),
              title: row.session.reelName,
              subtitle: _rowText(l10n, row, today),
              stackTrailingAtLargeText: true,
              trailing: _DeleteButton(
                label: l10n.copiesStorageDelete,
                semanticLabel: l10n.copiesStorageDeleteSemantics(
                  row.session.reelName,
                ),
                onPressed: () => unawaited(_deleteReel(row.reelId)),
              ),
            ),
        ],
      ),
      Padding(
        padding: EdgeInsets.fromLTRB(
          tt.spacing.gutter,
          tt.spacing.m,
          tt.spacing.gutter,
          tt.spacing.none,
        ),
        child: TtCallout(
          success: true,
          icon: Symbols.verified_user_rounded,
          body: l10n.copiesStorageNote,
        ),
      ),
    ];
  }

  /// "{n} copies · {size} · since {date}", with the editor for CapCut and
  /// Edits.
  String _rowText(AppLocalizations l10n, CopiesRow row, DateTime today) {
    final size = byteSizeText(l10n, row.session.copyBytes);
    final date = ttDayText(
      context,
      row.session.createdAt.toLocal(),
      today: today,
    );
    final count = row.session.copyCount;
    return row.editor == EditorApp.vn
        ? l10n.copiesStorageRow(count, size, date)
        : l10n.copiesStorageRowEditor(
            count,
            editorName(l10n, row.editor),
            size,
            date,
          );
  }

  /// The "Not linked to a reel" group.
  List<Widget> _orphanRows(AppLocalizations l10n, CopiesStorageState state) {
    final tt = context.tt;
    return [
      TtGroupLabel(l10n.copiesStorageOrphansLabel),
      Padding(
        padding: EdgeInsetsDirectional.fromSTEB(
          TtMetrics.groupLabelPaddingHorizontal,
          tt.spacing.none,
          TtMetrics.groupLabelPaddingHorizontal,
          tt.spacing.xs,
        ),
        child: Text(
          l10n.copiesStorageOrphansNote,
          style: tt.text.material.bodyMedium!.copyWith(
            color: context.scheme.onSurfaceVariant,
          ),
        ),
      ),
      TtGroupedRows(
        children: [
          for (final folder in state.orphans)
            TtListRow(
              key: ValueKey('copies-folder-${folder.folderName}'),
              tall: true,
              leading: const TtRowIcon(icon: Symbols.folder_rounded),
              title: folder.folderName,
              subtitle: l10n.copiesStorageOrphanRow(
                folder.fileCount,
                byteSizeText(l10n, folder.bytes),
              ),
              stackTrailingAtLargeText: true,
              trailing: _DeleteButton(
                label: l10n.copiesStorageDelete,
                semanticLabel: l10n.copiesStorageOrphanDeleteSemantics(
                  folder.folderName,
                ),
                onPressed: () => unawaited(_deleteFolder(folder)),
              ),
            ),
        ],
      ),
    ];
  }
}

/// A row's **Delete**: a text button in the error colour (the prototype's
/// `.danger` text button; `taketray_ui` has no such kind, and its text button
/// draws in the scheme's primary colour, so it is given the error colour in
/// its own `Theme`).
class _DeleteButton extends StatelessWidget {
  const _DeleteButton({
    required this.label,
    required this.semanticLabel,
    required this.onPressed,
  });

  final String label;
  final String semanticLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        colorScheme: theme.colorScheme.copyWith(
          primary: theme.colorScheme.error,
        ),
      ),
      child: TtButton(
        label: label,
        semanticLabel: semanticLabel,
        kind: TtButtonKind.text,
        size: TtButtonSize.small,
        onPressed: onPressed,
      ),
    );
  }
}

/// The reel's cover in a row: the picture, or a movie icon (proto.css:
/// `.li .thumb`). 40 x 52 dp with 8 dp corners, as the reel picker's.
class _Cover extends StatelessWidget {
  const _Cover(this.cover, {super.key});

  final ImageProvider? cover;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final film = Icon(
      Symbols.movie_rounded,
      size: TtMetrics.pickRowCoverIconSize,
      color: scheme.onSurfaceVariant,
    );
    final picture = cover;
    return SizedBox(
      width: TtMetrics.pickRowCoverWidth,
      height: TtMetrics.pickRowCoverHeight,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(context.tt.radii.s),
        child: ColoredBox(
          color: scheme.surfaceContainerHigh,
          child: Center(
            child: picture == null
                ? film
                : Image(
                    image: picture,
                    width: TtMetrics.pickRowCoverWidth,
                    height: TtMetrics.pickRowCoverHeight,
                    fit: BoxFit.cover,
                    excludeFromSemantics: true,
                    errorBuilder: (context, error, stackTrace) => film,
                  ),
          ),
        ),
      ),
    );
  }
}
