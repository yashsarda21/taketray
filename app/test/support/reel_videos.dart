import 'package:taketray/domain/models/media.dart';
import 'package:taketray/domain/rules/media_clip.dart';

import 'fake_media_bridge.dart';
import 'vm_harness.dart';

/// The phone's clock in the reel tests: after every date they use.
final DateTime reelTestNow = DateTime.utc(2026, 10, 30, 12);

/// A [VmHarness] whose clock is [reelTestNow], so the dates of the test
/// videos are not "in the future" for `shotAt`.
VmHarness reelHarness() => VmHarness(now: reelTestNow);

/// A video for a reel test: [id] is its MediaStore id, [shot] when it was
/// shot (UTC; 2026-10-28 09:id by default), [horizontal] swaps the size.
MediaVideo reelVideo(
  int id, {
  DateTime? shot,
  int durationMs = 4000,
  bool horizontal = false,
}) => fakeVideo(
  id: id,
  generation: id,
  durationMs: durationMs,
  sizeBytes: 1000 + id,
  dateTakenMs:
      (shot ?? DateTime.utc(2026, 10, 28, 9, id)).millisecondsSinceEpoch,
  width: horizontal ? 1920 : 1080,
  height: horizontal ? 1080 : 1920,
);

/// Saves [videos] as clips of reel [reelId] (zone [zoneId], null for none)
/// and returns their ids in order. With [onPhone] the videos are also on the
/// fake phone, so a verify finds them; without it they are gone from it.
Future<List<int>> putInReel(
  VmHarness h,
  int reelId,
  List<MediaVideo> videos, {
  String? zoneId,
  bool onPhone = true,
}) {
  if (onPhone) {
    h.bridge.put(videos);
  } else if (h.bridge.volumeList.every((v) => v.name != phone)) {
    // The videos are gone, but the phone's storage is there to say so.
    h.bridge.setVolume(phone, version: 'v1', generation: 1);
  }
  return h.media.clips.addNewClipsToReel(reelId, [
    for (final v in videos) newClipFrom(v, now: reelTestNow, zoneId: zoneId),
  ]);
}
