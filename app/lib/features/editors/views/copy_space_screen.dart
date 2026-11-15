import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:taketray/domain/models/editor_app.dart';
import 'package:taketray/domain/rules/space_check.dart';
import 'package:taketray/features/editors/view_models/copy_space_controller.dart';
import 'package:taketray/features/editors/views/editor_text.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray/platform/copy_bridge.dart';
import 'package:taketray/router/routes.dart';
import 'package:taketray_ui/taketray_ui.dart';

// Ids, counts and error types only (D-10).
final Logger _log = Logger('copySpace');

/// The space check before copying clips for an editor (`screens.js`:
/// `routes['vn-space']`, D-127), full screen above the tab shell
/// (`Routes.copySpace`). Only VN copies today ([editor] is VN).
///
/// It asks `EditSessionService.planCopy` what copying [clipIds] of reel
/// [reelId] would take, and shows one of:
/// - **Enough space** (the copies fit and 500 MB stays free): "These {n}
///   clips need {size}" with "You have {free} free.", the storage bar (the
///   phone's free space, the copies' share in the accent colour), a note that
///   TakeTray keeps 500 MB free, "Why copies?" and "Copies are temporary",
///   **Copy {n} clips** and **Back**. **Copy** starts the job once however
///   fast the taps, then replaces this screen with the progress. A start that
///   fails (another job holds the engine, anything else) says "Couldn't start
///   copying. Try again." and the screen stays.
/// - **Not enough space:** "Not enough space", the bar (what the copies need,
///   the part the phone has, after the reserve, solid, the rest hatched red),
///   "What you can do", **Select fewer clips** (back to picking) and
///   **Cancel** (to the reel's page).
/// - **Nothing to copy** (all copied already, or missing), or the phone's
///   numbers could not be read ("Couldn't start copying. Try again." with
///   **Try again**), each with **Back**.
///
/// A reel that is gone (deleted meanwhile) sends the app to Reels.
class CopySpaceScreen extends ConsumerStatefulWidget {
  const new({
    required this.reelId,
    required this.editor,
    required this.clipIds,
    super.key,
  });

  final int reelId;
  final EditorApp editor;

  /// The clips to copy, in shooting order.
  final List<int> clipIds;

  @override
  ConsumerState<CopySpaceScreen> createState() => _CopySpaceScreenState();
}

class _CopySpaceScreenState extends ConsumerState<CopySpaceScreen> {
  /// A start is running: the screen does nothing else until it answers.
  bool _starting = false;

  /// The last start failed: the line under the notes.
  bool _failed = false;

  /// Set once the screen has sent the app to Reels, so it does so once.
  bool _leaving = false;

  late final CopySpaceArgs _args = CopySpaceArgs(
    widget.reelId,
    widget.editor,
    widget.clipIds,
  );

  CopySpaceControllerProvider get _provider =>
      copySpaceControllerProvider(_args);

  void _leave() {
    if (_leaving) return;
    _leaving = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go(Routes.reels);
    });
  }

  void _back() =>
      context.canPop() ? context.pop() : context.go(Routes.reel(widget.reelId));

  /// **Cancel** of the short screen: nothing was started, so the reel's page
  /// without a word.
  void _cancel() => context.go(Routes.reel(widget.reelId));

  Future<void> _start(CopySpaceState state) async {
    if (_starting) return;
    final router = GoRouter.of(context);
    setState(() {
      _starting = true;
      _failed = false;
    });
    try {
      final jobId = await ref.read(_provider.notifier).start(state.plan);
      if (!mounted) return;
      unawaited(router.pushReplacement(Routes.copyProgressOf(jobId)));
    } on Object catch (error) {
      _log.warning('Starting the copy failed: ${error.runtimeType}');
      if (!mounted) return;
      if (error is CopyBusy && await _openHeldJob(router)) return;
      if (!mounted) return;
      setState(() {
        _starting = false;
        _failed = true;
      });
    }
  }

  /// Another job holds the copy engine: its own screen (progress, or the
  /// stop it ended in, with Try again and Delete copies and stop) is the way
  /// on, because a stopped job whose screen was replaced has no other (I-1).
  /// False when no job's plan is saved: the generic failure then shows.
  Future<bool> _openHeldJob(GoRouter router) async {
    try {
      final held = await ref.read(_provider.notifier).heldJobId();
      if (held == null || !mounted) return false;
      unawaited(router.pushReplacement(Routes.copyProgressOf(held)));
      return true;
    } on Object catch (error) {
      _log.warning('Reading the held copy job failed: ${error.runtimeType}');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final editor = editorName(l10n, widget.editor);
    final plan = ref.watch(_provider);
    final state = plan.value;
    if (plan.hasValue && state == null) _leave();

    Widget body;
    // A re-plan that fails while the copy is starting (the reel changed under
    // it) is not shown: the start answers, and the screen keeps the numbers it
    // had (Riverpod holds the last data beside the error).
    if (plan.hasError && !(_starting && state != null)) {
      body = _Message(
        title: l10n.copyStartFailed,
        actions: [
          TtButton(
            label: l10n.tryAgain,
            size: TtButtonSize.large,
            expand: true,
            onPressed: () => ref.invalidate(_provider),
          ),
          TtButton(
            label: l10n.copyBack,
            kind: TtButtonKind.text,
            expand: true,
            onPressed: _back,
          ),
        ],
      );
    } else if (state == null) {
      body = const SizedBox.shrink();
    } else if (state.nothingToCopy) {
      body = _Message(
        title: l10n.copyNothingTitle,
        body: l10n.copyNothingBody,
        actions: [
          TtButton(
            label: l10n.copyBack,
            size: TtButtonSize.large,
            expand: true,
            onPressed: _back,
          ),
        ],
      );
    } else {
      body = _Check(
        state: state,
        starting: _starting,
        failed: _failed,
        editor: widget.editor,
        editorName: editor,
        onCopy: () => unawaited(_start(state)),
        onBack: _back,
        onCancel: _cancel,
      );
    }

    return PopScope(
      // A start is running: the screen stays until it has an answer.
      canPop: !_starting,
      child: Scaffold(
        appBar: TtAppBar(
          title: l10n.copySpaceTitle(editor),
          leading: TtIconButton(
            icon: Symbols.close_rounded,
            semanticLabel: l10n.selectionClose,
            style: TtIconButtonStyle.circle,
            onPressed: _starting ? null : _back,
          ),
        ),
        body: body,
      ),
    );
  }
}

