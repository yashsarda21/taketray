import 'package:taketray_ui/src/tokens/tokens.g.dart';

/// Fixed sizes from the design tokens. Read them as `context.tt.sizes`.
class TtSizes {
  /// The token sizes; the same in every theme.
  const new();

  /// Minimum touch target (48 dp).
  double get touchTarget => TtSizeTokens.touchTarget;

  /// Small icon (18 dp), as in buttons.
  double get iconSmall => TtSizeTokens.iconSmall;

  /// Standard icon (24 dp).
  double get icon => TtSizeTokens.icon;

  /// Large icon (32 dp).
  double get iconLarge => TtSizeTokens.iconLarge;

  /// Top app bar height (64 dp).
  double get topAppBar => TtSizeTokens.topAppBar;

  /// Height of a reel chip in the tag player (56 dp).
  double get reelChip => TtSizeTokens.reelChip;

  /// Clip tile width / height (3:4).
  double get clipTileAspect => TtSizeTokens.clipTileAspect;

  /// Left and right screen margin (16 dp).
  double get screenGutter => TtSizeTokens.screenGutter;

  /// Width the screens are designed at (360 dp).
  double get designWidth => TtSizeTokens.designWidth;
}
