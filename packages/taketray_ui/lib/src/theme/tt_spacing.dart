import 'package:taketray_ui/src/tokens/tokens.g.dart';

/// Spacing scale (4 dp grid) from the design tokens. Read it as
/// `context.tt.spacing`.
class TtSpacing {
  /// The token spacing scale; the same in every theme.
  const new();

  /// 0 dp.
  double get none => TtSpaceTokens.s0;

  /// 4 dp.
  double get xxs => TtSpaceTokens.s1;

  /// 8 dp.
  double get xs => TtSpaceTokens.s2;

  /// 12 dp.
  double get s => TtSpaceTokens.s3;

  /// 16 dp.
  double get m => TtSpaceTokens.s4;

  /// 20 dp.
  double get l => TtSpaceTokens.s5;

  /// 24 dp.
  double get xl => TtSpaceTokens.s6;

  /// 32 dp.
  double get xxl => TtSpaceTokens.s8;

  /// 40 dp.
  double get x3l => TtSpaceTokens.s10;

  /// 48 dp.
  double get x4l => TtSpaceTokens.s12;

  /// 64 dp.
  double get x5l => TtSpaceTokens.s16;

  /// Left and right screen margin (16 dp).
  double get gutter => TtSizeTokens.screenGutter;

  /// Gap between tiles in the clip grid (4 dp).
  double get gridGap => TtSizeTokens.gridGap;
}
