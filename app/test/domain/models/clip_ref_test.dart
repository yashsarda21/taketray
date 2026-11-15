import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/models/clip_fingerprint.dart';
import 'package:taketray/domain/models/clip_ref.dart';
import 'package:taketray/domain/models/enums.dart';

ClipFingerprint get _fp => ClipFingerprint(
  sizeBytes: 1000,
  durationMs: 5000,
  dateTakenUtc: DateTime.utc(2026, 5, 1, 12),
  displayName: 'VID.mp4',
);

Clip _clip({
  required ClipSource source,
  int? mediaStoreId,
  String? volumeName,
  String? pickerUri,
  String mimeType = 'video/mp4',
}) => Clip(
  id: 1,
  source: source,
  fingerprint: _fp,
  width: 1080,
  height: 1920,
  mimeType: mimeType,
  firstSeenAt: DateTime.utc(2026, 5, 2),
  missing: false,
  mediaStoreId: mediaStoreId,
  volumeName: volumeName,
  pickerUri: pickerUri,
);

void main() {
  test('a MediaStore clip gives volume and id, no URI', () {
    final ref = ClipRef.of(
      _clip(
        source: ClipSource.mediaStore,
        mediaStoreId: 42,
        volumeName: 'external_primary',
        mimeType: 'video/quicktime',
      ),
    );
    expect(ref.volumeName, 'external_primary');
    expect(ref.mediaStoreId, 42);
    expect(ref.pickerUri, isNull);
    expect(ref.mimeType, 'video/quicktime');
  });

  test('a MediaStore clip ignores a stray picker URI', () {
    final ref = ClipRef.of(
      _clip(
        source: ClipSource.mediaStore,
        mediaStoreId: 42,
        volumeName: 'external_primary',
        pickerUri: 'content://x',
      ),
    );
    expect(ref.pickerUri, isNull);
    expect(ref.mediaStoreId, 42);
  });

  test('a picked clip gives its URI only', () {
    final ref = ClipRef.of(
      _clip(
        source: ClipSource.picker,
        pickerUri: 'content://media/picker/0/1',
        mimeType: 'video/webm',
      ),
    );
    expect(ref.pickerUri, 'content://media/picker/0/1');
    expect(ref.volumeName, isNull);
    expect(ref.mediaStoreId, isNull);
    expect(ref.mimeType, 'video/webm');
  });

  test('a picked clip with a volume or id set still gives the URI only', () {
    final ref = ClipRef.of(
      _clip(
        source: ClipSource.picker,
        pickerUri: 'content://media/picker/0/1',
        volumeName: 'external_primary',
        mediaStoreId: 7,
      ),
    );
    expect(ref.pickerUri, 'content://media/picker/0/1');
    expect(ref.volumeName, isNull);
    expect(ref.mediaStoreId, isNull);
  });

  test('equal refs are equal', () {
    final a = ClipRef.of(
      _clip(source: ClipSource.picker, pickerUri: 'content://a'),
    );
    final b = ClipRef.of(
      _clip(source: ClipSource.picker, pickerUri: 'content://a'),
    );
    final c = ClipRef.of(
      _clip(source: ClipSource.picker, pickerUri: 'content://b'),
    );
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a == c, isFalse);
  });

  test('refs differing in one field only are not equal', () {
    const base = ClipRef(
      volumeName: 'external_primary',
      mediaStoreId: 42,
      mimeType: 'video/mp4',
    );
    const sameAsBase = ClipRef(
      volumeName: 'external_primary',
      mediaStoreId: 42,
      mimeType: 'video/mp4',
    );
    const otherMime = ClipRef(
      volumeName: 'external_primary',
      mediaStoreId: 42,
      mimeType: 'video/quicktime',
    );
    const otherVolume = ClipRef(
      volumeName: '1234-ABCD',
      mediaStoreId: 42,
      mimeType: 'video/mp4',
    );
    const otherId = ClipRef(
      volumeName: 'external_primary',
      mediaStoreId: 43,
      mimeType: 'video/mp4',
    );
    const withUri = ClipRef(
      volumeName: 'external_primary',
      mediaStoreId: 42,
      pickerUri: 'content://x',
      mimeType: 'video/mp4',
    );
    expect(base, sameAsBase);
    expect(base.hashCode, sameAsBase.hashCode);
    for (final other in [otherMime, otherVolume, otherId, withUri]) {
      expect(base == other, isFalse);
      // A set tells them apart by == (a hash collision cannot fail this).
      expect({base, other}, hasLength(2));
    }
  });
}
