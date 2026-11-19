// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'backup_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The job that runs, if any (D-150): `null` when none does.
///
/// Kept alive, and not part of [BackupController]: the Settings row reads its
/// date again each time the Backup route pops (`ref.invalidate(
/// lastExportProvider)`), and [BackupController] rebuilds from that date, so
/// a notifier that is disposed and made again would forget the job and let a
/// second one start. Nothing but a job's own start and end writes here.

@ProviderFor(RunningBackupJob)
final runningBackupJobProvider = RunningBackupJobProvider._();

/// The job that runs, if any (D-150): `null` when none does.
///
/// Kept alive, and not part of [BackupController]: the Settings row reads its
/// date again each time the Backup route pops (`ref.invalidate(
/// lastExportProvider)`), and [BackupController] rebuilds from that date, so
/// a notifier that is disposed and made again would forget the job and let a
/// second one start. Nothing but a job's own start and end writes here.
final class RunningBackupJobProvider
    extends $NotifierProvider<RunningBackupJob, BackupJob?> {
  /// The job that runs, if any (D-150): `null` when none does.
  ///
  /// Kept alive, and not part of [BackupController]: the Settings row reads its
  /// date again each time the Backup route pops (`ref.invalidate(
  /// lastExportProvider)`), and [BackupController] rebuilds from that date, so
  /// a notifier that is disposed and made again would forget the job and let a
  /// second one start. Nothing but a job's own start and end writes here.
  RunningBackupJobProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'runningBackupJobProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$runningBackupJobHash();

  @$internal
  @override
  RunningBackupJob create() => RunningBackupJob();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BackupJob? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BackupJob?>(value),
    );
  }
}

String _$runningBackupJobHash() => r'eed67ac1a30d6eefeff3afdbb45b1e5878728de9';

/// The job that runs, if any (D-150): `null` when none does.
///
/// Kept alive, and not part of [BackupController]: the Settings row reads its
/// date again each time the Backup route pops (`ref.invalidate(
/// lastExportProvider)`), and [BackupController] rebuilds from that date, so
/// a notifier that is disposed and made again would forget the job and let a
/// second one start. Nothing but a job's own start and end writes here.

abstract class _$RunningBackupJob extends $Notifier<BackupJob?> {
  BackupJob? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<BackupJob?, BackupJob?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<BackupJob?, BackupJob?>,
              BackupJob?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The Export and import screen (Phase 10B, D-150).
///
/// - **One job at a time.** [export] and [importFrom] each start a job; a
///   call while one runs does nothing (double taps, or Export tapped while an
///   import runs). The job ends in a `finally`, so a picker that fails (the
///   activity went away) or an import that throws never leaves the buttons
///   off.
/// - **A job outlives the screen and this controller.** The running job is
///   [RunningBackupJob]'s, a kept-alive provider, so leaving the screen, or
///   the Settings row reading the date again, never forgets it: coming back
///   shows it still busy and cannot start a second one. While a job runs the
///   controller is also kept alive. A job works through what it took when
///   it started, so it ends well even if its controller was replaced. If
///   Android kills TakeTray while its picker is open, the job dies with the
///   process; the new process starts idle.
/// - **The date** is `lastExportProvider`'s, the one the Settings row shows.
///   A save invalidates it, so the row and this screen show the new date at
///   once.

@ProviderFor(BackupController)
final backupControllerProvider = BackupControllerProvider._();

/// The Export and import screen (Phase 10B, D-150).
///
/// - **One job at a time.** [export] and [importFrom] each start a job; a
///   call while one runs does nothing (double taps, or Export tapped while an
///   import runs). The job ends in a `finally`, so a picker that fails (the
///   activity went away) or an import that throws never leaves the buttons
///   off.
/// - **A job outlives the screen and this controller.** The running job is
///   [RunningBackupJob]'s, a kept-alive provider, so leaving the screen, or
///   the Settings row reading the date again, never forgets it: coming back
///   shows it still busy and cannot start a second one. While a job runs the
///   controller is also kept alive. A job works through what it took when
///   it started, so it ends well even if its controller was replaced. If
///   Android kills TakeTray while its picker is open, the job dies with the
///   process; the new process starts idle.
/// - **The date** is `lastExportProvider`'s, the one the Settings row shows.
///   A save invalidates it, so the row and this screen show the new date at
///   once.
final class BackupControllerProvider
    extends $AsyncNotifierProvider<BackupController, BackupState> {
  /// The Export and import screen (Phase 10B, D-150).
  ///
  /// - **One job at a time.** [export] and [importFrom] each start a job; a
  ///   call while one runs does nothing (double taps, or Export tapped while an
  ///   import runs). The job ends in a `finally`, so a picker that fails (the
  ///   activity went away) or an import that throws never leaves the buttons
  ///   off.
  /// - **A job outlives the screen and this controller.** The running job is
  ///   [RunningBackupJob]'s, a kept-alive provider, so leaving the screen, or
  ///   the Settings row reading the date again, never forgets it: coming back
  ///   shows it still busy and cannot start a second one. While a job runs the
  ///   controller is also kept alive. A job works through what it took when
  ///   it started, so it ends well even if its controller was replaced. If
  ///   Android kills TakeTray while its picker is open, the job dies with the
  ///   process; the new process starts idle.
  /// - **The date** is `lastExportProvider`'s, the one the Settings row shows.
  ///   A save invalidates it, so the row and this screen show the new date at
  ///   once.
  BackupControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: noRetry,
        name: r'backupControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$backupControllerHash();

  @$internal
  @override
  BackupController create() => BackupController();
}

String _$backupControllerHash() => r'3bcd7d134f487d9a966efe3b0edfc948ac1b9fe4';

/// The Export and import screen (Phase 10B, D-150).
///
/// - **One job at a time.** [export] and [importFrom] each start a job; a
///   call while one runs does nothing (double taps, or Export tapped while an
///   import runs). The job ends in a `finally`, so a picker that fails (the
///   activity went away) or an import that throws never leaves the buttons
///   off.
/// - **A job outlives the screen and this controller.** The running job is
///   [RunningBackupJob]'s, a kept-alive provider, so leaving the screen, or
///   the Settings row reading the date again, never forgets it: coming back
///   shows it still busy and cannot start a second one. While a job runs the
///   controller is also kept alive. A job works through what it took when
///   it started, so it ends well even if its controller was replaced. If
///   Android kills TakeTray while its picker is open, the job dies with the
///   process; the new process starts idle.
/// - **The date** is `lastExportProvider`'s, the one the Settings row shows.
///   A save invalidates it, so the row and this screen show the new date at
///   once.

abstract class _$BackupController extends $AsyncNotifier<BackupState> {
  FutureOr<BackupState> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<BackupState>, BackupState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<BackupState>, BackupState>,
              AsyncValue<BackupState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
