import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/data/media/add_videos_service.dart';
import 'package:taketray/data/media/media_work_queue.dart';
import 'package:taketray/data/media/thumbnail_cache.dart';
import 'package:taketray/data/media/zone_sync.dart';
import 'package:taketray/data/repositories/clips_repository.dart';
import 'package:taketray/data/repositories/phone_state_repository.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/data/repositories/zone_repository.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/domain/models/reel.dart';
import 'package:taketray/features/add_videos/views/open_add_videos.dart';
import 'package:taketray/features/media_access/view_models/media_access_controller.dart';
import 'package:taketray/platform/media_bridge.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../../support/fake_media_bridge.dart';
import '../../support/pump_screen.dart';
import '../../support/view_model_fakes.dart';
import '../../support/vm_harness.dart';

export '../../support/fake_media_bridge.dart' show fakeVideo;

/// The phone's clock in the Add videos tests: 15:00 local time on Friday
/// 2026-10-30 (local, so the day headers hold in any zone).
final DateTime addNow = DateTime(2026, 10, 30, 15);

/// What the host page at `/` shows: the screen the user came from.
const originMarker = 'the screen the user came from';

/// A [RecordingBridge] that also records every `videosInFolder` call as
/// `(volume, path, limit, offset)`.
class FolderBridge extends RecordingBridge {
  final List<(String, String, int, int)> pages = [];

  @override
  Future<List<MediaVideo>> videosInFolder(
    String volumeName,
    String relativePath,
    int limit,
    int offset,
  ) {
    pages.add((volumeName, relativePath, limit, offset));
    return super.videosInFolder(volumeName, relativePath, limit, offset);
  }

  /// Puts [videos] on [volume] in folder [path] and lists the folder with
  /// its count (replacing an earlier entry for the same folder).
  void putFolder(
    String path,
    List<MediaVideo> videos, {
    String volume = phone,
  }) {
    put(videos, volume: volume);
    folders = [
      for (final f in folders)
        if (f.volumeName != volume || f.relativePath != path) f,
      VideoFolder(
        volumeName: volume,
        relativePath: path,
        videoCount: videosByVolume[volume]!
            .where((v) => v.relativePath == path)
            .length,
      ),
    ];
  }

  /// Takes the video [id] off [volume], as a delete on the phone would.
  void deleteVideo(int id, {String volume = phone}) =>
      videosByVolume[volume]?.removeWhere((v) => v.mediaStoreId == id);
}

/// A video in [folder] shot at [shot] (local time), [seconds] long, with
/// MediaStore id and generation [id] and a size unique to it.
MediaVideo folderVideo(
  int id,
  DateTime shot, {
  String folder = whatsAppFolder,
  String volume = phone,
  int seconds = 5,
  bool horizontal = false,
}) => fakeVideo(
  id: id,
  generation: id,
  volume: volume,
  folder: folder,
  sizeBytes: 1000000 + id,
  durationMs: seconds * 1000,
  dateTakenMs: shot.millisecondsSinceEpoch,
  dateAddedSec: shot.millisecondsSinceEpoch ~/ 1000,
  dateModifiedSec: shot.millisecondsSinceEpoch ~/ 1000,
  width: horizontal ? 1920 : 1080,
  height: horizontal ? 1080 : 1920,
);

/// A video the photo picker hands over, [n] being unique to it.
PickedVideo pickedVideo(
  int n, {
  bool persisted = true,
  int seconds = 5,
  DateTime? shot,
}) => PickedVideo(
  uri:
      'content://media/picker/0/com.android.providers.media.photopicker/'
      'media/$n',
  sizeBytes: 2000000 + n,
  displayName: 'PICKED-$n.mp4',
  persisted: persisted,
  durationMs: seconds * 1000,
  dateTakenMs: (shot ?? addNow.subtract(const Duration(hours: 3)))
      .add(Duration(minutes: n))
      .millisecondsSinceEpoch,
  width: 1080,
  height: 1920,
  mimeType: 'video/mp4',
);

/// A friend's WhatsApp folder.
const whatsAppFolder =
    'Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Video/';

/// An [AddVideosService] that counts its folder adds, can hold one
/// ([gate]) and can fail the next one ([failNext]).
class CountingAddVideos extends AddVideosService {
  // The parameters of AddVideosService are private, so they cannot be super
  // parameters.
  // ignore: use_super_parameters, the same reason
  CountingAddVideos(
    MediaBridge bridge,
    ClipsRepository clips,
    PhoneStateRepository phone,
    ZoneRepository zones,
    ZoneSync zoneSync,
    MediaWorkQueue queue,
    Clock clock,
  ) : super(bridge, clips, phone, zones, zoneSync, queue, clock);

  /// The videos of every `addFromFolder` call, in order.
  final List<List<MediaVideo>> folderAdds = [];

  /// The targets of every `addFromFolder` call, in order.
  final List<AddTarget> targets = [];

  /// The videos of every `addPicked` call, in order.
  final List<List<PickedVideo>> pickedAdds = [];

