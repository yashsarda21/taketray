import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/domain/rules/photo_clip.dart';

PickedVideo _pick({int? taken, int? modified}) => PickedVideo(
  uri: 'content://media/picker/0/x/media/1',
  sizeBytes: 10,
  displayName: 'IMG_1.jpg',
  persisted: true,
  dateTakenMs: taken,
  dateModifiedMs: modified,
);

void main() {
  final now = DateTime.utc(2026, 11, 28, 12);
  final nowMs = now.millisecondsSinceEpoch;
  const day = 24 * 60 * 60 * 1000;

  DateTime at(int ms) => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);

  group('isPhotoMimeType', () {
    test('image/jpeg, image/heic, IMAGE/PNG, image/* yes; video/mp4, video/*, '
        '"", "imagex/y" no', () {
      for (final yes in ['image/jpeg', 'image/heic', 'IMAGE/PNG', 'image/*']) {
        expect(isPhotoMimeType(yes), isTrue, reason: yes);
      }
      for (final no in ['video/mp4', 'video/*', '', 'imagex/y', 'image']) {
        expect(isPhotoMimeType(no), isFalse, reason: no);
      }
    });
  });

  group('photoMimeTypeOf', () {
    test('a photo pick with no type or a non-image type is image/*', () {
      expect(defaultPhotoMimeType, 'image/*');
      expect(photoMimeTypeOf(null), 'image/*');
      expect(photoMimeTypeOf(''), 'image/*');
      expect(photoMimeTypeOf('application/octet-stream'), 'image/*');
      expect(photoMimeTypeOf('video/mp4'), 'image/*');
      expect(photoMimeTypeOf('image/heic'), 'image/heic');
      expect(photoMimeTypeOf('IMAGE/PNG'), 'IMAGE/PNG');
    });
  });

  group('pickedPhotoShotAt', () {
    test('taken wins when plausible', () {
      final shot = pickedPhotoShotAt(
        _pick(taken: 1700000000000, modified: 1690000000000),
        now: now,
      );
      expect(shot, DateTime.utc(2023, 11, 14, 22, 13, 20));
      expect(shot.isUtc, isTrue);
    });

    test('an impossible taken date falls to the modified date', () {
      for (final taken in [-1, nowMs + 2 * day]) {
        expect(
          pickedPhotoShotAt(
            _pick(taken: taken, modified: 1690000000000),
            now: now,
          ),
          at(1690000000000),
          reason: 'taken $taken',
        );
      }
      // No taken date at all: the same.
      expect(
        pickedPhotoShotAt(_pick(modified: 1690000000000), now: now),
        at(1690000000000),
      );
    });

    test('the modified date is read in milliseconds, not seconds', () {
      // Read as seconds, 1690000000 would land in 2023; as milliseconds it is
      // 19 days after 1970-01-01, and the instant must equal exactly that.
      expect(
        pickedPhotoShotAt(_pick(modified: 1690000000), now: now),
        at(1690000000),
      );
    });

    test('neither plausible gives now', () {
      expect(pickedPhotoShotAt(_pick(), now: now), now);
      expect(
        pickedPhotoShotAt(
          _pick(taken: -5, modified: nowMs + 3 * day),
          now: now,
        ),
        now,
      );
      // A local `now` still gives a UTC instant.
      expect(pickedPhotoShotAt(_pick(), now: now.toLocal()).isUtc, isTrue);
    });

    test('now + 24 h exactly is still plausible; one ms more is not', () {
      expect(
        pickedPhotoShotAt(
          _pick(taken: nowMs + day, modified: 1690000000000),
          now: now,
        ),
        at(nowMs + day),
      );
      expect(
        pickedPhotoShotAt(
          _pick(taken: nowMs + day + 1, modified: 1690000000000),
          now: now,
        ),
        at(1690000000000),
      );
      // The same bound for the modified date.
      expect(
        pickedPhotoShotAt(_pick(modified: nowMs + day), now: now),
        at(nowMs + day),
      );
      expect(
        pickedPhotoShotAt(_pick(modified: nowMs + day + 1), now: now),
        now,
      );
    });

    test('zero is plausible (not before 1970), for either date', () {
      expect(pickedPhotoShotAt(_pick(taken: 0), now: now), at(0));
      expect(pickedPhotoShotAt(_pick(modified: 0), now: now), at(0));
    });
  });
}
