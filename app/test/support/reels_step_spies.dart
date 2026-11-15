import 'dart:async';

import 'package:taketray/core/clock.dart';
import 'package:taketray/data/database/app_database.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/reel.dart';

import 'fixed_onboarding.dart';

/// A repository that logs `createAll` into [events], can hold it on [gate]
/// and make it fail with [failWith] (Phase 10A Task 8).
class SpyReels extends ReelsRepository {
  // The parameters of ReelsRepository are private, so they cannot be super
  // parameters.
  // ignore: use_super_parameters, the same reason
  SpyReels(AppDatabase db, Clock clock, this.events) : super(db, clock);

  final List<String> events;
  final List<List<String>> calls = [];
  Completer<void>? gate;
  Object? failWith;

  @override
  Future<List<Reel>> createAll(List<String> names) async {
    calls.add(List.of(names));
    events.add('createAll');
    await gate?.future;
    final failure = failWith;
    // ignore: only_throw_errors, a test makes it fail with any object
    if (failure != null) throw failure;
    final made = await super.createAll(names);
    events.add('createAll done');
    return made;
  }
}

/// A not-yet-onboarded [FixedOnboarding] that logs `finish` into [events] and
/// can make it fail with [failWith].
class SpyOnboarding extends FixedOnboarding {
  SpyOnboarding(this.events)
    : super(done: false, introPlayed: true, homeTipSeen: false);

  final List<String> events;
  int finishes = 0;
  Object? failWith;

  @override
  Future<void> finish() async {
    finishes++;
    events.add('finish');
    final failure = failWith;
    // ignore: only_throw_errors, a test makes it fail with any object
    if (failure != null) throw failure;
    await super.finish();
  }
}
