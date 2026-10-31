import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/data/repositories/clips_repository.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/domain/rules/shooting_order.dart';

export 'package:taketray/domain/rules/shooting_order.dart' show inShootingOrder;

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

/// The first stored clip that has a picture (`watchFirstShowableClip`): what
/// the Shooting mode card's backdrop falls back to when no clip waits in To
/// tag, as the prototype does (D-76). Null when there is none.
@riverpod
Stream<Clip?> firstShowableClip(Ref ref) =>
    ref.watch(clipsRepositoryProvider).watchFirstShowableClip();

/// The most recently shot of [clips] (the last in shooting order), or null
/// when there are none.
Clip? latestPending(List<Clip> clips) =>
    clips.isEmpty ? null : inShootingOrder(clips).last;
