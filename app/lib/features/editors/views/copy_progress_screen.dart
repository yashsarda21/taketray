import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:taketray/data/editors/edit_session_service.dart';
import 'package:taketray/domain/models/editor_app.dart';
import 'package:taketray/features/editors/view_models/copy_job_controller.dart';
import 'package:taketray/features/editors/view_models/copy_ready_controller.dart';
import 'package:taketray/features/editors/view_models/copy_screens.dart';
import 'package:taketray/features/editors/view_models/copy_stage.dart';
import 'package:taketray/features/editors/views/editor_text.dart';
import 'package:taketray/features/editors/views/stop_copy_dialog.dart';
import 'package:taketray/features/reels/view_models/reel_detail_controller.dart';
import 'package:taketray/features/reels/views/undo_snacks.dart';
import 'package:taketray/features/shooting_mode/views/shooting_time_text.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray/platform/copy_bridge.dart';
import 'package:taketray/router/routes.dart';
import 'package:taketray_ui/taketray_ui.dart';

// Job ids, counts and error types only (D-10).
final Logger _log = Logger('copyProgress');

/// What the screen still has to do after a failed exit: finish the job, or
/// finish stopping it. The button then reads **Try again**.
enum _Exit { finish, stop }

/// The copy of one job (`screens.js`: `routes['vn-copy']`, D-127), full
/// screen above the tab shell (`Routes.copyProgress`). It follows the job
/// [jobId] through `CopyJobController` and shows what the job's stage asks
/// for (`copyStageOf`):
///
/// - **Copying:** "Copying clips for VN", "{done} of {total} clips" over a
///   progress bar, "{size} of {size} · into Movies/TakeTray/{folder}", "Keep
///   TakeTray open until copying finishes. The screen stays on until then.",
///   and **Cancel**. The window is kept on while it copies
///   (`CopyBridge.keepScreenOn`, D-122) and let go on every way out of the
///   running state and of this screen; when the app comes back to the front
///   it is asked again, because the activity may be a new one.
/// - **Cancel**, or the system back, asks "Stop copying?"; **Stop** cancels
///   the job (the copies are deleted). The first copy of a reel then goes to
///   the reel's page with "Copying stopped. No copies were kept."; a copy
///   that adds clips to a folder says "Copying stopped. The new copies were
///   deleted." and keeps the old ones.
/// - **Phone storage is full** (`spaceFull`) and **Copying stopped**
///   (`interrupted`: TakeTray was closed mid-copy, also what a restart's
///   recovery found): **Try again** resumes with the clips left;
///   **Delete copies and stop** cancels.
/// - **Finished clean:** the job is finished (`finishJob`) and the first copy
///   of a VN reel goes to "Ready for VN"; a VN add goes to the reel's page
///   with "{n} clips added to the VN folder"; every copy for CapCut or Edits
///   goes to "Ready to add in {editor}" (D-129: the clips are added from the
///   folder's album).
/// - **Finished with clips that could not be copied:** "{n} clips couldn't be
///   copied" with **Continue with {m} clips** (finishes as above) and
///   **Cancel** (stops, deleting the copies). If **none** could be copied: "The
///   clips couldn't be copied", **Back** (stops; the empty session ends).
///
/// An exit that fails (`StateError` "not cleared yet", the bridge) says
/// "Something went wrong. Try again." under the words (not in a snack, which
/// would cover the buttons) and keeps the screen, so the user can
/// try again. A job that is gone (cleared, another job holds the engine, the
/// reel was deleted) sends the app to the reel's page, or to Reels when the
/// reel is gone, without a word. While the job is not yet known (the screen
/// opened before the first event) the engine is read once before giving up.
class CopyProgressScreen extends ConsumerStatefulWidget {
  const new({required this.jobId, super.key});

  final String jobId;

  @override
  ConsumerState<CopyProgressScreen> createState() => _CopyProgressScreenState();
}

class _CopyProgressScreenState extends ConsumerState<CopyProgressScreen> {
  late final CopyBridge _bridge = ref.read(copyBridgeProvider);
  late final OpenCopyScreens _open = ref.read(openCopyScreensProvider);
  late final AppLifecycleListener _lifecycle;

  late AppLocalizations _l10n;
  late GoRouter _router;
  late ReelSnacks _snacks;

