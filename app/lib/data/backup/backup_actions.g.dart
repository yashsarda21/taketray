// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'backup_actions.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(backupActions)
final backupActionsProvider = BackupActionsProvider._();

final class BackupActionsProvider
    extends $FunctionalProvider<BackupActions, BackupActions, BackupActions>
    with $Provider<BackupActions> {
  BackupActionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'backupActionsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$backupActionsHash();

  @$internal
  @override
  $ProviderElement<BackupActions> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  BackupActions create(Ref ref) {
    return backupActions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BackupActions value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BackupActions>(value),
    );
  }
}

String _$backupActionsHash() => r'5dc052a3c4664c0b6fd63c6d2817037bba03158f';
