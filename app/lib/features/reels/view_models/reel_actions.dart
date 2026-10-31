import 'dart:async';

import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/domain/models/undo_record.dart';

part 'reel_actions.g.dart';

// Ids and error types only, never a reel name (D-10).
final Logger _log = Logger('reelActions');

/// What the reel screens do to one reel besides the form: change its status
/// and delete it (D-85).
///
/// Kept alive, so a delete that was started on a screen that then goes away
/// still finishes and can be undone.
class ReelActions {
  ReelActions(this._reels);

  final ReelsRepository _reels;

  /// The deletes that are running, by reel id.
  final Map<int, Future<DeleteReelUndo>> _deleting = {};

  /// Sets the status of reel [id]. Throws when it could not (after logging
  /// the error's type); the status menu tells the user.
  Future<void> setStatus(int id, ReelStatus status) async {
    try {
      await _reels.setStatus(id, status);
    } on Object catch (error) {
      _log.warning(
        'Setting the status of reel $id failed: '
        '${error.runtimeType}',
      );
      rethrow;
    }
  }

  /// Deletes reel [id] and returns what Undo needs.
  ///
  /// Single-flight per reel: a second call while the first runs (a double tap
  /// on Delete reel) returns the first call's future, so the reel is deleted
  /// once and there is one record to undo. Throws when it could not, after
  /// logging the error's type.
  Future<DeleteReelUndo> confirmDelete(int id) {
    final running = _deleting[id];
    if (running != null) return running;
    final run = _delete(id);
    _deleting[id] = run;
    unawaited(
      run.then<void>((_) {}, onError: (_) {}).then<void>((_) {
        _deleting.removeWhere((_, running) => identical(running, run));
      }),
    );
    return run;
  }

  Future<DeleteReelUndo> _delete(int id) async {
    try {
      return await _reels.delete(id);
    } on Object catch (error) {
      _log.warning('Deleting reel $id failed: ${error.runtimeType}');
      rethrow;
    }
  }
}

@Riverpod(keepAlive: true)
ReelActions reelActions(Ref ref) =>
    ReelActions(ref.watch(reelsRepositoryProvider));
