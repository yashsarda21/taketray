import 'dart:async';

import 'package:taketray/platform/links_bridge.dart';

/// A [LinksBridge] with no phone, for tests.
///
/// - [answer] is what `openLink` answers (true: an app opened it; false: no
///   app on the phone can, or Android refused).
/// - [opened] records every link it was asked to open, in order, including
///   one that fails or waits.
/// - [failWith], when set, is thrown by the next calls instead of answering.
/// - [hold] makes the calls wait, after they are recorded, until [release]:
///   a test can tap again while the first open is still running.
class FakeLinksBridge implements LinksBridge {
  bool answer = true;
  Error? failWith;

  final List<String> opened = [];

  Completer<void>? _hold;

  /// Makes the calls wait until [release].
  void hold() => _hold = Completer<void>();

  /// Ends the hold; the calls that wait go on.
  void release() {
    _hold?.complete();
    _hold = null;
  }

  @override
  Future<bool> openLink(String url) async {
    opened.add(url);
    await _hold?.future;
    final error = failWith;
    if (error != null) throw error;
    return answer;
  }
}
