import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/core/guarded.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/data/repositories/references_repository.dart';
import 'package:taketray/domain/models/reel.dart';
import 'package:taketray/domain/rules/reference_links.dart';
import 'package:taketray/domain/rules/reference_url.dart';
import 'package:taketray/domain/rules/shared_link_kind.dart';
import 'package:taketray/domain/rules/text_limits.dart';

part 'save_reference_controller.g.dart';

// Error types only, never a link, a label, a reel name or the shared text
// (D-10).
final Logger _log = Logger('saveReference');

/// Which part of the Save reference sheet is showing.
enum SaveStep {
  /// The form: label, where to save, Save.
  form,

  /// The shared text had no link in it: nothing can be saved.
  notALink,

  /// The reference is saved.
  saved,
}

/// Where the reference goes.
enum SaveMode {
  /// A reel the user already has, picked from the list.
  existing,

  /// A reel made for it, named in the form.
  newReel,
}

/// What the Save reference sheet shows (D-166).
@immutable
class SaveReferenceState {
  const new({
    this.step = SaveStep.form,
    this.text,
    this.url = '',
    this.kind = SharedLinkKind.link,
    this.mode = SaveMode.existing,
    this.pickedReelId,
    this.nameError,
    this.clashingName,
    this.alreadyIn,
    this.failed = false,
    this.saving = false,
    this.savedReelId,
    this.savedReelName,
    this.savedLabel,
  });

  /// The screen's state before anything is shared: an empty form.
  static const SaveReferenceState initial = SaveReferenceState();

  /// Which part is showing.
  final SaveStep step;

  /// The text that was shared, for the "not a link" quote; null when there
  /// was none. Only kept in that step.
  final String? text;

  /// The link, as `normalizeReferenceUrl` stores it; empty when the text had
  /// no link.
  final String url;

  /// What the link is, read from the link as it was shared.
  final SharedLinkKind kind;

  /// Where the form saves to.
  final SaveMode mode;

  /// The reel picked in [SaveMode.existing], or null.
  final int? pickedReelId;

  /// Why the new reel's name was not accepted, or null; the sheet turns it
  /// into words.
  final ReelNameProblem? nameError;

  /// With [ReelNameProblem.duplicate]: the other reel's name, as stored.
  final String? clashingName;

  /// The name of the picked reel when it already has this link, else null.
  /// The sheet says so and Save waits.
  final String? alreadyIn;

  /// The last Save failed for a reason the user cannot fix.
  final bool failed;

  /// A Save is running; the sheet disables its buttons.
  final bool saving;

  /// With [SaveStep.saved]: the reel the link is in.
  final int? savedReelId;

  /// With [SaveStep.saved]: that reel's name.
  final String? savedReelName;

  /// With [SaveStep.saved]: the label that was saved, or null for none.
  final String? savedLabel;

  /// A copy with the given fields replaced. The nullable fields are replaced
  /// by what is passed, so pass them all or use [copyWith] only for the ones
  /// that should change together (see the controller).
  SaveReferenceState copyWith({
    SaveStep? step,
    SaveMode? mode,
    Object? pickedReelId = _keep,
    Object? nameError = _keep,
    Object? clashingName = _keep,
    Object? alreadyIn = _keep,
    bool? failed,
    bool? saving,
    Object? savedReelId = _keep,
    Object? savedReelName = _keep,
    Object? savedLabel = _keep,
  }) => SaveReferenceState(
    step: step ?? this.step,
    text: text,
    url: url,
    kind: kind,
    mode: mode ?? this.mode,
    pickedReelId: identical(pickedReelId, _keep)
        ? this.pickedReelId
        : pickedReelId as int?,
    nameError: identical(nameError, _keep)
        ? this.nameError
        : nameError as ReelNameProblem?,
    clashingName: identical(clashingName, _keep)
        ? this.clashingName
        : clashingName as String?,
    alreadyIn: identical(alreadyIn, _keep)
        ? this.alreadyIn
        : alreadyIn as String?,
    failed: failed ?? this.failed,
    saving: saving ?? this.saving,
    savedReelId: identical(savedReelId, _keep)
        ? this.savedReelId
        : savedReelId as int?,
    savedReelName: identical(savedReelName, _keep)
        ? this.savedReelName
        : savedReelName as String?,
    savedLabel: identical(savedLabel, _keep)
        ? this.savedLabel
        : savedLabel as String?,
  );
}

const Object _keep = Object();

