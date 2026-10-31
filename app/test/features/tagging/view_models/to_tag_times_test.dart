import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/data/media/clip_time.dart';
import 'package:taketray/features/tagging/view_models/to_tag_controller.dart';
import 'package:taketray/features/tagging/view_models/to_tag_times.dart';
import 'package:taketray/platform/media_bridge.dart';

import '../../../support/clips.dart';
import '../../../support/fake_media_bridge.dart';
import '../../../support/view_model_fakes.dart';

void main() {
  test('the times of the waiting clips, from ClipTimeService', () async {
    final bridge = FakeMediaBridge()..currentZone = 'Asia/Kolkata';
    final toTag = FakeToTag([
      testClip(1, shot: DateTime.utc(2026, 10, 28, 4, 11)),
    ]);
    final container = ProviderContainer.test(
      overrides: [
        mediaBridgeProvider.overrideWithValue(bridge),
        toTagControllerProvider.overrideWith(() => toTag),
      ],
    )..listen(toTagTimesProvider, (_, _) {});

    final first = await container.read(toTagTimesProvider.future);

    // The test clips have no zone of their own: the phone's (Kolkata).
    expect(first, {
      1: ClipLocalTime(
        wallClock: DateTime.utc(2026, 10, 28, 9, 41),
        zoneId: 'Asia/Kolkata',
        isPhoneZone: true,
      ),
    });

    // A new list (a scan added a clip) gives new times.
    toTag.clips.add([
      testClip(1, shot: DateTime.utc(2026, 10, 28, 4, 11)),
      testClip(2, shot: DateTime.utc(2026, 10, 28, 5)),
    ]);
    await pumpEventQueue();
    final second = await container.read(toTagTimesProvider.future);
    expect(second.keys, [1, 2]);
    expect(second[2]!.wallClock, DateTime.utc(2026, 10, 28, 10, 30));
    // Clip 1 came from the cache: one more call, for clip 2 only.
    expect(bridge.zoneOffsetRequests.last.$2, [
      DateTime.utc(2026, 10, 28, 5).millisecondsSinceEpoch,
    ]);
  });
}
