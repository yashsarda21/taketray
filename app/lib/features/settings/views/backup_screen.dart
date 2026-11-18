import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/core/midnight_tick.dart';
import 'package:taketray/data/backup/backup_actions.dart';
import 'package:taketray/data/backup/backup_format.dart';
import 'package:taketray/features/settings/view_models/backup_controller.dart';
import 'package:taketray/features/shell/views/root_messenger.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray/router/routes.dart';
import 'package:taketray_ui/taketray_ui.dart';

/// The Export and import screen (`Routes.backup`, from the Export and import
/// row in Settings; `screens.js`: `routes.backup`; Phase 10B, D-150).
///
/// - **Export a backup**: what it saves, "Last backup: {date}" or "No backup
///   yet" (the Settings row's words), and **Export backup**, which saves the
///   file through Android's picker. "Backup saved" or "Couldn't save the
///   backup." follow; a cancel says nothing.
/// - **Import a backup**: what it does, and **Import backup**. It asks
///   "Import a backup?" first (with a sentence about VN copies when there
///   are some), then opens Android's picker, imports the file and says how
///   it went in a dialog: "Backup imported" with "{found} of {total} clips
///   found.", or why nothing changed. A cancel at either step says nothing.
/// - The "Moving to a new phone?" callout.
///
/// While a job runs (`BackupController`), both buttons are off and its
/// section shows a progress bar. The messages are shown on the app's root
/// messenger, so they still show if the screen was left meanwhile; the
/// result dialog only shows while the screen is open.
class BackupScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  /// Whether the question before an import is being asked (or its answer
  /// acted on): a second tap on **Import backup** does nothing.
  bool _asking = false;

  Future<void> _export() async {
    final l10n = AppLocalizations.of(context);
    final messenger = rootMessengerOf(context);
    final outcome = await ref.read(backupControllerProvider.notifier).export();
    switch (outcome) {
      case ExportOutcome.saved:
        showTtSnackOn(
          messenger,
          message: l10n.backupSaved,
          icon: Symbols.check_circle_rounded,
        );
      case ExportOutcome.failed:
        showTtSnackOn(messenger, message: l10n.backupSaveFailed);
      case ExportOutcome.cancelled:
        break;
    }
  }

  Future<void> _import() async {
    if (_asking) return;
    _asking = true;
    try {
      await _askAndImport();
    } finally {
      _asking = false;
    }
  }

  Future<void> _askAndImport() async {
    final l10n = AppLocalizations.of(context);
    final messenger = rootMessengerOf(context);
    final controller = ref.read(backupControllerProvider.notifier);
    final copies = await controller.hasCopies();
    if (!mounted) return;
    final go = await showTtDialog<bool>(
      context,
      icon: Symbols.warning_rounded,
      title: l10n.backupConfirmTitle,
      body: l10n.backupConfirmBody,
      content: copies ? _DialogText(l10n.backupConfirmCopies) : null,
      actions: [
        TtDialogAction(false, l10n.cancel),
        TtDialogAction(true, l10n.backupConfirmImport, destructive: true),
      ],
    );
    if (go != true || !mounted) return;

    final ImportResult? result;
    try {
      result = await controller.importFrom();
    } on Object {
      // Logged by the controller, by type. Nothing was changed.
      showTtSnackOn(messenger, message: l10n.reelActionFailed);
      return;
    }
    if (result == null || !mounted) return;
    final (icon, title, body) = _resultText(l10n, result);
    await showTtDialog<void>(
      context,
      icon: icon,
      title: title,
      body: body,
      actions: [TtDialogAction<void>(null, l10n.backupResultOk)],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tt = context.tt;
    final backup = ref.watch(backupControllerProvider);
    final job = backup.value?.job;
    final busy = job != null;
    // Rebuilt at each local midnight, so a date gains its year when the year
    // turns (as the Settings row).
    final today =
        ref.watch(localDayProvider).value ??
        ref.watch(clockProvider).now().toLocal();
    final last = backup.value?.lastExport;
    final lastText = last != null
        ? l10n.settingsBackupLast(
            ttDayText(context, last.toLocal(), today: today),
          )
        : backup.isLoading && !backup.hasError
        ? null
        : l10n.settingsBackupNone;

    return Scaffold(
      appBar: TtAppBar(
        title: l10n.settingsBackupTitle,
        leading: TtIconButton(
          icon: Symbols.arrow_back_rounded,
          semanticLabel: l10n.navBack,
          style: TtIconButtonStyle.circle,
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(Routes.settings),
        ),
      ),
      body: SingleChildScrollView(
        // screens.js: routes.backup, `.scroll` padding 4px 16px 24px, gap
        // 12px.
        padding: EdgeInsetsDirectional.fromSTEB(
          tt.spacing.gutter,
          tt.spacing.xxs,
          tt.spacing.gutter,
          tt.spacing.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: tt.spacing.s,
          children: [
            _Section(
              key: const ValueKey('backup-export'),
              icon: Symbols.download_rounded,
              title: l10n.backupExportTitle,
              body: l10n.backupExportBody,
              note: lastText,
              progress: job == BackupJob.exporting
                  ? l10n.backupExportProgress
                  : null,
              button: TtButton(
                label: l10n.backupExportButton,
                onPressed: busy ? null : _export,
              ),
            ),
            _Section(
              key: const ValueKey('backup-import'),
              icon: Symbols.upload_file_rounded,
              title: l10n.backupImportTitle,
              body: l10n.backupImportBody,
              progress: job == BackupJob.importing
                  ? l10n.backupImportProgress
                  : null,
              button: TtButton(
                label: l10n.backupImportButton,
                kind: TtButtonKind.outlined,
                onPressed: busy ? null : _import,
              ),
            ),
            TtCallout(
              icon: Symbols.smartphone_rounded,
              title: l10n.backupNewPhoneTitle,
              body: l10n.backupNewPhoneBody,
              warning: true,
            ),
          ],
        ),
      ),
    );
  }
}