/// The Save reference sheet of the share screen (D-166): the shared text
/// becomes a link, a reel is picked or named, and one Save writes it.
///
/// [start] reads the shared text once per share. [pick] and [setMode] change
/// the form; [save] writes. **Nothing here changes an onboarding flag**: the
/// share engine only saves a reel and a reference (D-162).
///
/// Saving is single-flight, as in `ReelFormController`: a second call while
/// one runs returns the first call's future (a double tap on Save makes one
/// reel or one reference). Whatever goes wrong that the user cannot fix (a
/// busy database, the picked reel deleted meanwhile) ends in
/// [SaveReferenceState.failed], with the error type logged and nothing else.
///
/// Auto-disposes with the sheet; a save that outlives it still finishes, and
/// only the state is left alone.
@Riverpod(retry: noRetry)
class SaveReferenceController extends _$SaveReferenceController {
  Future<void>? _inFlight;

  /// Counts [start]s: a save or a read that was begun for an earlier share
  /// never touches the state of a later one.
  int _share = 0;

  /// Counts [pick]s, so a slow answer for a reel that is no longer picked is
  /// ignored.
  int _pickCount = 0;

  @override
  SaveReferenceState build() => SaveReferenceState.initial;

  /// Starts a share: turns [sharedText] into a link (the first one with a
  /// dotted host, as the Add sheet's Paste does) and shows the form, or shows
  /// the "not a link" state when there is none. A `null` or empty text (an
  /// empty `EXTRA_TEXT` arrives as `""`) is "not a link".
  ///
  /// A second share replaces everything of the first.
  Future<void> start(String? sharedText) async {
    final reels = ref.read(reelsRepositoryProvider);
    final share = ++_share;
    _pickCount++;
    // A save of the earlier share may still be running; it ends unseen.
    _inFlight = null;
    final link = sharedText == null ? null : pastedLink(sharedText);
    final url = link == null ? null : normalizeReferenceUrl(link);
    if (link == null || url == null) {
      _set(SaveReferenceState(step: SaveStep.notALink, text: sharedText));
      return;
    }
    _set(
      SaveReferenceState(
        // The kind comes from the link as it was shared: normalising turns
        // /reel/ into /p/.
        kind: sharedLinkKindOf(Uri.parse(link)),
        url: url.toString(),
      ),
    );
    // No reels yet: the form starts in New reel mode (and has no switch).
    final first = await guarded(
      _log,
      'Reading the reels',
      () => reels.watchAll().first,
    );
    // The sheet may have gone while the reels were read (the engine ends).
    if (first != null &&
        first.isEmpty &&
        ref.mounted &&
        share == _share &&
        state.step == SaveStep.form) {
      _set(state.copyWith(mode: SaveMode.newReel));
    }
  }

  /// Switches between a reel the user has and a new one. Forgets the name
  /// error and the failure.
  void setMode(SaveMode mode) {
    if (state.step != SaveStep.form) return;
    _set(
      state.copyWith(
        mode: mode,
        nameError: null,
        clashingName: null,
        failed: false,
      ),
    );
  }

  /// Picks reel [reelId] to save to. [SaveReferenceState.alreadyIn] is its
  /// name when the reel has this link already, else null. Forgets the
  /// failure.
  Future<void> pick(int reelId) async {
    if (state.step != SaveStep.form) return;
    final references = ref.read(referencesRepositoryProvider);
    final reels = ref.read(reelsRepositoryProvider);
    final url = state.url;
    final mine = ++_pickCount;
    _set(state.copyWith(pickedReelId: reelId, alreadyIn: null, failed: false));
    final has = await guarded(_log, 'Reading the references', () async {
      final saved = await references.watchForReel(reelId).first;
      return saved.any((r) => r.url == url);
    });
    if (has != true || mine != _pickCount) return;
    final reel = await guarded(_log, 'Reading the reel', () {
      return reels.getById(reelId);
    });
    if (reel == null || mine != _pickCount) return;
    _set(state.copyWith(alreadyIn: reel.name));
  }

  /// Forgets the picked reel, and its "already saved" banner, when it is not
  /// among [reelIds], the reels there are now (it was deleted while the sheet
  /// was open). Save waits for a new pick. Does nothing once the form is left,
  /// or when nothing is picked (D-166).
  void dropPickIfGone(Set<int> reelIds) {
    final picked = state.pickedReelId;
    if (state.step != SaveStep.form ||
        picked == null ||
        reelIds.contains(picked)) {
      return;
    }
    // A read for that pick still out must not answer for it.
    _pickCount++;
    _set(state.copyWith(pickedReelId: null, alreadyIn: null));
  }

  /// Forgets the name error and the failure (the user is typing again).
  void clearErrors() {
    if (state.nameError == null && !state.failed) return;
    _set(state.copyWith(nameError: null, clashingName: null, failed: false));
  }

