import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/domain/rules/chat_folders.dart';

void main() {
  group('isChatFolder', () {
    const chat = [
      // WhatsApp, old and new layouts, and the Business app.
      'WhatsApp/Media/WhatsApp Video',
      'WhatsApp/Media/WhatsApp Video/',
      'Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Video',
      'Android/media/com.whatsapp.w4b/WhatsApp Business/Media/WhatsApp Business Video',
      'WhatsApp Business/Media/WhatsApp Business Video',
      'Movies/WhatsApp',
      // The folder of older phones, on its own under Movies.
      'Movies/WhatsApp Video',
      'Movies/WhatsApp Business Video',
      'movies/whatsapp video/',
      // Telegram.
      'Telegram/Telegram Video',
      'Android/media/org.telegram.messenger/Telegram/Telegram Video',
      'Movies/Telegram',
      // Signal.
      'Signal',
      'Movies/Signal',
      'Android/media/org.thoughtcrime.securesms/Signal',
      // Messenger.
      'Movies/Messenger',
      'Android/media/com.facebook.orca/Messenger',
      // Snapchat.
      'Snapchat',
      'Android/media/com.snapchat.android/Snapchat',
      'Movies/Snapchat',
      // Any case.
      'whatsapp/media',
      'MOVIES/TELEGRAM',
      'Movies/sIgNaL',
      'Android/media/COM.WHATSAPP/x',
    ];
    for (final path in chat) {
      test('$path is a chat folder', () => expect(isChatFolder(path), isTrue));
    }

    const other = [
      'DCIM/Camera',
      'DCIM/Camera/',
      'Movies/Instagram',
      'Pictures/Signals',
      'Download',
      'Movies/Drone',
      'DCIM/OpenCamera',
      'Movies/Telegrams',
      'Movies/MyWhatsApp',
      'Movies/Signal Backup',
      'Movies/Snapchatter',
      'Movies/Messengers',
      'Movies/WhatsApp Videos',
      'Movies/My WhatsApp Video',
      'Movies/WhatsApp Video Backup',
      'Android/media/com.whatsapp.other/x',
      'DCIM/Camera/Signal2',
      '',
      '/',
      'Movies/TakeTray',
    ];
    for (final path in other) {
      test(
        '"$path" is not a chat folder',
        () => expect(isChatFolder(path), isFalse),
      );
    }

    test('the whole name must match, not a part of it', () {
      expect(isChatFolder('Pictures/Signals'), isFalse);
      expect(isChatFolder('Pictures/ASignal'), isFalse);
      expect(isChatFolder('Telegram Desktop'), isFalse);
    });

    test('a slash in the path splits segments; empty segments are ignored', () {
      expect(isChatFolder('//Movies//Signal//'), isTrue);
    });

    test('only A to Z case is folded: a dotless i is not an i', () {
      expect(isChatFolder('Movies/S\u0131gnal'), isFalse);
      expect(isChatFolder('Movies/SIGNAL'), isTrue);
    });
  });

  group('isOwnCopyFolder', () {
    for (final path in [
      'Movies/TakeTray',
      'Movies/TakeTray/',
      'Movies/TakeTray/Reel 1',
      'movies/taketray/x/y',
      'MOVIES/TAKETRAY',
    ]) {
      test("$path is TakeTray's own", () {
        expect(isOwnCopyFolder(path), isTrue);
      });
    }
    for (final path in [
      'Movies/TakeTray Test',
      'Movies/TakeTrayX',
      'DCIM/TakeTray',
      'Movies',
      'Movies/Other/TakeTray',
      'TakeTray/Movies',
      '',
      'Movies/Take Tray',
    ]) {
      test('"$path" is not', () => expect(isOwnCopyFolder(path), isFalse));
    }
  });
}
