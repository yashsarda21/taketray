import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/data/repositories/references_repository.dart';
import 'package:taketray/domain/models/reel.dart';
import 'package:taketray/domain/rules/text_limits.dart';
import 'package:taketray/features/onboarding/view_models/onboarding_controller.dart';
import 'package:taketray/features/onboarding/view_models/onboarding_steps.dart';

part 'reels_step_controller.g.dart';

// Error types and counts only: never a reel name, typed or saved (D-10).
final Logger _log = Logger('reelsStep');

/// The reel ideas under the field (`ob-reels` in the prototype), in the order
/// they are offered.
const List<String> onboardingIdeas = [
  'Day 1 Vlog',
  'Food',
  'Cinematic',
  'Behind the scenes',
  'Get ready with me',
];

/// The ideas stop showing once the list has this many names.
const int _ideasUntilNames = 5;

/// How many ideas show at once.
const int _ideasShown = 4;

const Object _keep = Object();

/// A reel the database already has, as the step lists it (D-168): its name and
/// how many references it holds.
typedef ExistingReel = ({String name, int referenceCount});

/// What onboarding's reels step shows (D-141).
@immutable
class ReelsStepState {
  const new({
    this.names = const [],
    this.error,
    this.clashingName,
    this.existing = const [],
    this.busy = false,
    this.failed = false,
    this.finished = false,
  });

  /// The reels to create, as they will be saved (trimmed), in the order added.
  final List<String> names;

  /// Why the last name was not accepted, or why Create was refused; null for
  /// no problem. The view turns it into words.
  final ReelNameProblem? error;

  /// With [ReelNameProblem.duplicate]: the other reel's name as it stands in
  /// the list or in the database, for "You already have a reel called {name}".
  final String? clashingName;

  /// The reels the database already has, oldest first, each with its reference
  /// count (a copy of the last read; the repository's own check is the
  /// backstop). A reel a share made before onboarding is one of them (D-168).
  final List<ExistingReel> existing;

  /// The names of [existing], in the same order.
  List<String> get existingNames => [for (final reel in existing) reel.name];

  /// Whether the database has any reel: the main button is then "Continue"
  /// when nothing is typed. (An app killed after Create but before onboarding
  /// was marked done comes back here.)
  bool get hasExistingReels => existing.isNotEmpty;

  /// Create, Continue or Skip is running: names cannot change and a second
  /// tap does nothing.
  final bool busy;

  /// The last attempt failed for a reason the user cannot fix; shown until the
  /// next attempt or edit.
  final bool failed;

  /// Onboarding is done: the screen goes to Reels.
  final bool finished;

  /// The ideas to show under the field: the first four of
  /// [onboardingIdeas] that neither the list nor an existing reel has (by
  /// [reelNameKey]), and none from five names on.
  List<String> get ideas {
    if (names.length >= _ideasUntilNames) return const [];
    final taken = {
      for (final name in names) reelNameKey(name),
      for (final reel in existing) reelNameKey(reel.name),
    };
    return [
      for (final idea in onboardingIdeas)
        if (!taken.contains(reelNameKey(idea))) idea,
    ].take(_ideasShown).toList();
  }

  ReelsStepState _with({
    List<String>? names,
    Object? error = _keep,
    Object? clashingName = _keep,
    List<ExistingReel>? existing,
    bool? busy,
    bool? failed,
    bool? finished,
  }) => ReelsStepState(
    names: names ?? this.names,
    error: identical(error, _keep) ? this.error : error as ReelNameProblem?,
    clashingName: identical(clashingName, _keep)
        ? this.clashingName
        : clashingName as String?,
    existing: existing ?? this.existing,
    busy: busy ?? this.busy,
    failed: failed ?? this.failed,
    finished: finished ?? this.finished,
  );

  @override
  bool operator ==(Object other) =>
      other is ReelsStepState &&
      listEquals(other.names, names) &&
      other.error == error &&
      other.clashingName == clashingName &&
      listEquals(other.existing, existing) &&
      other.busy == busy &&
      other.failed == failed &&
      other.finished == finished;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(names),
    error,
    clashingName,
    Object.hashAll(existing),
    busy,
    failed,
    finished,
  );
}

