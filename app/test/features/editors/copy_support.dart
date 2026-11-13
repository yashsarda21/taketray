import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/data/editors/edit_session_service.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/editor_app.dart';
import 'package:taketray/domain/models/reel.dart';
import 'package:taketray/features/editors/view_models/copy_job_controller.dart';
import 'package:taketray/platform/copy_bridge.dart';

import '../../support/reel_videos.dart';
import '../../support/vm_harness.dart';
import 'editors_support.dart';

/// Runs [job] in real time (the in-memory database answers on the real event
/// loop, not on the test's clock).
Future<T> real<T>(WidgetTester tester, Future<T> Function() job) async =>
    (await tester.runAsync(job)) as T;

/// Lets the database, the bridges' streams and the redraw all catch up.
Future<void> settleApp(WidgetTester tester) async {
  await tester.runAsync(settle);
  await tester.pump();
  await tester.pumpAndSettle();
}

/// A VN copy job started through the real `EditSessionService` on `h`'s
/// database and fake bridges: the plan is saved, the engine (the fake) holds
/// the running job.
class VnJob {
  VnJob(this.reel, this.clipIds, this.jobId, this.request);

  final Reel reel;

  /// The clips, in shooting order.
  final List<int> clipIds;
  final String jobId;
  final CopyRequest request;

  String get folder => request.folderName;

  /// What the engine reports: [state], with the items at the positions
  /// [copied] copied (a position is an index into the shooting order),
  /// [failed] failed and [undeleted] left behind by a cancel. `done` counts
  /// the copied and the failed ones unless [done] says otherwise.
  CopyJob report({
    CopyState state = CopyState.running,
    List<int> copied = const [],
    List<int> failed = const [],
    List<int> undeleted = const [],
    int? done,
    int? bytesDone,
  }) {
    CopiedFile file(int i) => CopiedFile(
      clipId: request.items[i].clipId,
      copyMediaStoreId: 900 + i,
      fileName: request.items[i].fileName,
      sizeBytes: request.items[i].sizeBytes,
      copiedAt: DateTime.utc(2026, 10, 30, 12),
    );
    int bytesOf(Iterable<int> items) =>
        items.fold(0, (sum, i) => sum + request.items[i].sizeBytes);
    return CopyJob(
      jobId: jobId,
      reelId: reel.id,
      folderName: folder,
      state: state,
      total: request.items.length,
      done: done ?? copied.length + failed.length,
      bytesDone: bytesDone ?? bytesOf([...copied, ...failed]),
      bytesTotal: bytesOf(List.generate(request.items.length, (i) => i)),
      copied: [for (final i in copied) file(i)],
      failedClipIds: [for (final i in failed) request.items[i].clipId],
      undeleted: [for (final i in undeleted) file(i)],
    );
  }
}

/// Reel [name] with [count] clips of [sizeBytes] each, shot an hour apart
/// from 09:00 UTC on 28 Oct 2026, in [zoneId] (null: no zone).
Future<(Reel, List<int>)> reelWithClips(
  WidgetTester tester,
  VmHarness h, {
  String name = 'Goa',
  int count = 4,
  int sizeBytes = 100000000,
  String? zoneId,
}) async {
  final reel = await real(
    tester,
    () => h.container.read(reelsRepositoryProvider).create(name),
  );
  final ids = await real(
    tester,
    () => putInReel(h, reel.id, [
      for (var i = 0; i < count; i++)
        sizedVideo(
          i + 1,
          shot: DateTime.utc(2026, 10, 28, 9 + i),
          size: sizeBytes,
        ),
    ], zoneId: zoneId),
  );
  return (reel, ids);
}

/// Plans and starts a VN copy of [clipIds] of [reel] (the whole reel when
/// null) through `h.container`'s service.
Future<VnJob> startVnJob(
  WidgetTester tester,
  VmHarness h,
  Reel reel,
  List<int> reelClipIds, {
  List<int>? clipIds,
}) async {
  h.editors.allow({'freeBytes', 'copyFolderNames', 'filesInCopyFolders'});
  h.copy.allowAll();
  final service = h.container.read(editSessionServiceProvider);
  final asked = clipIds ?? reelClipIds;
  return await real(tester, () async {
    final plan = await service.planCopy(reel.id, EditorApp.vn, asked);
    final jobId = await service.startCopy(plan);
    return VnJob(reel, plan.clipIds, jobId, h.copy.starts.last);
  });
}

/// The app leaves the front and comes back, through the lifecycle states
/// Flutter allows between them.
Future<void> leaveAndReturn(WidgetTester tester) async {
  final binding = tester.binding;
  [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ].forEach(binding.handleAppLifecycleStateChanged);
  await settleApp(tester);
}

/// Makes the copy job controller follow the engine, as the app's start does.
void followJob(ProviderContainer container) {
  container.read(copyJobControllerProvider);
}
