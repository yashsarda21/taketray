import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/domain/models/media.dart';

/// Encodes to JSON text and back, as the settings table would store it.
Map<String, dynamic> viaText(Map<String, dynamic> json) =>
    jsonDecode(jsonEncode(json)) as Map<String, dynamic>;

void main() {
  group('JSON round-trips', () {
    test('VolumeBaseline', () {
      const baseline = VolumeBaseline(version: 'v-1:abc', generation: 4821);
      final back = VolumeBaseline.fromJson(viaText(baseline.toJson()));
      expect(back, baseline);
      expect(back.version, 'v-1:abc');
      expect(back.generation, 4821);
    });

    test('ShootingState that is on, with baselines', () {
      final state = ShootingState(
        on: true,
        since: DateTime.utc(2026, 10, 28, 9, 15, 30, 123),
        baselines: const {
          'external_primary': VolumeBaseline(version: 'v1', generation: 10),
          '0000-0000': VolumeBaseline(version: 'v2', generation: 0),
        },
      );
      final back = ShootingState.fromJson(viaText(state.toJson()));
      expect(back, state);
      expect(back.since, DateTime.utc(2026, 10, 28, 9, 15, 30, 123));
      expect(back.since!.isUtc, isTrue);
      expect(back.baselines['0000-0000']!.generation, 0);
      // Nothing about earlier videos is written any more (D-90).
      expect(state.toJson().containsKey('earlierAdded'), isFalse);
    });

    test('ShootingState.off', () {
      final back = ShootingState.fromJson(viaText(ShootingState.off.toJson()));
      expect(back, ShootingState.off);
      expect(back.on, isFalse);
      expect(back.since, isNull);
      expect(back.baselines, isEmpty);
    });

    test('ShootingState stored with earlierAdded (before D-90) still reads, '
        'and the key is ignored', () {
      final state = ShootingState(
        on: true,
        since: DateTime.utc(2026, 10, 28),
        baselines: const {
          'external_primary': VolumeBaseline(version: 'v1', generation: 10),
        },
      );
      for (final old in [true, false]) {
        final json = viaText(state.toJson())..['earlierAdded'] = old;
        expect(ShootingState.fromJson(json), state, reason: '$old');
      }
    });
  });

  group('ShootingState.off', () {
    test('is off, with no start time or baselines', () {
      expect(ShootingState.off.on, isFalse);
      expect(ShootingState.off.since, isNull);
      expect(ShootingState.off.baselines, isEmpty);
    });
  });

  group('MediaVolume', () {
    test('isMounted is version != null', () {
      expect(
        const MediaVolume(
          name: 'external_primary',
          version: 'v',
          generation: 1,
        ).isMounted,
        isTrue,
      );
      expect(
        const MediaVolume(name: '0000-0000', generation: 1).isMounted,
        isFalse,
      );
    });
  });

  group('MediaVideo', () {
    MediaVideo video({String? mimeType}) => MediaVideo(
      volumeName: 'external_primary',
      mediaStoreId: 7,
      generationAdded: 9,
      sizeBytes: 100,
      displayName: 'a.mp4',
      relativePath: 'DCIM/Camera/',
      isPending: false,
      mimeType: mimeType ?? 'video/*',
    );

    test('mimeType defaults to video/*', () {
      const bare = MediaVideo(
        volumeName: 'v',
        mediaStoreId: 1,
        generationAdded: 1,
        sizeBytes: 1,
        displayName: 'a',
        relativePath: 'p/',
        isPending: false,
      );
      expect(bare.mimeType, 'video/*');
      expect(
        bare,
        video().copyWith(
          volumeName: 'v',
          mediaStoreId: 1,
          generationAdded: 1,
          sizeBytes: 1,
          displayName: 'a',
          relativePath: 'p/',
        ),
      );
    });

    test('an explicit mimeType is kept', () {
      expect(video(mimeType: 'video/mp4').mimeType, 'video/mp4');
    });
  });
}
