import 'package:flutter/services.dart';
import 'package:taketray/domain/models/clip_ref.dart';
import 'package:taketray/platform/editors_bridge.dart';

/// An [EditorsBridge] with no phone, for tests.
///
/// - Settable answers: [installed] (package name to installed; a package not
///   in it is not installed) with [icons], [sendResult], [chooserResult],
///   [openAppResult], [storeResult], [bytesFree] (what `freeBytes` answers),
///   [folderNames], [existing], [deleteReport], [files] and
///   [requestDeleteResult].
/// - `existingCopies` answers the asked ids that are in [existing].
///   `deleteCopies` answers [deleteReport] when it is set; otherwise it
///   deletes the asked ids that are in [existing] (they leave it) and reports
///   the rest as gone.
/// - Recorded: [calls] (every call's name, in order, including one that
///   fails), [sent] (package and clips of each `sendTo`), [chooserShares],
///   [openedApps], [openedListings], [deleteAsked] and [deleteRequested].
/// - [failNext] makes the next call of a method throw a `PlatformException`.
class FakeEditorsBridge implements EditorsBridge {
  Map<String, bool> installed = {};
  Map<String, Uint8List> icons = {};
  SendResult sendResult = SendResult.sent;
  bool chooserResult = true;
  bool openAppResult = true;
  bool storeResult = true;
  int bytesFree = 64 * 1000 * 1000 * 1000;
  List<String> folderNames = [];
  Set<int> existing = {};
  DeleteReport? deleteReport;
  List<CopyFolderFile> files = [];
  bool requestDeleteResult = true;

  final List<String> calls = [];
  final List<(String, List<ClipRef>)> sent = [];
  final List<(List<ClipRef>, String)> chooserShares = [];
  final List<String> openedApps = [];
  final List<String> openedListings = [];
  final List<List<CopyFileRef>> deleteAsked = [];
  final List<List<CopyFileRef>> deleteRequested = [];

  final Map<String, int> _failures = {};

  /// The next call of [method] throws a `PlatformException`. Calling it twice
  /// fails two calls.
  void failNext(String method) =>
      _failures[method] = (_failures[method] ?? 0) + 1;

  void _call(String method) {
    calls.add(method);
    final left = _failures[method] ?? 0;
    if (left > 0) {
      _failures[method] = left - 1;
      throw PlatformException(code: 'native-error', message: '$method failed');
    }
  }

  @override
  Future<List<InstalledApp>> apps(
    List<String> packageNames, {
    required int iconPx,
  }) async {
    _call('apps');
    return [
      for (final name in packageNames)
        InstalledApp(
          packageName: name,
          installed: installed[name] ?? false,
          iconPng: (installed[name] ?? false) ? icons[name] : null,
        ),
    ];
  }

  @override
  Future<SendResult> sendTo(
    String packageName,
    List<ClipRef> clipsInOrder,
  ) async {
    _call('sendTo');
    sent.add((packageName, List.of(clipsInOrder)));
    return sendResult;
  }

  @override
  Future<bool> shareWithChooser(
    List<ClipRef> clipsInOrder,
    String chooserTitle,
  ) async {
    _call('shareWithChooser');
    chooserShares.add((List.of(clipsInOrder), chooserTitle));
    return chooserResult;
  }

  @override
  Future<bool> openApp(String packageName) async {
    _call('openApp');
    openedApps.add(packageName);
    return openAppResult;
  }

  @override
  Future<bool> openStoreListing(String packageName) async {
    _call('openStoreListing');
    openedListings.add(packageName);
    return storeResult;
  }

  @override
  Future<int> freeBytes() async {
    _call('freeBytes');
    return bytesFree;
  }

  @override
  Future<List<String>> copyFolderNames() async {
    _call('copyFolderNames');
    return List.of(folderNames);
  }

  @override
  Future<Set<int>> existingCopies(List<CopyFileRef> refs) async {
    _call('existingCopies');
    return {
      for (final r in refs)
        if (existing.contains(r.mediaStoreId)) r.mediaStoreId,
    };
  }

  @override
  Future<DeleteReport> deleteCopies(List<CopyFileRef> refs) async {
    _call('deleteCopies');
    deleteAsked.add(List.of(refs));
    final fixed = deleteReport;
    if (fixed != null) return fixed;
    final ids = {for (final r in refs) r.mediaStoreId};
    final deleted = ids.intersection(existing);
    existing = existing.difference(deleted);
    return DeleteReport(deleted: deleted, gone: ids.difference(deleted));
  }

  @override
  Future<List<CopyFolderFile>> filesInCopyFolders() async {
    _call('filesInCopyFolders');
    return List.of(files);
  }

  @override
  Future<bool> requestDelete(List<CopyFileRef> refs) async {
    _call('requestDelete');
    deleteRequested.add(List.of(refs));
    return requestDeleteResult;
  }
}
