import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/data/repositories/clips_repository.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/models/enums.dart';

part 'pending_clips.g.dart';

/// The clips waiting in To tag, as the database has them, for the Shooting
/// mode card (its count and its backdrop).
///
/// Unlike `ToTagController` it only reads: building it does not scan or
/// verify, so the card on the Reels tab never takes the place of "To tag was
/// opened" (D-76).
@riverpod
Stream<List<Clip>> pendingClips(Ref ref) =>
    ref.watch(clipsRepositoryProvider).watchInbox(InboxState.pending);

/// [clips] in shooting order: oldest date taken first, then the lower id. A
/// new list; [clips] is not changed.
List<Clip> inShootingOrder(List<Clip> clips) => [...clips]
  ..sort((a, b) {
    final byDate = a.fingerprint.dateTakenUtc.compareTo(
      b.fingerprint.dateTakenUtc,
    );
    return byDate != 0 ? byDate : a.id.compareTo(b.id);
  });

/// The most recently shot of [clips] (the last in shooting order), or null
/// when there are none.
Clip? latestPending(List<Clip> clips) =>
    clips.isEmpty ? null : inShootingOrder(clips).last;
