import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/domain/rules/browse_folders.dart';

const phone = 'external_primary';
const card = '1234-5678';

VideoFolder folder(String path, {int count = 3, String volume = phone}) =>
    VideoFolder(volumeName: volume, relativePath: path, videoCount: count);

/// The relative paths [browseFolders] keeps, in its order.
List<String> pathsOf(List<VideoFolder> all) => [
  for (final f in browseFolders(all)) f.relativePath,
];

void main() {
  group("WhatsApp's Sent folders are hidden (D-111 ruling 3)", () {
    test('a Sent folder under a WhatsApp segment is hidden', () {
      expect(
        pathsOf([
          folder(
            'Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Video/Sent/',
          ),
          folder(
            'Android/media/com.whatsapp.w4b/WhatsApp Business/Media/WhatsApp '
            'Business Video/Sent/',
          ),
          folder('Movies/WhatsApp/Sent/'),
        ]),
        isEmpty,
      );
    });

    test('case is ignored, for both the segment and Sent', () {
      expect(
        pathsOf([
          folder('movies/whatsapp/sent/'),
          folder('MOVIES/WHATSAPP VIDEO/SENT/'),
          folder('Movies/WhatsApp/sEnT/'),
        ]),
        isEmpty,
      );
    });

    test(
      'Sent anywhere else, and WhatsApp folders that are not Sent, stay',
      () {
        expect(
          pathsOf([
            folder('DCIM/Sent/', count: 6),
            folder('Movies/Sent stuff/', count: 5),
            folder('WhatsApp Video/', count: 4),
            folder('Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Video/'),
            folder('Sent/', count: 2),
            // The last segment decides: a folder inside Sent is not Sent.
            folder('Movies/WhatsApp/Sent/Old/', count: 1),
          ]),
          [
            'DCIM/Sent/',
            'Movies/Sent stuff/',
            'WhatsApp Video/',
            'Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Video/',
            'Sent/',
            'Movies/WhatsApp/Sent/Old/',
          ],
        );
      },
    );

    test('a segment must start with WhatsApp: com.whatsapp alone does not '
        'count, and Sent is the whole last segment', () {
      expect(
        pathsOf([
          folder('Android/media/com.whatsapp/Sent/', count: 2),
          folder('Movies/WhatsApp/Sent2/', count: 1),
        ]),
        ['Android/media/com.whatsapp/Sent/', 'Movies/WhatsApp/Sent2/'],
      );
    });

    test('a path without its trailing slash is read the same way', () {
      expect(pathsOf([folder('Movies/WhatsApp/Sent')]), isEmpty);
    });
  });

  test('a folder with no videos is hidden', () {
    expect(
      pathsOf([
        folder('Movies/Empty/', count: 0),
        folder('Movies/Odd/', count: -1),
        folder('Movies/Full/', count: 1),
      ]),
      ['Movies/Full/'],
    );
  });

  group('names', () {
    test('the name is the last path segment', () {
      final [f] = browseFolders([folder('Android/media/x/GoPro/')]);
      expect(f.name, 'GoPro');
      expect(f.isMainFolder, isFalse);
      expect(f.volumeName, phone);
      expect(f.relativePath, 'Android/media/x/GoPro/');
      expect(f.videoCount, 3);
    });

    test('the volume root gets the main-folder key, with no translation', () {
      final [f] = browseFolders([folder('')]);
      expect(f.name, BrowseFolder.mainFolder);
      expect(f.isMainFolder, isTrue);
      expect(f.relativePath, '', reason: 'the path the bridge pages with');
      expect(f.detail, isNull);
    });

    test('a path of only slashes is the root too', () {
      final [f] = browseFolders([folder('/')]);
      expect(f.isMainFolder, isTrue);
    });

    test('a unique name has no detail', () {
      final all = browseFolders([
        folder('DCIM/Camera/'),
        folder('Movies/GoPro/'),
      ]);
      expect([for (final f in all) f.detail], [null, null]);
    });

    test('two folders with one name get their parent segment as detail', () {
      final all = browseFolders([
        folder('DCIM/Camera/', count: 9),
        folder('Movies/Camera/', count: 2),
        folder('Movies/GoPro/', count: 1),
      ]);
      expect(
        [for (final f in all) (f.name, f.detail)],
        [('Camera', 'DCIM'), ('Camera', 'Movies'), ('GoPro', null)],
      );
    });

    test('the names are compared without case', () {
      final all = browseFolders([
        folder('DCIM/Camera/', count: 9),
        folder('Pictures/camera/', count: 2),
      ]);
      expect([for (final f in all) f.detail], ['DCIM', 'Pictures']);
    });

    test('on two volumes, the detail adds the volume', () {
      final all = browseFolders([
        folder('DCIM/Camera/', count: 9),
        folder('DCIM/Camera/', count: 2, volume: card),
      ]);
      expect(
        [for (final f in all) f.detail],
        ['DCIM · $phone', 'DCIM · $card'],
      );
    });

    test('a name on two volumes adds the volume to every one of them', () {
      final all = browseFolders([
        folder('Movies/Clips/', count: 9),
        folder('Download/Clips/', count: 5),
        folder('Clips/', count: 2, volume: card),
      ]);
      expect(
        [for (final f in all) f.detail],
        ['Movies · $phone', 'Download · $phone', card],
      );
    });

    test('two roots (phone and card) are told apart by the volume', () {
      final all = browseFolders([
        folder('', count: 4),
        folder('', count: 2, volume: card),
      ]);
      expect(
        [for (final f in all) (f.isMainFolder, f.detail)],
        [(true, phone), (true, card)],
      );
    });
  });

  group('order', () {
    test('DCIM/Camera first, then by count, descending', () {
      expect(
        pathsOf([
          folder('Movies/A/', count: 5),
          folder('DCIM/Camera/', count: 1),
          folder('Movies/B/', count: 50),
          folder('Movies/C/', count: 7),
        ]),
        ['DCIM/Camera/', 'Movies/B/', 'Movies/C/', 'Movies/A/'],
      );
    });

    test('DCIM/Camera is matched without case and on every volume', () {
      expect(
        pathsOf([
          folder('Movies/B/', count: 50),
          folder('dcim/camera/', count: 1, volume: card),
          folder('DCIM/Camera/', count: 2),
          folder('DCIM/Camera/Sub/', count: 40),
        ]),
        ['DCIM/Camera/', 'dcim/camera/', 'Movies/B/', 'DCIM/Camera/Sub/'],
      );
    });

    test('a tie on count goes by name', () {
      expect(
        pathsOf([folder('x/Zed/'), folder('y/alpha/'), folder('z/Beta/')]),
        ['y/alpha/', 'z/Beta/', 'x/Zed/'],
      );
    });

    test('the order is total: the same input in any order gives one list', () {
      final input = [
        folder('Movies/Camera/'),
        folder('DCIM/Camera/', volume: card),
        folder('Pictures/Camera/'),
        folder('Movies/camera/'),
        folder('Camera/', volume: card),
        folder(''),
        folder('DCIM/Camera/'),
      ];
      final expected = pathsOf(input);
      expect(pathsOf(input.reversed.toList()), expected);
      expect(pathsOf([...input.skip(3), ...input.take(3)]), expected);
      expect(
        [
          for (final f in browseFolders(input.reversed.toList()))
            (f.volumeName, f.relativePath),
        ],
        [for (final f in browseFolders(input)) (f.volumeName, f.relativePath)],
      );
    });
  });

  test('BrowseFolder has value equality', () {
    expect(
      browseFolders([folder('Movies/A/')]),
      browseFolders([folder('Movies/A/')]),
    );
  });
}
