import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/features/tagging/views/stage_fit.dart';

/// The tag player's cover-or-contain rule (D-171, D-180): a clip covers the
/// stage unless covering would cut more than 20 % of it.
void main() {
  const screen = Size(360, 800);
  const s24 = Size(384, 832);

  test('9:16 on 360 × 800 crops exactly 20 % and covers', () {
    // Exactly the limit still covers (the handoff: "more than 20 %"). In
    // floating point the sum lands a hair under .2 for 1080 × 1920, but a
    // hair over it (0.20000000000000007) for 216 × 384 and 27 × 48, and for
    // 1053 × 1872 on the S24's 1080 × 2400 pixels: the rule must allow for
    // that rounding.
    for (final (area, clip) in [
      (screen, const Size(1080, 1920)),
      (screen, const Size(216, 384)),
      (screen, const Size(27, 48)),
      (const Size(1080, 2400), const Size(1053, 1872)),
    ]) {
      expect(coverCrop(area: area, clip: clip), closeTo(.2, 1e-9));
      expect(
        stageFit(area: area, clip: clip),
        BoxFit.cover,
        reason: '$clip',
      );
    }
  });

  test('a hair over 20 % is contained', () {
    const clip = Size(1094, 1920);
    expect(coverCrop(area: screen, clip: clip), closeTo(.2102, 1e-3));
    expect(stageFit(area: screen, clip: clip), BoxFit.contain);
  });

  test('9:16 on the S24 (384 × 832) crops 18 % and covers', () {
    const clip = Size(1080, 1920);
    expect(coverCrop(area: s24, clip: clip), closeTo(.1795, 1e-3));
    expect(stageFit(area: s24, clip: clip), BoxFit.cover);
  });

  test('16:9 is contained', () {
    const clip = Size(1920, 1080);
    expect(coverCrop(area: screen, clip: clip), closeTo(.747, 1e-3));
    expect(stageFit(area: screen, clip: clip), BoxFit.contain);
  });

  test('1:1 is contained', () {
    const clip = Size(1080, 1080);
    expect(coverCrop(area: screen, clip: clip), closeTo(.55, 1e-9));
    expect(stageFit(area: screen, clip: clip), BoxFit.contain);
  });

  test('3:4 is contained', () {
    const clip = Size(1080, 1440);
    expect(coverCrop(area: screen, clip: clip), closeTo(.40, 1e-9));
    expect(stageFit(area: screen, clip: clip), BoxFit.contain);
  });

  test('4:5 is contained', () {
    const clip = Size(1080, 1350);
    expect(coverCrop(area: screen, clip: clip), closeTo(.4375, 1e-9));
    expect(stageFit(area: screen, clip: clip), BoxFit.contain);
  });

  test('a clip as tall as the screen shape crops nothing', () {
    const clip = Size(1080, 2400);
    expect(coverCrop(area: screen, clip: clip), closeTo(0, 1e-9));
    expect(stageFit(area: screen, clip: clip), BoxFit.cover);
  });

  test('the crop is the same whichever side is cut', () {
    // A stage wider than the clip cuts the top and bottom instead.
    const wide = Size(800, 360);
    expect(
      coverCrop(area: wide, clip: const Size(1920, 1080)),
      closeTo(coverCrop(area: screen, clip: const Size(1080, 1920)), 1e-9),
    );
    expect(stageFit(area: wide, clip: const Size(1920, 1080)), BoxFit.cover);
    expect(stageFit(area: wide, clip: const Size(1080, 1920)), BoxFit.contain);
  });

  test('an empty or unknown size covers', () {
    const vertical = Size(1080, 1920);
    const nan = Size(double.nan, double.nan);
    const infinite = Size(360, double.infinity);
    for (final (area, clip) in [
      (screen, Size.zero),
      (screen, const Size(0, 1920)),
      (screen, const Size(1080, 0)),
      (screen, nan),
      (screen, const Size(-1080, -1920)),
      (Size.zero, vertical),
      (const Size(0, 800), vertical),
      (nan, vertical),
      (infinite, vertical),
    ]) {
      expect(
        stageFit(area: area, clip: clip),
        BoxFit.cover,
        reason: '$area $clip',
      );
      expect(
        coverCrop(area: area, clip: clip),
        0,
        reason: '$area $clip',
      );
    }
  });
}
