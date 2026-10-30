import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/models/clip_fingerprint.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/domain/rules/media_clip.dart';

import '../../support/fake_media_bridge.dart';

void main() {
  final now = DateTime.utc(2026, 10, 28, 12);

  group('newClipFrom', () {
    test('maps every field', () {
      final v = fakeVideo(
        id: 42,
        generation: 9,
        volume: '1a2b-3c4d',
        sizeBytes: 123456,
        name: 'clip.mp4',
        durationMs: 7300,
        dateTakenMs: 1780000000123,
        width: 1080,
        height: 1920,
        mimeType: 'video/quicktime',
      );
      expect(
        newClipFrom(v, now: now, zoneId: 'Asia/Kolkata'),
        NewClip.mediaStore(
          mediaStoreId: 42,
          volumeName: '1a2b-3c4d',
          fingerprint: ClipFingerprint(
            sizeBytes: 123456,
            durationMs: 7300,
            dateTakenUtc: DateTime.fromMillisecondsSinceEpoch(
              1780000000123,
              isUtc: true,
            ),
            displayName: 'clip.mp4',
          ),
          width: 1080,
          height: 1920,
          mimeType: 'video/quicktime',
          timeZoneId: 'Asia/Kolkata',
          generationAdded: 9,
        ),
      );
    });

    test('null duration and size map to 0', () {
      final v = fakeVideo(
        id: 1,
        sizeBytes: 0,
        durationMs: null,
        width: null,
        height: null,
      );
      final clip = newClipFrom(v, now: now, zoneId: null);
      expect(clip.fingerprint.durationMs, 0);
      expect(clip.fingerprint.sizeBytes, 0);
      expect(clip.width, 0);
      expect(clip.height, 0);
    });

    test('null mime type is video/*', () {
      const v = MediaVideo(
        volumeName: 'external_primary',
        mediaStoreId: 1,
        generationAdded: 1,
        sizeBytes: 10,
        displayName: 'a.mp4',
        relativePath: 'DCIM/Camera/',
        isPending: false,
      );
      expect(newClipFrom(v, now: now, zoneId: null).mimeType, 'video/*');
    });

    test('zone id passed through', () {
      final v = fakeVideo(id: 1);
      expect(
        newClipFrom(v, now: now, zoneId: 'Europe/London').timeZoneId,
        'Europe/London',
      );
      expect(newClipFrom(v, now: now, zoneId: null).timeZoneId, isNull);
      // Verbatim, even when it is not a zone Dart knows.
      expect(
        newClipFrom(v, now: now, zoneId: ' Mars/Olympus ').timeZoneId,
        ' Mars/Olympus ',
      );
    });

    test('identity is volume + id', () {
      final clip = newClipFrom(
        fakeVideo(id: 77, volume: '1a2b-3c4d'),
        now: now,
        zoneId: null,
      );
      expect(clip.source, ClipSource.mediaStore);
      expect(clip.volumeName, '1a2b-3c4d');
      expect(clip.mediaStoreId, 77);
      expect(clip.pickerUri, isNull);
    });

    test('the fingerprint date is the shooting date, with its fallback', () {
      final v = fakeVideo(
        id: 1,
        dateTakenMs: null,
        dateAddedSec: 1780000001,
        dateModifiedSec: 1780000002,
      );
      expect(
        newClipFrom(v, now: now, zoneId: null).fingerprint.dateTakenUtc,
        DateTime.utc(2026, 5, 28, 20, 26, 41),
      );
      expect(
        DateTime.fromMillisecondsSinceEpoch(1780000001000, isUtc: true),
        DateTime.utc(2026, 5, 28, 20, 26, 41),
      );
    });
  });

  group('isUsable', () {
    test('a finished video with a length is usable', () {
      expect(isUsable(fakeVideo(id: 1, durationMs: 1)), isTrue);
      expect(isUsable(fakeVideo(id: 1, durationMs: 60000)), isTrue);
    });

    test('a pending video is not usable', () {
      expect(isUsable(fakeVideo(id: 1, pending: true)), isFalse);
    });

    test('a zero, negative or unknown length is not usable', () {
      expect(isUsable(fakeVideo(id: 1, durationMs: 0)), isFalse);
      expect(isUsable(fakeVideo(id: 1, durationMs: -5)), isFalse);
      expect(isUsable(fakeVideo(id: 1, durationMs: null)), isFalse);
    });

    test('a zero or negative size is not usable (I-1)', () {
      expect(isUsable(fakeVideo(id: 1, sizeBytes: 0)), isFalse);
      expect(isUsable(fakeVideo(id: 1, sizeBytes: -1)), isFalse);
      expect(isUsable(fakeVideo(id: 1, sizeBytes: 1)), isTrue);
    });
  });
}