  /// The next `addPicked` throws.
  bool failNextPicked = false;

  /// Holds the next add until it completes.
  Completer<void>? gate;

  /// The next add throws.
  bool failNext = false;

  /// Every `marks` call throws.
  bool failMarks = false;

  @override
  Future<Map<int, AddMark>> marks(
    String volumeName,
    List<int> mediaStoreIds,
    AddTarget target,
  ) async {
    if (failMarks) throw StateError('the marks failed on purpose');
    return await super.marks(volumeName, mediaStoreIds, target);
  }

  @override
  Future<AddResult> addFromFolder(
    List<MediaVideo> videos,
    AddTarget target,
  ) async {
    folderAdds.add(List.of(videos));
    targets.add(target);
    final held = gate;
    gate = null;
    if (held != null) await held.future;
    if (failNext) {
      failNext = false;
      throw StateError('the add failed on purpose');
    }
    return await super.addFromFolder(videos, target);
  }

  @override
  Future<AddResult> addPicked(
    List<PickedVideo> videos,
    AddTarget target,
  ) async {
    pickedAdds.add(List.of(videos));
    if (failNextPicked) {
      failNextPicked = false;
      throw StateError('the picked add failed on purpose');
    }
    return await super.addPicked(videos, target);
  }
}

/// Everything an Add videos test needs: a [VmHarness] on a [FolderBridge]
/// whose clock is [addNow], a [FakeAccess] at full, and a
/// [CountingAddVideos] on the harness's providers.
class AddHarness {
  AddHarness({MediaAccessLevel access = MediaAccessLevel.full})
    : bridge = FolderBridge(),
      fakeAccess = FakeAccess(access) {
    h = VmHarness(now: addNow.toUtc(), bridge: bridge);
    cacheFolder = Directory.systemTemp.createTempSync('taketray_add');
    addTearDown(() => cacheFolder.deleteSync(recursive: true));
  }

  final FolderBridge bridge;
  final FakeAccess fakeAccess;
  late final VmHarness h;
  late final Directory cacheFolder;
  late CountingAddVideos service;

  /// More overrides for a test to add before it pumps.
  final List<Override> extraOverrides = [];

  List<Override> get overrides => [
    ...h.overrides,
    mediaAccessControllerProvider.overrideWith(() => fakeAccess),
    thumbnailCacheProvider.overrideWith(
      (ref) async => ThumbnailCache(bridge, cacheFolder),
    ),
    addVideosServiceProvider.overrideWith(
      (ref) => service = CountingAddVideos(
        ref.watch(mediaBridgeProvider),
        ref.watch(clipsRepositoryProvider),
        ref.watch(phoneStateRepositoryProvider),
        ref.watch(zoneRepositoryProvider),
        ref.watch(zoneSyncProvider),
        ref.watch(mediaWorkQueueProvider),
        ref.watch(clockProvider),
      ),
    ),
    ...extraOverrides,
  ];

  /// Pumps a host page with one button, **open**, that opens Add videos for
  /// [target] the way To tag and the reel page do.
  Future<ProviderContainer> pumpOrigin(
    WidgetTester tester,
    AddTarget target, {
    double textScale = 1,
    Brightness brightness = Brightness.light,
  }) async {
    final container = await pumpScreen(
      tester,
      Scaffold(
        body: Consumer(
          builder: (context, ref, _) => Column(
            children: [
              const Text(originMarker),
              TtButton(
                label: 'open',
                onPressed: () => unawaited(openAddVideos(context, ref, target)),
              ),
            ],
          ),
        ),
      ),
      overrides: overrides,
      addVideos: true,
      textScale: textScale,
      brightness: brightness,
      settle: false,
    );
    await settleApp(tester);
    return container;
  }

  /// Creates the reel [name].
  Future<Reel> makeReel(WidgetTester tester, String name) async => (await tester
      .runAsync(() => h.container.read(reelsRepositoryProvider).create(name)))!;

  /// The MediaStore ids waiting in To tag.
  Future<List<int>> pendingIds(WidgetTester tester) async => [
    for (final c in (await tester.runAsync(h.media.toTag))!)
      c.mediaStoreId ?? -1,
  ];
}

/// Lets the database, the bridge and the queue answer, then redraws.
Future<void> settleApp(WidgetTester tester) async {
  await tester.runAsync(settle);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.runAsync(settle);
  await tester.pump();
}

/// Taps [finder] and lets everything answer.
Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pump();
  await settleApp(tester);
}

/// Opens Add videos from the host page.
Future<void> openBrowser(WidgetTester tester) =>
    tapAndSettle(tester, find.text('open'));

/// Opens the folder whose row shows [name].
Future<void> openFolder(WidgetTester tester, String name) =>
    tapAndSettle(tester, find.text(name));

/// The tile of the video [id] in the grid.
Finder tileOf(int id) => find.byKey(ValueKey<String>('add-video-$id'));

/// The Add button of the bottom bar.
TtButton addButton(WidgetTester tester) => tester.widget<TtButton>(
  find.byKey(const ValueKey<String>('add-videos-add')),
);