/// The reels step of onboarding (D-141): the names the user plans, checked
/// with the reel form's rules, then made in one go.
///
/// - **[add]** trims the name, then refuses it as `empty`, `tooLong` or
///   `duplicate` (a name in the list or an existing reel, ignoring case and
///   edge spaces, [reelNameKey]); the state says why.
/// - **[create]** makes every name with one `createAll` (all or none), and only
///   then calls `finish()`. A second call while it runs, or once it is done,
///   does nothing. A reel made elsewhere meanwhile is shown as a duplicate and
///   nothing is finished; any other failure is `failed`.
/// - **existing reels** are read live from `ReelsRepository.watchAll` and
///   `ReferencesRepository.watchCounts` and shown oldest first with their
///   reference counts (D-168). Nothing shows until both have answered, so a
///   reel never appears with a count that is about to change; a count read
///   that fails counts as none. A count read that has not answered within
///   [stepReadLimit] is taken as none too (logged), so the rows, the duplicate
///   check and "Continue" never wait for it for good; the counts that arrive
///   later update the rows.
/// - **[skip]** (also the "Continue" of a phone that already has reels) calls
///   `finish()` and writes no reel.
///
/// A phone killed after the reels were made and before onboarding was marked
/// done opens this step again: the reels exist, so the step offers
/// "Continue", and typing the same names is refused as a duplicate, so one
/// Create never makes a second set.
@riverpod
class ReelsStepController extends _$ReelsStepController {
  /// The last reels and counts read; null until each has answered once.
  List<Reel>? _reels;
  Map<int, int>? _counts;

  /// Set when the counts did not answer within [stepReadLimit]: the reels
  /// are published with no counts until they do.
  bool _countsLate = false;
  Timer? _countsLimit;

  @override
  ReelsStepState build() {
    _reels = null;
    _counts = null;
    _countsLate = false;
    _countsLimit = Timer(stepReadLimit, () {
      if (!ref.mounted || _counts != null) return;
      _log.warning('Reading the reference counts took too long');
      _countsLate = true;
      _publish();
    });
    final reelsSubscription = ref
        .read(reelsRepositoryProvider)
        .watchAll()
        .listen(
          (reels) {
            if (!ref.mounted) return;
            _reels = reels;
            _publish();
          },
          onError: (Object error) =>
              _log.warning('Reading the reels failed: ${error.runtimeType}'),
        );
    final countsSubscription = ref
        .read(referencesRepositoryProvider)
        .watchCounts()
        .listen(
          (counts) {
            if (!ref.mounted) return;
            _counts = counts;
            _countsLimit?.cancel();
            _publish();
          },
          onError: (Object error) {
            // The counts are a hint: the reels show without them.
            _log.warning(
              'Reading the reference counts failed: ${error.runtimeType}',
            );
            if (!ref.mounted) return;
            _counts = const {};
            _countsLimit?.cancel();
            _publish();
          },
        );
    ref.onDispose(() {
      _countsLimit?.cancel();
      unawaited(reelsSubscription.cancel());
      unawaited(countsSubscription.cancel());
    });
    return const ReelsStepState();
  }

  /// Puts the last reels and counts in the state, once both have been read.
  void _publish() {
    final reels = _reels;
    final counts = _counts ?? (_countsLate ? const <int, int>{} : null);
    if (reels == null || counts == null) return;
    state = state._with(existing: _existingFrom(reels, counts));
  }

  /// [reels] oldest created first (ties: lowest id first), each with its
  /// count from [counts].
  List<ExistingReel> _existingFrom(List<Reel> reels, Map<int, int> counts) {
    final oldestFirst = [...reels]
      ..sort((a, b) {
        final byTime = a.createdAt.compareTo(b.createdAt);
        return byTime != 0 ? byTime : a.id.compareTo(b.id);
      });
    return [
      for (final reel in oldestFirst)
        (name: reel.name, referenceCount: counts[reel.id] ?? 0),
    ];
  }

