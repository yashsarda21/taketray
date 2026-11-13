import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/domain/models/clip_ref.dart';
import 'package:taketray/platform/editors_api.g.dart';

part 'editors_bridge.g.dart';

/// One copy TakeTray recorded: its MediaStore id on the phone's own storage,
/// its folder under `Movies/TakeTray/` and the file name it was given.
///
/// Its `toString` names neither the folder nor the file (D-10). The other
/// value types below follow the same rule.
@immutable
class CopyFileRef {
  const CopyFileRef({
    required this.mediaStoreId,
    required this.folderName,
    required this.fileName,
  });

  final int mediaStoreId;
  final String folderName;
  final String fileName;

  @override
  bool operator ==(Object other) =>
      other is CopyFileRef &&
      other.mediaStoreId == mediaStoreId &&
      other.folderName == folderName &&
      other.fileName == fileName;

  @override
  int get hashCode => Object.hash(mediaStoreId, folderName, fileName);

  @override
  String toString() => 'CopyFileRef($mediaStoreId)';
}

/// Whether an app is installed, with its icon as PNG bytes when it is.
@immutable
class InstalledApp {
  const InstalledApp({
    required this.packageName,
    required this.installed,
    this.iconPng,
  });

  final String packageName;
  final bool installed;
  final Uint8List? iconPng;

  @override
  bool operator ==(Object other) =>
      other is InstalledApp &&
      other.packageName == packageName &&
      other.installed == installed &&
      listEquals(other.iconPng, iconPng);

  @override
  int get hashCode => Object.hash(
    packageName,
    installed,
    iconPng == null ? null : Object.hashAll(iconPng!),
  );

  @override
  String toString() => 'InstalledApp(installed: $installed)';
}

/// How a direct share went.
enum SendResult { sent, notInstalled, failed }

/// What `deleteCopies` did with each id.
@immutable
class DeleteReport {
  const DeleteReport({
    this.deleted = const {},
    this.gone = const {},
    this.refused = const {},
    this.failed = const {},
  });

  final Set<int> deleted;
  final Set<int> gone;
  final Set<int> refused;
  final Set<int> failed;

  @override
  bool operator ==(Object other) =>
      other is DeleteReport &&
      setEquals(other.deleted, deleted) &&
      setEquals(other.gone, gone) &&
      setEquals(other.refused, refused) &&
      setEquals(other.failed, failed);

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(deleted),
    Object.hashAllUnordered(gone),
    Object.hashAllUnordered(refused),
    Object.hashAllUnordered(failed),
  );

  @override
  String toString() =>
      'DeleteReport(deleted: ${deleted.length}, gone: ${gone.length}, '
      'refused: ${refused.length}, failed: ${failed.length})';
}

/// One file directly in a copy folder.
@immutable
class CopyFolderFile {
  const CopyFolderFile({
    required this.mediaStoreId,
    required this.folderName,
    required this.fileName,
    required this.sizeBytes,
    required this.ownedByTakeTray,
  });

  final int mediaStoreId;
  final String folderName;
  final String fileName;
  final int sizeBytes;
  final bool ownedByTakeTray;

  @override
  bool operator ==(Object other) =>
      other is CopyFolderFile &&
      other.mediaStoreId == mediaStoreId &&
      other.folderName == folderName &&
      other.fileName == fileName &&
      other.sizeBytes == sizeBytes &&
      other.ownedByTakeTray == ownedByTakeTray;

  @override
  int get hashCode => Object.hash(
    mediaStoreId,
    folderName,
    fileName,
    sizeBytes,
    ownedByTakeTray,
  );

  @override
  String toString() =>
      'CopyFolderFile($mediaStoreId, $sizeBytes bytes, '
      'ownedByTakeTray: $ownedByTakeTray)';
}

/// What the app asks Android about video editors and TakeTray's copy
/// folders, in domain types (D-121).
///
/// - [apps]: each package, in order, installed or not, with its icon drawn to
///   an `iconPx` square PNG (1 to 512). An unknown package is not installed.
/// - [sendTo]: one share of the clips, **in the order given**, to that editor
///   alone, with a read grant for each; clips with no address are left out.
///   [shareWithChooser] does the same through Android's chooser.
/// - [openApp] opens an editor; [openStoreListing] opens its
///   `market://details` page (never a web address). False when nothing opens.
/// - [freeBytes]: free space on the phone's own storage, where copies go.
/// - The copy folders, `Movies/TakeTray/<folder>/`: [copyFolderNames] (every
///   folder name there, any owner), [existingCopies] (the refs whose file is
///   still TakeTray's: folder, name and owner all match; a failed read
///   **throws**, it never means "gone"), [deleteCopies] (deletes only what
///   passes that same guard; everything else is refused and left untouched),
///   [filesInCopyFolders] (every finished file one level below the root) and
///   [requestDelete] (Android's consent dialog for files in their folder with
///   their name, whoever owns them; true when the user allowed it).
///
/// A failure on the Kotlin side arrives as a `PlatformException`, unchanged:
/// `busy` and `host-gone` from [requestDelete], `no-activity`, or
/// `native-error` with the exception's class only. Never log a package,
/// folder or file name from these answers (D-10). Tests use
/// `FakeEditorsBridge`.
abstract interface class EditorsBridge {
  Future<List<InstalledApp>> apps(
    List<String> packageNames, {
    required int iconPx,
  });

