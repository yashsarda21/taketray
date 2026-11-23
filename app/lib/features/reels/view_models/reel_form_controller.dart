import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/core/guarded.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/data/repositories/references_repository.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/domain/models/reel.dart';
import 'package:taketray/domain/rules/reference_links.dart';
import 'package:taketray/domain/rules/reference_url.dart';
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
    this.linkError,
    this.clashingName,
    this.saving = false,
  });

  /// Why the name was not accepted by the last [ReelFormController.save], or
  /// null. The view turns it into words.
  final ReelNameProblem? nameError;

  /// Why the description was not accepted, or null.
  final ReelDescriptionProblem? descriptionError;

  /// Why the Reference link was not accepted, or null (D-159).
  final ReferenceUrlProblem? linkError;

  /// With [ReelNameProblem.duplicate]: the other reel's name, as stored (the
  /// copy says "You already have a reel called {name}" with it, not with the
  /// typed text, so a different case is shown as it is saved).
  final String? clashingName;

  /// A save is running; the sheet disables its buttons.
  final bool saving;

  bool get hasErrors =>
      nameError != null || descriptionError != null || linkError != null;
}

/// The create (null `reelId`) or edit sheet of one reel (D-85).
///
/// [save] checks the name, the description and the Reference link, all at
/// once, then writes. The name is checked against the reels as they are now
/// (a reel made a moment ago counts; when editing, the reel's own name in any
/// case is always fine, as in `ReelsRepository.rename`), and the
/// repository's own `duplicate` is the backstop if another reel took the name
/// between that check and the write. A problem is not thrown: [save] returns
/// null and the state holds `nameError` / `descriptionError` / `linkError`,
/// for the view to show.
/// Anything else that goes wrong (a database error, the reel being gone) is
/// logged by type and rethrown, for the view to tell the user.
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
  /// reel, or null when [name], [description] or [link] was not acceptable
  /// (see the class comment). Only what changed is written.
  ///
  /// [link] is the optional Reference link as typed or pasted (D-159): empty
  /// or blank means none; otherwise it must hold a link (`typedLink`: a
  /// caption with a link in it, or a bare address), or it is
  /// `ReferenceUrlProblem.invalid` and nothing is saved, not even the name.
  /// A new reel is made with its reference in one go (one transaction); an
  /// edit saves the reel's own fields, then adds the reference, and a link
  /// the reel already has is fine, not an error. If that add fails with a
  /// database error the reel's changes stay saved and the error is rethrown.
  /// Not for [createWith] (the tag player's form has no link field).
  ///
  /// [createWith] (a new reel only) makes the reel itself, in place of the
  /// repository's `create`, after the same checks: the tag player's New reel
  /// (D-97) makes it and puts the clip in it in one go, and returns the reel
  /// it made (null only when the player has closed, and with it the sheet).
  /// A name problem it throws (`InvalidInputException`) is shown like one
  /// found here.
  Future<Reel?> save({
    required String name,
    String? description,
    ReelStatus? status,
    String? link,
    Future<Reel?> Function(String name)? createWith,
  }) {
    assert(
      link == null || createWith == null,
      'the form for a clip has no link field',
    );
    final running = _inFlight;
    if (running != null) return running;
    final run = _save(name, description, status, link, createWith);
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
    String? link,
    Future<Reel?> Function(String name)? createWith,
  ) async {
    // Both read now: a save that outlives the sheet cannot read later.
    final repository = ref.read(reelsRepositoryProvider);
    final references = ref.read(referencesRepositoryProvider);
    final id = reelId;
    _set(const ReelFormState(saving: true));
    try {
      final reels = await repository.watchAll().first;
      final clash = _clashWith(reels, name, editing: id);
      final nameProblem =
          checkReelName(name) ??
          (clash == null ? null : ReelNameProblem.duplicate);
      final descriptionProblem = checkReelDescription(description);
      // Blank is no link; anything else must hold one. Found with the name
      // and description problems, so one Save shows them all.
      final hasLink = link != null && link.trim().isNotEmpty;
      final typed = hasLink ? typedLink(link) : null;
      final linkProblem = hasLink && typed == null
          ? ReferenceUrlProblem.invalid
          : null;
      if (nameProblem != null ||
          descriptionProblem != null ||
          linkProblem != null) {
        _set(
          ReelFormState(
            nameError: nameProblem,
            descriptionError: descriptionProblem,
            linkError: linkProblem,
            clashingName: clash?.name,
          ),
        );
        return null;
      }
      final Reel saved;
      if (id == null && createWith != null) {
        final made = await createWith(name);
        if (made == null) {
          _set(const ReelFormState());
          return null;
        }
        saved = made;
      } else if (id == null && typed != null) {
        saved = await repository.createWithReference(
          name,
          url: typed,
          description: description,
        );
      } else if (id == null) {
        saved = await repository.create(name, description: description);
      } else {
        saved = await _edit(
          repository,
          references,
          id,
          name,
          description,
          status,
          typed,
        );
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
          linkError: problem.problem is ReferenceUrlProblem
              ? problem.problem as ReferenceUrlProblem
              : null,
          clashingName: _clashWith(reels, name, editing: id)?.name,
        ),
      );
      return null;
    } on Object catch (error) {
      _log.warning('Saving a reel failed: ${error.runtimeType}');
      _set(const ReelFormState());
      rethrow;
    } finally {
      // Whatever way this ends, `saving` does not stay on: the handler for a
      // refused name reads the reels again, and that read can fail too.
      if (ref.mounted && state.saving) state = const ReelFormState();
    }
  }

  Future<Reel> _edit(
    ReelsRepository repository,
    ReferencesRepository references,
    int id,
    String name,
    String? description,
    ReelStatus? status,
    String? link,
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
    // The reel is saved; a failure here leaves it so (D-159). A link the
    // reel already has is no error: the result is not looked at.
    if (link != null) {
      await references.add(id, link);
    }
    return (await repository.getById(id))!;
  }

  /// The other reel that already has [name], or null. When this form edits
  /// reel [editing], its own name in any case is never a clash, even while
  /// another reel has it too (an Undo of a delete or a backup import can
  /// bring two): the same rule as `ReelsRepository.rename` (D-84 point 1),
  /// or neither reel could be saved without a rename.
  Reel? _clashWith(List<Reel> reels, String name, {required int? editing}) {
    final key = reelNameKey(name);
    if (editing != null &&
        reels.any((r) => r.id == editing && reelNameKey(r.name) == key)) {
      return null;
    }
    for (final reel in reels) {
      if (reel.id != editing && reelNameKey(reel.name) == key) return reel;
    }
    return null;
  }

  /// Sets the state unless the sheet has gone and taken the provider along.
  void _set(ReelFormState next) {
    if (ref.mounted) state = next;
  }
}
