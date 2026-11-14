import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/core/guarded.dart';
import 'package:taketray/data/editors/edit_session_service.dart';
import 'package:taketray/data/media/thumbnail_cache.dart';
import 'package:taketray/data/repositories/edit_sessions_repository.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/models/edit_session.dart';
import 'package:taketray/domain/models/editor_app.dart';
import 'package:taketray/features/clips/widgets/clip_thumbnail.dart';
import 'package:taketray/features/reels/view_models/home_controller.dart';

part 'copies_storage_controller.g.dart';

// Counts and error types only: never a reel or folder name (D-10).
final Logger _log = Logger('copiesStorage');

/// The editing sessions that hold copies, in order of their start, newest
/// first (ties by reel id, newest first); a session with no copies (CapCut or
/// Edits that sent the originals) holds no storage and is not listed.
List<EditSessionSummary> sessionsWithCopies(
  Iterable<EditSessionSummary> sessions,
) =>
    [
      for (final s in sessions)
        if (s.copyCount > 0) s,
    ]..sort((a, b) {
      final byDay = b.createdAt.compareTo(a.createdAt);
      return byDay != 0 ? byDay : b.reelId.compareTo(a.reelId);
    });

/// What Settings' "Storage used by VN copies" row says: how much the copies
/// take and in how many reels (D-130).
@immutable
class CopiesSummary {
  const CopiesSummary({required this.bytes, required this.reels});

  /// A summary of [sessions] (only those with copies count).
  factory CopiesSummary.of(Iterable<EditSessionSummary> sessions) {
    final held = sessionsWithCopies(sessions);
    return CopiesSummary(
      bytes: held.fold(0, (sum, s) => sum + s.copyBytes),
      reels: held.length,
    );
  }

  final int bytes;
  final int reels;

  @override
  bool operator ==(Object other) =>
      other is CopiesSummary && other.bytes == bytes && other.reels == reels;

  @override
  int get hashCode => Object.hash(bytes, reels);

  @override
  String toString() => 'CopiesSummary($bytes bytes, $reels reels)';
}

/// Every editing session, now and after every change to sessions, copies or
/// reels (`EditSessionsRepository.watchSummaries`).
@riverpod
Stream<List<EditSessionSummary>> editSessionSummaries(Ref ref) =>
    ref.watch(editSessionsRepositoryProvider).watchSummaries();

/// The summary of the sessions' copies, for Settings. It reads the database
/// only (no MediaStore), so the Settings tab stays cheap.
@riverpod
Stream<CopiesSummary> copiesSummary(Ref ref) => ref
    .watch(editSessionsRepositoryProvider)
    .watchSummaries()
    .map(CopiesSummary.of);

/// One reel's row on the storage screen.
@immutable
class CopiesRow {
  const CopiesRow({required this.session, required this.cover});

  final EditSessionSummary session;

  /// The reel's cover picture, or null: the movie icon.
  final ImageProvider? cover;

  int get reelId => session.reelId;
  EditorApp get editor => session.editor;
}

/// What the VN copies screen shows (D-130).
@immutable
class CopiesStorageState {
  CopiesStorageState({
    required List<CopiesRow> rows,
    required List<OrphanFolder> orphans,
  }) : rows = List.unmodifiable(rows),
       orphans = List.unmodifiable(orphans);

  /// One row per session that holds copies, newest first.
  final List<CopiesRow> rows;

  /// The files no session records, by folder.
  final List<OrphanFolder> orphans;

  /// What the sessions' copies take.
  int get totalBytes => rows.fold(0, (sum, r) => sum + r.session.copyBytes);

  /// Nothing to list at all.
  bool get isEmpty => rows.isEmpty && orphans.isEmpty;

  /// This state without the files of [folder].
  CopiesStorageState withoutOrphan(OrphanFolder folder) => CopiesStorageState(
    rows: rows,
    orphans: [
      for (final o in orphans)
        if (o != folder) o,
    ],
  );
}

/// The VN copies screen's data (D-130): `EditSessionService.storage()` (every
/// session and the files no session records), the sessions that hold copies
/// newest first, and each reel's cover joined by reel id from
/// `ReelSummary.cover` (the movie icon when it has none or the covers cannot
/// be read).
///
/// It reads again when a session, a copy or a reel changes (so a Done editing
/// from anywhere shows at once) and on [refresh] (the screen calls it when the
/// app comes back to the front: the folders may have changed outside
/// TakeTray). While it reads again the last state stays. An error is the
/// state when `storage()` fails; **Try again** is [refresh].
///
/// Auto-disposes with the screen.
@Riverpod(retry: noRetry)
class CopiesStorageController extends _$CopiesStorageController {
  @override
  Future<CopiesStorageState> build() async {
    final cache = ref.watch(thumbnailCacheProvider).value;
    // A change to any session or copy reads again; the value itself is
    // `storage()`'s.
    await ref.watch(editSessionSummariesProvider.future);
    final reels = await _reels();
    final overview = await ref.read(editSessionServiceProvider).storage();
    return CopiesStorageState(
      rows: [
        for (final session in sessionsWithCopies(overview.sessions))
          CopiesRow(
            session: session,
            cover: switch (reels[session.reelId]) {
              final clip? => clipThumbnail(
                clip: clip,
                logicalSize: homeCoverSize,
                cache: cache,
              ),
              null => null,
            },
          ),
      ],
      orphans: overview.orphans,
    );
  }

  /// The cover clip of every reel, by reel id; empty when the reels cannot be
  /// read (the rows then show the movie icon).
  Future<Map<int, Clip>> _reels() async {
    try {
      final summaries = await ref.watch(reelSummariesProvider.future);
      return {for (final s in summaries) s.reel.id: ?s.cover};
    } on Object catch (error) {
      _log.warning('Reading the reels failed: ${error.runtimeType}');
      return const {};
    }
  }

  /// Reads everything again.
  void refresh() => ref.invalidateSelf();

  /// Asks Android to delete [folder]'s files (its consent dialog, R7).
  /// Declined: the folder stays. Allowed (whatever the bytes freed, even 0):
  /// the folder leaves the screen at once. A failure is logged by type and
  /// thrown.
  Future<OrphanDeleteResult> deleteOrphans(OrphanFolder folder) async {
    final OrphanDeleteResult result;
    try {
      result = await ref.read(editSessionServiceProvider).deleteOrphans(folder);
    } on Object catch (error) {
      _log.warning('Deleting the files failed: ${error.runtimeType}');
      rethrow;
    }
    final current = state.value;
    if (result.allowed && current != null && ref.mounted) {
      state = AsyncData(current.withoutOrphan(folder));
    }
    return result;
  }
}