  /// The window flag this screen last asked for.
  bool _screenOn = false;

  /// The screen has handed over to another page; it does nothing more.
  bool _left = false;

  /// A stop, a finish or a Try again is running: nothing else starts.
  bool _working = false;

  /// The Stop dialog is open: the stage is not acted on until it is answered.
  bool _dialogOpen = false;

  /// The job has been seen at least once.
  bool _seen = false;

  /// The engine was asked once about a job that was not known yet.
  bool _asked = false;

  /// The last exit that failed, for the **Try again** button.
  _Exit? _pending;

  /// An action failed: "Something went wrong. Try again." shows under the
  /// words, where no snack can cover the buttons.
  bool _error = false;

  /// The plan's editor and whether this job started the session, read while
  /// the plan is still saved.
  ({EditorApp editor, bool startedSession})? _context;

  /// The plan has been asked for (whatever it answered).
  bool _contextRead = false;

  /// The reel was deleted: the way out is Reels.
  bool _reelGone = false;

  /// The reel's id, from the job id (`<reelId>-<UTC ms>`); null if it is not.
  late final int? _reelId = _reelIdOf(widget.jobId);

  static int? _reelIdOf(String jobId) {
    final dash = jobId.lastIndexOf('-');
    final id = dash <= 0 ? null : int.tryParse(jobId.substring(0, dash));
    return id != null && id > 0 ? id : null;
  }

  @override
  void initState() {
    super.initState();
    _open.add(widget.jobId);
    _lifecycle = AppLifecycleListener(onResume: _resumed);
    ref.listenManual(copyJobControllerProvider, (_, next) => _react(next));
    final reelId = _reelId;
    if (reelId != null) {
      ref.listenManual(reelByIdProvider(reelId), (_, next) {
        if (!next.hasValue || next.value != null) return;
        // The reel was deleted: nothing here has a home any more.
        _reelGone = true;
        _goOut();
      });
    }
    unawaited(_readContext());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _react(ref.read(copyJobControllerProvider));
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _l10n = AppLocalizations.of(context);
    _router = GoRouter.of(context);
    _snacks = ReelSnacks.of(context);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _open.remove(widget.jobId);
    // The window flag never outlives this screen.
    _setScreen(false);
    super.dispose();
  }

  // The window flag ------------------------------------------------------

  /// Asks for the flag, unless it is already as asked (or [force]: the
  /// activity may be a new one that never got it).
  void _setScreen(bool on, {bool force = false}) {
    if (_screenOn == on && !force) return;
    _screenOn = on;
    unawaited(_askBridge(on));
  }

  Future<void> _askBridge(bool on) async {
    try {
      await _bridge.keepScreenOn(on);
    } on Object catch (error) {
      _log.warning('Keeping the screen on failed: ${error.runtimeType}');
    }
  }

  /// The window flag for [job]'s stage: on only while it copies and nothing
  /// is stopping it.
  void _syncScreen(CopyJob? job, {bool force = false}) {
    final running =
        job != null &&
        job.jobId == widget.jobId &&
        copyStageOf(job) == CopyStage.running &&
        !_working &&
        !_left;
    _setScreen(running, force: force && running);
  }

  void _resumed() {
    if (!mounted || _left) return;
    final job = ref.read(copyJobControllerProvider);
    _syncScreen(job, force: true);
  }

  // Following the job ------------------------------------------------------

  Future<void> _readContext() async {
    try {
      final context = await ref
          .read(editSessionServiceProvider)
          .jobContext(widget.jobId);
      // The title names the job's editor as soon as it is known.
      if (context != null && mounted) setState(() => _context = context);
    } on Object catch (error) {
      _log.warning('Reading the job context failed: ${error.runtimeType}');
    } finally {
      // Read, or given up on: the title may use its VN fallback from now on.
      if (mounted) setState(() => _contextRead = true);
    }
  }

  void _react(CopyJob? job) {
    if (!mounted || _left) return;
    if (job == null || job.jobId != widget.jobId) {
      _gone(job);
      return;
    }
    _seen = true;
    _syncScreen(job);
    if (_working || _dialogOpen || _pending != null) return;
    if (copyStageOf(job) == CopyStage.finished) unawaited(_finish(job));
  }

