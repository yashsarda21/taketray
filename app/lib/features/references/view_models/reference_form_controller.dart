import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/core/guarded.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/data/repositories/references_repository.dart';
import 'package:taketray/domain/models/reel_reference.dart';
import 'package:taketray/domain/rules/reference_links.dart';
import 'package:taketray/domain/rules/text_limits.dart';

part 'reference_form_controller.g.dart';

// Error types only, never a link, a label or a reel name (D-10).
final Logger _log = Logger('referenceForm');

/// What [ReferenceFormController.saveNew] did. Switch over it: the compiler
/// makes the sheet handle every outcome.
sealed class ReferenceSaveResult {
  const new();
}

/// The link is saved on the reel.
@immutable
final class ReferenceSaved extends ReferenceSaveResult {
  const new(this.reference);

  final ReelReference reference;
}

/// What was typed has no link in it (the sheet says how to copy one).
@immutable
final class ReferenceNotALink extends ReferenceSaveResult {
  const new();
}

/// The reel already has this page; nothing was saved. [reelName] is the
/// reel's name as stored.
@immutable
final class ReferenceAlreadyIn extends ReferenceSaveResult {
  const new(this.reelName);

  final String reelName;
}

/// The label is over 60 characters; nothing was saved. The label field stops
/// at 60, so only a bug in the sheet gets here.
@immutable
final class ReferenceLabelTooLong extends ReferenceSaveResult {
  const new();
}

/// Saving failed for a reason the user cannot fix (the reel is gone, the
/// database failed); nothing was saved and the error type is logged.
@immutable
final class ReferenceSaveFailed extends ReferenceSaveResult {
  const new();
}

/// The Add / edit reference sheet of reel [reelId] (D-157). The state is
/// whether a save is running, for the sheet to disable its buttons.
///
/// [saveNew] makes the link out of what the user typed or pasted
/// (`typedLink`: a caption with a link in it, or a bare address), checks the
/// label, then saves. [saveLabel] changes the label of a saved reference. A
/// problem the user can fix is a result, not a throw; anything else is logged
/// by type and told as a failure.
///
/// Saving is single-flight, as in `ReelFormController`: a second call while
/// one runs returns the first call's future (a double tap on Save makes one
/// reference).
///
/// Auto-disposes with the sheet; a save that outlives it still finishes, and
/// only the state is left alone.
@Riverpod(retry: noRetry)
class ReferenceFormController extends _$ReferenceFormController {
  Future<ReferenceSaveResult>? _newInFlight;
  Future<bool>? _labelInFlight;

  @override
  bool build(int reelId) => false;

  /// Saves the link in [linkText] with [label] on this reel, or says why not
  /// (see [ReferenceSaveResult]).
  Future<ReferenceSaveResult> saveNew(String linkText, String label) {
    final running = _newInFlight;
    if (running != null) return running;
    final run = _saveNew(linkText, label);
    _newInFlight = run;
    unawaited(
      run.then<void>((_) {}, onError: (_) {}).then<void>((_) {
        if (identical(_newInFlight, run)) _newInFlight = null;
      }),
    );
    return run;
  }

  Future<ReferenceSaveResult> _saveNew(String linkText, String label) async {
    // Both read now: a save that outlives the sheet cannot read later.
    final references = ref.read(referencesRepositoryProvider);
    final reels = ref.read(reelsRepositoryProvider);
    final id = reelId;
    final link = typedLink(linkText);
    if (link == null) return const ReferenceNotALink();
    if (checkReferenceLabel(label) != null) {
      return const ReferenceLabelTooLong();
    }
    _setSaving(true);
    try {
      final result = await references.add(id, link, label: label);
      switch (result) {
        case ReferenceAdded(:final reference):
          return ReferenceSaved(reference);
        case ReferenceAlreadySaved():
          final reel = await reels.getById(id);
          if (reel == null) return const ReferenceSaveFailed();
          return ReferenceAlreadyIn(reel.name);
      }
    } on InvalidInputException catch (problem) {
      // The form checked both already; the repository's rules say the same.
      return problem.problem is ReferenceLabelProblem
          ? const ReferenceLabelTooLong()
          : const ReferenceNotALink();
    } on Object catch (error) {
      _log.warning('Saving a reference failed: ${error.runtimeType}');
      return const ReferenceSaveFailed();
    } finally {
      _setSaving(false);
    }
  }

  /// Sets the label of reference [id] ([label] blank clears it). False when
  /// it could not be saved (the reference is gone, the label is over 60
  /// characters, the database failed); the error type is logged.
  Future<bool> saveLabel(int id, String label) {
    final running = _labelInFlight;
    if (running != null) return running;
    final run = _saveLabel(id, label);
    _labelInFlight = run;
    unawaited(
      run.then<void>((_) {}, onError: (_) {}).then<void>((_) {
        if (identical(_labelInFlight, run)) _labelInFlight = null;
      }),
    );
    return run;
  }

  Future<bool> _saveLabel(int id, String label) async {
    final references = ref.read(referencesRepositoryProvider);
    _setSaving(true);
    try {
      await references.setLabel(id, label);
      return true;
    } on Object catch (error) {
      _log.warning('Saving a label failed: ${error.runtimeType}');
      return false;
    } finally {
      _setSaving(false);
    }
  }

  /// Sets the state unless the sheet has gone and taken the provider along.
  void _setSaving(bool saving) {
    if (ref.mounted) state = saving;
  }
}
