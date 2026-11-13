import 'package:taketray/domain/models/media.dart';

import '../../support/fake_media_bridge.dart';

/// A video for these tests: [size] bytes, [seconds] long, shot at [shot]
/// (UTC).
MediaVideo sizedVideo(
  int id, {
  required DateTime shot,
  int seconds = 4,
  int size = 1000,
}) => fakeVideo(
  id: id,
  generation: id,
  durationMs: seconds * 1000,
  sizeBytes: size,
  dateTakenMs: shot.millisecondsSinceEpoch,
  width: 1080,
  height: 1920,
);
