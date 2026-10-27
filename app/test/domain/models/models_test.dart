import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/domain/models/app_settings.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/models/clip_fingerprint.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/domain/models/reel.dart';
import 'package:taketray/domain/models/reel_reference.dart';
import 'package:taketray/domain/models/vn_copy.dart';
import 'package:taketray/domain/models/vn_session.dart';
import 'package:taketray/domain/models/zone_entry.dart';

/// Encodes to JSON text and back, as a file on disk would.
Map<String, dynamic> viaText(Map<String, dynamic> json) =>
    jsonDecode(jsonEncode(json)) as Map<String, dynamic>;

void main() {
  final fingerprint = ClipFingerprint(
    sizeBytes: 12345678,
    durationMs: 9500,
    dateTakenUtc: DateTime.utc(2026, 3, 10, 8, 30, 15, 250),
    displayName: 'VID_20260310_140015.mp4',
  );

  group('JSON round-trips', () {
    test('Reel, with and without a description', () {
      final reel = Reel(
        id: 1,
        name: 'Goa 🌴',
        description: 'Beach trip',
        status: ReelStatus.ready,
        createdAt: DateTime.utc(2026, 3, 10, 12, 0, 0, 123),
        updatedAt: DateTime.utc(2026, 3, 11),
      );
      expect(Reel.fromJson(reel.toJson()), reel);
      expect(Reel.fromJson(viaText(reel.toJson())), reel);

      final bare = reel.copyWith(description: null);
      expect(Reel.fromJson(viaText(bare.toJson())), bare);
    });

    test('ClipFingerprint', () {
      expect(
        ClipFingerprint.fromJson(viaText(fingerprint.toJson())),
        fingerprint,
      );
    });

    test('Clip from MediaStore, with every optional field', () {
      final clip = Clip(
        id: 7,
        source: ClipSource.mediaStore,
        mediaStoreId: 4242,
        volumeName: 'external_primary',
        fingerprint: fingerprint,
        width: 1080,
        height: 1920,
        mimeType: 'video/mp4',
        timeZoneId: 'Asia/Kolkata',
        generationAdded: 99,
        firstSeenAt: DateTime.utc(2026, 3, 10, 9),
        missing: true,
        lastVerifiedAt: DateTime.utc(2026, 3, 12),
      );
      expect(Clip.fromJson(clip.toJson()), clip);
      expect(Clip.fromJson(viaText(clip.toJson())), clip);
    });

    test('Clip from the picker, with no optional fields', () {
      final clip = Clip(
        id: 8,
        source: ClipSource.picker,
        pickerUri: 'content://media/picker/0/x/1',
        fingerprint: fingerprint,
        width: 720,
        height: 1280,
        mimeType: 'video/quicktime',
        firstSeenAt: DateTime.utc(2026, 3, 10, 9),
        missing: false,
      );
      expect(Clip.fromJson(viaText(clip.toJson())), clip);
    });

    test('NewClip, both kinds', () {
      final detected = NewClip.mediaStore(
        mediaStoreId: 1,
        volumeName: 'external_primary',
        fingerprint: fingerprint,
        width: 1080,
        height: 1920,
        mimeType: 'video/mp4',
        timeZoneId: 'Europe/London',
        generationAdded: 5,
      );
      final picked = NewClip.picker(
        pickerUri: 'content://media/picker/0/x/2',
        fingerprint: fingerprint,
        width: 1080,
        height: 1920,
        mimeType: 'video/mp4',
      );
      expect(NewClip.fromJson(viaText(detected.toJson())), detected);
      expect(NewClip.fromJson(viaText(picked.toJson())), picked);
    });

    test('ReelReference, with and without a label', () {
      final reference = ReelReference(
        id: 3,
        reelId: 1,
        url: 'https://www.instagram.com/reel/ABC/',
        source: ReferenceSource.instagram,
        label: 'Transition idea',
        createdAt: DateTime.utc(2026, 3, 10),
      );
      expect(ReelReference.fromJson(viaText(reference.toJson())), reference);

      final bare = reference.copyWith(label: null);
      expect(ReelReference.fromJson(viaText(bare.toJson())), bare);
    });

    test('VnSession', () {
      final session = VnSession(
        reelId: 1,
        folderName: 'Goa (2)',
        createdAt: DateTime.utc(2026, 3, 10),
      );
      expect(VnSession.fromJson(viaText(session.toJson())), session);
    });

    test('VnCopy', () {
      const copy = VnCopy(
        reelId: 1,
        clipId: 7,
        copyMediaStoreId: 555,
        fileName: '2026-03-10_14-00-15.mp4',
        sizeBytes: 12345678,
      );
      expect(VnCopy.fromJson(viaText(copy.toJson())), copy);
    });

    test('ZoneEntry', () {
      final entry = ZoneEntry(
        at: DateTime.utc(2026, 3, 10, 12),
        zoneId: 'Europe/London',
      );
      expect(ZoneEntry.fromJson(viaText(entry.toJson())), entry);
    });

    test('AppSettings', () {
      const settings = AppSettings(
        watchedFolders: ['DCIM/Camera', 'Movies/Edits'],
        eveningReminderEnabled: false,
        eveningReminderMinutes: 1200,
      );
      expect(AppSettings.fromJson(viaText(settings.toJson())), settings);
    });

    test('times come back as UTC', () {
      final entry = ZoneEntry.fromJson(
        viaText(ZoneEntry(at: DateTime.utc(2026), zoneId: 'UTC').toJson()),
      );
      expect(entry.at.isUtc, isTrue);
    });
  });

  group('AppSettings', () {
    test('defaults: DCIM/Camera, reminder on at 21:00', () {
      const settings = AppSettings();
      expect(settings.watchedFolders, ['DCIM/Camera']);
      expect(settings.eveningReminderEnabled, isTrue);
      expect(settings.eveningReminderMinutes, 1260);
      expect(settings.eveningReminderMinutes, 21 * 60);
    });

    test('an empty JSON object gives the defaults', () {
      expect(AppSettings.fromJson(const {}), const AppSettings());
    });
  });

  group('models are immutable values', () {
    test('equal fields are equal, copyWith changes one field', () {
      final a = ZoneEntry(at: DateTime.utc(2026), zoneId: 'UTC');
      final b = ZoneEntry(at: DateTime.utc(2026), zoneId: 'UTC');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      final c = a.copyWith(zoneId: 'Asia/Kolkata');
      expect(c.zoneId, 'Asia/Kolkata');
      expect(a.zoneId, 'UTC');
    });

    test('a settings list cannot be changed in place', () {
      const settings = AppSettings();
      expect(() => settings.watchedFolders.add('x'), throwsUnsupportedError);
    });
  });

  group('NewClip identity', () {
    test('mediaStore() and picker() set the source', () {
      final detected = NewClip.mediaStore(
        mediaStoreId: 1,
        volumeName: 'external_primary',
        fingerprint: fingerprint,
        width: 1,
        height: 1,
        mimeType: 'video/mp4',
      );
      expect(detected.source, ClipSource.mediaStore);
      expect(detected.pickerUri, isNull);

      final picked = NewClip.picker(
        pickerUri: 'content://x',
        fingerprint: fingerprint,
        width: 1,
        height: 1,
        mimeType: 'video/mp4',
      );
      expect(picked.source, ClipSource.picker);
      expect(picked.mediaStoreId, isNull);
      expect(picked.volumeName, isNull);
    });

    test('the main constructor refuses a half-empty mediaStore identity', () {
      expect(
        () => NewClip(
          source: ClipSource.mediaStore,
          mediaStoreId: 1,
          fingerprint: fingerprint,
          width: 1,
          height: 1,
          mimeType: 'video/mp4',
        ),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => NewClip(
          source: ClipSource.mediaStore,
          volumeName: 'external_primary',
          fingerprint: fingerprint,
          width: 1,
          height: 1,
          mimeType: 'video/mp4',
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('the main constructor refuses a picker clip with no URI', () {
      expect(
        () => NewClip(
          source: ClipSource.picker,
          fingerprint: fingerprint,
          width: 1,
          height: 1,
          mimeType: 'video/mp4',
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('fromJson also refuses a half-empty identity', () {
      final json = NewClip.picker(
        pickerUri: 'content://x',
        fingerprint: fingerprint,
        width: 1,
        height: 1,
        mimeType: 'video/mp4',
      ).toJson()..remove('pickerUri');
      expect(() => NewClip.fromJson(json), throwsA(isA<AssertionError>()));
    });
  });
}
