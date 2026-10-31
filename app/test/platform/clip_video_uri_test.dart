import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/platform/media_bridge.dart';

import '../support/clips.dart';

void main() {
  group('clipVideoUri', () {
    test('builds the MediaStore content uri', () {
      final clip = testClip(42);

      expect(
        clipVideoUri(clip),
        Uri.parse('content://media/external_primary/video/media/42'),
      );
    });

    test("uses the clip's own volume", () {
      final clip = testClip(7).copyWith(volumeName: '1a2b-3c4d');

      expect(
        clipVideoUri(clip).toString(),
        'content://media/1a2b-3c4d/video/media/7',
      );
    });

    test('picker uri passes through', () {
      const picked =
          'content://media/picker/0/com.android.providers.media.photopicker'
          '/media/1000000033';
      final clip = testClip(5).copyWith(
        source: ClipSource.picker,
        mediaStoreId: null,
        volumeName: null,
        pickerUri: picked,
      );

      expect(clipVideoUri(clip), Uri.parse(picked));
    });

    test('detached id gives null', () {
      // A clip whose video was detached from MediaStore has no usable
      // identity: its id is cleared, or is not a real row number.
      expect(clipVideoUri(testClip(1).copyWith(mediaStoreId: null)), isNull);
      expect(clipVideoUri(testClip(1).copyWith(mediaStoreId: 0)), isNull);
      expect(clipVideoUri(testClip(1).copyWith(mediaStoreId: -1)), isNull);
      expect(clipVideoUri(testClip(1).copyWith(volumeName: null)), isNull);
      expect(clipVideoUri(testClip(1).copyWith(volumeName: '')), isNull);
    });

    test('missing flag gives null', () {
      expect(clipVideoUri(testClip(1, missing: true)), isNull);
      expect(
        clipVideoUri(
          testClip(2, missing: true).copyWith(
            source: ClipSource.picker,
            mediaStoreId: null,
            volumeName: null,
            pickerUri: 'content://picker/2',
          ),
        ),
        isNull,
      );
    });

    test('a picker clip with no uri gives null', () {
      final clip = testClip(3).copyWith(
        source: ClipSource.picker,
        mediaStoreId: null,
        volumeName: null,
        pickerUri: null,
      );

      expect(clipVideoUri(clip), isNull);
      expect(clipVideoUri(clip.copyWith(pickerUri: '')), isNull);
    });

    test('a clip never plays the identity of the other source', () {
      // The identity is the source's own: a stray field of the other kind is
      // not used (the wrong video is the worst bug).
      final store = testClip(9).copyWith(pickerUri: 'content://picker/other');
      expect(
        clipVideoUri(store).toString(),
        'content://media/external_primary/video/media/9',
      );

      final picked = testClip(9)
          .copyWith(source: ClipSource.picker, pickerUri: 'content://picker/9');
      expect(clipVideoUri(picked).toString(), 'content://picker/9');
    });

    test('an address that does not parse gives null', () {
      final clip = testClip(3).copyWith(
        source: ClipSource.picker,
        mediaStoreId: null,
        volumeName: null,
        pickerUri: 'content://[bad',
      );

      expect(clipVideoUri(clip), isNull);
    });
  });
}
