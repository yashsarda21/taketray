import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/core/guarded.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/domain/models/reel.dart';
import 'package:taketray/domain/rules/text_limits.dart';

part 'reel_form_controller.g.dart';

// Error types only, never a reel name or a description (D-10).
final Logger _log = Logger('reelForm');

/// What the create / edit sheet shows besides the text itself (D-85).
@immutable
class ReelFormState {
  const new({
    this.nameError,
    this.descriptionError,
    this.clashingName,
    this.saving = false,
  });

  /// Why the name was not accepted by the last [ReelFormController.save], or
  /// null. The view turns it into words.
  final ReelNameProblem? nameError;

  /// Why the description was not accepted, or null.
  final ReelDescriptionProblem? descriptionError;

  /// With [ReelNameProblem.duplicate]: the other reel's name, as stored (the
  /// copy says "You already have a reel called {name}" with it, not with the
  /// typed text, so a different case is shown as it is saved).
  final String? clashingName;

  /// A save is running; the sheet disables its buttons.
  final bool saving;

  bool get hasErrors => nameError != null || descriptionError != null;
}

/// The create (null `reelId`) or edit sheet of one reel (D-85).
///
/// [save] checks the name and the description, both at once, then writes. The
/// name is checked against the reels as they are now (a reel made a moment
/// ago counts), and the repository's own `duplicate` is the backstop if
/// another reel took the name between that check and the write. A problem is
/// not thrown: [save] returns null and the state holds `nameError` /
/// `descriptionError`, for the view to show. Anything else that goes wrong (a
/// database error, the reel being gone) is logged by type and rethrown, for
/// the view to tell the user.
///
/// Saving is single-flight: a second call while one runs returns the first
/// call's future (a double tap on Save makes one reel).
///
/// Auto-disposes with the sheet; a save that outlives it still finishes, and
/// only the state is left alone.
@Riverpod(retry: noRetry)
class ReelFormController extends _$ReelFormController {
  Future<Reel?>? _inFlight;

  @override
  ReelFormState build(int? reelId) => const ReelFormState();

  /// Forgets the errors (the user is typing again).
  void clearErrors() {
    if (state.hasErrors) state = ReelFormState(saving: state.saving);
  }

  /// Creates the reel, or, when this form edits one, saves [name],
  /// [description] and [status] (null keeps it) in one go. Returns the saved
  /// reel, or null when [name] or [description] was not acceptable (see the
  /// class comment). Only what changed is written.
  Future<Reel?> save({
    required String name,
    String? description,
    ReelStatus? status,
  }) {
    final running = _inFlight;
    if (running != null) return running;
    final run = _save(name, description, status);
    _inFlight = run;
    // Clear the slot whichever way it ends, without making a second,
    // unhandled copy of the error.
    unawaited(
      run.then<void>((_) {}, onError: (_) {}).then<void>((_) {
        if (identical(_inFlight, run)) _inFlight = null;
      }),
    );
    return run;
  }

  Future<Reel?> _save(
    String name,
    String? description,
    ReelStatus? status,
  ) async {
    final repository = ref.read(reelsRepositoryProvider);
    final id = reelId;
    _set(const ReelFormState(saving: true));
    try {
      final reels = await repository.watchAll().first;
      final clash = _clashWith(reels, name, except: id);
      final nameProblem =
          checkReelName(name) ??
          (clash == null ? null : ReelNameProblem.duplicate);
      final descriptionProblem = checkReelDescription(description);
      if (nameProblem != null || descriptionProblem != null) {
        _set(
          ReelFormState(
            nameError: nameProblem,
            descriptionError: descriptionProblem,
            clashingName: clash?.name,
          ),
        );
        return null;
      }
      final Reel saved;
      if (id == null) {
        saved = await repository.create(name, description: description);
      } else {
        saved = await _edit(repository, id, name, description, status);
      }
      _set(const ReelFormState());
      return saved;
    } on InvalidInputException catch (problem) {
      // Another reel took the name (or the repository's rules are stricter
      // than the form's): show it as the form would have.
      final reels = await repository.watchAll().first;
      _set(
        ReelFormState(
          nameError: problem.problem is ReelNameProblem
              ? problem.problem as ReelNameProblem
              : null,
          descriptionError: problem.problem is ReelDescriptionProblem
              ? problem.problem as ReelDescriptionProblem
              : null,
          clashingName: _clashWith(reels, name, except: id)?.name,
        ),
      );
      return null;
    } on Object catch (error) {
      _log.warning('Saving a reel failed: ${error.runtimeType}');
      _set(const ReelFormState());
      rethrow;
    }
  }

  Future<Reel> _edit(
    ReelsRepository repository,
    int id,
    String name,
    String? description,
    ReelStatus? status,
  ) async {
    final current = await repository.getById(id);
    if (current == null) throw StateError('No reel with id $id');
    // The name goes first: it is the write that can still be refused.
    if (normalizeName(name) != current.name) await repository.rename(id, name);
    final cleaned = description == null ? '' : normalizeName(description);
    final newDescription = cleaned.isEmpty ? null : cleaned;
    if (newDescription != current.description) {
      await repository.setDescription(id, newDescription);
    }
    if (status != null && status != current.status) {
      await repository.setStatus(id, status);
    }
    return (await repository.getById(id))!;
  }

  Reel? _clashWith(List<Reel> reels, String name, {required int? except}) {
    final key = reelNameKey(name);
    for (final reel in reels) {
      if (reel.id != except && reelNameKey(reel.name) == key) return reel;
    }
    return null;
  }

  /// Sets the state unless the sheet has gone and taken the provider along.
  void _set(ReelFormState next) {
    if (ref.mounted) state = next;
  }
}
