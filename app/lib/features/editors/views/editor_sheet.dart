import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:taketray/data/editors/edit_session_service.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/editor_app.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/features/editors/view_models/editor_choices.dart';
import 'package:taketray/features/editors/views/editor_missing_dialog.dart';
import 'package:taketray/features/editors/views/editor_text.dart';
import 'package:taketray/features/editors/views/mark_status_dialog.dart';
import 'package:taketray/features/editors/views/open_share.dart';
import 'package:taketray/features/reels/view_models/reel_detail_controller.dart';
import 'package:taketray/features/reels/views/sheet_failure.dart';
import 'package:taketray/features/reels/views/undo_snacks.dart';
import 'package:taketray/features/tagging/views/to_tag_screen.dart'
    show formatClipDuration;
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray/platform/editors_bridge.dart' show SendResult;
import 'package:taketray/router/routes.dart';
import 'package:taketray_ui/taketray_ui.dart';

// Ids, counts, the editor's enum name and error types only (D-10).
final Logger _log = Logger('editorSheet');

/// How long after a send the "Mark as Ready to edit" offer waits
/// (`app.js`: `pickEditor`, 1300 ms): the user is in the editor by then, and
/// sees the question when they come back.
// style-check: allow a wait before a question, not motion
const Duration _readyOfferDelay = Duration(milliseconds: 1300);

/// What a row of the sheet decided.
sealed class _Chosen {
  const _Chosen();
}

/// The originals went to [editor]: [count] clips.
class _Sent extends _Chosen {
  const _Sent(this.editor, this.count);

  final EditorApp editor;
  final int count;
}

/// VN: on to the space check.
class _OpenVn extends _Chosen {
  const _OpenVn();
}

/// Other app…: Android's share menu.
class _OpenShare extends _Chosen {
  const _OpenShare();
}

/// The editor sheet (`screens.js`: `sheets.editor`, D-126) for the clips
/// [clipIds] of reel [reelId], in shooting order: "Edit {n} clips in…" over
/// **CapCut**, **Instagram Edits**, **VN** and **Other app…**.
///
/// - **CapCut and Instagram Edits** get the originals in one share
///   (`EditSessionService.sendOriginals`: the session and the sent clips are
///   written first and taken back if the share fails). **Sent**: the sheet and
///   the picking screen close, the reel's page shows "Sent {n} clips to
///   {editor}", and 1.3 s later "Mark {name} as Ready to edit?" is offered,
///   only when the reel is still Collecting. **Not installed**: the "isn't
///   installed" dialog, the sheet stays and asks the phone again. **Failed**
///   (or a share that throws): "Couldn't open {editor}. Try again." in the
///   sheet, which stays.
/// - **VN** closes the sheet and pushes the space check
///   (`Routes.copySpaceOf`); nothing is written yet.
/// - **Other app…** closes the sheet and opens Android's share menu
///   (`openShare`'s rules): no session, no question.
/// - An editor the phone lacks is greyed out with "Not installed", and a note
///   says so. When asking the phone fails, all three look installed and the
///   share decides.
///
/// Every row is inert while a send runs (one share, however many taps), and
/// the sheet cannot be dragged away meanwhile.
Future<void> showEditorSheet(
  BuildContext context, {
  required int reelId,
  required List<int> clipIds,
}) async {
  // Everything the end needs is looked up now: the picking screen under the
  // sheet is gone when a send ends well.
  final l10n = AppLocalizations.of(context);
  final router = GoRouter.of(context);
  final container = ProviderScope.containerOf(context, listen: false);
  final snacks = ReelSnacks.of(context);
  final navigator = Navigator.of(context, rootNavigator: true);

  final chosen = await showTtSheet<_Chosen>(
    context,
    builder: (_) => _EditorSheet(reelId: reelId, clipIds: clipIds),
  );
  switch (chosen) {
    case null:
      return;
    case _OpenVn():
      unawaited(router.push(Routes.copySpaceOf(reelId, EditorApp.vn, clipIds)));
    case _OpenShare():
      await shareClips(
        snacks,
        l10n,
        container.read(editSessionServiceProvider),
        clipIds,
      );
    case _Sent(:final editor, :final count):
      // Back to the reel's page (the picking screen was pushed from it).
      if (router.canPop()) {
        router.pop();
      } else {
        router.go(Routes.reel(reelId));
      }
      snacks.show(
        l10n.editorSentSnack(count, editorName(l10n, editor)),
        icon: Symbols.open_in_new_rounded,
      );
      unawaited(_offerReady(navigator, container, reelId));
  }
}

/// After [_readyOfferDelay], offers "Mark {name} as Ready to edit?" when the
/// reel is still Collecting. It never throws: the app may be gone by then.
Future<void> _offerReady(
  NavigatorState navigator,
  ProviderContainer container,
  int reelId,
) async {
  await Future<void>.delayed(_readyOfferDelay);
  try {
    if (!navigator.mounted) return;
    final reel = await container.read(reelsRepositoryProvider).getById(reelId);
    if (reel == null || reel.status != ReelStatus.collecting) return;
    // The navigator's own context has no navigator above it; the overlay is
    // below it.
    final overlay = navigator.overlay;
    if (!navigator.mounted || overlay == null) return;
    await showMarkStatusDialogIn(
      overlay.context,
      container,
      reelId,
      ReelStatus.ready,
    );
  } on Object catch (error) {
    _log.warning('The Ready to edit offer failed: ${error.runtimeType}');
  }
}

class _EditorSheet extends ConsumerStatefulWidget {
  const new({required this.reelId, required this.clipIds});

  final int reelId;
  final List<int> clipIds;

  @override
  ConsumerState<_EditorSheet> createState() => _EditorSheetState();
}