  /// Saves the link with [label] to the picked reel, or, in New reel mode,
  /// to a reel named [name], made in the same go. On success the step is
  /// [SaveStep.saved].
  ///
  /// - **A name problem** (empty, over 40 characters, another reel's name) is
  ///   [SaveReferenceState.nameError]; nothing is saved.
  /// - **The reel already has the link** is [SaveReferenceState.alreadyIn];
  ///   nothing is saved.
  /// - **Nothing picked** does nothing.
  /// - **Anything else** (the picked reel deleted, a busy database, a label
  ///   over 60 characters) is [SaveReferenceState.failed], the type logged.
  ///
  /// A second call while one runs returns the first one's future.
  Future<void> save({required String name, required String label}) {
    final running = _inFlight;
    if (running != null) return running;
    final run = _save(name, label);
    _inFlight = run;
    unawaited(
      run.then<void>((_) {}, onError: (_) {}).then<void>((_) {
        if (identical(_inFlight, run)) _inFlight = null;
      }),
    );
    return run;
  }

  Future<void> _save(String name, String label) async {
    // Both read now: a save that outlives the sheet cannot read later.
    final reels = ref.read(reelsRepositoryProvider);
    final references = ref.read(referencesRepositoryProvider);
    if (state.step != SaveStep.form) return;
    final share = _share;
    final url = state.url;
    final mode = state.mode;
    final picked = state.pickedReelId;
    if (mode == SaveMode.existing && picked == null) return;
    // What this save changes, unless a newer share has taken the screen.
    void set(SaveReferenceState next) {
      if (share == _share) _set(next);
    }

    set(
      state.copyWith(
        nameError: null,
        clashingName: null,
        failed: false,
        saving: true,
      ),
    );
    try {
      if (checkReferenceLabel(label) != null) {
        // The field stops at 60, so only a bug gets here.
        set(state.copyWith(failed: true));
        return;
      }
      if (mode == SaveMode.newReel) {
        await _saveNew(reels, name, url, label, set);
      } else {
        await _saveExisting(reels, references, picked!, url, label, set);
      }
    } on InvalidInputException catch (problem) {
      final reason = problem.problem;
      if (reason is ReelNameProblem) {
        // Another reel took the name after the check: show it as the check
        // would have.
        final clash = await guarded(_log, 'Reading the reels', () {
          return _clashWith(reels, name);
        });
        set(state.copyWith(nameError: reason, clashingName: clash?.name));
      } else {
        _log.warning('The repository refused a save: ${reason.runtimeType}');
        set(state.copyWith(failed: true));
      }
    } on Object catch (error) {
      _log.warning('Saving a reference failed: ${error.runtimeType}');
      set(state.copyWith(failed: true));
    } finally {
      // Whatever way this ends, `saving` does not stay on.
      if (ref.mounted && share == _share && state.saving) {
        state = state.copyWith(saving: false);
      }
    }
  }

  Future<void> _saveNew(
    ReelsRepository reels,
    String name,
    String url,
    String label,
    void Function(SaveReferenceState) set,
  ) async {
    final clash = await _clashWith(reels, name);
    final problem =
        checkReelName(name) ??
        (clash == null ? null : ReelNameProblem.duplicate);
    if (problem != null) {
      set(state.copyWith(nameError: problem, clashingName: clash?.name));
      return;
    }
    final made = await reels.createWithReference(name, url: url, label: label);
    set(
      state.copyWith(
        step: SaveStep.saved,
        savedReelId: made.id,
        savedReelName: made.name,
        savedLabel: cleanReferenceLabel(label),
      ),
    );
  }

  Future<void> _saveExisting(
    ReelsRepository reels,
    ReferencesRepository references,
    int reelId,
    String url,
    String label,
    void Function(SaveReferenceState) set,
  ) async {
    final result = await references.add(reelId, url, label: label);
    final reel = await reels.getById(reelId);
    if (reel == null) {
      // Deleted right after the write: there is no reel to say it is in.
      set(state.copyWith(failed: true));
      return;
    }
    switch (result) {
      case ReferenceAdded(:final reference):
        set(
          state.copyWith(
            step: SaveStep.saved,
            savedReelId: reelId,
            savedReelName: reel.name,
            savedLabel: reference.label,
          ),
        );
      case ReferenceAlreadySaved():
        set(state.copyWith(alreadyIn: reel.name));
    }
  }

  /// The reel that has [name] (ignoring case and edge spaces), or null.
  Future<Reel?> _clashWith(ReelsRepository reels, String name) async {
    final key = reelNameKey(name);
    for (final reel in await reels.watchAll().first) {
      if (reelNameKey(reel.name) == key) return reel;
    }
    return null;
  }

  /// Sets the state unless the sheet has gone and taken the provider along.
  void _set(SaveReferenceState next) {
    if (ref.mounted) state = next;
  }
}