/// A whole-screen message with buttons: the numbers cannot be had, or there
/// is nothing to copy.
class _Message extends StatelessWidget {
  const new({required this.title, required this.actions, this.body});

  final String title;
  final String? body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => TtStatusLayout(
    icon: Symbols.info_rounded,
    tone: TtStatusTone.warning,
    title: title,
    body: body == null ? null : Text(body!),
    actions: actions,
  );
}

/// The numbers, the bar, the notes and the buttons (enough or short).
class _Check extends StatelessWidget {
  const new({
    required this.state,
    required this.editor,
    required this.editorName,
    required this.starting,
    required this.failed,
    required this.onCopy,
    required this.onBack,
    required this.onCancel,
  });

  final CopySpaceState state;

  /// The editor the clips are for, and its name as the notes say it.
  final EditorApp editor;
  final String editorName;
  final bool starting;
  final bool failed;
  final VoidCallback onCopy;
  final VoidCallback onBack;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tt = context.tt;
    final scheme = context.scheme;
    final plan = state.plan;
    final count = plan.clipIds.length;
    String size(int bytes) => byteSizeText(l10n, bytes);
    final enough = state.enough;
    final free = size(plan.freeBytes);
    final need = size(plan.needBytes);
    final vn = editor == EditorApp.vn;
    final folder = 'Movies/TakeTray/${plan.folderName}';

    final bar = enough
        ? TtStorageBar.enough(
            needFraction: state.needFraction,
            needLabel: l10n.copyLegendCopies(need),
            freeAfterLabel: l10n.copyLegendFreeAfter(
              size(plan.space.freeAfterBytes),
            ),
            semanticLabel: l10n.copySpaceBarSemantics(free, need),
          )
        : TtStorageBar.short(
            haveFraction: state.haveFraction,
            haveLabel: l10n.copyShortHave(free),
            shortLabel: l10n.copyShortBy(size(plan.space.shortByBytes)),
            semanticLabel: l10n.copyShortBarSemantics(
              need,
              free,
              size(plan.space.shortByBytes),
            ),
          );
    final bodyStyle = tt.text.material.bodyMedium!.copyWith(
      color: scheme.onSurfaceVariant,
    );

    final children = <Widget>[
      Text(
        enough ? l10n.copySpaceNeed(count, need) : l10n.copyShortTitle,
        style: tt.text.material.headlineSmall!.copyWith(
          color: scheme.onSurface,
        ),
      ),
      Text(
        enough
            ? l10n.copySpaceFree(free)
            : l10n.copyShortBody(count, need, free),
        style: bodyStyle,
      ),
      bar,
      Text(
        l10n.copyReserveNote(size(copyReserveBytes)),
        style: tt.text.material.bodySmall!.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      if (enough) ...[
        TtCallout(
          icon: Symbols.folder_copy_rounded,
          title: l10n.copyWhyTitle,
          richBody: boldSpans(
            vn
                ? l10n.vnCopyWhyBody(boldMark(folder))
                : l10n.projectCopyWhyBody(editorName, boldMark(folder)),
          ),
        ),
        TtCallout(
          icon: Symbols.delete_sweep_rounded,
          title: l10n.copyTemporaryTitle,
          body: vn
              ? l10n.vnCopyTemporaryBody
              : l10n.projectCopyTemporaryBody(editorName),
        ),
      ] else
        TtCallout(
          icon: Symbols.info_rounded,
          title: l10n.copyShortHelpTitle,
          body: l10n.copyShortHelpBody,
          warning: true,
        ),
      if (failed)
        TtCallout(
          icon: Symbols.info_rounded,
          body: l10n.copyStartFailed,
          warning: true,
        ),
    ];

    // proto: `.scroll { padding: 8px 24px; gap: 14px }`, then the buttons in
    // `padding: 12px 16px 16px; gap: 8px`.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: tt.spacing.xl,
              vertical: tt.spacing.xs,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: tt.spacing.s,
              children: children,
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
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              spacing: tt.spacing.xs,
              children: enough
                  ? [
                      TtButton(
                        label: l10n.copyStart(count),
                        icon: Symbols.content_copy_rounded,
                        size: TtButtonSize.large,
                        expand: true,
                        onPressed: starting ? null : onCopy,
                      ),
                      TtButton(
                        label: l10n.copyBack,
                        kind: TtButtonKind.text,
                        expand: true,
                        onPressed: starting ? null : onBack,
                      ),
                    ]
                  : [
                      TtButton(
                        label: l10n.copySelectFewer,
                        size: TtButtonSize.large,
                        expand: true,
                        onPressed: onBack,
                      ),
                      TtButton(
                        label: l10n.cancel,
                        kind: TtButtonKind.text,
                        expand: true,
                        onPressed: onCancel,
                      ),
                    ],
            ),
          ),
        ),
      ],
    );
  }
}