  /// The job is not (or no longer) the one held.
  void _gone(CopyJob? held) {
    // Our own stop or finish clears the job; it takes the screen away itself.
    if (_working) return;
    if (held == null && !_seen && !_asked) {
      // The first event may not have arrived: read the engine once.
      _asked = true;
      unawaited(_readEngineOnce());
      return;
    }
    if (_asked && !_seen && _checking) return;
    _goOut();
  }

  bool _checking = false;

  Future<void> _readEngineOnce() async {
    _checking = true;
    try {
      await ref.read(copyJobControllerProvider.notifier).onResume();
    } finally {
      _checking = false;
    }
    if (mounted) _react(ref.read(copyJobControllerProvider));
  }

  /// Hands over: the reel's page (Reels when the reel is gone), with
  /// [snack] if any.
  void _goOut({String? snack}) {
    if (_left) return;
    _left = true;
    _setScreen(false);
    final router = _router;
    final snacks = _snacks;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final id = _reelId;
      final toReels = id == null || _reelGone;
      router.go(toReels ? Routes.reels : Routes.reel(id));
      if (snack != null && !toReels) snacks.show(snack);
    });
  }

  // The buttons ------------------------------------------------------------

  Future<void> _askStop() async {
    if (_working || _dialogOpen || _left) return;
    final job = ref.read(copyJobControllerProvider);
    _dialogOpen = true;
    final bool stop;
    try {
      stop = await showStopCopyDialog(context, copies: job?.copied.length ?? 0);
    } finally {
      _dialogOpen = false;
    }
    if (!mounted) return;
    if (stop) {
      await _stop();
    } else {
      // The job may have ended while the dialog was open.
      _react(ref.read(copyJobControllerProvider));
    }
  }

  void _onBack() {
    if (_working || _left) return;
    final job = ref.read(copyJobControllerProvider);
    if (job != null && copyStageOf(job) == CopyStage.allFailed) {
      // Nothing was copied: Back is just Back.
      unawaited(_stop());
      return;
    }
    unawaited(_askStop());
  }

  /// Stops the job and deletes its copies; then the reel's page and the
  /// snack. A stop that fails leaves the screen as it was, with **Try again**
  /// when the engine did stop but the result could not be cleared.
  Future<void> _stop() async {
    if (_working || _left) return;
    final service = ref.read(editSessionServiceProvider);
    setState(() {
      _working = true;
      _pending = null;
      _error = false;
    });
    _setScreen(false);
    try {
      final context = await service.jobContext(widget.jobId) ?? _context;
      await service.cancelCopy(widget.jobId);
      if (!mounted) return;
      _goOut(
        snack: context?.startedSession ?? false
            ? _l10n.copyStoppedFirst
            : _l10n.copyStoppedAdd,
      );
    } on Object catch (error) {
      _log.warning('Stopping the copy failed: ${error.runtimeType}');
      if (!mounted) return;
      _failed(
        _Exit.stop,
        stopped:
            ref.read(copyJobControllerProvider)?.state == CopyState.cancelled,
      );
    }
  }

  /// Finishes the job and goes on: the ready screen for the first copy of a VN
  /// reel and for every CapCut or Edits copy, the reel's page for a VN add.
  Future<void> _finish(CopyJob job) async {
    if (_working || _left) return;
    final service = ref.read(editSessionServiceProvider);
    setState(() {
      _working = true;
      _pending = null;
      _error = false;
    });
    _setScreen(false);
    try {
      final context = await service.jobContext(widget.jobId) ?? _context;
      final copied = job.copied.length;
      await service.finishJob(widget.jobId);
      if (!mounted) return;
      // The first copy of a VN reel, and every copy for CapCut or Edits (the
      // clips are added from the folder's album, D-129), get the steps; a
      // VN add goes back to the page with a snack.
      if ((context?.startedSession ?? false) ||
          (context?.editor.takesShares ?? false)) {
        _left = true;
        final id = _reelId;
        if (id == null || _reelGone) {
          _left = false;
          _goOut();
        } else {
          // The pictures are this job's clips: a second batch shows the
          // new clips, not the first batch's.
          unawaited(
            _router.pushReplacement(
              Routes.copyReadyOf(
                id,
                clipIds: [for (final f in job.copied) f.clipId],
              ),
            ),
          );
        }
      } else {
        // Only a VN add reaches here (a first copy and every CapCut or
        // Edits copy went to the steps above): the folder is VN's.
        _goOut(
          snack: _l10n.copyAddedSnack(copied, editorName(_l10n, EditorApp.vn)),
        );
      }
    } on Object catch (error) {
      _log.warning('Finishing the copy failed: ${error.runtimeType}');
      if (!mounted) return;
      _failed(_Exit.finish);
    }
  }

  /// **Try again** after spaceFull or interrupted: copies the rest.
  Future<void> _resume() async {
    if (_working || _left) return;
    final service = ref.read(editSessionServiceProvider);
    setState(() {
      _working = true;
      _error = false;
    });
    try {
      await service.resumeCopy(widget.jobId);
      if (!mounted) return;
      setState(() => _working = false);
      _react(ref.read(copyJobControllerProvider));
    } on Object catch (error) {
      _log.warning('Resuming the copy failed: ${error.runtimeType}');
      if (!mounted) return;
      _failed(null);
    }
  }

  /// An exit failed: tell the user and keep the screen. [pending] is what
  /// **Try again** repeats, when the progress view is showing.
  void _failed(_Exit? pending, {bool stopped = false}) {
    setState(() {
      _error = true;
      _working = false;
      _pending = pending == _Exit.stop && !stopped ? null : pending;
    });
    _react(ref.read(copyJobControllerProvider));
  }

  void _retry() {
    final job = ref.read(copyJobControllerProvider);
    switch (_pending) {
      case _Exit.stop:
        unawaited(_stop());
      case _Exit.finish:
        if (job != null) unawaited(_finish(job));
      case null:
        break;
    }
  }

  // The views --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final job = ref.watch(copyJobControllerProvider);
    final mine = job != null && job.jobId == widget.jobId;
    final Widget body;
    if (!mine) {
      body = const SizedBox.shrink();
    } else {
      body = switch (copyStageOf(job)) {
        CopyStage.running ||
        CopyStage.finished ||
        CopyStage.cancelled => _progress(l10n, job),
        CopyStage.spaceFull => _spaceFull(l10n, job),
        CopyStage.interrupted => _interrupted(l10n, job),
        CopyStage.someFailed => _someFailed(l10n, job),
        CopyStage.allFailed => _allFailed(l10n, job),
      };
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Scaffold(body: SafeArea(bottom: false, child: body)),
    );
  }

  /// [body] with the failure line under it, when an action failed.
  Widget _withError(AppLocalizations l10n, Widget? body) {
    if (!_error) return body ?? const SizedBox.shrink();
    final tt = context.tt;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: tt.spacing.s,
      children: [
        ?body,
        // A live region: the failure replaced a snack, which was one.
        Semantics(
          liveRegion: true,
          child: Text(
            l10n.reelActionFailed,
            textAlign: TextAlign.center,
            style: tt.text.material.bodyMedium!.copyWith(
              color: context.scheme.error,
            ),
          ),
        ),
      ],
    );
  }

  /// **Cancel**: the Stop dialog; **Try again** after a failed exit.
  Widget _progress(AppLocalizations l10n, CopyJob job) {
    final tt = context.tt;
    final scheme = context.scheme;
    final total = job.total;
    final done = job.done.clamp(0, total);
    final count = l10n.copyProgressCount(done, total);
    final retry = _pending != null;
    return TtStatusLayout(
      icon: Symbols.folder_copy_rounded,
      tone: TtStatusTone.primary,
      // Empty until the plan's editor has been read (the first frame), so
      // a CapCut job never says VN; VN only when the plan cannot be read.
      title: !_contextRead
          ? ''
          : l10n.copyProgressTitle(
              editorName(l10n, _context?.editor ?? EditorApp.vn),
            ),
      body: _withError(
        l10n,
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: tt.spacing.s,
          children: [
            // A live region, so a screen reader says the count as it moves
            // (the prototype's `aria-live="polite"`); the bar's own node is
            // folded into it, with its percent.
            Semantics(
              container: true,
              liveRegion: true,
              excludeSemantics: true,
              label: count,
              value: l10n.copyPercent(
                total == 0 ? 0 : (done / total * 100).round(),
              ),
              child: TtProgressBar(
                value: total == 0 ? 0 : done / total,
                label: count,
                semanticLabel: count,
                percentText: l10n.copyPercent,
              ),
            ),
            Text(
              l10n.copyProgressBytes(
                byteSizeText(l10n, job.bytesDone),
                byteSizeText(l10n, job.bytesTotal),
                job.folderName,
              ),
              textAlign: TextAlign.center,
              style: tt.text.material.bodySmall!.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            Padding(
              padding: EdgeInsets.only(top: tt.spacing.s),
              child: Text(l10n.copyKeepOpen, textAlign: TextAlign.center),
            ),
          ],
        ),
      ),
      actions: [
        if (retry)
          TtButton(
            label: l10n.tryAgain,
            size: TtButtonSize.large,
            expand: true,
            onPressed: _working ? null : _retry,
          )
        else
          TtButton(
            label: l10n.cancel,
            kind: TtButtonKind.outlined,
            size: TtButtonSize.large,
            expand: true,
            onPressed: _working ? null : () => unawaited(_askStop()),
          ),
      ],
    );
  }

  Widget _spaceFull(AppLocalizations l10n, CopyJob job) => TtStatusLayout(
    icon: Symbols.sd_card_alert_rounded,
    tone: TtStatusTone.error,
    title: l10n.copySpaceFullTitle,
    body: _withError(
      l10n,
      Text(l10n.copySpaceFullBody(job.copied.length, job.total)),
    ),
    actions: _resumeActions(l10n),
  );

  Widget _interrupted(AppLocalizations l10n, CopyJob job) => TtStatusLayout(
    icon: Symbols.warning_rounded,
    tone: TtStatusTone.warning,
    title: l10n.copyInterruptedTitle,
    body: _withError(
      l10n,
      Text(l10n.copyInterruptedBody(job.copied.length, job.total)),
    ),
    actions: _resumeActions(l10n),
  );

  List<Widget> _resumeActions(AppLocalizations l10n) => [
    TtButton(
      label: l10n.tryAgain,
      size: TtButtonSize.large,
      expand: true,
      onPressed: _working ? null : () => unawaited(_resume()),
    ),
    TtButton(
      label: l10n.copyDeleteStop,
      kind: TtButtonKind.text,
      expand: true,
      onPressed: _working ? null : () => unawaited(_stop()),
    ),
  ];

  Widget _someFailed(AppLocalizations l10n, CopyJob job) {
    final failed = copyFailedCount(job);
    final others = (job.total - failed).clamp(0, job.total);
    final String body;
    if (failed == 1) {
      final time = ref.watch(failedClipTimeProvider(job.failedClipIds.first));
      body = switch (time.value) {
        final shot? => l10n.copyFailedOneBody(
          wallClockTimeText(
            shot,
            locale: Localizations.localeOf(context).toString(),
            use24Hour: MediaQuery.alwaysUse24HourFormatOf(context),
          ),
          others,
        ),
        // No time yet (it is being read) or no clip: no time in the line.
        null => l10n.copyFailedOneBodyNoTime(others),
      };
    } else {
      body = l10n.copyFailedManyBody(others);
    }
    return TtStatusLayout(
      icon: Symbols.warning_rounded,
      tone: TtStatusTone.warning,
      title: l10n.copyFailedTitle(failed),
      body: _withError(l10n, Text(body)),
      actions: [
        TtButton(
          label: l10n.copyContinueWith(others),
          size: TtButtonSize.large,
          expand: true,
          onPressed: _working ? null : () => unawaited(_finish(job)),
        ),
        TtButton(
          label: l10n.cancel,
          kind: TtButtonKind.text,
          expand: true,
          onPressed: _working ? null : () => unawaited(_stop()),
        ),
      ],
    );
  }

  Widget _allFailed(AppLocalizations l10n, CopyJob job) => TtStatusLayout(
    icon: Symbols.error_rounded,
    tone: TtStatusTone.error,
    title: l10n.copyAllFailedTitle(job.total),
    body: _withError(l10n, Text(l10n.copyAllFailedBody(job.total))),
    actions: [
      TtButton(
        label: l10n.copyBack,
        size: TtButtonSize.large,
        expand: true,
        onPressed: _working ? null : () => unawaited(_stop()),
      ),
    ],
  );
}
