import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taketray/data/media/add_videos_service.dart';
import 'package:taketray/data/media/thumbnail_cache.dart';
import 'package:taketray/domain/rules/browse_folders.dart';
import 'package:taketray/features/add_videos/view_models/add_folders_controller.dart';
import 'package:taketray/features/add_videos/views/add_videos_flow.dart';
import 'package:taketray/features/clips/widgets/clip_thumbnail.dart';
import 'package:taketray/features/reels/views/open_once.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray/router/routes.dart';
import 'package:taketray_ui/taketray_ui.dart';

/// Skeleton rows shown while the folders load.
const int _skeletonRows = 4;

/// Add videos' folder list (prototype screen 17, `add-folders`; D-114),
/// full screen above the tab shell (`Routes.addVideos`).
///
/// From the top: an app bar "Add videos" with "to To tag" or "to {reel}" and
/// **Back**; the one-time tip "Keep friends' clips sharp" with **Got it**
/// (`FolderTip`; once dismissed it never shows again on this phone); then
/// every folder with videos (`AddFoldersController`, `browseFolders`), each a
/// tall row: a 2×2 preview of its first four videos (read only when the row
/// is built; a folder icon when there is none or the read failed), its name
/// ("Main folder" for a volume's root), "{n} videos", for a name another row
/// shares the folder above it and, across volumes, "Phone" or "Other
/// storage" (never a volume's name), and a chevron.
///
/// A tap opens the folder's grid (`Routes.addVideosFolder`, once however fast
/// the taps). When the grid adds videos, this screen closes too, handing the
/// result to whoever opened it (`openAddVideos`).
///
/// - Loading shows skeleton rows; a failed read "Couldn't load your folders"
///   with **Try again**; no folder with videos "No videos yet".
/// - The app coming back to the front reads the folders and previews again.
/// - **Access lost** (anything but full) while this is the top screen, or
///   **the target reel deleted**: the screen closes, back to where it was
///   opened (where the banner explains). When the grid is on top, the grid
///   closes first and this follows.
class AddFoldersScreen extends ConsumerStatefulWidget {
  const new({required this.target, super.key});

  final AddTarget target;

  @override
  ConsumerState<AddFoldersScreen> createState() => _AddFoldersScreenState();
}