  Future<SendResult> sendTo(String packageName, List<ClipRef> clipsInOrder);

  Future<bool> shareWithChooser(
    List<ClipRef> clipsInOrder,
    String chooserTitle,
  );

  Future<bool> openApp(String packageName);

  Future<bool> openStoreListing(String packageName);

  /// Free bytes on the primary external volume.
  Future<int> freeBytes();

  /// The folder names under `Movies/TakeTray/`.
  Future<List<String>> copyFolderNames();

  /// Throws on failure, never "gone".
  Future<Set<int>> existingCopies(List<CopyFileRef> refs);

  Future<DeleteReport> deleteCopies(List<CopyFileRef> refs);

  Future<List<CopyFolderFile>> filesInCopyFolders();

  /// System consent; true when allowed and done.
  Future<bool> requestDelete(List<CopyFileRef> refs);
}

/// The [EditorsBridge] that talks to Kotlin through the Pigeon-generated
/// [EditorsHostApi]. It only converts between message and domain types.
class PigeonEditorsBridge implements EditorsBridge {
  /// [api] defaults to a real [EditorsHostApi]; tests pass a stub.
  new([EditorsHostApi? api]) : _api = api ?? EditorsHostApi();

  final EditorsHostApi _api;

  @override
  Future<List<InstalledApp>> apps(
    List<String> packageNames, {
    required int iconPx,
  }) async => [
    for (final a in await _api.apps(packageNames, iconPx))
      InstalledApp(
        packageName: a.packageName,
        installed: a.installed,
        iconPng: a.iconPng,
      ),
  ];

  @override
  Future<SendResult> sendTo(
    String packageName,
    List<ClipRef> clipsInOrder,
  ) async => switch (await _api.sendTo(packageName, _clips(clipsInOrder))) {
    SendResultMsg.sent => SendResult.sent,
    SendResultMsg.notInstalled => SendResult.notInstalled,
    SendResultMsg.failed => SendResult.failed,
  };

  @override
  Future<bool> shareWithChooser(
    List<ClipRef> clipsInOrder,
    String chooserTitle,
  ) => _api.shareWithChooser(_clips(clipsInOrder), chooserTitle);

  @override
  Future<bool> openApp(String packageName) => _api.openApp(packageName);

  @override
  Future<bool> openStoreListing(String packageName) =>
      _api.openStoreListing(packageName);

  @override
  Future<int> freeBytes() => _api.freeBytes();

  @override
  Future<List<String>> copyFolderNames() => _api.copyFolderNames();

  @override
  Future<Set<int>> existingCopies(List<CopyFileRef> refs) async =>
      (await _api.existingCopies(_refs(refs))).toSet();

  @override
  Future<DeleteReport> deleteCopies(List<CopyFileRef> refs) async {
    final r = await _api.deleteCopies(_refs(refs));
    return DeleteReport(
      deleted: r.deleted.toSet(),
      gone: r.gone.toSet(),
      refused: r.refused.toSet(),
      failed: r.failed.toSet(),
    );
  }

  @override
  Future<List<CopyFolderFile>> filesInCopyFolders() async => [
    for (final f in await _api.filesInCopyFolders())
      CopyFolderFile(
        mediaStoreId: f.mediaStoreId,
        folderName: f.folderName,
        fileName: f.fileName,
        sizeBytes: f.sizeBytes,
        ownedByTakeTray: f.ownedByTakeTray,
      ),
  ];

  @override
  Future<bool> requestDelete(List<CopyFileRef> refs) =>
      _api.requestDelete(_refs(refs));
}

List<ShareClipMsg> _clips(List<ClipRef> clips) => [
  for (final c in clips)
    ShareClipMsg(
      volumeName: c.volumeName,
      mediaStoreId: c.mediaStoreId,
      pickerUri: c.pickerUri,
    ),
];

List<CopyFileRefMsg> _refs(List<CopyFileRef> refs) => [
  for (final r in refs)
    CopyFileRefMsg(
      mediaStoreId: r.mediaStoreId,
      folderName: r.folderName,
      fileName: r.fileName,
    ),
];

/// The app's [EditorsBridge]; tests override it with `FakeEditorsBridge`.
@Riverpod(keepAlive: true)
EditorsBridge editorsBridge(Ref ref) => PigeonEditorsBridge();
