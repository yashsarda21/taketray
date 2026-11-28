import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/features/clips/widgets/media_counts.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';

/// `clipsAndPhotosText` (D-200, R13-1): in a mixed count "clips" counts the
/// videos only.
void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  String text(int videos, int photos) =>
      clipsAndPhotosText(l10n, videos: videos, photos: photos);

  test('8 and 2: "8 clips and 2 photos"', () {
    expect(text(8, 2), '8 clips and 2 photos');
  });

  test('1 and 1: "1 clip and 1 photo"', () {
    expect(text(1, 1), '1 clip and 1 photo');
  });

  test('0 and 2: "2 photos"', () {
    expect(text(0, 2), '2 photos');
    expect(text(0, 1), '1 photo');
  });

  test('5 and 0: exactly reelCardClips(5)', () {
    expect(text(5, 0), l10n.reelCardClips(5));
    expect(text(1, 0), l10n.reelCardClips(1));
    expect(text(0, 0), l10n.reelCardClips(0));
  });
}
