import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:taketray/data/media/thumbnail_cache.dart';
import 'package:taketray/domain/models/editor_app.dart';
import 'package:taketray/features/clips/widgets/clip_thumbnail.dart';
import 'package:taketray/features/editors/view_models/copy_ready_controller.dart';
import 'package:taketray/features/editors/views/editor_missing_dialog.dart';
import 'package:taketray/features/editors/views/editor_text.dart';
import 'package:taketray/features/reels/views/undo_snacks.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray/platform/editors_bridge.dart';
import 'package:taketray/router/routes.dart';
import 'package:taketray_ui/taketray_ui.dart';

// Ids and error types only (D-10).
final Logger _log = Logger('copyReady');

/// The pictures in step 3 are drawn this big (logical pixels, the longer
/// side); the mock holds six of them in three columns.
const double _tileSize = 64;

/// "Ready for VN" (`screens.js`: `routes['vn-ready']`, D-127), full screen
/// above the tab shell (`Routes.copyReady`), shown after the first VN copy
/// of a reel.
///
/// A close button; a check and "Ready for VN"; "In VN, tap **New project** and
/// open the **{folder}** folder."; three steps (`TtIllustratedSteps`): tap
/// New project, open the folder, select all the clips (the first six clips
/// that have a copy, numbered, in shooting order); **Open VN** and **Done**.
///
/// The folder is the session's, so a reel renamed meanwhile still shows the
/// folder that holds the copies. **Open VN** opens the app; when the phone
/// has no such app, the "VN isn't installed" dialog. **Done**, the close
/// button and the system back go to the reel's page; nothing is deleted
/// (that is Done editing). A reel that is gone sends the app to Reels; a
/// session that is gone (Done editing ran elsewhere) to the reel's page.
class CopyReadyScreen extends ConsumerStatefulWidget {
  const new({required this.reelId, super.key});

  final int reelId;

  @override
  ConsumerState<CopyReadyScreen> createState() => _CopyReadyScreenState();
}

class _CopyReadyScreenState extends ConsumerState<CopyReadyScreen> {
  bool _leaving = false;
  bool _opening = false;

  void _leave(String location) {
    if (_leaving) return;
    _leaving = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go(location);
    });
  }

  void _done() => _leave(Routes.reel(widget.reelId));

  Future<void> _openEditor() async {
    if (_opening) return;
    _opening = true;
    final l10n = AppLocalizations.of(context);
    final snacks = ReelSnacks.of(context);
    final bridge = ref.read(editorsBridgeProvider);
    try {
      final opened = await bridge.openApp(EditorApp.vn.packageName);
      if (!opened && mounted) {
        await showEditorMissingDialog(context, EditorApp.vn);
      }
    } on Object catch (error) {
      _log.warning('Opening the editor failed: ${error.runtimeType}');
      snacks.show(l10n.reelActionFailed, done: false);
    } finally {
      _opening = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tt = context.tt;
    final scheme = context.scheme;
    final ready = ref.watch(copyReadyControllerProvider(widget.reelId)).value;
    final session = ready?.session;
    if (ready != null && ready.reelGone) _leave(Routes.reels);
    if (ready != null && !ready.reelGone && session == null) {
      _leave(Routes.reel(widget.reelId));
    }
    final editor = editorName(l10n, EditorApp.vn);
    final folder = session?.folderName ?? '';
    final cache = ref.watch(thumbnailCacheProvider).value;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _done();
      },
      child: Scaffold(
        appBar: TtAppBar(
          title: '',
          leading: TtIconButton(
            icon: Symbols.close_rounded,
            semanticLabel: l10n.selectionClose,
            style: TtIconButtonStyle.circle,
            onPressed: _done,
          ),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: tt.spacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: tt.spacing.m,
                  children: [
                    Row(
                      spacing: tt.spacing.s,
                      children: [
                        ExcludeSemantics(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: tt.colors.successContainer,
                              shape: BoxShape.circle,
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(tt.spacing.xs),
                              child: Icon(
                                Symbols.check_rounded,
                                size: tt.sizes.iconLarge,
                                color: tt.colors.onSuccessContainer,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Semantics(
                            header: true,
                            child: Text(
                              l10n.copyReadyTitle(editor),
                              style: tt.text.material.headlineSmall!.copyWith(
                                color: scheme.onSurface,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text.rich(
                      boldSpans(
                        l10n.vnReadyIntro(
                          boldMark(l10n.vnReadyNewProject),
                          boldMark(folder),
                        ),
                      ),
                      style: tt.text.material.bodyLarge!.copyWith(
                        color: scheme.onSurface,
                      ),
                    ),
                    TtIllustratedSteps(
                      steps: [
                        TtIllustratedStep.newProject(
                          number: l10n.copyStepNumber(1),
                          title: l10n.vnStep1Title,
                          body: l10n.vnStep1Body,
                        ),
                        TtIllustratedStep.folders(
                          number: l10n.copyStepNumber(2),
                          title: l10n.vnStep2Title(folder),
                          body: l10n.vnStep2Body,
                          folders: [
                            l10n.vnFolderCamera,
                            l10n.vnFolderDownload,
                            folder,
                            l10n.vnFolderWhatsApp,
                          ],
                          highlighted: 2,
                        ),
                        TtIllustratedStep.tiles(
                          number: l10n.copyStepNumber(3),
                          title: l10n.vnStep3Title,
                          body: l10n.vnStep3Body,
                          thumbnails: [
                            for (final clip in (ready?.clips ?? const []).take(
                              TtMetrics.stepTilesMax,
                            ))
                              clipThumbnail(
                                clip: clip,
                                logicalSize: _tileSize,
                                cache: cache,
                              ),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: tt.spacing.xs),
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  tt.spacing.m,
                  tt.spacing.s,
                  tt.spacing.m,
                  tt.spacing.m,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: tt.spacing.xs,
                  children: [
                    TtButton(
                      label: l10n.copyOpenEditor(editor),
                      icon: Symbols.open_in_new_rounded,
                      size: TtButtonSize.large,
                      expand: true,
                      onPressed: () => unawaited(_openEditor()),
                    ),
                    TtButton(
                      label: l10n.copyDone,
                      kind: TtButtonKind.text,
                      expand: true,
                      onPressed: _done,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
