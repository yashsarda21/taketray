import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/models/clip_fingerprint.dart';
import 'package:taketray/domain/models/enums.dart';

/// A detected clip for a screen test: shot at [shot] (default 2026-10-28
/// 09:41 local), [durationMs] long, on the phone's own storage.
Clip testClip(
  int id, {
  DateTime? shot,
  int durationMs = 32000,
  bool missing = false,
}) => Clip(
  id: id,
  source: ClipSource.mediaStore,
  fingerprint: ClipFingerprint(
    sizeBytes: 1000000 + id,
    durationMs: durationMs,
    dateTakenUtc: (shot ?? DateTime(2026, 10, 28, 9, 41)).toUtc(),
    displayName: 'VID_$id.mp4',
  ),
  width: 1080,
  height: 1920,
  mimeType: 'video/mp4',
  firstSeenAt: DateTime.utc(2026, 10, 28, 10),
  missing: missing,
  mediaStoreId: id,
  volumeName: 'external_primary',
);
