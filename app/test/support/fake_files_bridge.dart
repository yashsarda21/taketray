import 'dart:async';

import 'package:taketray/platform/files_bridge.dart';

/// One call to a [FakeFilesBridge]: the method's name and its arguments, in
/// the order the method takes them.
typedef FilesCall = ({String method, List<Object?> args});

/// A [FilesBridge] with no phone, for tests.
///
/// - Settable answers: [saveAnswer] (the saved document's address; null is a
///   cancel), [openAnswer] (the opened text; null, the default, is a cancel),
///   [folderAnswer] (the chosen folder's path; null, the default, is a cancel)
///   and [appInfoAnswer]. `shareFile` answers nothing.
/// - Recorded: [calls] (every call's name and arguments, in order, including
///   one that fails or waits), [methods] (just the names) and [saved] (the
///   name and text of each save that answered an address).
/// - [failNext] makes the next call of a method throw a [FileBridgeException]
///   with the given problem; calling it twice fails two calls.
/// - [hold] makes the calls of a method wait, after they are recorded, until
///   [release]: a test can tap again while the first call is still running.
///   A held call that is set to fail fails once released.
class FakeFilesBridge implements FilesBridge {
  String? saveAnswer = 'content://fake.documents/document/1';
  String? openAnswer;
  String? folderAnswer;
  AppInfo appInfoAnswer = const AppInfo(
    versionName: '1.0.0',
    androidRelease: '15',
  );

  final List<FilesCall> calls = [];
  final List<({String name, String text})> saved = [];

  final Map<String, List<FilesProblem>> _failures = {};
  final Map<String, Completer<void>> _holds = {};

  /// The names of [calls], in order.
  List<String> get methods => [for (final c in calls) c.method];

  /// The next call of [method] throws `FileBridgeException(problem)`.
  void failNext(String method, [FilesProblem problem = FilesProblem.failed]) =>
      (_failures[method] ??= []).add(problem);

  /// Makes the calls of [method] wait until [release] is called for it.
  void hold(String method) => _holds[method] = Completer<void>();

  /// Ends the hold on [method]; the calls that wait go on.
  void release(String method) => _holds.remove(method)?.complete();

  Future<void> _call(String method, [List<Object?> args = const []]) async {
    calls.add((method: method, args: args));
    await _holds[method]?.future;
    final queued = _failures[method];
    if (queued != null && queued.isNotEmpty) {
      throw FileBridgeException(queued.removeAt(0));
    }
  }

  @override
  Future<void> shareFile(
    String path,
    String mimeType,
    String subject,
    String text,
  ) => _call('shareFile', [path, mimeType, subject, text]);

  @override
  Future<String?> saveDocument(
    String suggestedName,
    String mimeType,
    String text,
  ) async {
    await _call('saveDocument', [suggestedName, mimeType, text]);
    final answer = saveAnswer;
    if (answer != null) saved.add((name: suggestedName, text: text));
    return answer;
  }

  @override
  Future<String?> openDocument(List<String> mimeTypes, int maxBytes) async {
    await _call('openDocument', [mimeTypes, maxBytes]);
    return openAnswer;
  }

  @override
  Future<String?> pickFolder() async {
    await _call('pickFolder');
    return folderAnswer;
  }

  @override
  Future<AppInfo> appInfo() async {
    await _call('appInfo');
    return appInfoAnswer;
  }
}
