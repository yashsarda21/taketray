import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:taketray/data/database/app_database.dart';
import 'package:taketray/data/media/media_scanner.dart';
import 'package:taketray/data/media/media_verifier.dart';
import 'package:taketray/data/media/media_work_queue.dart';
import 'package:taketray/data/media/zone_sync.dart';
import 'package:taketray/data/repositories/clips_repository.dart';
import 'package:taketray/data/repositories/phone_state_repository.dart';
import 'package:taketray/data/repositories/settings_repository.dart';
import 'package:taketray/data/repositories/zone_repository.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/domain/rules/media_clip.dart';

import '../../support/clip_setup.dart';
import '../../support/fake_background_bridge.dart';
import '../../support/fake_media_bridge.dart';
import '../../support/fixed_clock.dart';
import '../../support/test_database.dart';

/// The phone's own storage, as MediaStore names it.
const phone = 'external_primary';

/// An SD card.
const card = '1234-5678';

/// A [FakeMediaBridge] that also records the arguments of the calls the
/// scanner and the verifier page or batch: `(afterGeneration, limit)` of each
/// `videosAddedAfter` and `(volume, ids)` of each `videosByIds`.
class RecordingBridge extends FakeMediaBridge {
  final List<(String, int, int)> addedAfter = [];
  final List<(String, List<int>)> byIds = [];

  @override
  Future<List<MediaVideo>> videosAddedAfter(
    String volumeName,
    int afterGeneration,
    List<String> folders,
    int limit,
  ) {
    addedAfter.add((volumeName, afterGeneration, limit));
    return super.videosAddedAfter(volumeName, afterGeneration, folders, limit);
  }

  @override
  Future<List<MediaVideo>> videosByIds(String volumeName, List<int> ids) {
    byIds.add((volumeName, List.of(ids)));
    return super.videosByIds(volumeName, ids);
  }

  /// Puts [videos] on [volume] (after the ones there) and sets the volume's
  /// generation to the highest generation it holds, with version [version].
  void put(
    List<MediaVideo> videos, {
    String volume = phone,
    String version = 'v1',
    int? generation,
  }) {
    final list = videosByVolume.putIfAbsent(volume, () => [])..addAll(videos);
    final highest = list.fold(
      0,
      (best, v) => v.generationAdded > best ? v.generationAdded : best,
    );
    setVolume(volume, version: version, generation: generation ?? highest);
  }

  /// Adds or replaces [volume] in the volume list.
  void setVolume(String volume, {required String? version, int? generation}) {
    final at = volumeList.indexWhere((v) => v.name == volume);
    final entry = MediaVolume(
      name: volume,
      version: version,
      generation: generation ?? (at < 0 ? 0 : volumeList[at].generation),
    );
    if (at < 0) {
      volumeList.add(entry);
    } else {
      volumeList[at] = entry;
    }
  }

  /// Removes [volume] from the list (a removed SD card).
  void removeVolume(String volume) =>
      volumeList.removeWhere((v) => v.name == volume);

  /// How many times [method] was called.
  int count(String method) => calls.where((c) => c == method).length;
}

/// Everything the media tests need, on a fresh in-memory database.
class MediaHarness {
  MediaHarness({
    DateTime? now,
    RecordingBridge? bridge,
    FakeBackgroundBridge? background,
    ZoneRepository Function(AppDatabase, FixedClock)? zones,
  }) : db = testDatabase(),
       clock = FixedClock(now ?? DateTime.utc(2026, 6, 1, 9)),
       bridge = bridge ?? RecordingBridge(),
       background = background ?? FakeBackgroundBridge() {
    addTearDown(db.close);
    clips = ClipsRepository(db, clock);
    phoneState = PhoneStateRepository(db, clock);
    settings = SettingsRepository(db, clock);
    this.zones = (zones ?? ZoneRepository.new)(db, clock);
    zoneSync = ZoneSync(this.bridge, this.zones, clock);
    scanner = scannerWith(clips);
    verifier = MediaVerifier(this.bridge, clips, phoneState, queue, clock);
  }

  final AppDatabase db;
  final FixedClock clock;
  final RecordingBridge bridge;

  /// The background bridge the scanner reads the shade action from (D-106).
  final FakeBackgroundBridge background;
  final MediaWorkQueue queue = MediaWorkQueue();
  late final ClipsRepository clips;
  late final PhoneStateRepository phoneState;
  late final SettingsRepository settings;
  late final ZoneRepository zones;
  late final ZoneSync zoneSync;
  late final MediaScanner scanner;
  late final MediaVerifier verifier;

  /// A scanner on the same bridge, phone state and queue, with another clips
  /// repository (to inject a failure).
  MediaScanner scannerWith(ClipsRepository clips) => MediaScanner(
    bridge,
    clips,
    phoneState,
    settings,
    zones,
    zoneSync,
    queue,
    clock,
    background,
  );

  /// Switches Shooting mode on with [baselines] (by volume name).
  Future<ShootingState> turnOn(Map<String, VolumeBaseline> baselines) =>
      phoneState.turnShootingOn(baselines);

  /// Turns Shooting mode on the way the app does: every mounted volume's
  /// current version and generation.
  Future<ShootingState> turnOnNow() => turnOn({
    for (final v in bridge.volumeList)
      if (v.version != null)
        v.name: VolumeBaseline(version: v.version!, generation: v.generation),
  });

  Future<VolumeBaseline?> baselineOf(String volume) async =>
      (await phoneState.loadShooting()).baselines[volume];

  /// The clips in To tag (pending), oldest first.
  Future<List<Clip>> toTag() => clips.watchInbox(InboxState.pending).first;

  Future<List<Clip>> skipped() => clips.watchInbox(InboxState.skipped).first;

  /// Every clip row, by id.
  Future<List<Clip>> allClips() async =>
      await clips.clipsByIds(await clips.allClipIds());

  /// Saves [videos] as detected clips (in To tag), as an earlier scan would.
  Future<List<int>> store(List<MediaVideo> videos, {String? zoneId}) =>
      clips.saveDetected([
        for (final v in videos)
          newClipFrom(v, now: clock.now(), zoneId: zoneId),
      ]);

  Future<Clip> clip(int id) async => (await clips.clipsByIds({id})).single;
}

/// Waits (a turn of the event loop at a time) until [condition] holds, and
/// fails the test when it does not within [turns] turns.
Future<void> until(bool Function() condition, {int turns = 2000}) async {
  for (var i = 0; i < turns; i++) {
    if (condition()) return;
    await Future<void>.delayed(Duration.zero);
  }
  fail('condition never held');
}

/// Lets every queued job that can run, run (a few hundred event-loop turns).
Future<void> settle() async {
  for (var i = 0; i < 300; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// Captures every log record (the raw message and error, so a leak cannot
/// hide behind the formatter).
List<LogRecord> captureLogs() {
  final records = <LogRecord>[];
  final sub = Logger.root.onRecord.listen(records.add);
  addTearDown(sub.cancel);
  return records;
}

/// Every log record as one string: message, error and the logger's name.
String logText(List<LogRecord> records) =>
    [for (final r in records) '${r.loggerName} ${r.message} ${r.error ?? ''}']
        .join('\n');