class _AddFoldersScreenState extends ConsumerState<AddFoldersScreen>
    with WidgetsBindingObserver {
  /// Opens the grid once however fast the taps.
  final OpenOnce _grid = OpenOnce();

  /// The screen is closing; it closes once.
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _grid.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    unawaited(ref.read(addFoldersControllerProvider.notifier).refresh());
    ref.invalidate(folderPreviewProvider);
  }

  /// Closes the screen with [result] for whoever opened it, once, and only
  /// while it is the top screen (when the grid is on top, the grid leaves
  /// and hands its exit here).
  void _leave([AddResult? result, bool fromGrid = false]) {
    if (_leaving || !mounted) return;
    if (!fromGrid && !(ModalRoute.of(context)?.isCurrent ?? false)) return;
    _leaving = true;
    context.pop(result);
  }

  void _openFolder(BrowseFolder folder) {
    final reelId = switch (widget.target) {
      AddToToTag() => null,
      AddToReel(:final reelId) => reelId,
    };
    _grid.open(() async {
      final exit = await context.push<Object?>(
        Routes.addVideosFolderOf(
          folder.volumeName,
          folder.relativePath,
          reelId: reelId,
        ),
      );
      // Back from the grid stays here; an add, or a reason to leave, closes
      // this screen too.
      if (exit is AddResult) _leave(exit, true);
      if (exit == addVideosLeave) _leave(null, true);
      return exit;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    leaveWhenAddVideosEnds(ref, widget.target, _leave);
    final folders = ref.watch(addFoldersControllerProvider);
    final tipSeen = ref.watch(folderTipProvider).value;
    final subtitle = addVideosTargetText(context, ref, widget.target);

    return Scaffold(
      appBar: TtAppBar(
        title: l10n.addVideosTitle,
        subtitle: subtitle,
        leading: TtIconButton(
          icon: Symbols.arrow_back_rounded,
          semanticLabel: l10n.navBack,
          style: TtIconButtonStyle.circle,
          onPressed: () => context.pop(),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          if (tipSeen == false)
            SliverToBoxAdapter(
              child: _Tip(
                onDismiss: () =>
                    unawaited(ref.read(folderTipProvider.notifier).dismiss()),
              ),
            ),
          ...switch (folders) {
            AsyncData(:final value) when value.isEmpty => [
              SliverToBoxAdapter(
                child: TtEmptyState(
                  illustration: TtIllustrationKind.folder,
                  title: l10n.addFoldersEmptyTitle,
                  body: l10n.addFoldersEmptyBody,
                ),
              ),
            ],
            AsyncData(:final value) => [_rows(context, value)],
            AsyncError() => [
              SliverToBoxAdapter(
                child: TtEmptyState(
                  illustration: TtIllustrationKind.folder,
                  title: l10n.addFoldersLoadFailedTitle,
                  body: l10n.toTagLoadFailedBody,
                  actions: [
                    TtButton(
                      label: l10n.tryAgain,
                      kind: TtButtonKind.tonal,
                      onPressed: ref
                          .read(addFoldersControllerProvider.notifier)
                          .retry,
                    ),
                  ],
                ),
              ),
            ],
            _ => [_skeletons(context)],
          },
          SliverToBoxAdapter(child: SizedBox(height: _endSpace(context))),
        ],
      ),
    );
  }

  /// Room under the last row: the phone's own bar and a little air.
  double _endSpace(BuildContext context) =>
      MediaQuery.paddingOf(context).bottom + context.tt.spacing.xl;

  /// The folders as one lazy list of grouped rows: only the rows on screen
  /// are built, so only their previews are read.
  Widget _rows(BuildContext context, List<BrowseFolder> folders) {
    final tt = context.tt;
    const outer = Radius.circular(TtMetrics.groupedRowsOuterRadius);
    const inner = Radius.circular(TtMetrics.groupedRowsInnerRadius);
    final last = folders.length - 1;
    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: tt.spacing.gutter),
      sliver: SliverList.builder(
        itemCount: folders.length,
        itemBuilder: (context, index) {
          final folder = folders[index];
          return Padding(
            padding: EdgeInsets.only(
              top: index == 0 ? tt.spacing.none : TtMetrics.groupedRowsGap,
            ),
            // tt-style.css: .style-tt .scroll > .li (a settings-style group)
            child: Material(
              color: context.scheme.surfaceContainerLow,
              borderRadius: BorderRadius.vertical(
                top: index == 0 ? outer : inner,
                bottom: index == last ? outer : inner,
              ),
              clipBehavior: Clip.antiAlias,
              child: _FolderRow(
                key: ValueKey((folder.volumeName, folder.relativePath)),
                folder: folder,
                onTap: () => _openFolder(folder),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _skeletons(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tt = context.tt;
    return SliverToBoxAdapter(
      child: Semantics(
        container: true,
        label: l10n.loading,
        child: ExcludeSemantics(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: tt.spacing.gutter),
            child: Column(
              spacing: tt.spacing.l,
              children: [
                for (var i = 0; i < _skeletonRows; i++)
                  Row(
                    spacing: tt.spacing.m,
                    children: const [
                      SizedBox.square(
                        dimension: TtMetrics.folderPreviewSize,
                        child: TtClipTileSkeleton(),
                      ),
                      Expanded(child: TtSkeletonLine(widthFactor: 0.6)),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The tip "Keep friends' clips sharp" with **Got it**.
class _Tip extends StatelessWidget {
  const new({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tt = context.tt;
    // screens.js: `<div class="callout" style="margin:4px 16px 8px">`
    return Padding(
      padding: EdgeInsets.fromLTRB(
        tt.spacing.gutter,
        tt.spacing.xxs,
        tt.spacing.gutter,
        tt.spacing.xs,
      ),
      child: TtCallout(
        icon: Symbols.tips_and_updates_rounded,
        title: l10n.addFoldersTipTitle,
        body: l10n.addFoldersTipBody,
        action: Align(
          alignment: AlignmentDirectional.centerStart,
          child: TtButton(
            label: l10n.addFoldersTipDismiss,
            kind: TtButtonKind.text,
            onPressed: onDismiss,
          ),
        ),
      ),
    );
  }
}

/// One folder: its preview, name, "{n} videos" with what tells it apart,
/// and a chevron.
class _FolderRow extends ConsumerWidget {
  const new({required this.folder, required this.onTap, super.key});

  final BrowseFolder folder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final parts = [
      l10n.addFoldersCount(folder.videoCount),
      ?folder.parent,
      if (folder.storage case final storage?) storageText(l10n, storage),
    ];
    return TtListRow(
      tall: true,
      leading: _FolderPreview(folder: folder),
      title: folder.isMainFolder ? l10n.addFoldersMainFolder : folder.name,
      subtitle: parts.reduce(l10n.addFoldersJoin),
      trailing: const Icon(Symbols.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

/// The words for [storage]: "Phone", "Other storage", "Other storage 2".
String storageText(AppLocalizations l10n, FolderStorage storage) {
  if (storage.isPhone) return l10n.addFoldersStoragePhone;
  final number = storage.number;
  return number == null
      ? l10n.addFoldersStorageOther
      : l10n.addFoldersStorageOtherNumbered(number);
}

/// The 2×2 mosaic of a folder's first four videos (as many as it has, laid
/// out two to a row like the prototype's grid), or the folder icon when
/// there are none or they could not be read. Hidden from screen readers: the
/// row's words say what it is.
class _FolderPreview extends ConsumerWidget {
  const new({required this.folder});

  final BrowseFolder folder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tt = context.tt;
    final scheme = context.scheme;
    final videos = ref.watch(
      folderPreviewProvider(folder.volumeName, folder.relativePath),
    );
    final cache = ref.watch(thumbnailCacheProvider).value;
    final shown = videos.value ?? const [];
    const columns = 2;
    final rows = (shown.length / columns).ceil();
    Widget content;
    if (videos.hasError || (videos.hasValue && shown.isEmpty)) {
      content = Center(
        child: Icon(
          Symbols.folder_rounded,
          size: TtMetrics.folderPreviewIconSize,
          color: scheme.onSurfaceVariant,
        ),
      );
    } else if (shown.isEmpty) {
      content = const SizedBox.shrink();
    } else {
      content = Column(
        spacing: TtMetrics.folderPreviewGap,
        children: [
          for (var r = 0; r < rows; r++)
            Expanded(
              child: Row(
                spacing: TtMetrics.folderPreviewGap,
                children: [
                  for (var c = 0; c < columns; c++)
                    Expanded(
                      child: r * columns + c < shown.length
                          ? Image(
                              image: clipThumbnail(
                                clip: shown[r * columns + c].picture,
                                logicalSize: TtMetrics.folderPreviewSize,
                                cache: cache,
                              ),
                              fit: BoxFit.cover,
                              excludeFromSemantics: true,
                              errorBuilder: (_, _, _) =>
                                  const SizedBox.shrink(),
                            )
                          : const SizedBox.shrink(),
                    ),
                ],
              ),
            ),
        ],
      );
    }
    // proto.css: .li .thumb { border-radius: 8px; background:
    // surface-container-high }
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: TtMetrics.folderPreviewSize,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(tt.radii.s),
          child: ColoredBox(color: scheme.surfaceContainerHigh, child: content),
        ),
      ),
    );
  }
}
