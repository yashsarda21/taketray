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
  group("TakeTray's own copy folders are hidden (I-2)", () {
    test('every folder under Movies/TakeTray/ on the phone is hidden, the '
        'root too', () {
      expect(
        pathsOf([
          folder('Movies/TakeTray/Goa/', count: 12),
          folder('Movies/TakeTray/Goa Trip/', count: 4),
          folder('Movies/TakeTray/', count: 2),
          folder('Movies/TakeTray', count: 2),
          folder('Movies/TakeTray/Goa/Deeper/', count: 2),
          folder('DCIM/Camera/', count: 1),
        ]),
        ['DCIM/Camera/'],
      );
    });

    test('case is ignored, ASCII only', () {
      expect(
        pathsOf([
          folder('movies/taketray/Goa/'),
          folder('MOVIES/TAKETRAY/Goa/'),
          folder('Movies/TakeTRAY/GOA/'),
        ]),
        isEmpty,
      );
      // A Kelvin sign (U+212A) is not a k, and a dotless i is not an i.
      expect(
        pathsOf([
          folder('Movies/Ta\u212Aetray/Goa/'),
          folder('Mov\u0131es/TakeTray/Goa/'),
        ]),
        ['Movies/Ta\u212Aetray/Goa/', 'Mov\u0131es/TakeTray/Goa/'],
      );
    });

    test('lookalikes stay: TakeTray Test, TakeTrayX, another place', () {
      expect(
        pathsOf([
          folder('Movies/TakeTray Test/', count: 9),
          folder('Movies/TakeTray Test/Goa/', count: 8),
          folder('Movies/TakeTrayX/', count: 7),
          folder('Movies/TakeTrayX/Goa/', count: 6),
          folder('Movies/Take Tray/', count: 5),
          folder('DCIM/TakeTray/Goa/', count: 4),
          folder('Movies/Other/TakeTray/Goa/', count: 3),
          folder('TakeTray/Goa/', count: 2),
        ]),
        [
          'Movies/TakeTray Test/',
          'Movies/TakeTray Test/Goa/',
          'Movies/TakeTrayX/',
          'Movies/TakeTrayX/Goa/',
          'Movies/Take Tray/',
          'DCIM/TakeTray/Goa/',
          'Movies/Other/TakeTray/Goa/',
          'TakeTray/Goa/',
        ],
      );
    });

    test("another storage's Movies/TakeTray/ is not ours and stays", () {
      expect(
        pathsOf([
          folder('Movies/TakeTray/Goa/', count: 5, volume: card),
          folder('Movies/TakeTray/Goa/', count: 3),
        ]),
        ['Movies/TakeTray/Goa/'],
      );
      expect(
        [
          for (final f in browseFolders([
            folder('Movies/TakeTray/Goa/', count: 5, volume: card),
            folder('Movies/TakeTray/Goa/', count: 3),
          ]))
            f.volumeName,
        ],
        [card],
      );
    });
  });

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

    test('a WhatsApp segment anywhere before Sent counts, not only the '
        'immediate parent', () {
      expect(
        pathsOf([
          folder('Movies/WhatsApp/Extra/Sent/'),
          folder('Android/media/com.whatsapp/WhatsApp/Media/Sent/'),
          folder('WhatsApp/A/B/C/Sent'),
        ]),
        isEmpty,
      );
      // No WhatsApp segment at all before it: it stays, whatever the depth.
      expect(
        pathsOf([
          folder('Movies/Extra/Sent/', count: 2),
          folder('A/B/C/Sent/', count: 1),
        ]),
        ['Movies/Extra/Sent/', 'A/B/C/Sent/'],
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
      expect(f.parent, isNull);
      expect(f.storage, isNull);
    });

    test('a path of only slashes is the root too', () {
      final [f] = browseFolders([folder('/')]);
      expect(f.isMainFolder, isTrue);
    });

    test('a unique name has no detail', () {
      final all = browseFolders([
        folder('DCIM/Camera/'),
        folder('Movies/GoPro/'),
        folder('Movies/Clips/', volume: card),
      ]);
      expect(
        [for (final f in all) (f.parent, f.storage)],
        [(null, null), (null, null), (null, null)],
      );
    });

    test('two folders with one name get their parent segment as detail', () {
      final all = browseFolders([
        folder('DCIM/Camera/', count: 9),
        folder('Movies/Camera/', count: 2),
        folder('Movies/GoPro/', count: 1),
      ]);
      expect(
        [for (final f in all) (f.name, f.parent, f.storage)],
        [
          ('Camera', 'DCIM', null),
          ('Camera', 'Movies', null),
          ('GoPro', null, null),
        ],
      );
    });

    test('the names are compared without case', () {
      final all = browseFolders([
        folder('DCIM/Camera/', count: 9),
        folder('Pictures/camera/', count: 2),
      ]);
      expect([for (final f in all) f.parent], ['DCIM', 'Pictures']);
    });

    test('on two volumes, the detail adds the storage: the phone, or other '
        'storage, never the volume name', () {
      final all = browseFolders([
        folder('DCIM/Camera/', count: 9),
        folder('DCIM/Camera/', count: 2, volume: card),
      ]);
      expect(
        [for (final f in all) (f.parent, f.storage)],
        [('DCIM', FolderStorage.phone), ('DCIM', const FolderStorage.other())],
      );
    });

    test('a name on two volumes adds the storage to every one of them', () {
      final all = browseFolders([
        folder('Movies/Clips/', count: 9),
        folder('Download/Clips/', count: 5),
        folder('Clips/', count: 2, volume: card),
      ]);
      expect(
        [for (final f in all) (f.parent, f.storage)],
        [
          ('Movies', FolderStorage.phone),
          ('Download', FolderStorage.phone),
          (null, const FolderStorage.other()),
        ],
      );
    });

    test('two roots (phone and card) are told apart by the storage', () {
      final all = browseFolders([
        folder('', count: 4),
        folder('', count: 2, volume: card),
      ]);
      expect(
        [for (final f in all) (f.isMainFolder, f.parent, f.storage)],
        [
          (true, null, FolderStorage.phone),
          (true, null, const FolderStorage.other()),
        ],
      );
    });

    test('only external_primary is the phone; any other name is other '
        'storage', () {
      final all = browseFolders([
        folder('A/Camera/', count: 9, volume: 'external'),
        folder('B/Camera/', count: 8, volume: 'EXTERNAL_PRIMARY'),
        folder('C/Camera/', count: 7),
      ]);
      expect([for (final f in all) f.storage?.isPhone], [false, false, true]);
    });

    test('with two other storages in the list, each gets a number, in the '
        'order of their volume names, the same on every row', () {
      const usb = '0A0B-0C0D';
      final all = browseFolders([
        folder('DCIM/Camera/', count: 9),
        folder('DCIM/Camera/', count: 8, volume: card),
        folder('DCIM/Camera/', count: 7, volume: usb),
        // Another name on the card alone: the card keeps its number.
        folder('Movies/GoPro/', count: 6),
        folder('GoPro/', count: 5, volume: card),
      ]);
      expect(
        [for (final f in all) (f.volumeName, f.storage)],
        [
          (phone, FolderStorage.phone),
          (card, const FolderStorage.other(2)),
          (usb, const FolderStorage.other(1)),
          (phone, FolderStorage.phone),
          (card, const FolderStorage.other(2)),
        ],
      );
    });

    test('an other storage with no clash of its own still counts for the '
        'numbers', () {
      const usb = '0A0B-0C0D';
      final all = browseFolders([
        folder('DCIM/Camera/', count: 9),
        folder('DCIM/Camera/', count: 8, volume: usb),
        folder('Movies/Only/', count: 1, volume: card),
      ]);
      expect(
        [for (final f in all) f.storage],
        [FolderStorage.phone, const FolderStorage.other(1), null],
      );
    });

    test('a hidden folder does not count for the numbers', () {
      const usb = '0A0B-0C0D';
      final all = browseFolders([
        folder('DCIM/Camera/', count: 9),
        folder('DCIM/Camera/', count: 8, volume: card),
        folder('Movies/Empty/', count: 0, volume: usb),
        folder('Movies/WhatsApp/Sent/', volume: usb),
      ]);
      expect(
        [for (final f in all) f.storage],
        [FolderStorage.phone, const FolderStorage.other()],
      );
    });

    test('FolderStorage has value equality', () {
      expect(FolderStorage.phone, FolderStorage.phone);
      expect(const FolderStorage.other(), const FolderStorage.other());
      expect(const FolderStorage.other(2), const FolderStorage.other(2));
      expect(
        const FolderStorage.other(2).hashCode,
        const FolderStorage.other(2).hashCode,
      );
      expect(const FolderStorage.other(), isNot(FolderStorage.phone));
      expect(const FolderStorage.other(1), isNot(const FolderStorage.other(2)));
      expect(const FolderStorage.other(1), isNot(const FolderStorage.other()));
      expect(FolderStorage.phone.isPhone, isTrue);
      expect(const FolderStorage.other(3).isPhone, isFalse);
      expect(const FolderStorage.other(3).number, 3);
      expect(FolderStorage.phone.number, isNull);
      // Never the volume name (D-10): only the kind and the number.
      expect('${const FolderStorage.other(2)}', 'FolderStorage(other 2)');
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

  test('BrowseFolder is equal only when every field is, the detail '
      'included', () {
    const base = BrowseFolder(
      volumeName: phone,
      relativePath: 'Movies/A/',
      videoCount: 3,
      name: 'A',
      parent: 'Movies',
      storage: FolderStorage.phone,
    );
    BrowseFolder same() => const BrowseFolder(
      volumeName: phone,
      relativePath: 'Movies/A/',
      videoCount: 3,
      name: 'A',
      parent: 'Movies',
      storage: FolderStorage.phone,
    );
    expect(same(), base);
    expect(same().hashCode, base.hashCode);
    final others = [
      const BrowseFolder(
        volumeName: phone,
        relativePath: 'Movies/A/',
        videoCount: 3,
        name: 'A',
        parent: 'Other',
        storage: FolderStorage.phone,
      ),
      const BrowseFolder(
        volumeName: phone,
        relativePath: 'Movies/A/',
        videoCount: 3,
        name: 'A',
        storage: FolderStorage.phone,
      ),
      const BrowseFolder(
        volumeName: phone,
        relativePath: 'Movies/A/',
        videoCount: 3,
        name: 'A',
        parent: 'Movies',
      ),
      const BrowseFolder(
        volumeName: phone,
        relativePath: 'Movies/A/',
        videoCount: 3,
        name: 'A',
        parent: 'Movies',
        storage: FolderStorage.other(),
      ),
      const BrowseFolder(
        volumeName: card,
        relativePath: 'Movies/A/',
        videoCount: 3,
        name: 'A',
        parent: 'Movies',
        storage: FolderStorage.phone,
      ),
      const BrowseFolder(
        volumeName: phone,
        relativePath: 'Movies/B/',
        videoCount: 3,
        name: 'A',
        parent: 'Movies',
        storage: FolderStorage.phone,
      ),
      const BrowseFolder(
        volumeName: phone,
        relativePath: 'Movies/A/',
        videoCount: 4,
        name: 'A',
        parent: 'Movies',
        storage: FolderStorage.phone,
      ),
      const BrowseFolder(
        volumeName: phone,
        relativePath: 'Movies/A/',
        videoCount: 3,
        name: 'B',
        parent: 'Movies',
        storage: FolderStorage.phone,
      ),
    ];
    for (final other in others) {
      expect(other, isNot(base), reason: '$other');
    }
  });
}
