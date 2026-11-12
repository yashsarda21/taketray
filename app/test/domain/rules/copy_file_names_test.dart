import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/domain/rules/copy_file_names.dart';

CopyNameSource src(int id, DateTime at, [String ext = 'mp4']) =>
    CopyNameSource(clipId: id, localShotAt: at, extension: ext);

void main() {
  final shot = DateTime.utc(2026, 10, 12, 14, 32, 5);

  group('copyExtension', () {
    test('the display name wins when it is a known video extension', () {
      for (final e in ['mp4', 'mov', 'm4v', '3gp', 'mkv', 'webm']) {
        expect(copyExtension('clip.$e', 'video/avi'), e);
      }
    });

    test('the extension is lower-cased', () {
      expect(copyExtension('IMG_1.MOV', 'video/mp4'), 'mov');
      expect(copyExtension('a.Mp4', 'video/quicktime'), 'mp4');
    });

    test('the last dot counts', () {
      expect(copyExtension('a.mov.mp4', 'video/quicktime'), 'mp4');
      expect(copyExtension('my.trip.mov', 'video/mp4'), 'mov');
    });

    test('an unknown extension falls back to the MIME type', () {
      expect(copyExtension('a.xyz', 'video/quicktime'), 'mov');
      expect(copyExtension('a.avi', 'video/mp4'), 'mp4');
    });

    test('MIME mapping', () {
      expect(copyExtension('a', 'video/mp4'), 'mp4');
      expect(copyExtension('a', 'video/quicktime'), 'mov');
      expect(copyExtension('a', 'video/3gpp'), '3gp');
      expect(copyExtension('a', 'video/x-matroska'), 'mkv');
      expect(copyExtension('a', 'video/webm'), 'webm');
    });

    test('the MIME type is matched without regard to case', () {
      expect(copyExtension('a', 'Video/QuickTime'), 'mov');
    });

    test('an unknown MIME type gives mp4', () {
      expect(copyExtension('a', 'video/x-unknown'), 'mp4');
      expect(copyExtension('a', ''), 'mp4');
      expect(copyExtension('a.xyz', 'application/octet-stream'), 'mp4');
    });

    test('a name that starts with the dot is its extension', () {
      expect(copyExtension('.mov', 'video/mp4'), 'mov');
      expect(copyExtension('.xyz', 'video/quicktime'), 'mov');
    });

    test('no dot or a trailing dot falls back to the MIME type', () {
      expect(copyExtension('noext', 'video/quicktime'), 'mov');
      expect(copyExtension('trailing.', 'video/webm'), 'webm');
      expect(copyExtension('', 'video/3gpp'), '3gp');
    });
  });

  group('copyFileNames', () {
    test('an empty list gives an empty map', () {
      expect(copyFileNames([], {}), <int, String>{});
    });

    test('names come from the fields as given', () {
      expect(copyFileNames([src(7, shot)], {}), {7: '2026-10-12_14-32-05.mp4'});
    });

    test('numbers are zero padded', () {
      expect(copyFileNames([src(1, DateTime.utc(2026, 1, 2, 3, 4, 5))], {}), {
        1: '2026-01-02_03-04-05.mp4',
      });
    });

    test('a local-zone DateTime is read by its fields too', () {
      expect(copyFileNames([src(1, DateTime(2026, 10, 12, 14, 32, 5))], {}), {
        1: '2026-10-12_14-32-05.mp4',
      });
    });

    test('the extension is used as given', () {
      expect(copyFileNames([src(1, shot, 'mov')], {}), {
        1: '2026-10-12_14-32-05.mov',
      });
    });

    test('two clips in one second get _2, a third _3, in order', () {
      expect(copyFileNames([src(5, shot), src(3, shot), src(9, shot)], {}), {
        5: '2026-10-12_14-32-05.mp4',
        3: '2026-10-12_14-32-05_2.mp4',
        9: '2026-10-12_14-32-05_3.mp4',
      });
    });

    test('sub-second differences do not matter', () {
      final a = DateTime.utc(2026, 10, 12, 14, 32, 5, 100);
      final b = DateTime.utc(2026, 10, 12, 14, 32, 5, 900);
      expect(copyFileNames([src(1, a), src(2, b)], {}), {
        1: '2026-10-12_14-32-05.mp4',
        2: '2026-10-12_14-32-05_2.mp4',
      });
    });

    test('a taken name blocks it, case-insensitively', () {
      expect(copyFileNames([src(1, shot)], {'2026-10-12_14-32-05.mp4'}), {
        1: '2026-10-12_14-32-05_2.mp4',
      });
      expect(copyFileNames([src(1, shot)], {'2026-10-12_14-32-05.MP4'}), {
        1: '2026-10-12_14-32-05_2.mp4',
      });
    });

    test('an upper-case extension still clashes with the same name', () {
      expect(copyFileNames([src(1, shot, 'MP4'), src(2, shot, 'MP4')], {}), {
        1: '2026-10-12_14-32-05.MP4',
        2: '2026-10-12_14-32-05_2.MP4',
      });
      expect(
        copyFileNames([src(1, shot, 'MP4')], {'2026-10-12_14-32-05.mp4'}),
        {1: '2026-10-12_14-32-05_2.MP4'},
      );
    });

    test('taken _2 is skipped too', () {
      expect(
        copyFileNames(
          [src(1, shot)],
          {'2026-10-12_14-32-05.mp4', '2026-10-12_14-32-05_2.mp4'},
        ),
        {1: '2026-10-12_14-32-05_3.mp4'},
      );
    });

    test('a taken _2 alone does not block the plain name', () {
      expect(copyFileNames([src(1, shot)], {'2026-10-12_14-32-05_2.mp4'}), {
        1: '2026-10-12_14-32-05.mp4',
      });
    });

    test('a clash with a taken name and an earlier clip both count', () {
      expect(
        copyFileNames(
          [src(1, shot), src(2, shot)],
          {'2026-10-12_14-32-05.mp4'},
        ),
        {1: '2026-10-12_14-32-05_2.mp4', 2: '2026-10-12_14-32-05_3.mp4'},
      );
    });

    test('the same stem with different extensions does not clash', () {
      expect(copyFileNames([src(1, shot), src(2, shot, 'mov')], {}), {
        1: '2026-10-12_14-32-05.mp4',
        2: '2026-10-12_14-32-05.mov',
      });
      expect(
        copyFileNames([src(1, shot, 'mov')], {'2026-10-12_14-32-05.mp4'}),
        {1: '2026-10-12_14-32-05.mov'},
      );
    });

    test('the repeated hour at a clock change never overwrites', () {
      // 01:30 happens twice on the day the clocks go back; both clips read
      // 01:30:00 on the wall clock.
      final first = DateTime.utc(2026, 10, 25, 1, 30);
      final second = DateTime.utc(2026, 10, 25, 1, 30);
      expect(copyFileNames([src(1, first), src(2, second)], {}), {
        1: '2026-10-25_01-30-00.mp4',
        2: '2026-10-25_01-30-00_2.mp4',
      });
    });

    test('a duplicate clip id is refused', () {
      expect(
        () => copyFileNames([src(1, shot), src(2, shot), src(1, shot)], {}),
        throwsArgumentError,
      );
      expect(
        () => copyFileNames([src(1, shot), src(1, shot)], {}),
        throwsArgumentError,
      );
    });

    test('distinct ids are accepted', () {
      expect(copyFileNames([src(1, shot), src(2, shot)], {}).length, 2);
    });

    test('the taken set is not changed', () {
      final taken = {'x.mp4'};
      copyFileNames([src(1, shot)], taken);
      expect(taken, {'x.mp4'});
    });
  });
}
