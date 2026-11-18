// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'backup_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The Export and import screen (Phase 10B, D-150).
///
/// - **One job at a time.** [export] and [importFrom] each start a job; a
///   call while one runs does nothing (double taps, or Export tapped while an
///   import runs). The job ends in a `finally`, so a picker that fails (the
///   activity went away) or an import that throws never leaves the buttons
///   off.
/// - **A job outlives the screen.** While it runs the controller is kept
///   alive, so leaving the screen and coming back shows it still busy and
///   cannot start a second one. If Android kills TakeTray while its picker
///   is open, the job dies with the process; the new process starts idle.
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
/// - **A job outlives the screen.** While it runs the controller is kept
///   alive, so leaving the screen and coming back shows it still busy and
///   cannot start a second one. If Android kills TakeTray while its picker
///   is open, the job dies with the process; the new process starts idle.
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
  /// - **A job outlives the screen.** While it runs the controller is kept
  ///   alive, so leaving the screen and coming back shows it still busy and
  ///   cannot start a second one. If Android kills TakeTray while its picker
  ///   is open, the job dies with the process; the new process starts idle.
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

String _$backupControllerHash() => r'9a27a9fe4a0895cdf15f2b97ed3d88d9925c8da2';

/// The Export and import screen (Phase 10B, D-150).
///
/// - **One job at a time.** [export] and [importFrom] each start a job; a
///   call while one runs does nothing (double taps, or Export tapped while an
///   import runs). The job ends in a `finally`, so a picker that fails (the
///   activity went away) or an import that throws never leaves the buttons
///   off.
/// - **A job outlives the screen.** While it runs the controller is kept
///   alive, so leaving the screen and coming back shows it still busy and
///   cannot start a second one. If Android kills TakeTray while its picker
///   is open, the job dies with the process; the new process starts idle.
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