class _EditorSheetState extends ConsumerState<_EditorSheet>
    with WidgetsBindingObserver {
  /// A send is running (or the sheet is closing): the rows do nothing.
  bool _busy = false;

  /// The editor whose send just failed, for the line in the sheet.
  EditorApp? _failed;

  /// The failed send had no clip left to send: the line says so, because
  /// trying again cannot work.
  bool _failedForMissing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Back from the Play Store (or anywhere): the phone is asked again, so a
  /// row that was greyed out works once its editor is installed.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      ref.invalidate(editorChoicesProvider);
    }
  }

  /// One row of the sheet: [editor] is null for Other app….
  Future<void> _choose(EditorApp? editor) async {
    if (_busy) return;
    final navigator = Navigator.of(context);
    setState(() {
      _busy = true;
      _failed = null;
      _failedForMissing = false;
    });
    switch (editor) {
      case null:
        navigator.pop(const _OpenShare());
      case EditorApp.vn:
        navigator.pop(const _OpenVn());
      case EditorApp.capcut || EditorApp.edits:
        await _send(editor, navigator);
    }
  }

  Future<void> _send(EditorApp editor, NavigatorState navigator) async {
    SendOutcome outcome;
    try {
      outcome = await ref
          .read(editSessionServiceProvider)
          .sendOriginals(widget.reelId, editor, widget.clipIds);
    } on Object catch (error) {
      _log.warning('Sending to ${editor.name} failed: ${error.runtimeType}');
      outcome = const SendOutcome(SendResult.failed, 0);
    }
    if (!mounted) return;
    switch (outcome.result) {
      case SendResult.sent:
        navigator.pop(_Sent(editor, outcome.sentCount));
      case SendResult.notInstalled:
        await showEditorMissingDialog(context, editor);
        if (!mounted) return;
        // The phone is asked again: the row is greyed out now.
        ref.invalidate(editorChoicesProvider);
        setState(() => _busy = false);
      case SendResult.failed:
        // `failed` with nothing sent is also "no clip of these is left".
        final left = outcome.sentCount == 0 && !_anyClipLeft();
        setState(() {
          _busy = false;
          _failed = editor;
          _failedForMissing = left;
        });
    }
  }

  /// Whether any of the asked clips is still on the phone and in the reel.
  bool _anyClipLeft() {
    final asked = widget.clipIds.toSet();
    final clips = ref.read(reelClipsProvider(widget.reelId)).value ?? const [];
    return clips.any((c) => asked.contains(c.clip.id) && !c.clip.missing);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tt = context.tt;
    final choices =
        ref.watch(editorChoicesProvider).value ??
        [
          for (final e in EditorApp.values)
            EditorChoice(editor: e, installed: true),
        ];
    final reelClips =
        ref.watch(reelClipsProvider(widget.reelId)).value ?? const [];
    final asked = widget.clipIds.toSet();
    final picked = [
      for (final c in reelClips)
        if (asked.contains(c.clip.id)) c.clip,
    ];
    final durationMs = picked.fold(0, (s, c) => s + c.fingerprint.durationMs);
    final bytes = picked.fold(0, (s, c) => s + c.fingerprint.sizeBytes);
    final anyMissing = choices.any((c) => !c.installed);
    final failed = _failed;

    Widget row(EditorApp? editor) {
      final choice = editor == null
          ? null
          : choices.firstWhere((c) => c.editor == editor);
      final installed = choice?.installed ?? true;
      final name = editor == null ? l10n.editorOther : editorName(l10n, editor);
      final subtitle = switch (editor) {
        _ when !installed => l10n.editorNotInstalled,
        null => l10n.editorOtherSub,
        EditorApp.vn => l10n.editorMakesCopies(byteSizeText(l10n, bytes)),
        _ => l10n.editorGetsOriginals,
      };
      return TtListRow(
        key: ValueKey<String>('editor-row-${editor?.name ?? 'other'}'),
        tall: true,
        title: name,
        subtitle: subtitle,
        leading: editor == null
            ? const TtRowIcon(icon: Symbols.apps_rounded)
            : TtAppIcon(
                png: choice?.icon,
                fallbackLetters: switch (editor) {
                  EditorApp.capcut => 'C',
                  EditorApp.edits => 'E',
                  EditorApp.vn => 'VN',
                },
              ),
        trailing: installed ? const Icon(Symbols.chevron_right_rounded) : null,
        off: !installed,
        semanticLabel: installed
            ? null
            : l10n.editorNotInstalledSemantics(name),
        onTap: installed ? () => unawaited(_choose(editor)) : null,
      );
    }

    return PopScope(
      // A send is running: the sheet stays until it has an answer.
      canPop: !_busy,
      child: TtSheet(
        title: l10n.editorSheetTitle(widget.clipIds.length),
        footer: failed == null
            ? null
            : SheetFailure(
                message: _failedForMissing
                    ? l10n.shareClipsMissing
                    : l10n.editorOpenFailed(editorName(l10n, failed)),
              ),
        child: ListView(
          shrinkWrap: true,
          padding: EdgeInsets.only(bottom: tt.spacing.s),
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: tt.spacing.xl),
              child: Text(
                l10n.editorSheetSubtitle(formatClipDuration(durationMs)),
                style: tt.text.material.bodyMedium!.copyWith(
                  color: context.scheme.onSurfaceVariant,
                ),
              ),
            ),
            for (final editor in EditorApp.values) row(editor),
            row(null),
            if (anyMissing)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  tt.spacing.xl,
                  tt.spacing.xs,
                  tt.spacing.xl,
                  tt.spacing.none,
                ),
                child: Text(
                  l10n.editorGreyedNote,
                  style: tt.text.material.bodySmall!.copyWith(
                    color: context.scheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