  /// Adds [typed] to the list; true when it was added, false when it was
  /// refused ([ReelsStepState.error] says why) or the step is busy.
  bool add(String typed) {
    if (state.busy || state.finished) return false;
    final problem = checkReelName(typed);
    if (problem != null) {
      state = state._with(error: problem, clashingName: null, failed: false);
      return false;
    }
    final key = reelNameKey(typed);
    final clash =
        _clashIn(state.names, key) ?? _clashIn(state.existingNames, key);
    if (clash != null) {
      state = state._with(
        error: ReelNameProblem.duplicate,
        clashingName: clash,
        failed: false,
      );
      return false;
    }
    state = state._with(
      names: [...state.names, normalizeName(typed)],
      error: null,
      clashingName: null,
      failed: false,
    );
    return true;
  }

  /// Adds one of the [onboardingIdeas] like a typed name.
  void addIdea(String name) => add(name);

  /// Takes the [index]th name out of the list; a place outside it, or a busy
  /// step, does nothing.
  void remove(int index) {
    if (state.busy || state.finished) return;
    if (index < 0 || index >= state.names.length) return;
    state = state._with(
      names: [...state.names]..removeAt(index),
      error: null,
      clashingName: null,
      failed: false,
    );
  }

  /// Forgets the error and the failure (the user is typing again).
  void clearError() {
    final s = state;
    if (s.error == null && s.clashingName == null && !s.failed) return;
    state = s._with(error: null, clashingName: null, failed: false);
  }

  /// Makes every name in the list, then finishes onboarding. With no names it
  /// does nothing ([skip] is what "Continue" calls).
  Future<void> create() async {
    final names = state.names;
    if (state.busy || state.finished || names.isEmpty) return;
    state = state._with(
      busy: true,
      error: null,
      clashingName: null,
      failed: false,
    );
    final repository = ref.read(reelsRepositoryProvider);
    try {
      await repository.createAll(names);
    } on InvalidInputException catch (refused) {
      await _refused(repository, names, refused);
      return;
    } on Object catch (error) {
      _log.warning('Creating the reels failed: ${error.runtimeType}');
      _set((s) => s._with(busy: false, failed: true));
      return;
    }
    // The reels exist. Whatever happens next they are never made again: a
    // finish that fails leaves the list empty, so the step offers "Continue".
    await _finish(clearNames: true);
  }

  /// Finishes onboarding without making a reel.
  Future<void> skip() async {
    if (state.busy || state.finished) return;
    state = state._with(busy: true, error: null, clashingName: null);
    await _finish(clearNames: false);
  }

  Future<void> _finish({required bool clearNames}) async {
    try {
      await ref.read(onboardingControllerProvider.notifier).finish();
    } on Object catch (error) {
      _log.warning('Finishing onboarding failed: ${error.runtimeType}');
      _set(
        (s) => s._with(
          names: clearNames ? const [] : null,
          busy: false,
          failed: true,
        ),
      );
      return;
    }
    _set((s) => s._with(busy: false, finished: true));
  }

  /// The repository refused the names: say why, keep the list.
  Future<void> _refused(
    ReelsRepository repository,
    List<String> names,
    InvalidInputException refused,
  ) async {
    final problem = refused.problem;
    if (problem is! ReelNameProblem) {
      _log.warning('Creating the reels was refused: ${problem.runtimeType}');
      _set((s) => s._with(busy: false, failed: true));
      return;
    }
    List<Reel> reels;
    try {
      reels = await repository.watchAll().first;
    } on Object catch (error) {
      _log.warning('Reading the reels failed: ${error.runtimeType}');
      reels = const [];
    }
    final existing = [for (final r in reels) r.name];
    String? clash;
    if (problem == ReelNameProblem.duplicate) {
      for (final name in names) {
        clash = _clashIn(existing, reelNameKey(name));
        if (clash != null) break;
      }
      clash ??= names.first;
    }
    _set(
      (s) => s._with(
        error: problem,
        clashingName: clash,
        existing: reels.isEmpty
            ? null
            : _existingFrom(reels, _counts ?? const {}),
        busy: false,
      ),
    );
  }

  /// The name in [names] with [key], or null.
  String? _clashIn(List<String> names, String key) {
    for (final name in names) {
      if (reelNameKey(name) == key) return name;
    }
    return null;
  }

  /// Changes the state unless the step has gone and taken the provider along.
  void _set(ReelsStepState Function(ReelsStepState) change) {
    if (ref.mounted) state = change(state);
  }
}
