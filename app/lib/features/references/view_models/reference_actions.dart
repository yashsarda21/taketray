import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/data/repositories/references_repository.dart';
import 'package:taketray/domain/models/reel_reference.dart';
import 'package:taketray/domain/models/undo_record.dart';
import 'package:taketray/platform/links_bridge.dart';

part 'reference_actions.g.dart';

// Ids and error types only: never a link, a label or a reel name (D-10).
final Logger _log = Logger('referenceActions');

/// The references of reel [reelId], newest first (ties: the highest id
/// first), again after every change (`ReferencesRepository.watchForReel`).
@riverpod
Stream<List<ReelReference>> reelReferences(Ref ref, int reelId) =>
    ref.watch(referencesRepositoryProvider).watchForReel(reelId);

/// What a reference card does (D-158): open its link, copy it, remove it.
///
/// Kept alive, so a remove started on a page that then goes away still
/// finishes and can be undone.
class ReferenceActions {
  ReferenceActions(this._references, this._links);

  final ReferencesRepository _references;
  final LinksBridge _links;

  /// Opens [reference]'s stored link in the app or browser the phone picks.
  /// False when nothing on the phone could open it, or the bridge failed
  /// (its error type is logged); the card then says so.
  Future<bool> open(ReelReference reference) async {
    try {
      final opened = await _links.openLink(reference.url);
      if (!opened) _log.info('No app opened reference ${reference.id}');
      return opened;
    } on Object catch (error) {
      _log.warning(
        'Opening reference ${reference.id} failed: ${error.runtimeType}',
      );
      return false;
    }
  }

  /// Puts [reference]'s stored link (not its label) on the clipboard. Throws
  /// when the clipboard refused, after logging the error's type.
  Future<void> copy(ReelReference reference) async {
    try {
      await Clipboard.setData(ClipboardData(text: reference.url));
    } on Object catch (error) {
      _log.warning(
        'Copying reference ${reference.id} failed: ${error.runtimeType}',
      );
      rethrow;
    }
  }

  /// Removes reference [id] at once and returns what Undo needs to put it
  /// back (`ReelsRepository.undoAll`), or null when there was no such
  /// reference. Throws when it could not, after logging the error's type.
  Future<ReferenceRemoveUndo?> remove(int id) async {
    try {
      return await _references.delete(id);
    } on Object catch (error) {
      _log.warning('Removing reference $id failed: ${error.runtimeType}');
      rethrow;
    }
  }
}

@Riverpod(keepAlive: true)
ReferenceActions referenceActions(Ref ref) => ReferenceActions(
  ref.watch(referencesRepositoryProvider),
  ref.watch(linksBridgeProvider),
);
