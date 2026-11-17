import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taketray/features/settings/view_models/watched_folders_controller.dart';

/// A [WatchedFoldersController] that starts at [initial] (null: the first
/// read never answers), records its calls in [calls] as
/// `setWatched(DCIM/Camera, false)` and `addFolder`, applies each toggle to
/// the rows as the real one does once the database has answered, and answers
/// `addFolder` with [addResult] (after [addGate], when a test sets one).
class FakeWatchedFolders extends WatchedFoldersController {
  FakeWatchedFolders(
    this.initial, {
    this.addResult = AddFolderResult.cancelled,
  });

  final WatchedFoldersView? initial;
  final List<String> calls = [];

  /// What the next `addFolder` answers.
  AddFolderResult addResult;

  /// When set, `addFolder` waits for it.
  Completer<void>? addGate;

  late WatchedFoldersView _now;

  @override
  Future<WatchedFoldersView> build() {
    final first = initial;
    if (first == null) return Completer<WatchedFoldersView>().future;
    _now = first;
    return Future.value(first);
  }

  /// Shows [view].
  void show(WatchedFoldersView view) {
    _now = view;
    state = AsyncData(view);
  }

  @override
  Future<void> setWatched(String relativePath, bool watched) async {
    calls.add('setWatched($relativePath, $watched)');
    show(
      WatchedFoldersView(
        fullAccess: _now.fullAccess,
        rows: [
          for (final r in _now.rows)
            if (r.relativePath == relativePath)
              r.copyWith(watched: watched)
            else
              r,
        ],
      ),
    );
  }

  @override
  Future<AddFolderResult> addFolder() async {
    calls.add('addFolder');
    await addGate?.future;
    return addResult;
  }
}