/// The glyph, title and text of the dialog after an import. Only an import
/// that happened says how many clips were found.
(IconData, String, String?) _resultText(
  AppLocalizations l10n,
  ImportResult result,
) => switch (result) {
  ImportDone(:final found, :final total) => (
    Symbols.check_circle_rounded,
    l10n.backupImportedTitle,
    l10n.backupImportedBody(found, total),
  ),
  ImportBusyCopying() => (
    Symbols.hourglass_top_rounded,
    l10n.copyStillRunning,
    null,
  ),
  ImportRefused(problem: BackupProblem.notJson || BackupProblem.notTakeTray) =>
    (Symbols.error_rounded, l10n.backupNotBackup, null),
  ImportRefused(problem: BackupProblem.newerVersion) => (
    Symbols.error_rounded,
    l10n.backupNewerVersion,
    null,
  ),
  ImportRefused(problem: BackupProblem.invalidData) => (
    Symbols.error_rounded,
    l10n.backupDamaged,
    null,
  ),
  ImportTooLarge() => (Symbols.error_rounded, l10n.backupTooLarge, null),
};

/// One section of the screen (`.desc` in `screens.js`: `routes.backup`): a
/// glyph and a [title], the [body], an optional [note] (the last backup),
/// a progress bar while its job runs ([progress] is what a screen reader
/// says for it), and the [button].
class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.body,
    required this.button,
    this.note,
    this.progress,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? note;
  final String? progress;
  final Widget button;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final scheme = context.scheme;
    final text = tt.text.material;
    final progress = this.progress;
    final note = this.note;
    // proto.css: .desc (surface container low); tt-style.css: radius 20px;
    // screens.js: padding 16px, gap 8px.
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(tt.radii.xl),
      ),
      child: Padding(
        padding: EdgeInsets.all(tt.spacing.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: tt.spacing.xs,
          children: [
            Row(
              spacing: tt.spacing.xs,
              children: [
                Icon(icon, color: scheme.primary),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: text.titleMedium!.copyWith(
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Text(
              body,
              style: text.bodyMedium!.copyWith(color: scheme.onSurfaceVariant),
            ),
            if (note != null)
              Text(
                note,
                style: text.bodySmall!.copyWith(color: scheme.onSurfaceVariant),
              ),
            if (progress != null) TtProgressBar(semanticLabel: progress),
            Align(alignment: AlignmentDirectional.centerStart, child: button),
          ],
        ),
      ),
    );
  }
}

/// A paragraph of a dialog's `content`, in the dialog's own body style.
class _DialogText extends StatelessWidget {
  const _DialogText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: context.tt.text.material.bodyMedium!.copyWith(
      color: context.scheme.onSurfaceVariant,
    ),
  );
}
